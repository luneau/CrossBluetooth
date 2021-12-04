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

// MARK: -  CENTRAL : Write publisher (with or without response)


extension CBCharacteristic {
    public func writePacketsPublisher(dataPacketsPublisher publisher : AnyPublisher<(CBCharacteristicWriteType,Data), BluetoothError>) -> AnyPublisher<Data, BluetoothError> {
        return BTWritePacketsPublisher( withCharacteristic:  self, publisher : publisher ).eraseToAnyPublisher()
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
