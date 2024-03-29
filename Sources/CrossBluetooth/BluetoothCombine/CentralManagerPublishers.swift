//
//  CentralManagerPublishers.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 04/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - state publisher

final class BTCentralManagerStateSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBManagerState,SubscriberType.Failure == Never {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    public let centralManager: CBCentralManager
    private var centralDelegateWrapper : CentralManagerDelegateWrapper?
    init(subscriber: SubscriberType, centralManager: CBCentralManager) {
        self.centralManager = centralManager
        self.subscriber = AnySubscriber(subscriber)
        self.centralDelegateWrapper = centralManager.delegate as?  CentralManagerDelegateWrapper ??  {
            let delegate = CentralManagerDelegateWrapper()
            centralManager.delegate  = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard let centralDelegateWrapper = self.centralDelegateWrapper else { return }
        guard centralDelegateWrapper.stateSubscriber == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(centralManager.state)
            return
        }
        centralDelegateWrapper.stateSubscriber = subscriber
        
        let _ = subscriber?.receive(centralManager.state)
    }
    
    func cancel() {
        centralDelegateWrapper?.stateSubscriber = nil
        centralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTCentralManagerStatePublisher: Publisher {
    
    typealias Output = CBManagerState
    typealias Failure = Never
    
    let centralManager: CBCentralManager
    
    init(centralManager: CBCentralManager) {
        self.centralManager = centralManager
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTCentralManagerStateSubscription(subscriber: subscriber, centralManager: centralManager)
        subscriber.receive(subscription: subscription)
    }
}


// MARK: - scan publisher

final class BTCentralManagerScanSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBCentralManager, ScannedDevice), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    private let centralManager: CBCentralManager
    private let serviceUUIDs: [CBUUID]?
    private let options: [String: Any]?
    private var centralDelegateWrapper : CentralManagerDelegateWrapper?
    private var scanningStateCancelable : AnyCancellable? = nil
    
    init(subscriber: SubscriberType, centralManager: CBCentralManager , withServices serviceUUIDs: [CBUUID]? ,
         options: [String: Any]? ) {
        self.subscriber = AnySubscriber(subscriber)
        self.centralManager = centralManager
        self.serviceUUIDs = serviceUUIDs
        self.options = options
        self.centralDelegateWrapper = centralManager.delegate as?  CentralManagerDelegateWrapper ??  {
            let delegate = CentralManagerDelegateWrapper()
            centralManager.delegate  = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard centralDelegateWrapper?.scanSubscriber == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.scanInProgress))
            return
        }
        scanningStateCancelable = centralManager.publisher(for: \.isScanning).dropFirst().sink { [weak self] isScanning in
            if !isScanning {
                self?.subscriber?.receive(completion: .finished)
            }
        }
        centralDelegateWrapper?.scanSubscriber = subscriber
        
        if centralManager.state == .poweredOn && !centralManager.isScanning {
                centralManager.scanForPeripherals(withServices:serviceUUIDs, options: options)
            }
    }
    
    func cancel() {
        subscriber = nil
        centralDelegateWrapper?.scanSubscriber = nil
        centralDelegateWrapper = nil
        if centralManager.isScanning && centralManager.state == .poweredOn {
            centralManager.stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let scannedDevice = ScannedDevice(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI.intValue)
        _ = subscriber?.receive((central, scannedDevice))
    }
}
struct BTCentralManagerScanPublisher : Publisher {
    
    typealias Output = (CBCentralManager,ScannedDevice)
    typealias Failure = BluetoothError
    
    let centralManager: CBCentralManager
    let serviceUUIDs: [CBUUID]?
    let options: [String: Any]?
    
    init(centralManager: CBCentralManager ,withServices serviceUUIDs: [CBUUID]? = nil,
         options: [String: Any]? = nil) {
        self.centralManager = centralManager
        self.serviceUUIDs = serviceUUIDs
        self.options = options
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTCentralManagerScanSubscription(subscriber: subscriber, centralManager: centralManager, withServices : serviceUUIDs, options : options)
        subscriber.receive(subscription: subscription)
    }
}
