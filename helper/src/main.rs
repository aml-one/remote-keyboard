//! Remote Keyboard helper: BLE central that injects HID boot reports.
//!
//! Phone advertises service `8f7a0001-…` and notifies keyboard/mouse
//! characteristics. This process injects `SendInput` / `CGEvent` / uinput.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use btleplug::api::{Central, CentralEvent, CharPropFlags, Manager as _, Peripheral as _, ScanFilter};
use btleplug::platform::{Adapter, Manager};
use enigo::{Axis, Button, Coordinate, Direction, Enigo, Keyboard, Mouse, Settings};
use futures::StreamExt;
use tokio::sync::Mutex;
use uuid::Uuid;

const SERVICE: Uuid = Uuid::from_u128(0x8f7a0001_4c6f_4d2e_9a11_7c6ff0000001);
const KEYBOARD: Uuid = Uuid::from_u128(0x8f7a0002_4c6f_4d2e_9a11_7c6ff0000001);
const MOUSE: Uuid = Uuid::from_u128(0x8f7a0003_4c6f_4d2e_9a11_7c6ff0000001);

static CONNECTED: AtomicBool = AtomicBool::new(false);

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Remote Keyboard helper");
    println!("Waiting for a phone advertising AOW Keyboard…");
    #[cfg(target_os = "macos")]
    {
        println!("Grant Accessibility to this helper in System Settings → Privacy.");
    }
    #[cfg(target_os = "linux")]
    {
        println!("Linux: this helper uses the session input APIs. For /dev/uinput, add:");
        println!("  KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\"");
    }

    spawn_ui();
    loop {
        match run_once().await {
            Ok(()) => CONNECTED.store(false, Ordering::Relaxed),
            Err(error) => {
                eprintln!("helper: {error}");
                CONNECTED.store(false, Ordering::Relaxed);
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    }
}

fn status_title() -> &'static str {
    if CONNECTED.load(Ordering::Relaxed) {
        "Remote Keyboard · connected"
    } else {
        "Remote Keyboard · waiting"
    }
}

fn spawn_tray() -> Option<tray_icon::TrayIcon> {
    tray_icon::TrayIconBuilder::new()
        .with_tooltip(status_title())
        .build()
        .ok()
}

fn spawn_ui() {
    std::thread::spawn(|| {
        let event_loop = tao::event_loop::EventLoop::new();
        let window = tao::window::WindowBuilder::new()
            .with_title(status_title())
            .with_inner_size(tao::dpi::LogicalSize::new(420.0, 148.0))
            .with_resizable(false)
            .build(&event_loop)
            .ok();
        let tray = spawn_tray();
        let mut last = CONNECTED.load(Ordering::Relaxed);
        event_loop.run(move |event, _, control_flow| {
            *control_flow = tao::event_loop::ControlFlow::WaitUntil(
                std::time::Instant::now() + Duration::from_millis(400),
            );
            let connected = CONNECTED.load(Ordering::Relaxed);
            if connected != last {
                last = connected;
                let title = status_title();
                if let Some(ref window) = window {
                    window.set_title(title);
                }
                if let Some(ref tray) = tray {
                    let _ = tray.set_tooltip(Some(title));
                }
            }
            if let tao::event::Event::WindowEvent {
                event: tao::event::WindowEvent::CloseRequested,
                ..
            } = event
            {
                *control_flow = tao::event_loop::ControlFlow::Exit;
                std::process::exit(0);
            }
        });
    });
}

async fn run_once() -> Result<(), Box<dyn std::error::Error>> {
    let manager = Manager::new().await?;
    let adapters = manager.adapters().await?;
    let adapter = adapters
        .into_iter()
        .next()
        .ok_or("No Bluetooth adapter")?;
    find_and_serve(&adapter).await
}

async fn find_and_serve(adapter: &Adapter) -> Result<(), Box<dyn std::error::Error>> {
    adapter.start_scan(ScanFilter::default()).await?;
    let mut events = adapter.events().await?;
    while let Some(event) = events.next().await {
        if let CentralEvent::DeviceDiscovered(id) = event {
            let Ok(peripheral) = adapter.peripheral(&id).await else {
                continue;
            };
            let Some(props) = peripheral.properties().await? else {
                continue;
            };
            let name = props.local_name.unwrap_or_default();
            let has_service = props.services.iter().any(|u| *u == SERVICE);
            if !has_service && !name.to_lowercase().contains("remote keyboard") {
                continue;
            }
            println!("Found {name}");
            adapter.stop_scan().await.ok();
            serve_peripheral(peripheral).await?;
            return Ok(());
        }
    }
    Ok(())
}

async fn serve_peripheral(
    peripheral: btleplug::platform::Peripheral,
) -> Result<(), Box<dyn std::error::Error>> {
    peripheral.connect().await?;
    peripheral.discover_services().await?;
    CONNECTED.store(true, Ordering::Relaxed);
    println!("Connected. Injecting keys and mouse.");
    let injector = Arc::new(Mutex::new(Enigo::new(&Settings::default())?));
    for characteristic in peripheral.characteristics() {
        if characteristic.uuid == KEYBOARD || characteristic.uuid == MOUSE {
            if characteristic.properties.contains(CharPropFlags::NOTIFY) {
                peripheral.subscribe(&characteristic).await.ok();
            }
        }
    }
    let mut notifications = peripheral.notifications().await?;
    while let Some(note) = notifications.next().await {
        let mut lock = injector.lock().await;
        if note.uuid == KEYBOARD {
            inject_keyboard(&mut lock, &note.value);
        } else if note.uuid == MOUSE {
            inject_mouse(&mut lock, &note.value);
        }
    }
    CONNECTED.store(false, Ordering::Relaxed);
    Ok(())
}

fn hid_to_key(hid: u8) -> Option<enigo::Key> {
    use enigo::Key;
    match hid {
        0x04..=0x1d => Some(Key::Unicode((b'a' + (hid - 0x04)) as char)),
        0x1e => Some(Key::Unicode('1')),
        0x1f => Some(Key::Unicode('2')),
        0x20 => Some(Key::Unicode('3')),
        0x21 => Some(Key::Unicode('4')),
        0x22 => Some(Key::Unicode('5')),
        0x23 => Some(Key::Unicode('6')),
        0x24 => Some(Key::Unicode('7')),
        0x25 => Some(Key::Unicode('8')),
        0x26 => Some(Key::Unicode('9')),
        0x27 => Some(Key::Unicode('0')),
        0x28 => Some(Key::Return),
        0x29 => Some(Key::Escape),
        0x2a => Some(Key::Backspace),
        0x2b => Some(Key::Tab),
        0x2c => Some(Key::Space),
        0x2d => Some(Key::Unicode('-')),
        0x2e => Some(Key::Unicode('=')),
        0x33 => Some(Key::Unicode(';')),
        0x34 => Some(Key::Unicode('\'')),
        0x36 => Some(Key::Unicode(',')),
        0x37 => Some(Key::Unicode('.')),
        0x38 => Some(Key::Unicode('/')),
        0x4c => Some(Key::Delete),
        0x4f => Some(Key::RightArrow),
        0x50 => Some(Key::LeftArrow),
        0x51 => Some(Key::DownArrow),
        0x52 => Some(Key::UpArrow),
        _ => None,
    }
}

fn inject_keyboard(enigo: &mut Enigo, frame: &[u8]) {
    if frame.len() < 9 || frame[0] != 0x01 {
        return;
    }
    let mods = frame[1];
    let _ = enigo.key(
        enigo::Key::Control,
        if mods & 0x01 != 0 {
            Direction::Press
        } else {
            Direction::Release
        },
    );
    let _ = enigo.key(
        enigo::Key::Shift,
        if mods & 0x02 != 0 {
            Direction::Press
        } else {
            Direction::Release
        },
    );
    let _ = enigo.key(
        enigo::Key::Alt,
        if mods & 0x04 != 0 {
            Direction::Press
        } else {
            Direction::Release
        },
    );
    let _ = enigo.key(
        enigo::Key::Meta,
        if mods & 0x08 != 0 {
            Direction::Press
        } else {
            Direction::Release
        },
    );
    for hid in &frame[3..9] {
        if *hid == 0 {
            continue;
        }
        if let Some(key) = hid_to_key(*hid) {
            let _ = enigo.key(key, Direction::Click);
        }
    }
}

fn inject_mouse(enigo: &mut Enigo, frame: &[u8]) {
    if frame.len() < 5 || frame[0] != 0x02 {
        return;
    }
    let buttons = frame[1];
    let dx = frame[2] as i8 as i32;
    let dy = frame[3] as i8 as i32;
    let wheel = frame[4] as i8 as i32;
    if dx != 0 || dy != 0 {
        let _ = enigo.move_mouse(dx, dy, Coordinate::Rel);
    }
    if wheel != 0 {
        let _ = enigo.scroll(wheel, Axis::Vertical);
    }
    for (bit, button) in [(1, Button::Left), (2, Button::Right), (4, Button::Middle)] {
        if buttons & bit != 0 {
            let _ = enigo.button(button, Direction::Click);
        }
    }
}
