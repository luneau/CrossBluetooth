import Foundation
import CoreBluetooth
// this a version slighty modified from https://github.com/Polidea/RxBluetoothKit 
public enum BluetoothError: Error {
    case destroyed
    // Emitted when `CentralManager.scanForPeripherals` called and there is already ongoing scan
    case scanInProgress
    // Emitted when `PeripheralManager.startAdvertising` called andm there is already ongoing advertisement
    case advertisingInProgress
    case onlyOneSubscriberAuthorized
    case advertisingStartFailed(Error)
    // States
    case bluetoothUnsupported
    case bluetoothUnauthorized
    case bluetoothPoweredOff
    case bluetoothInUnknownState
    case bluetoothResetting
    // Peripheral
    case peripheralIsAlreadyObservingConnection(CBPeripheral)
    case peripheralConnectionFailed(CBPeripheral, Error?)
    case peripheralDisconnected(CBPeripheral, Error?)
    case peripheralRSSIReadFailed(CBPeripheral, Error?)
    case peripheralIsNotConnected(CBPeripheral)
    case peripheralMTUMissMatch((Int,Int))
    // Services
    case servicesDiscoveryFailed(CBPeripheral, Error?)
    case includedServicesDiscoveryFailed(CBPeripheral, Error?)
    case addingServiceFailed(CBService, Error?)
    // Characteristics
    case characteristicsDiscoveryFailed(CBService, Error?)
    case characteristicWriteFailed(CBCharacteristic, Error?)
    case characteristicReadFailed(CBCharacteristic, Error?)
    case characteristicNotifyChangeFailed(CBCharacteristic, Error?)
    case characteristicSetNotifyValueFailed(CBCharacteristic, Error?)
    case characteristicUpdateValueFailed(CBCharacteristic, Error?)
    // Descriptors
    case descriptorsDiscoveryFailed(CBCharacteristic, Error?)
    case descriptorWriteFailed(CBDescriptor, Error?)
    case descriptorReadFailed(CBDescriptor, Error?)
    // L2CAP
    case openingL2CAPChannelFailed(CBPeripheral, Error?)
    case publishingL2CAPChannelFailed(CBL2CAPPSM, Error?)
    // Unknown
    case unknownWriteType
    // misused api
    case misUsedAPI(String)
}

extension BluetoothError: CustomStringConvertible {

    /// Human readable description of bluetooth error
    public var description: String {
        switch self {
        case .peripheralIsNotConnected:
            return """
            The device is not connected to central.
            """
        case .onlyOneSubscriberAuthorized:
            return """
            there is already one subscibers to this service.
            """
        case .destroyed:
            return """
            The object that is the source of this Observable was destroyed.
            It's programmer's error, please check documentation of error for more details
            """
        case .scanInProgress:
            return """
            Tried to scan for peripheral when there is already ongoing scan.
            You can have only 1 ongoing scanning, please check documentation of CentralManager for more details
            """
        case .advertisingInProgress:
            return """
            Tried to advertise when there is already advertising ongoing.
            You can have only 1 ongoing advertising, please check documentation of PeripheralManager for more details
            """
        case let .advertisingStartFailed(err):
            return "Start advertising error occured: \(err.localizedDescription)"
        case .bluetoothUnsupported:
            return "Bluetooth is unsupported"
        case .bluetoothUnauthorized:
            return "Bluetooth is unauthorized"
        case .bluetoothPoweredOff:
            return "Bluetooth is powered off"
        case .bluetoothInUnknownState:
            return "Bluetooth is in unknown state"
        case .bluetoothResetting:
            return "Bluetooth is resetting"
        // Peripheral
        case .peripheralIsAlreadyObservingConnection:
            return """
            Peripheral connection is already being observed.
            You cannot try to establishConnection to peripheral when you have ongoing
            connection (previously establishConnection subscription was not disposed).
            """
        case let .peripheralConnectionFailed(_, err):
            return "Connection error has occured: \(err?.localizedDescription ?? "-")"
        case let .peripheralDisconnected(_, err):
            return "Connection error has occured: \(err?.localizedDescription ?? "-")"
        case let .peripheralRSSIReadFailed(_, err):
            return "RSSI read failed : \(err?.localizedDescription ?? "-")"
        // Services
        case let .servicesDiscoveryFailed(_, err):
            return "Services discovery error has occured: \(err?.localizedDescription ?? "-")"
        case let .includedServicesDiscoveryFailed(_, err):
            return "Included services discovery error has occured: \(err?.localizedDescription ?? "-")"
        case let .addingServiceFailed(_, err):
            return "Adding PeripheralManager service error has occured: \(err?.localizedDescription ?? "-")"
        // Characteristics
        case let .characteristicsDiscoveryFailed(_, err):
            return "Characteristics discovery error has occured: \(err?.localizedDescription ?? "-")"
        case let .characteristicWriteFailed(_, err):
            return "Characteristic write error has occured: \(err?.localizedDescription ?? "-")"
        case let .characteristicReadFailed(_, err):
            return "Characteristic read error has occured: \(err?.localizedDescription ?? "-")"
        case let .characteristicNotifyChangeFailed(_, err):
            return "Characteristic notify change error has occured: \(err?.localizedDescription ?? "-")"
        case let .characteristicSetNotifyValueFailed(_, err):
            return "Characteristic isNotyfing value change error has occured: \(err?.localizedDescription ?? "-")"
        case let .characteristicUpdateValueFailed(_, err):
            return "Characteristic update value change error has occured: \(err?.localizedDescription ?? "-")"
        // Descriptors
        case let .descriptorsDiscoveryFailed(_, err):
            return "Descriptor discovery error has occured: \(err?.localizedDescription ?? "-")"
        case let .descriptorWriteFailed(_, err):
            return "Descriptor write error has occured: \(err?.localizedDescription ?? "-")"
        case let .descriptorReadFailed(_, err):
            return "Descriptor read error has occured: \(err?.localizedDescription ?? "-")"
        case let .openingL2CAPChannelFailed(_, err):
            return "Opening L2CAP channel error has occured: \(err?.localizedDescription ?? "-")"
        case let .publishingL2CAPChannelFailed(_, err):
            return "Publishing L2CAP channel error has occured: \(err?.localizedDescription ?? "-")"
        // Unknown
        case .unknownWriteType:
            return "Unknown write type"
        case .peripheralMTUMissMatch(let value ):
            return "mtu mismatched please check it up packet size expected \(value.0) received \(value.1)"
        case .misUsedAPI(let message):
            return "misused API clue -> \(message)"
        }
    }
}

extension BluetoothError {
    init(state: CBManagerState) {
        switch state {
        case .unsupported:
            self = .bluetoothUnsupported
        case .unauthorized:
            self = .bluetoothUnauthorized
        case .poweredOff:
            self = .bluetoothPoweredOff
        case .unknown:
            self = .bluetoothInUnknownState
        case .resetting:
            self = .bluetoothResetting
        default:
            self = .bluetoothInUnknownState
        }
    }
}

extension BluetoothError: Equatable {}

// swiftlint:disable cyclomatic_complexity

public func == (lhs: BluetoothError, rhs: BluetoothError) -> Bool {
    switch (lhs, rhs) {
    case (.scanInProgress, .scanInProgress): return true
    case (.advertisingInProgress, .advertisingInProgress): return true
    case (.advertisingStartFailed, .advertisingStartFailed): return true
    // States
    case (.bluetoothUnsupported, .bluetoothUnsupported): return true
    case (.bluetoothUnauthorized, .bluetoothUnauthorized): return true
    case (.bluetoothPoweredOff, .bluetoothPoweredOff): return true
    case (.bluetoothInUnknownState, .bluetoothInUnknownState): return true
    case (.bluetoothResetting, .bluetoothResetting): return true
    // Services
    case let (.servicesDiscoveryFailed(l, _), .servicesDiscoveryFailed(r, _)): return l == r
    case let (.includedServicesDiscoveryFailed(l, _), .includedServicesDiscoveryFailed(r, _)): return l == r
    case let (.addingServiceFailed(l, _), .addingServiceFailed(r, _)): return l == r
    // Peripherals
    case let (.peripheralIsAlreadyObservingConnection(l), .peripheralIsAlreadyObservingConnection(r)): return l == r
    case let (.peripheralConnectionFailed(l, _), .peripheralConnectionFailed(r, _)): return l == r
    case let (.peripheralDisconnected(l, _), .peripheralDisconnected(r, _)): return l == r
    case let (.peripheralRSSIReadFailed(l, _), .peripheralRSSIReadFailed(r, _)): return l == r
    // Characteristics
    case let (.characteristicsDiscoveryFailed(l, _), .characteristicsDiscoveryFailed(r, _)): return l == r
    case let (.characteristicWriteFailed(l, _), .characteristicWriteFailed(r, _)): return l == r
    case let (.characteristicReadFailed(l, _), .characteristicReadFailed(r, _)): return l == r
    case let (.characteristicNotifyChangeFailed(l, _), .characteristicNotifyChangeFailed(r, _)): return l == r
    case let (.characteristicSetNotifyValueFailed(l, _), .characteristicSetNotifyValueFailed(r, _)): return l == r
    case let (.characteristicUpdateValueFailed(l, _), .characteristicUpdateValueFailed(r, _)): return l == r
    // Descriptors
    case let (.descriptorsDiscoveryFailed(l, _), .descriptorsDiscoveryFailed(r, _)): return l == r
    case let (.descriptorWriteFailed(l, _), .descriptorWriteFailed(r, _)): return l == r
    case let (.descriptorReadFailed(l, _), .descriptorReadFailed(r, _)): return l == r
    // L2CAP
    case let (.openingL2CAPChannelFailed(l, _), .openingL2CAPChannelFailed(r, _)): return l == r
    case let (.publishingL2CAPChannelFailed(l, _), .publishingL2CAPChannelFailed(r, _)): return l == r
    // Unknown
    case (.unknownWriteType, .unknownWriteType): return true
    default: return false
    }
}

// swiftlint:enable cyclomatic_complexity
