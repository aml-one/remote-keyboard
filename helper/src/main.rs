//! Remote Keyboard helper: BLE central that injects HID boot reports.
//!
//! Phone advertises service `8f7a0001-…` and notifies keyboard/mouse
//! characteristics. This process injects `SendInput` / `CGEvent` / uinput.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{self, Sender};
use std::time::Duration;

use btleplug::api::{
    Central, CentralEvent, Manager as _, Peripheral as _, PeripheralProperties, ScanFilter,
};
use btleplug::platform::{Adapter, Manager, PeripheralId};
use enigo::{Axis, Button, Coordinate, Direction, Enigo, Keyboard, Mouse, Settings};
use futures::StreamExt;
use uuid::Uuid;

mod hid_raw;
mod ui;

enum InjectCmd {
    Keyboard(Vec<u8>),
    Mouse(Vec<u8>),
}

struct Injector {
    enigo: Enigo,
    mods: u8,
    keys: [u8; 6],
    buttons: u8,
    mouse_dx: i32,
    mouse_dy: i32,
    mouse_wheel: i32,
}

impl Injector {
    fn new(enigo: Enigo) -> Self {
        Self {
            enigo,
            mods: 0,
            keys: [0; 6],
            buttons: 0,
            mouse_dx: 0,
            mouse_dy: 0,
            mouse_wheel: 0,
        }
    }

    fn apply_keyboard(&mut self, frame: &[u8]) {
        self.flush_mouse();
        inject_keyboard(&mut self.enigo, frame, &mut self.mods, &mut self.keys);
    }

    fn queue_mouse(&mut self, frame: &[u8]) {
        if frame.len() < 5 || frame[0] != 0x02 {
            return;
        }
        let buttons = frame[1];
        if buttons != self.buttons {
            self.flush_mouse();
            apply_buttons(&mut self.enigo, self.buttons, buttons);
            self.buttons = buttons;
        }
        self.mouse_dx += frame[2] as i8 as i32;
        self.mouse_dy += frame[3] as i8 as i32;
        self.mouse_wheel += frame[4] as i8 as i32;
    }

    fn flush_mouse(&mut self) {
        if self.mouse_dx != 0 || self.mouse_dy != 0 {
            move_pointer_rel(&mut self.enigo, self.mouse_dx, self.mouse_dy);
            self.mouse_dx = 0;
            self.mouse_dy = 0;
        }
        if self.mouse_wheel != 0 {
            let _ = self.enigo.scroll(self.mouse_wheel, Axis::Vertical);
            self.mouse_wheel = 0;
        }
    }
}

/// Enigo is not `Send` on macOS (`CGEventSource`). Own it on a dedicated
/// thread so the BLE task can stay on the tokio runtime.
fn spawn_injector() -> Sender<InjectCmd> {
    let (tx, rx) = mpsc::channel();
    std::thread::Builder::new()
        .name("rk-inject".into())
        .spawn(move || {
            let mut settings = Settings::default();
            settings.linux_delay = 0;
            // Relative SendInput, not 0–65535 absolute (that path jitters).
            settings.windows_subject_to_mouse_speed_and_acceleration_level = true;
            let enigo = match Enigo::new(&settings) {
                Ok(enigo) => enigo,
                Err(error) => {
                    eprintln!("helper: injector {error}");
                    return;
                }
            };
            let mut inj = Injector::new(enigo);
            while let Ok(first) = rx.recv() {
                match first {
                    InjectCmd::Keyboard(frame) => inj.apply_keyboard(&frame),
                    InjectCmd::Mouse(frame) => inj.queue_mouse(&frame),
                }
                while let Ok(more) = rx.try_recv() {
                    match more {
                        InjectCmd::Keyboard(frame) => inj.apply_keyboard(&frame),
                        InjectCmd::Mouse(frame) => inj.queue_mouse(&frame),
                    }
                }
                inj.flush_mouse();
            }
        })
        .expect("inject thread");
    tx
}

const SERVICE: Uuid = Uuid::from_u128(0x8f7a0001_4c6f_4d2e_9a11_7c6ff0000001);
const KEYBOARD: Uuid = Uuid::from_u128(0x8f7a0002_4c6f_4d2e_9a11_7c6ff0000001);
const MOUSE: Uuid = Uuid::from_u128(0x8f7a0003_4c6f_4d2e_9a11_7c6ff0000001);

static CONNECTED: AtomicBool = AtomicBool::new(false);

fn main() -> Result<(), Box<dyn std::error::Error>> {
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

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    runtime.spawn(async {
        loop {
            let retry = match run_once().await {
                Ok(()) => {
                    CONNECTED.store(false, Ordering::Relaxed);
                    false
                }
                Err(error) => {
                    eprintln!("helper: {error}");
                    CONNECTED.store(false, Ordering::Relaxed);
                    true
                }
            };
            if retry {
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }
    });
    ui::run_ui();
    Ok(())
}

fn status_title() -> &'static str {
    if CONNECTED.load(Ordering::Relaxed) {
        "Remote Keyboard · connected"
    } else {
        "Remote Keyboard · waiting"
    }
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

/// Phone advertises as `AOW Keyboard`. Older helpers only matched
/// "remote keyboard", so a running helper never saw the pad.
fn advertised_name_matches(name: &str) -> bool {
    let n = name.trim().to_lowercase();
    n.contains("aow keyboard") || n.contains("remote keyboard")
}

fn looks_like_phone(props: &PeripheralProperties) -> bool {
    if props.services.iter().any(|u| *u == SERVICE) {
        return true;
    }
    if props.service_data.keys().any(|u| *u == SERVICE) {
        return true;
    }
    advertised_name_matches(props.local_name.as_deref().unwrap_or(""))
}

async fn find_and_serve(adapter: &Adapter) -> Result<(), Box<dyn std::error::Error>> {
    // Subscribe before scanning so Windows DeviceDiscovered is not missed.
    let mut events = adapter.events().await?;
    adapter.start_scan(ScanFilter::default()).await?;
    let mut ticker = tokio::time::interval(Duration::from_secs(1));
    loop {
        tokio::select! {
            Some(event) = events.next() => {
                let id = match event {
                    CentralEvent::DeviceDiscovered(id) | CentralEvent::DeviceUpdated(id) => id,
                    _ => continue,
                };
                if try_serve_id(adapter, &id).await? {
                    return Ok(());
                }
            }
            _ = ticker.tick() => {
                for peripheral in adapter.peripherals().await? {
                    let Some(props) = peripheral.properties().await? else {
                        continue;
                    };
                    if !looks_like_phone(&props) {
                        continue;
                    }
                    let name = props.local_name.unwrap_or_else(|| "AOW Keyboard".into());
                    println!("Found {name}");
                    adapter.stop_scan().await.ok();
                    serve_peripheral(peripheral).await?;
                    return Ok(());
                }
            }
        }
    }
}

async fn try_serve_id(
    adapter: &Adapter,
    id: &PeripheralId,
) -> Result<bool, Box<dyn std::error::Error>> {
    let Ok(peripheral) = adapter.peripheral(id).await else {
        return Ok(false);
    };
    let Some(props) = peripheral.properties().await? else {
        return Ok(false);
    };
    if !looks_like_phone(&props) {
        return Ok(false);
    }
    let name = props.local_name.unwrap_or_else(|| "AOW Keyboard".into());
    println!("Found {name}");
    adapter.stop_scan().await.ok();
    serve_peripheral(peripheral).await?;
    Ok(true)
}

async fn serve_peripheral(
    peripheral: btleplug::platform::Peripheral,
) -> Result<(), Box<dyn std::error::Error>> {
    peripheral.connect().await?;
    tokio::time::sleep(Duration::from_millis(400)).await;
    peripheral.discover_services().await?;
    let mut chars: Vec<_> = peripheral
        .characteristics()
        .into_iter()
        .filter(|c| c.uuid == KEYBOARD || c.uuid == MOUSE)
        .collect();
    if chars.is_empty() {
        tokio::time::sleep(Duration::from_millis(700)).await;
        peripheral.discover_services().await?;
        chars = peripheral
            .characteristics()
            .into_iter()
            .filter(|c| c.uuid == KEYBOARD || c.uuid == MOUSE)
            .collect();
    }
    if chars.is_empty() {
        return Err("Phone GATT has no keyboard/mouse characteristics yet".into());
    }
    let mut notifications = peripheral.notifications().await?;
    for characteristic in &chars {
        println!("Subscribe {}", characteristic.uuid);
        peripheral.subscribe(characteristic).await?;
    }
    CONNECTED.store(true, Ordering::Relaxed);
    println!("Connected. Injecting keys and mouse.");
    let injector = spawn_injector();
    while let Some(note) = notifications.next().await {
        let cmd = if note.uuid == KEYBOARD {
            InjectCmd::Keyboard(note.value)
        } else if note.uuid == MOUSE {
            InjectCmd::Mouse(note.value)
        } else {
            continue;
        };
        if injector.send(cmd).is_err() {
            break;
        }
    }
    CONNECTED.store(false, Ordering::Relaxed);
    Ok(())
}

fn inject_key(enigo: &mut Enigo, hid: u8, direction: Direction) {
    if let Some(key) = hid_raw::hid_named(hid) {
        let _ = enigo.key(key, direction);
    } else if let Some(raw) = hid_raw::hid_raw(hid) {
        let _ = enigo.raw(raw, direction);
    }
}

fn inject_keyboard(enigo: &mut Enigo, frame: &[u8], mods: &mut u8, keys: &mut [u8; 6]) {
    if frame.len() < 9 || frame[0] != 0x01 {
        return;
    }
    let next_mods = frame[1];
    let mut next_keys = [0u8; 6];
    next_keys.copy_from_slice(&frame[3..9]);

    fn set_mod(enigo: &mut Enigo, old: u8, new: u8, bit: u8, key: enigo::Key) {
        let was = old & bit != 0;
        let now = new & bit != 0;
        if was == now {
            return;
        }
        let _ = enigo.key(
            key,
            if now {
                Direction::Press
            } else {
                Direction::Release
            },
        );
    }
    set_mod(enigo, *mods, next_mods, 0x01, enigo::Key::Control);
    set_mod(enigo, *mods, next_mods, 0x02, enigo::Key::Shift);
    set_mod(enigo, *mods, next_mods, 0x04, enigo::Key::Alt);
    set_mod(enigo, *mods, next_mods, 0x08, enigo::Key::Meta);
    *mods = next_mods;

    for hid in keys.iter() {
        if *hid == 0 || next_keys.contains(hid) {
            continue;
        }
        inject_key(enigo, *hid, Direction::Release);
    }
    for hid in next_keys.iter() {
        if *hid == 0 || keys.contains(hid) {
            continue;
        }
        inject_key(enigo, *hid, Direction::Press);
    }
    *keys = next_keys;
}

fn apply_buttons(enigo: &mut Enigo, old: u8, new: u8) {
    for (bit, button) in [(1, Button::Left), (2, Button::Right), (4, Button::Middle)] {
        let down = new & bit != 0;
        let was = old & bit != 0;
        if down && !was {
            let _ = enigo.button(button, Direction::Press);
        } else if !down && was {
            let _ = enigo.button(button, Direction::Release);
        }
    }
}

fn move_pointer_rel(enigo: &mut Enigo, dx: i32, dy: i32) {
    if dx == 0 && dy == 0 {
        return;
    }
    #[cfg(windows)]
    {
        // Pixel-accurate. Enigo's default Rel→Abs 0–65535 mapping jitters.
        #[repr(C)]
        struct Point {
            x: i32,
            y: i32,
        }
        extern "system" {
            fn GetCursorPos(point: *mut Point) -> i32;
            fn SetCursorPos(x: i32, y: i32) -> i32;
        }
        let mut point = Point { x: 0, y: 0 };
        unsafe {
            if GetCursorPos(&mut point) != 0 {
                let _ = SetCursorPos(point.x + dx, point.y + dy);
                return;
            }
        }
    }
    let _ = enigo.move_mouse(dx, dy, Coordinate::Rel);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_phone_advertise_name() {
        assert!(advertised_name_matches("AOW Keyboard"));
        assert!(advertised_name_matches("aow keyboard"));
        assert!(advertised_name_matches("Remote Keyboard"));
        assert!(!advertised_name_matches("AirPods"));
        assert!(!advertised_name_matches(""));
    }

    #[test]
    fn azerty_a_sends_physical_q_position() {
        // Pad AZERTY A → HID 0x14 (US Q). Helper must inject that position.
        assert!(hid_raw::hid_named(0x14).is_none());
        assert!(hid_raw::hid_raw(0x14).is_some());
    }
}
