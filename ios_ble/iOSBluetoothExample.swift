import CoreBluetooth

// Core Bluetooth ViewModel (logic only) kept separate from UI.
class BluetoothViewModel: NSObject, ObservableObject {
    @Published var stateDescription: String = "Initializing"
    @Published var discoveredPeripheralId: String? = nil
    @Published var hexValueHistory: [String] = []
    @Published var lastNumberValue: UInt64? = nil
    @Published var rssi: NSNumber? = nil
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false

    private let targetName = "XSC"
    private let targetCharacteristicUUID = CBUUID(string: "E73C3003-B8BB-494E-86C5-01FD7341F217") // this is where you set the uuid for the temperature value

    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: DispatchQueue(label: "bt.central"))
    }

    func toggleScan() {
        guard central.state == .poweredOn else { return }
        if isScanning {
            central.stopScan()
            isScanning = false
            stateDescription = "Scan stopped"
        } else {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            isScanning = true
            stateDescription = "Scanning for \(targetName)..."
        }
    }

    func disconnect() {
        guard let p = targetPeripheral else { return }
        central.cancelPeripheralConnection(p)
    }
}

extension BluetoothViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            stateDescription = "Bluetooth powered on"
        case .unsupported: stateDescription = "Unsupported"
        case .unauthorized: stateDescription = "Unauthorized (grant permission)"
        case .poweredOff: stateDescription = "Powered off"
        case .resetting: stateDescription = "Resetting"
        case .unknown: fallthrough
        @unknown default: stateDescription = "Unknown state: \(central.state.rawValue)"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if let name = name, name == targetName {
            stateDescription = "Discovered target. Connecting..."
            discoveredPeripheralId = peripheral.identifier.uuidString
            rssi = RSSI
            targetPeripheral = peripheral
            central.stopScan()
            isScanning = false
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        stateDescription = "Connected. Discovering services..."
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        stateDescription = "Failed to connect: \(error?.localizedDescription ?? "Unknown")"
        isConnected = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        stateDescription = "Disconnected: \(error?.localizedDescription ?? "No error")"
        targetPeripheral = nil
        targetCharacteristic = nil
    }
}

extension BluetoothViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { stateDescription = "Service discovery error: \(error)"; return }
        guard let services = peripheral.services else { stateDescription = "No services"; return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { stateDescription = "Characteristic discovery error: \(error)"; return }
        guard let characteristics = service.characteristics else { return }
        for c in characteristics where c.uuid == targetCharacteristicUUID {
            targetCharacteristic = c
            stateDescription = "Found characteristic. Enabling notifications..."
            peripheral.setNotifyValue(true, for: c)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { stateDescription = "Notify state error: \(error)"; return }
        if characteristic.isNotifying {
            stateDescription = "Receiving notifications"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            stateDescription = "Value update error: \(error)"
            return
        }
        guard let data = characteristic.value else {
            return
        }
        print("Raw data received: \(data.map { String(format: "%02x", $0) }.joined())")

        // Swap endianness of the data
        let swappedData = Data(data.reversed())
        let swappedHexString = swappedData.map { String(format: "%02x", $0) }.joined()
        print("Swapped endianness data: \(swappedHexString)")

        let number = UInt64(swappedHexString, radix: 16)

        guard let unwrappedNumber = number else {
            stateDescription = "Failed to convert swapped hex string to number"
            return
        }

//        var m: UInt64 = 0

        // var m_10: UInt64 = 45
        // var b_10: UInt64 = 950
        // var number_10: UInt64 = unwrappedNumber * 10
        // var result_10: UInt64 = (m_10 * number_10) - b_10
        // var result: UInt64 = result_10 / 10
        // lastNumberValue = result

        var m_100: UInt64 = 22
        var b_100: UInt64 = 2120
        var number_100: UInt64 = unwrappedNumber
        var result_100: UInt64 = (m_100 * number_100) + b_100
        var result: UInt64 = result_100 / 100
        lastNumberValue = result

        // lastNumberValue = unwrappedNumber

        hexValueHistory.append(swappedHexString)
        if hexValueHistory.count > 100 {
            hexValueHistory.removeFirst()
        }
    }
}

// UI moved to separate ContentView.swift file.
