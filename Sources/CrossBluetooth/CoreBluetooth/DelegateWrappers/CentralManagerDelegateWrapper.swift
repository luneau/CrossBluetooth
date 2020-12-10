//
//  CentralManagerDelegateWrapper.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 25/10/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import CoreBluetooth
import Combine
import os.log

final class CentralManagerDelegateWrapper: NSObject, CBCentralManagerDelegate {
    
    public var stateSubscriber : AnySubscriber<CBManagerState, Never>? = nil
    public var scanSubscriber: AnySubscriber<(CBCentralManager, ScannedDevice), BluetoothError>? = nil
    public var connectionSuscribers = [CBPeripheral : AnySubscriber<CBPeripheralState, BluetoothError>]()
   
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let _ = stateSubscriber?.receive(central.state)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let scannedDevice = ScannedDevice(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI.intValue)
        let _ = scanSubscriber?.receive((central,scannedDevice))
       
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //self.centralManager(central: central, didConnect: peripheral)
        guard let subscriber = connectionSuscribers[peripheral] else {  return }
        //let _ = subscriber?.subscriber?.receive((peripheral , peripheral.state))
        let _ = subscriber.receive(peripheral.state)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //self.centralManager(central: central, didFailToConnect: peripheral, error: error)
        guard let subscriber = connectionSuscribers[peripheral] else {  return }
       // let _ = subscriber?.subscriber?.receive(completion: .failure(BluetoothError.peripheralConnectionFailed(peripheral, error)))
        let _ = subscriber.receive(completion: .failure(BluetoothError.peripheralConnectionFailed(peripheral, error)))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        //centralManager(central: central, didDisconnectPeripheral: peripheral, error: error)
        guard let subscriber = connectionSuscribers[peripheral] else {  return }
        
        let _ =  error == nil ? subscriber.receive(completion: .finished)
            : subscriber.receive(completion: .failure(BluetoothError.peripheralDisconnected(peripheral,error)))
        
    }
}
