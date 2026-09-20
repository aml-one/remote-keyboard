package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.ParcelUuid
import android.util.Log
import java.util.concurrent.Executors

/**
 * Helper GATT advertise. HID pairing uses [BluetoothHidDevice]’s own
 * packet — do not add a second connectable beacon there (Windows lists
 * it as another Unknown, or a named device that is not the keyboard).
 */
internal object NameBeacon {
    private const val TAG = "NameBeacon"
    private val executor = Executors.newSingleThreadExecutor()
    private var advertiser: BluetoothLeAdvertiser? = null

    private val legacyCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.i(TAG, "helper advertise started")
        }

        override fun onStartFailure(errorCode: Int) {
            Log.w(TAG, "helper advertise failed $errorCode")
            if (!pendingRetry) return
            pendingRetry = false
            executor.execute {
                val adv = advertiser ?: return@execute
                startLegacy(adv, nameOnly(), helperScan)
            }
        }
    }

    private var pendingRetry = false
    private var helperScan: AdvertiseData? = null

    fun startHelper(adapter: BluetoothAdapter, service: ParcelUuid) {
        helperScan = AdvertiseData.Builder().addServiceUuid(service).build()
        start(adapter, nameAndUuid(service), helperScan, retryNameOnly = true)
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        executor.execute {
            val adv = advertiser
            advertiser = null
            pendingRetry = false
            helperScan = null
            if (adv != null) stopUnsafe(adv)
        }
    }

    @SuppressLint("MissingPermission")
    private fun start(
        adapter: BluetoothAdapter,
        primary: AdvertiseData,
        scan: AdvertiseData?,
        retryNameOnly: Boolean,
    ) {
        executor.execute {
            BluetoothIdentity.awaitApplied(adapter)
            val adv = adapter.bluetoothLeAdvertiser
            if (adv == null) {
                Log.w(TAG, "no LE advertiser")
                return@execute
            }
            stopUnsafe(adv)
            advertiser = adv
            pendingRetry = retryNameOnly
            Log.i(TAG, "helper advertise name=${BluetoothIdentity.NAME}")
            startLegacy(adv, primary, scan)
        }
    }

    private fun nameAndUuid(service: ParcelUuid): AdvertiseData {
        return AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(service)
            .build()
    }

    private fun nameOnly(): AdvertiseData {
        return AdvertiseData.Builder().setIncludeDeviceName(true).build()
    }

    @SuppressLint("MissingPermission")
    private fun startLegacy(adv: BluetoothLeAdvertiser, data: AdvertiseData, scan: AdvertiseData?) {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0)
            .build()
        try {
            if (scan != null) {
                adv.startAdvertising(settings, data, scan, legacyCallback)
            } else {
                adv.startAdvertising(settings, data, legacyCallback)
            }
        } catch (error: Throwable) {
            Log.w(TAG, "helper advertise failed", error)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopUnsafe(adv: BluetoothLeAdvertiser) {
        try {
            adv.stopAdvertising(legacyCallback)
        } catch (_: Throwable) {
        }
    }
}
