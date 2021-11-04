//
//  CBCharacteristicCombineExt.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 05/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: -  CENTRAL : Scan Descriptor publisher
/**
 *  @method descriptorPublisher
 *
 *  @discussion         This method returns a Publisher of Descriptors attach to the Characteristic
 *
 */
extension CBCharacteristic {
    public func descriptorPublisher() -> AnyPublisher<[CBDescriptor], BluetoothError> {
        return BTDescriptorPublisher ( withCharacteristic:  self).eraseToAnyPublisher()
    }
}

// MARK: -  CENTRAL : WriteWithoutResponse publisher

extension CBCharacteristic {
    public func writeWithoutResponsePublisher(withPayload payload : Data) -> AnyPublisher<Int, BluetoothError> {
        return BTWriteWithoutResponsePublisher( withCharacteristic:  self, payload : payload ).eraseToAnyPublisher()
    }
}
extension CBCharacteristic {
    public func writeWithoutResponsePublisher(withDataPublisher publisher : AnyPublisher<Data, BluetoothError>) -> AnyPublisher<Int, BluetoothError> {
        return BTDataWriteWithoutResponsePublisher( withCharacteristic:  self, publisher : publisher ).eraseToAnyPublisher()
    }
}
// MARK: -  CENTRAL : WriteWithResponse publisher

extension CBCharacteristic {
    public func writeWithResponsePublisher(withPayload payload : Data) -> AnyPublisher<Int, BluetoothError> {
        return BTWriteWithResponsePublisher( withCharacteristic:  self, payload : payload ).eraseToAnyPublisher()
    }
}

extension CBCharacteristic {
    public func writeWithResponsePublisher(withDataPublisher publisher : AnyPublisher<Data, BluetoothError>) -> AnyPublisher<Int, BluetoothError> {
        return BTDataWriteWithResponsePublisher( withCharacteristic:  self, publisher : publisher ).eraseToAnyPublisher()
    }
}
// MARK: -  CENTRAL : Packet Data Publisher

extension CBCharacteristic {
    public func packetDataPublisher(forType type: CBCharacteristicWriteType) -> PacketDataSubject {
        let mtu = self.service?.peripheral?.maximumWriteValueLength(for: type) ?? 23
        return PacketDataSubject(withMtu: mtu)
    }
}

// MARK: - CENTRAL : UpdateValue publisher

extension CBCharacteristic {
    public func didUpdateValuePublisher() -> AnyPublisher< Data, BluetoothError> {
        return BTDidUpdateValuePublisher( withCharacteristic:  self ).eraseToAnyPublisher()
    }
}

// MARK: - CENTRAL : ReadValue publisher

extension CBCharacteristic {
    public func readValuePublisher() -> AnyPublisher<Data, BluetoothError> {
        return BTReadValuePublisher( withCharacteristic:  self ).eraseToAnyPublisher()
    }
}
// MARK: - CENTRAL : ask for notfication publisher

extension CBCharacteristic {
    public func setNotificationPublisher(value : Bool = true) -> AnyPublisher<CBCharacteristic, BluetoothError> {
        return BTSetNotificationPublisher( withCharacteristic:  self, setValue : value ).eraseToAnyPublisher()
    }
}

// MARK: - CENTRAL : open L2CAP publisher

extension CBCharacteristic {
    public var L2CAP_PSM : CBL2CAPPSM {
        get {
            guard let value = self.value else { return 0}
            return value.withUnsafeBytes { $0.load(as: UInt16.self) }
        }
    }
    public func openL2CAPPublisher(psm : CBL2CAPPSM) -> AnyPublisher<CBL2CAPChannel, BluetoothError> {
        
#if compiler(>=5.5)
        guard  let service = self.service,
               let peripheral = service.peripheral else {
                   return Fail(error: BluetoothError.destroyed).eraseToAnyPublisher()
               }
        return BTOpenL2CAPPublisher( peripheral , psm : psm ).eraseToAnyPublisher()
#else
        return BTOpenL2CAPPublisher( self.service.peripheral , psm : psm ).eraseToAnyPublisher()
#endif
        
    }
    
}
