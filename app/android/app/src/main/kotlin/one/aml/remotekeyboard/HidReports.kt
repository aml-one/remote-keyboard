package one.aml.remotekeyboard

object HidReports {
    const val REPORT_KEYBOARD: Byte = 0x01
    const val REPORT_MOUSE: Byte = 0x02

    // Boot keyboard + relative mouse. Report ID 1 = keys, 2 = pointer.
    val DESCRIPTOR: ByteArray = byteArrayOf(
        0x05, 0x01, // USAGE_PAGE (Generic Desktop)
        0x09, 0x06, // USAGE (Keyboard)
        0xa1.toByte(), 0x01, // COLLECTION (Application)
        0x85.toByte(), REPORT_KEYBOARD, // REPORT_ID (1)
        0x05, 0x07, //   USAGE_PAGE (Keyboard)
        0x19, 0xe0.toByte(), //   USAGE_MINIMUM (LeftControl)
        0x29, 0xe7.toByte(), //   USAGE_MAXIMUM (Right GUI)
        0x15, 0x00, //   LOGICAL_MINIMUM (0)
        0x25, 0x01, //   LOGICAL_MAXIMUM (1)
        0x75, 0x01, //   REPORT_SIZE (1)
        0x95.toByte(), 0x08, //   REPORT_COUNT (8)
        0x81.toByte(), 0x02, //   INPUT (Data,Var,Abs)
        0x95.toByte(), 0x01, //   REPORT_COUNT (1)
        0x75, 0x08, //   REPORT_SIZE (8)
        0x81.toByte(), 0x01, //   INPUT (Cnst,Ary,Abs)
        0x95.toByte(), 0x06, //   REPORT_COUNT (6)
        0x75, 0x08, //   REPORT_SIZE (8)
        0x15, 0x00, //   LOGICAL_MINIMUM (0)
        0x25, 0x65, //   LOGICAL_MAXIMUM (101)
        0x05, 0x07, //   USAGE_PAGE (Keyboard)
        0x19, 0x00, //   USAGE_MINIMUM (0)
        0x29, 0x65, //   USAGE_MAXIMUM (101)
        0x81.toByte(), 0x00, //   INPUT (Data,Ary,Abs)
        0xc0.toByte(), // END_COLLECTION
        0x05, 0x01, // USAGE_PAGE (Generic Desktop)
        0x09, 0x02, // USAGE (Mouse)
        0xa1.toByte(), 0x01, // COLLECTION (Application)
        0x09, 0x01, //   USAGE (Pointer)
        0xa1.toByte(), 0x00, //   COLLECTION (Physical)
        0x85.toByte(), REPORT_MOUSE, //   REPORT_ID (2)
        0x05, 0x09, //     USAGE_PAGE (Button)
        0x19, 0x01, //     USAGE_MINIMUM (1)
        0x29, 0x03, //     USAGE_MAXIMUM (3)
        0x15, 0x00, //     LOGICAL_MINIMUM (0)
        0x25, 0x01, //     LOGICAL_MAXIMUM (1)
        0x95.toByte(), 0x03, //     REPORT_COUNT (3)
        0x75, 0x01, //     REPORT_SIZE (1)
        0x81.toByte(), 0x02, //     INPUT (Data,Var,Abs)
        0x95.toByte(), 0x01, //     REPORT_COUNT (1)
        0x75, 0x05, //     REPORT_SIZE (5)
        0x81.toByte(), 0x01, //     INPUT (Cnst)
        0x05, 0x01, //     USAGE_PAGE (Generic Desktop)
        0x09, 0x30, //     USAGE (X)
        0x09, 0x31, //     USAGE (Y)
        0x09, 0x38, //     USAGE (Wheel)
        0x15, 0x81.toByte(), //     LOGICAL_MINIMUM (-127)
        0x25, 0x7f, //     LOGICAL_MAXIMUM (127)
        0x75, 0x08, //     REPORT_SIZE (8)
        0x95.toByte(), 0x03, //     REPORT_COUNT (3)
        0x81.toByte(), 0x06, //     INPUT (Data,Var,Rel)
        0xc0.toByte(), //   END_COLLECTION
        0xc0.toByte(), // END_COLLECTION
    )

    fun keyboard(modifiers: Int, keys: IntArray): ByteArray {
        val out = ByteArray(8)
        out[0] = (modifiers and 0xff).toByte()
        for (i in 0 until minOf(6, keys.size)) {
            out[2 + i] = (keys[i] and 0xff).toByte()
        }
        return out
    }

    fun mouse(buttons: Int, dx: Int, dy: Int, wheel: Int): ByteArray {
        return byteArrayOf(
            (buttons and 0x07).toByte(),
            dx.coerceIn(-127, 127).toByte(),
            dy.coerceIn(-127, 127).toByte(),
            wheel.coerceIn(-127, 127).toByte(),
        )
    }

    fun mouseChunks(buttons: Int, dx: Int, dy: Int, wheel: Int): List<ByteArray> {
        val chunks = ArrayList<ByteArray>(1)
        var x = dx
        var y = dy
        var w = wheel
        do {
            val sx = x.coerceIn(-127, 127)
            val sy = y.coerceIn(-127, 127)
            val sw = w.coerceIn(-127, 127)
            chunks.add(mouse(buttons, sx, sy, sw))
            x -= sx
            y -= sy
            w -= sw
        } while (x != 0 || y != 0 || w != 0)
        return chunks
    }

    fun framedMouseChunks(buttons: Int, dx: Int, dy: Int, wheel: Int): List<ByteArray> {
        return mouseChunks(buttons, dx, dy, wheel).map { byteArrayOf(REPORT_MOUSE) + it }
    }

    fun framedKeyboard(modifiers: Int, keys: IntArray): ByteArray {
        return byteArrayOf(REPORT_KEYBOARD) + keyboard(modifiers, keys)
    }

    fun framedMouse(buttons: Int, dx: Int, dy: Int, wheel: Int): ByteArray {
        return byteArrayOf(REPORT_MOUSE) + mouse(buttons, dx, dy, wheel)
    }
}
