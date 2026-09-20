package one.aml.remotekeyboard

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.ParcelUuid
import java.util.UUID

class BleHidServer(private val context: Context) {
    var advertising: Boolean = false
        private set
    var connected: Boolean = false
        private set
    var deviceName: String = ""
        private set
    var onChanged: (() -> Unit)? = null

    private var server: BluetoothGattServer? = null
    private var keyboardChar: BluetoothGattCharacteristic? = null
    private var mouseChar: BluetoothGattCharacteristic? = null
    private val centrals = LinkedHashSet<BluetoothDevice>()

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private val manager: BluetoothManager?
        get() = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private val gattCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            if (device == null) return
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                centrals.add(device)
            } else {
                centrals.remove(device)
            }
            connected = centrals.isNotEmpty()
            deviceName = if (connected) safeName(centrals.first()) else ""
            emit()
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?,
        ) {
            server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, characteristic?.value)
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            descriptor: android.bluetooth.BluetoothGattDescriptor?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            if (responseNeeded) {
                server?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun start(): Boolean {
        val bt = adapter ?: return false
        if (!bt.isEnabled) return false
        BluetoothIdentity.apply(bt)
        val gatt = manager?.openGattServer(context, gattCallback) ?: return false
        val service = BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        keyboardChar = notifyChar(KEYBOARD)
        mouseChar = notifyChar(MOUSE)
        service.addCharacteristic(keyboardChar)
        service.addCharacteristic(mouseChar)
        gatt.addService(service)
        server = gatt
        if (bt.bluetoothLeAdvertiser == null) {
            server?.close()
            server = null
            return false
        }
        advertising = true
        NameBeacon.startHelper(bt, ParcelUuid(SERVICE))
        emit()
        return true
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        NameBeacon.stop()
        try {
            server?.close()
        } catch (_: Throwable) {
        }
        server = null
        keyboardChar = null
        mouseChar = null
        centrals.clear()
        advertising = false
        connected = false
        deviceName = ""
        emit()
    }

    @SuppressLint("MissingPermission")
    fun sendKeyboard(modifiers: Int, keys: IntArray): Boolean {
        return notify(keyboardChar, HidReports.framedKeyboard(modifiers, keys))
    }

    @SuppressLint("MissingPermission")
    fun sendMouse(buttons: Int, dx: Int, dy: Int, wheel: Int): Boolean {
        var ok = true
        for (payload in HidReports.framedMouseChunks(buttons, dx, dy, wheel)) {
            ok = notify(mouseChar, payload) && ok
        }
        return ok
    }

    @SuppressLint("MissingPermission")
    private fun notify(characteristic: BluetoothGattCharacteristic?, payload: ByteArray): Boolean {
        val gatt = server ?: return false
        val char = characteristic ?: return false
        if (centrals.isEmpty()) return false
        char.value = payload
        var ok = false
        for (device in centrals) {
            ok = gatt.notifyCharacteristicChanged(device, char, false) || ok
        }
        return ok
    }

    private fun notifyChar(uuid: UUID): BluetoothGattCharacteristic {
        val characteristic = BluetoothGattCharacteristic(
            uuid,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        val cccd = android.bluetooth.BluetoothGattDescriptor(
            CCCD,
            android.bluetooth.BluetoothGattDescriptor.PERMISSION_READ or
                android.bluetooth.BluetoothGattDescriptor.PERMISSION_WRITE,
        )
        characteristic.addDescriptor(cccd)
        return characteristic
    }

    @SuppressLint("MissingPermission")
    private fun safeName(device: BluetoothDevice): String {
        return try {
            device.name ?: device.address
        } catch (_: SecurityException) {
            device.address
        }
    }

    private fun emit() {
        onChanged?.invoke()
    }

    companion object {
        private const val TAG = "BleHidServer"
        val SERVICE: UUID = UUID.fromString("8f7a0001-4c6f-4d2e-9a11-7c6ff0000001")
        val KEYBOARD: UUID = UUID.fromString("8f7a0002-4c6f-4d2e-9a11-7c6ff0000001")
        val MOUSE: UUID = UUID.fromString("8f7a0003-4c6f-4d2e-9a11-7c6ff0000001")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
