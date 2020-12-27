//
//  CBPeripheralCombineExt.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 24/10/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//
import Foundation
import CoreBluetooth
import Combine



// MARK: - state publisher
extension CBPeripheral {  
    public func statePublisher() -> AnyPublisher<CBPeripheralState, Never> {
        self.publisher(for: \.state).eraseToAnyPublisher()
    }
}
// MARK: - state publisher
extension CBPeripheral {
    public func namePublisher() -> AnyPublisher<String?, Never> {
        self.publisher(for: \.name).eraseToAnyPublisher()
    }
}
// MARK: - RSSI updates publisher
extension CBPeripheral {
    public func rssiPublisher() -> AnyPublisher<Int,BluetoothError> {
        BTPeripheralRSSIPublisher(peripheral: self).eraseToAnyPublisher()
    }
}

// MARK: - fetch servives publisher
extension CBPeripheral {
    public func servicesPublisher(withServices serviceUUIDs: [CBUUID]? = nil) -> AnyPublisher<([CBService],[CBService]),BluetoothError> {
        return BTPeripheralServicesPublisher ( peripheral : self,  withServices : serviceUUIDs).eraseToAnyPublisher()
    }
}

// MARK: - Connection Disconnection lifecyle updates publisher
extension CBPeripheral {
    public func connect(_ centralManager: CBCentralManager,
                 options: [String : Any]? = nil) -> AnyPublisher<CBPeripheralState,BluetoothError>  {
        
        return BTPeripheralConnectionStatePublisher (centralManager: centralManager, peripheral : self, options : options).eraseToAnyPublisher()
    }
    func disconnect(_ centralManager: CBCentralManager){
        guard self.state != .connected else {return}
        centralManager.cancelPeripheralConnection(self)
        
    }
}


extension CBPeripheral {
    public func readyToWriteWithoutResponsePublisher(forAttribute attribute : CBAttribute) -> AnyPublisher<Bool,BluetoothError> {
        return BTPeripheralReadyToWritePublisher (self, attribute : attribute).eraseToAnyPublisher()
    }
    
}

extension CBPeripheral {
    public func didWritePublisher(forAttribute attribute : CBAttribute) -> AnyPublisher<CBAttribute,BluetoothError> {
        return BTPeripheralDidWritePublisher (self, attribute : attribute).eraseToAnyPublisher()
    }
    
}

