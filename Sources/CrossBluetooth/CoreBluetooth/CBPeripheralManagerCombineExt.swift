//
//  CBPeripheralManagerCombineExt.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 11/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//
import Foundation
import CoreBluetooth
import Combine

// MARK: - state publisher
extension CBPeripheralManager {
    
    public func statePublisher() -> AnyPublisher<CBManagerState, Never> {
        self.publisher(for: \.state).eraseToAnyPublisher()
    }
    
}
// MARK: - Peripheral : Read Characteristic publisher

extension CBPeripheralManager {
    public func readRequestPublisher(forCharacteristic characteristic : CBCharacteristic) -> AnyPublisher<CBATTRequest, BluetoothError>  {
        return BTReadRequestPublisher(peripheralManager: self, characteristic: characteristic).eraseToAnyPublisher()
    }
}

// MARK: - Peripheral : Write Characteristic publisher

extension CBPeripheralManager {
    public func writeRequestPublisher(forCharacteristic characteristic : CBCharacteristic) -> AnyPublisher<CBATTRequest, BluetoothError>  {
        return BTWriteRequestPublisher( peripheralManager: self, characteristic: characteristic).eraseToAnyPublisher()
    }
}

// MARK: - Peripheral : Did subscribe to Characteritics
extension CBPeripheralManager {
    public func didSubscribeToCharacteristic() -> AnyPublisher<(CBCentral,CBCharacteristic,PubSubEvent), Never>  {
        return BTDidSubscribeToCharacteristicPublisher(peripheralManager: self).eraseToAnyPublisher()
    }
}

// MARK: - Peripheral : Update Characteristic publisher

extension CBPeripheralManager {
    public func updateValuePublisher( central : CBCentral, characteristic : CBMutableCharacteristic ,value : Data) -> AnyPublisher<Int, BluetoothError>  {
        return BTUpdateValuePublisher( peripheralManager: self,central : central ,characteristic: characteristic, value : value ).eraseToAnyPublisher()
    }
}
// MARK: - Peripheral : Is Ready to Update Characteristic publisher

extension CBPeripheralManager {
    public func isReadyToUpdateValuePublisher(characteristic : CBMutableCharacteristic) -> AnyPublisher<Bool, Never>  {
        return BTIsReadyToUpdateValuePublisher( peripheralManager: self, characteristic: characteristic).eraseToAnyPublisher()
    }
}
// MARK: - Service Advertising publisher

extension CBPeripheralManager {
    public func advertiseDataPublisher(advertisementData :  [String : Any]) -> AnyPublisher<CBPeripheralManager, BluetoothError>  {
        return BTAdvertiseDataPublisher(peripheralManager: self, advertisementData: advertisementData).eraseToAnyPublisher()
    }
}

// MARK: - Service Advertising publisher

extension CBPeripheralManager {
    public func advertiseServicePublisher(service :  CBMutableService) -> AnyPublisher<CBService, BluetoothError>  {
        return BTAdvertiseServicePublisher(peripheralManager: self, service :  service).eraseToAnyPublisher()
    }
}
// MARK: - L2CAP publisher

extension CBPeripheralManager {
    public func advertiseL2CAPPublisher(withEncryption encryption: Bool = false) -> AnyPublisher<(CBL2CAPPSM,PubSubEvent), BluetoothError>  {
        return BTAdvertiseL2CAPChannelPublisher(peripheralManager: self, withEncryption: encryption).eraseToAnyPublisher()
    }
}
extension CBPeripheralManager {
    public func didOpenL2CAPChannel(psm: CBL2CAPPSM) -> AnyPublisher<(CBL2CAPChannel,PubSubEvent), BluetoothError>  {
        return BTDidOpenL2CAPChannelPublisher(peripheralManager: self, withPSM : psm).eraseToAnyPublisher()
    }
}
