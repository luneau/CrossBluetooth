//
//  CBCentralManagerCombineExt.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 23/10/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

public struct ScannedDevice {
    
    public let peripheral: CBPeripheral
    public let advertisementData: [String : Any]
    public let rssi: Int
}

// MARK: - state publisher

extension CBCentralManager {
    public class func statePublisher(centralManager: CBCentralManager = CBCentralManager()) -> AnyPublisher<CBManagerState,Never> {
        return BTCentralManagerStatePublisher(centralManager: centralManager).eraseToAnyPublisher()
    }
    public func statePublisher() -> AnyPublisher<CBManagerState, Never> {
            self.publisher(for: \.state).eraseToAnyPublisher()
    }
    
}

// MARK: - scan publisher

extension CBCentralManager {
    public class func scanPublisher(withServices serviceUUIDs: [CBUUID]? = nil,
                             options: [String: Any]? = nil, centralManager : CBCentralManager = CBCentralManager()) -> AnyPublisher<(CBCentralManager,ScannedDevice),BluetoothError> {
        return BTCentralManagerScanPublisher (centralManager: centralManager, withServices : serviceUUIDs, options : options).eraseToAnyPublisher()
    }
    
    public func scanPublisher(withServices serviceUUIDs: [CBUUID]? = nil,
                             options: [String: Any]? = nil) -> AnyPublisher<(CBCentralManager,ScannedDevice),BluetoothError> {
        return BTCentralManagerScanPublisher (centralManager: self, withServices : serviceUUIDs, options : options).eraseToAnyPublisher()
    }
}
