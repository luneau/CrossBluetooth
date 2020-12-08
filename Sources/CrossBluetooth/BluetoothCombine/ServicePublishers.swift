//
//  ServicePublishers.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 13/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: -  CENTRAL : Scan Included Services publisher

final class BTIncludedServicesSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBService,[CBService]), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<(CBService,[CBService]), BluetoothError>? = nil
    private let service: CBService
    private let serviceUUIDs: [CBUUID]?
    
    init(subscriber: SubscriberType, service : CBService , withServices serviceUUIDs: [CBUUID]? = nil) {
        self.subscriber = AnySubscriber(subscriber)
        self.service = service
        self.serviceUUIDs = serviceUUIDs
        self.peripheralDelegateWrapper = service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.includedServiceSubscribers[service] == nil else {
            // only one subscription per  service àoç
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        
        peripheralDelegateWrapper.includedServiceSubscribers[service] = subscriber
        service.peripheral.delegate = peripheralDelegateWrapper
        if service.peripheral.state == .connected {
            service.peripheral.discoverIncludedServices(serviceUUIDs, for: service)
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(service.peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.includedServiceSubscribers.removeValue(forKey: service)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTIncludedServicesPublisher: Publisher {
    
    typealias Output = (CBService,[CBService])
    typealias Failure = BluetoothError
    
    private let service: CBService
    let serviceUUIDs: [CBUUID]?
    
    init(withService service: CBService ,withServices serviceUUIDs: [CBUUID]? = nil) {
        self.service = service
        self.serviceUUIDs = serviceUUIDs
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTIncludedServicesSubscription(subscriber: subscriber , service: service, withServices : serviceUUIDs)
        subscriber.receive(subscription: subscription)
    }
}


// MARK: - CENTRAL : Scan Characteristics publisher

final class BTCharacteristicSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBService,[CBCharacteristic]), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<(CBService,[CBCharacteristic]), BluetoothError>? = nil
    private let service: CBService
    private let uuids: [CBUUID]?
    
    init(subscriber: SubscriberType, service : CBService , forUUIDs uuids: [CBUUID]? = nil,
         options: [String: Any]? = nil) {
        self.subscriber = AnySubscriber(subscriber)
        self.service = service
        self.uuids = uuids
        self.peripheralDelegateWrapper = service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.characteristicSubscribers[service] == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        
        peripheralDelegateWrapper.characteristicSubscribers[service] = subscriber
        service.peripheral.delegate = peripheralDelegateWrapper
        if service.peripheral.state == .connected {
            service.peripheral.discoverCharacteristics(uuids, for: service)
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(service.peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.characteristicSubscribers.removeValue(forKey: service)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTCharacteristicPublisher: Publisher {
    
    typealias Output = (CBService,[CBCharacteristic])
    typealias Failure = BluetoothError
    
    private let service: CBService
    let uuids: [CBUUID]?
    
    init(withService service: CBService ,forUUIDs uuids: [CBUUID]? = nil) {
        self.service = service
        self.uuids = uuids
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTCharacteristicSubscription(subscriber: subscriber , service: service, forUUIDs : uuids)
        subscriber.receive(subscription: subscription)
    }
}
