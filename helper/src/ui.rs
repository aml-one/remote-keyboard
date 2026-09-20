//! Helper window: AOW pastel card. Close hides to the tray; the helper keeps running.

use std::num::NonZeroU32;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::time::Duration;

use ab_glyph::{Font, FontRef, PxScale, ScaleFont};
use tiny_skia::{
    Color, FillRule, GradientStop, LinearGradient, Paint, PathBuilder, Pixmap, Point,
    PremultipliedColorU8, SpreadMode, Stroke, Transform,
};
use tao::event::{Event, StartCause, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoopBuilder, EventLoopProxy};

use super::{status_title, CONNECTED};

enum UiMsg {
    Show,
    Quit,
}

fn col_bg() -> Color {
    Color::from_rgba8(247, 245, 252, 255)
}
fn col_card() -> Color {
    Color::from_rgba8(255, 255, 255, 255)
}
fn col_stroke() -> Color {
    Color::from_rgba8(233, 228, 245, 255)
}
fn col_ink() -> Color {
    Color::from_rgba8(26, 20, 48, 255)
}
fn col_muted() -> Color {
    Color::from_rgba8(107, 99, 144, 255)
}
fn col_mint() -> Color {
    Color::from_rgba8(92, 203, 180, 255)
}
fn col_amber() -> Color {
    Color::from_rgba8(246, 185, 100, 255)
}
fn col_sky_well() -> Color {
    Color::from_rgba8(232, 242, 254, 255)
}
fn col_pearl() -> Color {
    Color::from_rgba8(252, 250, 255, 255)
}
fn col_wait_pill() -> Color {
    Color::from_rgba8(255, 243, 224, 255)
}
fn col_live_pill() -> Color {
    Color::from_rgba8(230, 247, 242, 255)
}

pub fn run_ui() {
    let event_loop = EventLoopBuilder::<UiMsg>::with_user_event().build();
    let proxy = event_loop.create_proxy();
    let window = tao::window::WindowBuilder::new()
        .with_title(status_title())
        .with_inner_size(tao::dpi::LogicalSize::new(460.0, 248.0))
        .with_min_inner_size(tao::dpi::LogicalSize::new(460.0, 248.0))
        .with_resizable(false)
        .build(&event_loop)
        .ok();
    let Some(window) = window else {
        eprintln!("helper: could not open a window");
        loop {
            std::thread::sleep(Duration::from_secs(60));
        }
    };
    let window = Arc::new(window);
    let fonts = HelperFonts::load();
    let context = match softbuffer::Context::new(window.clone()) {
        Ok(context) => context,
        Err(error) => {
            eprintln!("helper: window surface {error}");
            run_without_surface(event_loop, proxy, window);
            return;
        }
    };
    let mut surface = match softbuffer::Surface::new(&context, window.clone()) {
        Ok(surface) => surface,
        Err(error) => {
            eprintln!("helper: window buffer {error}");
            run_without_surface(event_loop, proxy, window);
            return;
        }
    };
    let mut tray = None;
    let mut last = CONNECTED.load(Ordering::Relaxed);
    window.request_redraw();
    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::WaitUntil(std::time::Instant::now() + Duration::from_millis(400));
        match event {
            Event::NewEvents(StartCause::Init) => {
                tray = spawn_tray(proxy.clone());
            }
            Event::UserEvent(UiMsg::Show) => show_window(&window),
            Event::UserEvent(UiMsg::Quit) => {
                *control_flow = ControlFlow::Exit;
            }
            Event::RedrawRequested(_) => {
                if window.is_visible() {
                    let connected = CONNECTED.load(Ordering::Relaxed);
                    paint(&window, &mut surface, &fonts, connected);
                }
            }
            Event::WindowEvent {
                event: WindowEvent::Resized(_),
                ..
            } => {
                if window.is_visible() {
                    window.request_redraw();
                }
            }
            Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } => hide_window(&window),
            Event::MainEventsCleared => {
                let connected = CONNECTED.load(Ordering::Relaxed);
                if connected != last {
                    last = connected;
                    let title = status_title();
                    window.set_title(title);
                    if let Some(ref tray) = tray {
                        let _ = tray.tray.set_tooltip(Some(title));
                    }
                    if window.is_visible() {
                        window.request_redraw();
                    }
                }
            }
            _ => {}
        }
    });
}

fn run_without_surface(
    event_loop: tao::event_loop::EventLoop<UiMsg>,
    proxy: EventLoopProxy<UiMsg>,
    window: Arc<tao::window::Window>,
) {
    let mut tray = None;
    let mut last = CONNECTED.load(Ordering::Relaxed);
    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::WaitUntil(std::time::Instant::now() + Duration::from_millis(400));
        match event {
            Event::NewEvents(StartCause::Init) => {
                tray = spawn_tray(proxy.clone());
            }
            Event::UserEvent(UiMsg::Show) => show_window(&window),
            Event::UserEvent(UiMsg::Quit) => {
                *control_flow = ControlFlow::Exit;
            }
            Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } => hide_window(&window),
            Event::MainEventsCleared => {
                let connected = CONNECTED.load(Ordering::Relaxed);
                if connected != last {
                    last = connected;
                    let title = status_title();
                    window.set_title(title);
                    if let Some(ref tray) = tray {
                        let _ = tray.tray.set_tooltip(Some(title));
                    }
                }
            }
            _ => {}
        }
    });
}

fn show_window(window: &tao::window::Window) {
    window.set_visible(true);
    window.set_focus();
    window.request_redraw();
}

fn hide_window(window: &tao::window::Window) {
    window.set_visible(false);
}

struct TrayUi {
    tray: tray_icon::TrayIcon,
    _open: tray_icon::menu::MenuItem,
    _quit: tray_icon::menu::MenuItem,
}

fn spawn_tray(proxy: EventLoopProxy<UiMsg>) -> Option<TrayUi> {
    use tray_icon::menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem};
    use tray_icon::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};

    let open = MenuItem::new("Open", true, None);
    let quit = MenuItem::new("Quit", true, None);
    let open_id = open.id().clone();
    let quit_id = quit.id().clone();
    let menu = Menu::with_items(&[&open, &PredefinedMenuItem::separator(), &quit]).ok()?;
    let icon = make_tray_icon()?;
    let tray = TrayIconBuilder::new()
        .with_tooltip(status_title())
        .with_icon(icon)
        .with_menu(Box::new(menu))
        .with_menu_on_left_click(false)
        .build()
        .ok()?;
    TrayIconEvent::set_event_handler(Some({
        let proxy = proxy.clone();
        move |event| {
            let open = matches!(
                event,
                TrayIconEvent::Click {
                    button: MouseButton::Left,
                    button_state: MouseButtonState::Up,
                    ..
                } | TrayIconEvent::DoubleClick {
                    button: MouseButton::Left,
                    ..
                }
            );
            if open {
                let _ = proxy.send_event(UiMsg::Show);
            }
        }
    }));
    MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
        if event.id == open_id {
            let _ = proxy.send_event(UiMsg::Show);
        } else if event.id == quit_id {
            let _ = proxy.send_event(UiMsg::Quit);
        }
    }));
    Some(TrayUi {
        tray,
        _open: open,
        _quit: quit,
    })
}

fn make_tray_icon() -> Option<tray_icon::Icon> {
    let size = 32u32;
    let mut pixmap = Pixmap::new(size, size)?;
    pixmap.fill(Color::from_rgba8(0, 0, 0, 0));
    let s = 1.0_f32;
    draw_trackpad_mark(&mut pixmap, 1.0, 1.0, 30.0, s);
    let mut rgba = vec![0u8; (size * size * 4) as usize];
    for (i, px) in pixmap.pixels().iter().enumerate() {
        rgba[i * 4] = px.red();
        rgba[i * 4 + 1] = px.green();
        rgba[i * 4 + 2] = px.blue();
        rgba[i * 4 + 3] = px.alpha();
    }
    tray_icon::Icon::from_rgba(rgba, size, size).ok()
}

struct HelperFonts {
    regular: Vec<u8>,
    bold: Vec<u8>,
}

impl HelperFonts {
    fn load() -> Self {
        let regular = read_first(regular_font_paths());
        let bold = read_first(bold_font_paths()).or_else(|| regular.clone());
        Self {
            regular: regular.unwrap_or_default(),
            bold: bold.unwrap_or_default(),
        }
    }

    fn regular(&self) -> Option<FontRef<'_>> {
        FontRef::try_from_slice(&self.regular).ok()
    }

    fn bold(&self) -> Option<FontRef<'_>> {
        FontRef::try_from_slice(&self.bold).ok()
    }
}

fn read_first(paths: &[&str]) -> Option<Vec<u8>> {
    for path in paths {
        if let Ok(bytes) = std::fs::read(path) {
            if bytes.len() > 1024 {
                return Some(bytes);
            }
        }
    }
    None
}

fn regular_font_paths() -> &'static [&'static str] {
    &[
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\calibri.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
    ]
}

fn bold_font_paths() -> &'static [&'static str] {
    &[
        r"C:\Windows\Fonts\segoeuib.ttf",
        r"C:\Windows\Fonts\calibrib.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
    ]
}

fn paint(
    window: &tao::window::Window,
    surface: &mut softbuffer::Surface<Arc<tao::window::Window>, Arc<tao::window::Window>>,
    fonts: &HelperFonts,
    connected: bool,
) {
    let size = window.inner_size();
    let Some(width) = NonZeroU32::new(size.width) else {
        return;
    };
    let Some(height) = NonZeroU32::new(size.height) else {
        return;
    };
    if surface.resize(width, height).is_err() {
        return;
    }
    let Ok(mut buffer) = surface.buffer_mut() else {
        return;
    };
    let Some(mut pixmap) = Pixmap::new(width.get(), height.get()) else {
        return;
    };
    let s = window.scale_factor() as f32;
    let w = width.get() as f32;
    let h = height.get() as f32;

    fill_atmosphere(&mut pixmap, w, h, connected, s);
    let pad = 18.0 * s;
    fill_round_rect(
        &mut pixmap,
        pad,
        pad,
        w - pad * 2.0,
        h - pad * 2.0,
        24.0 * s,
        col_card(),
    );
    stroke_round_rect(
        &mut pixmap,
        pad,
        pad,
        w - pad * 2.0,
        h - pad * 2.0,
        24.0 * s,
        col_stroke(),
        s.max(1.0),
    );

    let icon = 72.0 * s;
    let icon_x = pad + 22.0 * s;
    let icon_y = pad + 28.0 * s;
    draw_trackpad_mark(&mut pixmap, icon_x, icon_y, icon, s);

    let text_x = icon_x + icon + 18.0 * s;
    if let Some(bold) = fonts.bold() {
        draw_text(
            &mut pixmap,
            &bold,
            "Remote Keyboard Helper",
            text_x,
            icon_y + 22.0 * s,
            17.0 * s,
            col_ink(),
        );
    }
    let pill_y = icon_y + 34.0 * s;
    let label = if connected { "Connected" } else { "Waiting" };
    let pill_w = 108.0 * s;
    let pill_h = 26.0 * s;
    fill_round_rect(
        &mut pixmap,
        text_x,
        pill_y,
        pill_w,
        pill_h,
        13.0 * s,
        if connected { col_live_pill() } else { col_wait_pill() },
    );
    fill_circle(
        &mut pixmap,
        text_x + 14.0 * s,
        pill_y + pill_h / 2.0,
        4.5 * s,
        if connected { col_mint() } else { col_amber() },
    );
    if let Some(regular) = fonts.regular() {
        draw_text(
            &mut pixmap,
            &regular,
            label,
            text_x + 24.0 * s,
            pill_y + 18.0 * s,
            13.0 * s,
            col_ink(),
        );
        let (line1, line2) = if connected {
            (
                "Keys and mouse come from your phone.",
                "Leave this helper running.",
            )
        } else {
            (
                "Looking for AOW Keyboard on your phone.",
                "Keep Bluetooth on, then tap Connect.",
            )
        };
        draw_text(
            &mut pixmap,
            &regular,
            line1,
            text_x,
            icon_y + 86.0 * s,
            12.5 * s,
            col_muted(),
        );
        draw_text(
            &mut pixmap,
            &regular,
            line2,
            text_x,
            icon_y + 104.0 * s,
            12.5 * s,
            col_muted(),
        );
    }

    for (dest, src) in buffer.iter_mut().zip(pixmap.pixels()) {
        *dest = ((src.red() as u32) << 16) | ((src.green() as u32) << 8) | src.blue() as u32;
    }
    let _ = buffer.present();
}

fn fill_atmosphere(pixmap: &mut Pixmap, w: f32, h: f32, connected: bool, s: f32) {
    pixmap.fill(col_bg());
    let end = if connected {
        Color::from_rgba8(230, 247, 242, 255)
    } else {
        Color::from_rgba8(237, 233, 255, 255)
    };
    if let Some(shader) = LinearGradient::new(
        Point::from_xy(0.0, 0.0),
        Point::from_xy(w, h),
        vec![GradientStop::new(0.0, col_bg()), GradientStop::new(1.0, end)],
        SpreadMode::Pad,
        Transform::identity(),
    ) {
        let mut paint = Paint::default();
        paint.shader = shader;
        paint.anti_alias = true;
        pixmap.fill_rect(
            tiny_skia::Rect::from_xywh(0.0, 0.0, w, h).unwrap(),
            &paint,
            Transform::identity(),
            None,
        );
    }
    let mut wash = Paint::default();
    wash.anti_alias = true;
    wash.set_color(if connected {
        Color::from_rgba8(92, 203, 180, 42)
    } else {
        Color::from_rgba8(124, 111, 240, 40)
    });
    pixmap.fill_path(
        &circle_path(w * 0.18, h * 0.08, 90.0 * s),
        &wash,
        FillRule::Winding,
        Transform::identity(),
        None,
    );
    wash.set_color(Color::from_rgba8(111, 177, 240, 36));
    pixmap.fill_path(
        &circle_path(w * 0.92, h * 0.88, 80.0 * s),
        &wash,
        FillRule::Winding,
        Transform::identity(),
        None,
    );
}

fn draw_trackpad_mark(pixmap: &mut Pixmap, x: f32, y: f32, size: f32, s: f32) {
    fill_round_rect(pixmap, x, y, size, size, 19.0 * s, col_sky_well());
    stroke_round_rect(
        pixmap,
        x,
        y,
        size,
        size,
        19.0 * s,
        Color::from_rgba8(176, 214, 248, 255),
        s,
    );
    let inset = 12.0 * s;
    let plate_h = size - inset * 2.0 - 14.0 * s;
    fill_round_rect(
        pixmap,
        x + inset,
        y + inset,
        size - inset * 2.0,
        plate_h,
        10.0 * s,
        col_pearl(),
    );
    stroke_round_rect(
        pixmap,
        x + inset,
        y + inset,
        size - inset * 2.0,
        plate_h,
        10.0 * s,
        Color::from_rgba8(201, 214, 240, 255),
        s * 0.8,
    );
    let btn_y = y + inset + plate_h + 4.0 * s;
    let btn_h = 10.0 * s;
    let gap = 4.0 * s;
    let btn_w = (size - inset * 2.0 - gap) / 2.0;
    fill_round_rect(pixmap, x + inset, btn_y, btn_w, btn_h, 4.0 * s, col_pearl());
    fill_round_rect(
        pixmap,
        x + inset + btn_w + gap,
        btn_y,
        btn_w,
        btn_h,
        4.0 * s,
        col_pearl(),
    );
}

fn fill_round_rect(pixmap: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, r: f32, color: Color) {
    let Some(path) = round_rect_path(x, y, w, h, r) else {
        return;
    };
    let mut paint = Paint::default();
    paint.anti_alias = true;
    paint.set_color(color);
    pixmap.fill_path(
        &path,
        &paint,
        FillRule::Winding,
        Transform::identity(),
        None,
    );
}

fn stroke_round_rect(
    pixmap: &mut Pixmap,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    r: f32,
    color: Color,
    width: f32,
) {
    let Some(path) = round_rect_path(x, y, w, h, r) else {
        return;
    };
    let mut paint = Paint::default();
    paint.anti_alias = true;
    paint.set_color(color);
    let stroke = Stroke {
        width,
        ..Stroke::default()
    };
    pixmap.stroke_path(&path, &paint, &stroke, Transform::identity(), None);
}

fn fill_circle(pixmap: &mut Pixmap, cx: f32, cy: f32, radius: f32, color: Color) {
    let mut paint = Paint::default();
    paint.anti_alias = true;
    paint.set_color(color);
    pixmap.fill_path(
        &circle_path(cx, cy, radius),
        &paint,
        FillRule::Winding,
        Transform::identity(),
        None,
    );
}

fn circle_path(cx: f32, cy: f32, radius: f32) -> tiny_skia::Path {
    let mut pb = PathBuilder::new();
    pb.push_circle(cx, cy, radius);
    pb.finish().unwrap()
}

fn round_rect_path(x: f32, y: f32, w: f32, h: f32, r: f32) -> Option<tiny_skia::Path> {
    if w <= 0.0 || h <= 0.0 {
        return None;
    }
    let r = r.max(0.0).min(w / 2.0).min(h / 2.0);
    let mut pb = PathBuilder::new();
    pb.move_to(x + r, y);
    pb.line_to(x + w - r, y);
    pb.quad_to(x + w, y, x + w, y + r);
    pb.line_to(x + w, y + h - r);
    pb.quad_to(x + w, y + h, x + w - r, y + h);
    pb.line_to(x + r, y + h);
    pb.quad_to(x, y + h, x, y + h - r);
    pb.line_to(x, y + r);
    pb.quad_to(x, y, x + r, y);
    pb.close();
    pb.finish()
}

fn draw_text(pixmap: &mut Pixmap, font: &FontRef<'_>, text: &str, x: f32, y: f32, size: f32, color: Color) {
    let scale = PxScale::from(size);
    let scaled = font.as_scaled(scale);
    let mut caret = x;
    for ch in text.chars() {
        let glyph = font
            .glyph_id(ch)
            .with_scale_and_position(scale, ab_glyph::point(caret, y));
        caret += scaled.h_advance(glyph.id);
        let Some(outlined) = font.outline_glyph(glyph) else {
            continue;
        };
        let bounds = outlined.px_bounds();
        let sr = color.red();
        let sg = color.green();
        let sb = color.blue();
        outlined.draw(|px, py, cover| {
            if cover < 0.04 {
                return;
            }
            let ix = bounds.min.x as i32 + px as i32;
            let iy = bounds.min.y as i32 + py as i32;
            blend_px(pixmap, ix, iy, sr, sg, sb, cover);
        });
    }
}

fn blend_px(pixmap: &mut Pixmap, x: i32, y: i32, sr: f32, sg: f32, sb: f32, cover: f32) {
    if x < 0 || y < 0 {
        return;
    }
    let (x, y) = (x as u32, y as u32);
    if x >= pixmap.width() || y >= pixmap.height() {
        return;
    }
    let i = (y * pixmap.width() + x) as usize;
    let dst = pixmap.pixels()[i];
    let inv = 1.0 - cover;
    let r = sr * cover + (dst.red() as f32 / 255.0) * inv;
    let g = sg * cover + (dst.green() as f32 / 255.0) * inv;
    let b = sb * cover + (dst.blue() as f32 / 255.0) * inv;
    pixmap.pixels_mut()[i] = PremultipliedColorU8::from_rgba(
        (r * 255.0) as u8,
        (g * 255.0) as u8,
        (b * 255.0) as u8,
        255,
    )
    .unwrap_or(dst);
}
