package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppQosSettings
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.util.Log
import java.util.concurrent.Executors

class HidHost(private val context: Context) {
    private val executor = Executors.newSingleThreadExecutor()
    private var hid: BluetoothHidDevice? = null
    private var host: BluetoothDevice? = null
    var available: Boolean = false
        private set
    var supported: Boolean = true
        private set
    var connected: Boolean = false
        private set
    var deviceName: String = ""
        private set
    var onChanged: (() -> Unit)? = null

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private val callback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
            Log.i(TAG, "onAppStatusChanged registered=$registered plugged=${pluggedDevice?.address}")
            available = registered
            if (!registered) {
                HidNameAdvertise.stop()
                connected = false
                host = null
                deviceName = ""
                emit()
                return
            }
            val live = pluggedDevice ?: firstConnected()
            if (live != null) {
                HidNameAdvertise.stop()
                adoptHost(live)
                connectHost(live)
            } else {
                reconnectBondedHosts()
                if (!connected) {
                    adapter?.let { HidNameAdvertise.start(it) }
                }
            }
            emit()
        }

        override fun onConnectionStateChanged(device: BluetoothDevice?, state: Int) {
            Log.i(TAG, "onConnectionStateChanged state=$state device=${device?.address}")
            when (state) {
                BluetoothProfile.STATE_CONNECTED -> {
                    HidNameAdvertise.stop()
                    adoptHost(device)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    if (host?.address == device?.address) {
                        connected = false
                        host = null
                        deviceName = ""
                        if (available) {
                            adapter?.let { HidNameAdvertise.start(it) }
                        }
                    }
                }
            }
            emit()
        }
    }

    private val serviceListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile != BluetoothProfile.HID_DEVICE || proxy !is BluetoothHidDevice) return
            hid = proxy
            register(proxy)
        }

        override fun onServiceDisconnected(profile: Int) {
            if (profile != BluetoothProfile.HID_DEVICE) return
            hid = null
            available = false
            connected = false
            host = null
            deviceName = ""
            emit()
        }
    }

    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        val bt = adapter ?: return false
        if (!bt.isEnabled) return false
        BluetoothIdentity.awaitApplied(bt)
        val ok = try {
            bt.getProfileProxy(context, serviceListener, BluetoothProfile.HID_DEVICE)
        } catch (error: Throwable) {
            Log.w(TAG, "HID profile missing", error)
            false
        }
        Log.i(TAG, "getProfileProxy(HID_DEVICE)=$ok")
        if (!ok) {
            supported = false
            emit()
        }
        return ok
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        val proxy = hid
        val device = host
        if (proxy != null && device != null) {
            try {
                proxy.disconnect(device)
            } catch (_: Throwable) {
            }
        }
        try {
            proxy?.unregisterApp()
        } catch (_: Throwable) {
        }
        adapter?.closeProfileProxy(BluetoothProfile.HID_DEVICE, proxy)
        HidNameAdvertise.stop()
        hid = null
        host = null
        connected = false
        available = false
        deviceName = ""
        emit()
    }

    @SuppressLint("MissingPermission")
    fun sendKeyboard(modifiers: Int, keys: IntArray): Boolean {
        val proxy = hid ?: return false
        val device = host ?: return false
        return try {
            proxy.sendReport(device, HidReports.REPORT_KEYBOARD.toInt(), HidReports.keyboard(modifiers, keys))
        } catch (error: Throwable) {
            Log.w(TAG, "keyboard report failed", error)
            false
        }
    }

    @SuppressLint("MissingPermission")
    fun sendMouse(buttons: Int, dx: Int, dy: Int, wheel: Int): Boolean {
        val proxy = hid ?: return false
        val device = host ?: return false
        return try {
            var ok = true
            for (report in HidReports.mouseChunks(buttons, dx, dy, wheel)) {
                ok = proxy.sendReport(device, HidReports.REPORT_MOUSE.toInt(), report) && ok
            }
            ok
        } catch (error: Throwable) {
            Log.w(TAG, "mouse report failed", error)
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun register(proxy: BluetoothHidDevice) {
        val adapter = adapter
        if (adapter != null) {
            BluetoothIdentity.awaitApplied(adapter)
            try {
                Thread.sleep(250)
            } catch (_: InterruptedException) {
            }
        }
        val sdp = BluetoothHidDeviceAppSdpSettings(
            BluetoothIdentity.NAME,
            "AmL Remote Keyboard",
            "AmL",
            BluetoothHidDevice.SUBCLASS1_COMBO,
            HidReports.DESCRIPTOR,
        )
        val qos = BluetoothHidDeviceAppQosSettings(
            BluetoothHidDeviceAppQosSettings.SERVICE_BEST_EFFORT,
            800,
            9,
            0,
            11250,
            BluetoothHidDeviceAppQosSettings.MAX,
        )
        val ok = try {
            proxy.registerApp(sdp, null, qos, executor, callback)
        } catch (error: Throwable) {
            Log.w(TAG, "registerApp failed", error)
            false
        }
        Log.i(TAG, "registerApp=$ok name=${BluetoothIdentity.NAME}")
        available = ok
        emit()
    }

    @SuppressLint("MissingPermission")
    private fun adoptHost(device: BluetoothDevice?) {
        if (device == null) return
        host = device
        connected = true
        deviceName = safeName(device)
        Log.i(TAG, "host=${device.address} name=$deviceName")
        sendIdle()
    }

    @SuppressLint("MissingPermission")
    private fun sendIdle() {
        sendKeyboard(0, intArrayOf())
        sendMouse(0, 0, 0, 0)
    }

    @SuppressLint("MissingPermission")
    private fun connectHost(device: BluetoothDevice) {
        val proxy = hid ?: return
        try {
            val ok = proxy.connect(device)
            Log.i(TAG, "connect ${device.address}=${ok}")
        } catch (error: Throwable) {
            Log.w(TAG, "connect failed", error)
        }
    }

    @SuppressLint("MissingPermission")
    private fun firstConnected(): BluetoothDevice? {
        val proxy = hid ?: return null
        return try {
            proxy.connectedDevices.firstOrNull()
        } catch (_: Throwable) {
            null
        }
    }

    @SuppressLint("MissingPermission")
    private fun reconnectBondedHosts() {
        hid ?: return
        val bt = adapter ?: return
        val live = firstConnected()
        if (live != null) {
            HidNameAdvertise.stop()
            adoptHost(live)
            return
        }
        val bonded = try {
            bt.bondedDevices.orEmpty()
        } catch (_: Throwable) {
            emptySet()
        }
        for (device in bonded) {
            if (!isLikelyHidHost(device)) continue
            Log.i(TAG, "reconnect bonded ${device.address} name=${safeName(device)}")
            connectHost(device)
        }
    }

    @SuppressLint("MissingPermission")
    private fun isLikelyHidHost(device: BluetoothDevice): Boolean {
        if (device.bondState != BluetoothDevice.BOND_BONDED) return false
        val major = try {
            device.bluetoothClass?.majorDeviceClass
        } catch (_: Throwable) {
            null
        } ?: return true
        return major != BluetoothClass.Device.Major.AUDIO_VIDEO &&
            major != BluetoothClass.Device.Major.PHONE &&
            major != BluetoothClass.Device.Major.HEALTH &&
            major != BluetoothClass.Device.Major.WEARABLE &&
            major != BluetoothClass.Device.Major.TOY &&
            major != BluetoothClass.Device.Major.IMAGING
    }

    @SuppressLint("MissingPermission")
    private fun safeName(device: BluetoothDevice?): String {
        if (device == null) return ""
        return try {
            device.name ?: device.address ?: ""
        } catch (_: SecurityException) {
            device.address ?: ""
        }
    }

    private fun emit() {
        onChanged?.invoke()
    }

    companion object {
        private const val TAG = "HidHost"
        fun profileSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
    }
}
