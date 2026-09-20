//! USB HID keyboard usages → platform key codes.
//!
//! The phone already remaps AZERTY labels to US HID *positions* so a real
//! Bluetooth HID host types the glyph on the pad. The helper must do the
//! same: inject that physical key and let the OS layout finish the job.
//! Unicode / VK_A-style letters skip the layout and type QWERTY.

/// Named keys that are the same on every layout (Enter, arrows, …).
pub fn hid_named(hid: u8) -> Option<enigo::Key> {
    use enigo::Key;
    Some(match hid {
        0x28 => Key::Return,
        0x29 => Key::Escape,
        0x2A => Key::Backspace,
        0x2B => Key::Tab,
        0x2C => Key::Space,
        0x39 => Key::CapsLock,
        0x4C => Key::Delete,
        0x4F => Key::RightArrow,
        0x50 => Key::LeftArrow,
        0x51 => Key::DownArrow,
        0x52 => Key::UpArrow,
        _ => return None,
    })
}

/// Platform scan / keycode for a HID usage. `None` → use [`hid_named`].
pub fn hid_raw(hid: u8) -> Option<u16> {
    let code = RAW[hid as usize];
    if code == 0 {
        None
    } else {
        Some(code)
    }
}

#[cfg(target_os = "windows")]
const RAW: [u16; 256] = windows_set1();

/// X11 keycode = Linux evdev + 8.
#[cfg(all(unix, not(target_os = "macos")))]
const RAW: [u16; 256] = linux_x11();

#[cfg(target_os = "macos")]
const RAW: [u16; 256] = macos_ansi();

#[cfg(not(any(
    target_os = "windows",
    target_os = "macos",
    all(unix, not(target_os = "macos"))
)))]
const RAW: [u16; 256] = [0; 256];

/// PS/2 Set 1 scancodes. Letters match USB HID positions (Q = 0x10).
#[cfg(target_os = "windows")]
const fn windows_set1() -> [u16; 256] {
    let mut t = [0u16; 256];
    // a–z
    t[0x04] = 0x1E;
    t[0x05] = 0x30;
    t[0x06] = 0x2E;
    t[0x07] = 0x20;
    t[0x08] = 0x12;
    t[0x09] = 0x21;
    t[0x0A] = 0x22;
    t[0x0B] = 0x23;
    t[0x0C] = 0x17;
    t[0x0D] = 0x24;
    t[0x0E] = 0x25;
    t[0x0F] = 0x26;
    t[0x10] = 0x32;
    t[0x11] = 0x31;
    t[0x12] = 0x18;
    t[0x13] = 0x19;
    t[0x14] = 0x10; // Q position — AZERTY types A
    t[0x15] = 0x13;
    t[0x16] = 0x1F;
    t[0x17] = 0x14;
    t[0x18] = 0x16;
    t[0x19] = 0x2F;
    t[0x1A] = 0x11;
    t[0x1B] = 0x2D;
    t[0x1C] = 0x15;
    t[0x1D] = 0x2C;
    // 1–0
    t[0x1E] = 0x02;
    t[0x1F] = 0x03;
    t[0x20] = 0x04;
    t[0x21] = 0x05;
    t[0x22] = 0x06;
    t[0x23] = 0x07;
    t[0x24] = 0x08;
    t[0x25] = 0x09;
    t[0x26] = 0x0A;
    t[0x27] = 0x0B;
    t[0x2D] = 0x0C; // -
    t[0x2E] = 0x0D; // =
    t[0x2F] = 0x1A; // [
    t[0x30] = 0x1B; // ]
    t[0x31] = 0x2B; // \
    t[0x33] = 0x27; // ;
    t[0x34] = 0x28; // '
    t[0x35] = 0x29; // `
    t[0x36] = 0x33; // ,
    t[0x37] = 0x34; // .
    t[0x38] = 0x35; // /
    t[0x3A] = 0x3B; // F1
    t[0x3B] = 0x3C;
    t[0x3C] = 0x3D;
    t[0x3D] = 0x3E;
    t[0x3E] = 0x3F;
    t[0x3F] = 0x40;
    t[0x40] = 0x41;
    t[0x41] = 0x42;
    t[0x42] = 0x43;
    t[0x43] = 0x44; // F10
    t[0x44] = 0x57; // F11
    t[0x45] = 0x58; // F12
    t
}

/// evdev KEY_* + 8 → X11 keycode. Letters share USB HID positions.
#[cfg(all(unix, not(target_os = "macos")))]
const fn linux_x11() -> [u16; 256] {
    let mut t = [0u16; 256];
    let evdev = [
        (0x04u8, 30u16), // KEY_A
        (0x05, 48),
        (0x06, 46),
        (0x07, 32),
        (0x08, 18),
        (0x09, 33),
        (0x0A, 34),
        (0x0B, 35),
        (0x0C, 23),
        (0x0D, 36),
        (0x0E, 37),
        (0x0F, 38),
        (0x10, 50),
        (0x11, 49),
        (0x12, 24),
        (0x13, 25),
        (0x14, 16), // KEY_Q
        (0x15, 19),
        (0x16, 31),
        (0x17, 20),
        (0x18, 22),
        (0x19, 47),
        (0x1A, 17),
        (0x1B, 45),
        (0x1C, 21),
        (0x1D, 44),
        (0x1E, 2),
        (0x1F, 3),
        (0x20, 4),
        (0x21, 5),
        (0x22, 6),
        (0x23, 7),
        (0x24, 8),
        (0x25, 9),
        (0x26, 10),
        (0x27, 11),
        (0x2D, 12),
        (0x2E, 13),
        (0x2F, 26),
        (0x30, 27),
        (0x31, 43),
        (0x33, 39),
        (0x34, 40),
        (0x35, 41),
        (0x36, 51),
        (0x37, 52),
        (0x38, 53),
        (0x3A, 59),
        (0x3B, 60),
        (0x3C, 61),
        (0x3D, 62),
        (0x3E, 63),
        (0x3F, 64),
        (0x40, 65),
        (0x41, 66),
        (0x42, 67),
        (0x43, 68),
        (0x44, 87),
        (0x45, 88),
    ];
    let mut i = 0;
    while i < evdev.len() {
        let (hid, key) = evdev[i];
        t[hid as usize] = key + 8;
        i += 1;
    }
    t
}

/// Carbon `kVK_ANSI_*` — physical ANSI positions, layout applied by macOS.
#[cfg(target_os = "macos")]
const fn macos_ansi() -> [u16; 256] {
    let mut t = [0u16; 256];
    t[0x04] = 0x00; // A
    t[0x05] = 0x0B; // B
    t[0x06] = 0x08;
    t[0x07] = 0x02;
    t[0x08] = 0x0E;
    t[0x09] = 0x03;
    t[0x0A] = 0x05;
    t[0x0B] = 0x04;
    t[0x0C] = 0x22;
    t[0x0D] = 0x26;
    t[0x0E] = 0x28;
    t[0x0F] = 0x25;
    t[0x10] = 0x2E;
    t[0x11] = 0x2D;
    t[0x12] = 0x1F;
    t[0x13] = 0x23;
    t[0x14] = 0x0C; // Q
    t[0x15] = 0x0F;
    t[0x16] = 0x01;
    t[0x17] = 0x11;
    t[0x18] = 0x20;
    t[0x19] = 0x09;
    t[0x1A] = 0x0D;
    t[0x1B] = 0x07;
    t[0x1C] = 0x10;
    t[0x1D] = 0x06;
    t[0x1E] = 0x12; // 1
    t[0x1F] = 0x13;
    t[0x20] = 0x14;
    t[0x21] = 0x15;
    t[0x22] = 0x17;
    t[0x23] = 0x16;
    t[0x24] = 0x1A;
    t[0x25] = 0x1C;
    t[0x26] = 0x19;
    t[0x27] = 0x1D; // 0
    t[0x2D] = 0x1B; // -
    t[0x2E] = 0x18; // =
    t[0x2F] = 0x21; // [
    t[0x30] = 0x1E; // ]
    t[0x31] = 0x2A; // \
    t[0x33] = 0x29; // ;
    t[0x34] = 0x27; // '
    t[0x35] = 0x32; // `
    t[0x36] = 0x2B; // ,
    t[0x37] = 0x2F; // .
    t[0x38] = 0x2C; // /
    t[0x3A] = 0x7A; // F1
    t[0x3B] = 0x78;
    t[0x3C] = 0x63;
    t[0x3D] = 0x76;
    t[0x3E] = 0x60;
    t[0x3F] = 0x61;
    t[0x40] = 0x62;
    t[0x41] = 0x64;
    t[0x42] = 0x65;
    t[0x43] = 0x6D;
    t[0x44] = 0x67;
    t[0x45] = 0x6F;
    t
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn q_position_is_physical_not_unicode() {
        assert!(hid_named(0x14).is_none());
        let q = hid_raw(0x14).expect("Q usage");
        #[cfg(target_os = "windows")]
        assert_eq!(q, 0x10);
        #[cfg(target_os = "macos")]
        assert_eq!(q, 0x0C);
        #[cfg(all(unix, not(target_os = "macos")))]
        assert_eq!(q, 24);
        let a = hid_raw(0x04).expect("A usage");
        assert_ne!(a, q);
    }

    #[test]
    fn enter_is_named() {
        assert!(hid_named(0x28).is_some());
        assert!(hid_raw(0x28).is_none());
    }
}
