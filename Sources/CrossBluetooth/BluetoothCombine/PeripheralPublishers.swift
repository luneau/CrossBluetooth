//
//  PeripheralPublishers.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 13/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine



// MARK: - rssi publisher
final class BTPeripheralRSSISubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBPeripheral,Int), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>? = nil
    private let peripheral: CBPeripheral
    
    init(subscriber: SubscriberType, peripheral : CBPeripheral ) {
        self.subscriber = AnySubscriber(subscriber)
        self.peripheral = peripheral
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.rssiSubscriber == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        peripheralDelegateWrapper.rssiSubscriber = subscriber
        peripheral.delegate = peripheralDelegateWrapper
        
        if peripheral.state == .connected {
            peripheral.readRSSI()
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.servicesSubscriber = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
}

struct BTPeripheralRSSIPublisher: Publisher {
    typealias Output =  (CBPeripheral,Int)
    typealias Failure = BluetoothError
    
    private let peripheral: CBPeripheral
    
    init( peripheral : CBPeripheral) {
        self.peripheral = peripheral
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPeripheralRSSISubscription(subscriber: subscriber,peripheral: peripheral)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - Scan Services publisher

final class BTPeripheralServicesSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBPeripheral,[CBService],[CBService]), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>? = nil
    private let peripheral: CBPeripheral
    private let serviceUUIDs: [CBUUID]?
    
    init(subscriber: SubscriberType, peripheral : CBPeripheral , withServices serviceUUIDs: [CBUUID]? = nil,
         options: [String: Any]? = nil) {
        self.subscriber = AnySubscriber(subscriber)
        self.peripheral = peripheral
        self.serviceUUIDs = serviceUUIDs
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.servicesSubscriber == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        
        peripheralDelegateWrapper.servicesSubscriber = subscriber
        if peripheral.state == .connected {
            peripheral.discoverServices(serviceUUIDs)
            if let services = peripheral.services {
                if services.count > 0 {
                    let _ = subscriber?.receive((peripheral,services, []))
                }
            }
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.servicesSubscriber = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTPeripheralServicesPublisher: Publisher {
    
    typealias Output = (CBPeripheral,[CBService],[CBService])
    typealias Failure = BluetoothError
    
    private let peripheral: CBPeripheral
    let serviceUUIDs: [CBUUID]?
    
    init(peripheral : CBPeripheral ,withServices serviceUUIDs: [CBUUID]? = nil) {
        self.peripheral = peripheral
        self.serviceUUIDs = serviceUUIDs
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPeripheralServicesSubscription(subscriber: subscriber , peripheral: peripheral, withServices : serviceUUIDs)
        subscriber.receive(subscription: subscription)
    }
}



// MARK: - connect publisher
final class BTPeripheralConnectionStateSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input ==  CBPeripheralState, SubscriberType.Failure == BluetoothError {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    private let centralManager: CBCentralManager
    private let peripheral: CBPeripheral
    private let options: [String: Any]?
    
    private var centralDelegateWrapper : CentralManagerDelegateWrapper?
    
    init(subscriber:  SubscriberType, centralManager: CBCentralManager, peripheral : CBPeripheral ,
         options: [String: Any]? = nil) {
        self.subscriber = AnySubscriber(subscriber)
        self.centralManager = centralManager
        self.peripheral = peripheral
        self.options = options
        self.centralDelegateWrapper = centralManager.delegate as?  CentralManagerDelegateWrapper ??  {
            let delegate = CentralManagerDelegateWrapper()
            centralManager.delegate  = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return }
        guard let subscriber = self.subscriber else {return}
        guard centralDelegateWrapper?.connectionSuscribers[peripheral] == nil else {
            return
        }
        
        centralDelegateWrapper?.connectionSuscribers[peripheral] = subscriber
        
        if peripheral.state == .disconnected {
            self.centralManager.connect(self.peripheral,options: self.options)
        }
        let _ = subscriber.receive( peripheral.state)
    }
    
    func cancel() {
        (peripheral.delegate as? PeripheralDelegateWrapper)?.finishAllSubscritions()
        self.centralManager.cancelPeripheralConnection(peripheral)
        centralDelegateWrapper?.connectionSuscribers.removeValue(forKey: peripheral)
        centralDelegateWrapper = nil
        subscriber = nil
        
    }
    
}
struct BTPeripheralConnectionStatePublisher: Publisher {
    
    typealias Output =  CBPeripheralState
    typealias Failure = BluetoothError
    
    let centralManager: CBCentralManager
    private let peripheral: CBPeripheral
    let options: [String: Any]?
    
    init(centralManager: CBCentralManager, peripheral : CBPeripheral,
         options: [String: Any]? = nil) {
        self.centralManager = centralManager
        self.peripheral = peripheral
        self.options = options
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPeripheralConnectionStateSubscription(subscriber: subscriber, centralManager: centralManager,peripheral: peripheral)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - ready to write without response publisher
final class BTPeripheralReadyToWriteSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Bool, SubscriberType.Failure == BluetoothError {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    private let peripheral: CBPeripheral
    private let attribute : CBAttribute
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(subscriber:  SubscriberType,  peripheral : CBPeripheral , attribute : CBAttribute) {
        self.subscriber = AnySubscriber(subscriber)
        self.peripheral = peripheral
        self.attribute = attribute
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return }
        guard let subscriber = self.subscriber else {return}
        
        guard peripheralDelegateWrapper?.peripheralReadySubscribers[attribute]  == nil else {
            subscriber.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        peripheralDelegateWrapper?.peripheralReadySubscribers[attribute] = subscriber
        
        let _ = subscriber.receive(peripheral.canSendWriteWithoutResponse)
    }
    
    func cancel() {
        peripheralDelegateWrapper?.peripheralReadySubscribers.removeValue(forKey: attribute)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTPeripheralReadyToWritePublisher: Publisher {
    
    typealias Output = Bool
    typealias Failure = BluetoothError
    
    private let peripheral: CBPeripheral
    private let attribute : CBAttribute
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(_ peripheral : CBPeripheral, attribute : CBAttribute) {
        self.peripheral = peripheral
        self.attribute = attribute
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPeripheralReadyToWriteSubscription(subscriber: subscriber, peripheral: peripheral, attribute: attribute)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - did write with response publisher
final class BTPeripheralDidWriteSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBAttribute, SubscriberType.Failure == BluetoothError {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    private let peripheral: CBPeripheral
    private let attribute : CBAttribute
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(subscriber:  SubscriberType,  peripheral : CBPeripheral , attribute : CBAttribute) {
        self.subscriber = AnySubscriber(subscriber)
        self.attribute = attribute
        self.peripheral = peripheral
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return }
        guard let subscriber = self.subscriber else {return}
        
        guard peripheralDelegateWrapper?.didWriteSubscribers[attribute]  == nil else {
            subscriber.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        peripheralDelegateWrapper?.didWriteSubscribers[attribute] = subscriber
        
    }
    
    func cancel() {
        peripheralDelegateWrapper?.didWriteSubscribers.removeValue(forKey: attribute)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTPeripheralDidWritePublisher: Publisher {
    
    typealias Output = CBAttribute
    typealias Failure = BluetoothError
    
    private let peripheral: CBPeripheral
    private let attribute : CBAttribute
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(_ peripheral : CBPeripheral, attribute : CBAttribute) {
        self.peripheral = peripheral
        self.attribute = attribute
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPeripheralDidWriteSubscription(subscriber: subscriber, peripheral: peripheral, attribute: attribute)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - open L2CAP publisher
final class BTOpenL2CAPSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBL2CAPChannel, SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure>?
    private let peripheral: CBPeripheral
    private let psm : CBL2CAPPSM
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(subscriber: SubscriberType,  peripheral : CBPeripheral , psm : CBL2CAPPSM) {
        
        self.subscriber = AnySubscriber(subscriber)
        self.peripheral = peripheral
        self.psm = psm
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return }
        guard let subscriber = self.subscriber else {return}
        
        
        guard peripheralDelegateWrapper?.peripheralDidOpenL2CAPSubscribers[psm]  == nil else {
            subscriber.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
            
        }
        peripheralDelegateWrapper?.peripheralDidOpenL2CAPSubscribers[psm] = subscriber
        peripheral.openL2CAPChannel(psm)
    }
    
    func cancel() {
        peripheralDelegateWrapper?.peripheralDidOpenL2CAPSubscribers.removeValue(forKey: psm)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTOpenL2CAPPublisher: Publisher {
    
    typealias Output = CBL2CAPChannel
    typealias Failure = BluetoothError
    
    private let peripheral: CBPeripheral
    private let psm : CBL2CAPPSM
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(_ peripheral : CBPeripheral, psm : CBL2CAPPSM) {
        self.peripheral = peripheral
        self.psm = psm
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {                  
        let subscription = BTOpenL2CAPSubscription(subscriber: subscriber, peripheral: peripheral, psm: psm)
        subscriber.receive(subscription: subscription)
    }
}
