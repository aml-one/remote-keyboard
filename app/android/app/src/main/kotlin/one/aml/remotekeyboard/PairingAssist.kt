package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import java.nio.charset.StandardCharsets

/**
 * Windows numeric-comparison pairing (variant 2). Xiaomi requires
 * BLUETOOTH_PRIVILEGED for [BluetoothDevice.setPairingConfirmation], so
 * this receiver must not abort the system dialog — HyperOS has to show
 * the matching PIN. [setPin] is attempted without aborting.
 */
class PairingRequestReceiver : BroadcastReceiver() {
    @SuppressLint("MissingPermission")
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BluetoothDevice.ACTION_PAIRING_REQUEST) return
        val device = PairingAssist.deviceFrom(intent) ?: return
        val variant = intent.getIntExtra(BluetoothDevice.EXTRA_PAIRING_VARIANT, BluetoothDevice.ERROR)
        val key = intent.getIntExtra(BluetoothDevice.EXTRA_PAIRING_KEY, BluetoothDevice.ERROR)
        val pin = if (key >= 0 && key != BluetoothDevice.ERROR) "%06d".format(key) else ""
        Log.i(TAG, "pairing ${device.address} name=${PairingAssist.safeName(device)} variant=$variant key=$key")
        PairingAssist.notifyPin(pin)
        if (pin.isNotEmpty()) {
            val ok = try {
                device.setPin(pin.toByteArray(StandardCharsets.UTF_8))
            } catch (error: Throwable) {
                Log.w(TAG, "setPin failed", error)
                false
            }
            Log.i(TAG, "setPin=$ok pin=$pin")
        }
        // Never abortBroadcast: setPairingConfirmation needs PRIVILEGED on HyperOS.
        // Leaving the ordered broadcast running lets the system PIN sheet appear.
    }

    companion object {
        private const val TAG = "PairingAssist"
    }
}

internal object PairingAssist {
    private const val TAG = "PairingAssist"
    private var receiver: BroadcastReceiver? = null
    var onPin: ((String) -> Unit)? = null

    fun notifyPin(pin: String) {
        if (pin.isEmpty()) return
        onPin?.invoke(pin)
    }

    fun start(context: Context) {
        if (receiver != null) return
        val filter = IntentFilter(BluetoothDevice.ACTION_PAIRING_REQUEST).apply { priority = 1000 }
        val next = PairingRequestReceiver()
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                context.applicationContext.registerReceiver(next, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                context.applicationContext.registerReceiver(next, filter)
            }
            receiver = next
            Log.i(TAG, "registered")
        } catch (error: Throwable) {
            Log.w(TAG, "register failed", error)
        }
    }

    fun stop(context: Context) {
        onPin = null
        val current = receiver ?: return
        receiver = null
        try {
            context.applicationContext.unregisterReceiver(current)
        } catch (_: Throwable) {
        }
        Log.i(TAG, "unregistered")
    }

    @Suppress("DEPRECATION")
    fun deviceFrom(intent: Intent): BluetoothDevice? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
    }

    @SuppressLint("MissingPermission")
    fun safeName(device: BluetoothDevice): String {
        return try {
            device.name ?: ""
        } catch (_: Throwable) {
            ""
        }
    }
}
