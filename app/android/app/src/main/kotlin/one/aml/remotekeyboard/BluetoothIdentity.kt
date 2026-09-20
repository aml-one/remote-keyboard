package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.util.Log

internal object BluetoothIdentity {
    /** Shown in Windows Add a device via [HidNameAdvertise], not Xiaomi’s HID packet. */
    const val NAME = "AOW Keyboard"
    private const val TAG = "BluetoothIdentity"
    private var previous: String? = null

    @SuppressLint("MissingPermission")
    fun apply(adapter: BluetoothAdapter) {
        val before = try {
            adapter.name
        } catch (_: Throwable) {
            "?"
        }
        if (previous == null && before.isNotBlank() && before != NAME) {
            previous = before
        }
        val ok = try {
            adapter.setName(NAME)
        } catch (error: Throwable) {
            Log.w(TAG, "setName failed before=$before", error)
            false
        }
        val after = try {
            adapter.name
        } catch (_: Throwable) {
            "?"
        }
        Log.i(TAG, "setName($NAME)=$ok before=$before after=$after")
    }

    @SuppressLint("MissingPermission")
    fun restore(adapter: BluetoothAdapter?) {
        val old = previous ?: return
        previous = null
        if (adapter == null || old.isBlank() || old == NAME) return
        val ok = try {
            adapter.setName(old)
        } catch (error: Throwable) {
            Log.w(TAG, "restore name failed", error)
            false
        }
        Log.i(TAG, "restore name=$old ok=$ok")
    }

    @SuppressLint("MissingPermission")
    fun awaitApplied(adapter: BluetoothAdapter): Boolean {
        apply(adapter)
        repeat(20) {
            val now = try {
                adapter.name
            } catch (_: Throwable) {
                null
            }
            if (now == NAME) return true
            apply(adapter)
            try {
                Thread.sleep(50)
            } catch (_: InterruptedException) {
                return now == NAME
            }
        }
        Log.w(TAG, "adapter name never stuck, still=${try { adapter.name } catch (_: Throwable) { "?" }}")
        return false
    }
}
