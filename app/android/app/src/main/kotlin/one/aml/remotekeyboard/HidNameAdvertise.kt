package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.util.Log
import java.util.concurrent.Executors

/**
 * Named legacy advertise + Microsoft Swift Pair so Windows can list
 * AOW Keyboard. A second advertising set with a random address needs
 * BLUETOOTH_PRIVILEGED on Xiaomi and is skipped.
 */
internal object HidNameAdvertise {
    private const val TAG = "HidNameAdvertise"
    private const val MICROSOFT = 0x0006
    private val SWIFT_PAIR = byteArrayOf(0x03, 0x00, 0x80.toByte())
    private val executor = Executors.newSingleThreadExecutor()
    private var advertiser: BluetoothLeAdvertiser? = null

    fun start(adapter: BluetoothAdapter) {
        executor.execute {
            BluetoothIdentity.awaitApplied(adapter)
            val adv = adapter.bluetoothLeAdvertiser
            if (adv == null) {
                Log.w(TAG, "no LE advertiser")
                return@execute
            }
            stopUnsafe(adv)
            advertiser = adv
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0)
                .build()
            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .addManufacturerData(MICROSOFT, SWIFT_PAIR)
                .build()
            Log.i(TAG, "start name=${BluetoothIdentity.NAME}")
            try {
                adv.startAdvertising(settings, data, callback)
            } catch (error: Throwable) {
                Log.w(TAG, "advertise failed", error)
            }
        }
    }

    fun stop() {
        executor.execute {
            val adv = advertiser
            advertiser = null
            if (adv != null) stopUnsafe(adv)
        }
    }

    private val callback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.i(TAG, "started")
        }

        override fun onStartFailure(errorCode: Int) {
            Log.w(TAG, "failed code=$errorCode")
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopUnsafe(adv: BluetoothLeAdvertiser) {
        try {
            adv.stopAdvertising(callback)
        } catch (_: Throwable) {
        }
    }
}
