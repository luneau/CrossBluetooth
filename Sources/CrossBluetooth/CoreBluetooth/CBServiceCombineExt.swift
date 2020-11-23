//
//  CBServiceCombineExt.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 03/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: -  CENTRAL : Scan Included Services publisher (requires to be connected)

extension CBService {
    public func includedServicesPublisher(withServices serviceUUIDs: [CBUUID]? = nil) -> AnyPublisher<(CBService,[CBService]), BluetoothError> {
        return BTIncludedServicesPublisher ( withService:  self,  withServices : serviceUUIDs).eraseToAnyPublisher()
    }
}

// MARK: - CENTRAL : Scan Characteristics publisher (requires to be connected)

extension CBService {
    public func characteristicsPublisher(withServices serviceUUIDs: [CBUUID]? = nil) -> AnyPublisher<(CBService,[CBCharacteristic]), BluetoothError> {
        return BTCharacteristicPublisher ( withService:  self,  withServices : serviceUUIDs).eraseToAnyPublisher()
    }
}
