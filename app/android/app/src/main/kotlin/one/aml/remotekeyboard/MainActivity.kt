package one.aml.remotekeyboard

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val hid by lazy { HidHost(this) }
    private val ble by lazy { BleHidServer(this) }
    private var events: EventChannel.EventSink? = null
    private var pendingPerms: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hid.onChanged = { emitStatus() }
        ble.onChanged = { emitStatus() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(statusMap())
                "requestPermissions" -> requestBluetooth(result)
                "startHid" -> result.success(startHid())
                "startBle" -> result.success(startBle())
                "stop" -> {
                    stopAll()
                    result.success(true)
                }
                "sendKeyboard" -> {
                    val mods = call.argument<Int>("modifiers") ?: 0
                    val keys = (call.argument<List<Int>>("keys") ?: emptyList()).toIntArray()
                    result.success(sendKeyboard(mods, keys))
                }
                "tapKey" -> {
                    val hid = call.argument<Int>("hid") ?: 0
                    val mods = call.argument<Int>("modifiers") ?: 0
                    result.success(tapKey(mods, hid))
                }
                "sendMouse" -> {
                    val buttons = call.argument<Int>("buttons") ?: 0
                    val dx = call.argument<Int>("dx") ?: 0
                    val dy = call.argument<Int>("dy") ?: 0
                    val wheel = call.argument<Int>("wheel") ?: 0
                    result.success(sendMouse(buttons, dx, dy, wheel))
                }
                "keepAwake" -> {
                    val on = call.argument<Boolean>("on") == true
                    runOnUiThread {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    this@MainActivity.events = events
                    events?.success(statusMap())
                }

                override fun onCancel(arguments: Any?) {
                    this@MainActivity.events = null
                }
            },
        )
    }

    private var pairingPin: String = ""

    private fun startHid(): Boolean {
        ble.stop()
        PairingAssist.onPin = { pin ->
            pairingPin = pin
            emitStatus()
        }
        PairingAssist.start(this)
        val ok = hid.start()
        if (ok) {
            ConnectedService.start(this, "Waiting for Bluetooth HID")
        }
        emitStatus()
        return ok
    }

    private fun startBle(): Boolean {
        PairingAssist.stop(this)
        pairingPin = ""
        hid.stop()
        val ok = ble.start()
        if (ok) ConnectedService.start(this, "Waiting for helper")
        emitStatus()
        return ok
    }

    private fun stopAll() {
        PairingAssist.stop(this)
        pairingPin = ""
        hid.stop()
        ble.stop()
        val adapter = (getSystemService(android.content.Context.BLUETOOTH_SERVICE)
            as? android.bluetooth.BluetoothManager)?.adapter
        BluetoothIdentity.restore(adapter)
        ConnectedService.stop(this)
        emitStatus()
    }

    private fun sendKeyboard(modifiers: Int, keys: IntArray): Boolean {
        val hidOk = hid.connected && hid.sendKeyboard(modifiers, keys)
        val bleOk = ble.connected && ble.sendKeyboard(modifiers, keys)
        return hidOk || bleOk
    }

    private fun tapKey(modifiers: Int, hid: Int): Boolean {
        if (hid == 0) return sendKeyboard(0, intArrayOf())
        val down = sendKeyboard(modifiers, intArrayOf(hid))
        val up = sendKeyboard(0, intArrayOf())
        return down || up
    }

    private fun sendMouse(buttons: Int, dx: Int, dy: Int, wheel: Int): Boolean {
        val hidOk = hid.connected && hid.sendMouse(buttons, dx, dy, wheel)
        val bleOk = ble.connected && ble.sendMouse(buttons, dx, dy, wheel)
        return hidOk || bleOk
    }

    private fun statusMap(): Map<String, Any?> {
        val transport = when {
            hid.connected -> "hid"
            ble.connected -> "helper"
            ble.advertising -> "helper"
            hid.available -> "hid"
            else -> "none"
        }
        return mapOf(
            "hidAvailable" to (HidHost.profileSupported() && hid.available),
            "hidSupported" to (HidHost.profileSupported() && hid.supported),
            "bleAdvertising" to ble.advertising,
            "connected" to (hid.connected || ble.connected),
            "transport" to transport,
            "deviceName" to when {
                hid.connected -> hid.deviceName
                ble.connected -> ble.deviceName
                else -> ""
            },
            "pairingPin" to pairingPin,
        )
    }

    private fun emitStatus() {
        val snapshot = statusMap()
        runOnUiThread {
            val text = when {
                hid.connected -> {
                    pairingPin = ""
                    "HID · ${hid.deviceName.ifBlank { "computer" }}"
                }
                ble.connected -> ble.deviceName.ifBlank { "computer" }
                ble.advertising -> "Waiting for helper"
                hid.available -> "Waiting for Bluetooth HID"
                else -> "Remote Keyboard"
            }
            if (hid.connected || ble.connected || ble.advertising || hid.available) {
                ConnectedService.start(this, text)
            }
            events?.success(snapshot)
        }
    }

    private fun requestBluetooth(result: MethodChannel.Result) {
        val missing = missingPermissions()
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPerms = result
        ActivityCompat.requestPermissions(this, missing, REQ)
    }

    private fun missingPermissions(): Array<String> {
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            needed += Manifest.permission.BLUETOOTH_CONNECT
            needed += Manifest.permission.BLUETOOTH_ADVERTISE
            needed += Manifest.permission.BLUETOOTH_SCAN
        } else {
            needed += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed += Manifest.permission.POST_NOTIFICATIONS
        }
        return needed.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }.toTypedArray()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ) return
        pendingPerms?.success(missingPermissions().isEmpty())
        pendingPerms = null
    }

    override fun onDestroy() {
        stopAll()
        super.onDestroy()
    }

    companion object {
        private const val METHOD = "one.aml.remotekeyboard/hid"
        private const val EVENTS = "one.aml.remotekeyboard/events"
        private const val REQ = 71
    }
}
