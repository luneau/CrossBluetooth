//
//  PeripheralManagerPublishers.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 13/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Peripheral : Read Characteristic publisher

final class BTReadRequestSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBPeripheralManager,CBATTRequest), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    private let characteristic: CBCharacteristic
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.readRequestSubscribers[characteristic] == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.readRequestSubscribers[characteristic] = subscriber
    }
    
    func cancel() {
        delegateWrapper?.readRequestSubscribers.removeValue(forKey: characteristic)
        subscriber = nil
        delegateWrapper = nil
    }
}
struct BTReadRequestPublisher : Publisher {
    
    typealias Output = (CBPeripheralManager,CBATTRequest)
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let characteristic: CBCharacteristic
    
    init(peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic) {
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTReadRequestSubscription(subscriber: subscriber, peripheralManager: peripheralManager, characteristic: characteristic)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : Write Characteristic publisher

final class BTPWriteRequestSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBPeripheralManager,CBATTRequest), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    private let characteristic: CBCharacteristic
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.writeRequestSubscribers[characteristic] == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.writeRequestSubscribers[characteristic] = subscriber
    }
    
    func cancel() {
        delegateWrapper?.writeRequestSubscribers.removeValue(forKey: characteristic)
        subscriber = nil
        delegateWrapper = nil
    }
}
struct BTWriteRequestPublisher : Publisher {
    
    typealias Output = (CBPeripheralManager,CBATTRequest)
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let characteristic: CBCharacteristic
    
    init(peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic) {
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPWriteRequestSubscription(subscriber: subscriber, peripheralManager: peripheralManager, characteristic: characteristic)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : Update Characteristic publisher

final class BTPUpdateValueSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBPeripheralManager,CBATTRequest), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    private let characteristic: CBCharacteristic
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    private let data : Data
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic, value : Data) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
        self.data = value
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.updateValueSubscribers[characteristic] == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.updateValueSubscribers[characteristic] = subscriber
    }
    func updateDate() {
        
    }
    func cancel() {
        delegateWrapper?.updateValueSubscribers.removeValue(forKey: characteristic)
        subscriber = nil
        delegateWrapper = nil
    }
}
struct BTUpdateValuePublisher : Publisher {
    
    typealias Output = (CBPeripheralManager,CBATTRequest)
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let characteristic: CBCharacteristic
    let data : Data
    
    init(peripheralManager: CBPeripheralManager , characteristic: CBCharacteristic, value : Data) {
        self.peripheralManager = peripheralManager
        self.characteristic = characteristic
        self.data = value
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTPUpdateValueSubscription(subscriber: subscriber, peripheralManager: peripheralManager, characteristic: characteristic, value: data)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : advertise data publisher

final class BTAdvertiseDataSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBPeripheralManager, SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    let advertisementData :  [String : Any]
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , advertisementData: [String : Any]) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.advertisementData = advertisementData
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.advertisingSubscriber == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.advertisingSubscriber = subscriber
        peripheralManager.startAdvertising(advertisementData)
    }
    
    func cancel() {
        peripheralManager.stopAdvertising()
        delegateWrapper?.advertisingSubscriber = nil
        subscriber = nil
        delegateWrapper = nil
    }
}
struct BTAdvertiseDataPublisher : Publisher {
    
    typealias Output = CBPeripheralManager
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let advertisementData :  [String : Any]
    
    init(peripheralManager: CBPeripheralManager , advertisementData: [String : Any]) {
        self.peripheralManager = peripheralManager
        self.advertisementData = advertisementData
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTAdvertiseDataSubscription(subscriber: subscriber, peripheralManager: peripheralManager, advertisementData: advertisementData)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : advertise Service publisher

final class BTAdvertiseServiceSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBService, SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    let service: CBMutableService
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , service: CBMutableService) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.service = service
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.addServiceSubscribers[service] == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.addServiceSubscribers[service] = subscriber
        peripheralManager.add(service)
    }
    
    func cancel() {
        peripheralManager.remove(service)
        delegateWrapper?.addServiceSubscribers.removeValue(forKey: service)
        subscriber = nil
        delegateWrapper = nil
    }
}
struct BTAdvertiseServicePublisher : Publisher {
    
    typealias Output = CBService
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let service: CBMutableService
    
    init(peripheralManager: CBPeripheralManager , service: CBMutableService) {
        self.peripheralManager = peripheralManager
        self.service = service
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTAdvertiseServiceSubscription(subscriber: subscriber, peripheralManager: peripheralManager, service: service)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : advertise L2CAP Channel publisher

final class BTAdvertiseL2CAPChannelSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBL2CAPPSM,PubSubEvent), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    let encryption: Bool
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , withEncryption encryption: Bool = false) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.encryption = encryption
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
      
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.advertisingL2CAPSubscriber == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.advertisingL2CAPSubscriber = subscriber
        peripheralManager.publishL2CAPChannel(withEncryption: encryption)
    }
    
    func cancel() {
        delegateWrapper?.advertisingL2CAPSubscriber = nil
        subscriber = nil
        delegateWrapper = nil
    }
}

struct BTAdvertiseL2CAPChannelPublisher : Publisher {
    
    typealias Output = (CBL2CAPPSM,PubSubEvent)
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let encryption: Bool
    
    init(peripheralManager: CBPeripheralManager ,  withEncryption encryption: Bool = false) {
        self.peripheralManager = peripheralManager
        self.encryption = encryption
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTAdvertiseL2CAPChannelSubscription(subscriber: subscriber, peripheralManager: peripheralManager, withEncryption : encryption)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: - Peripheral : didopen L2CAP Channel publisher

final class BTDidOpenL2CAPChannelSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBL2CAPChannel,PubSubEvent), SubscriberType.Failure == BluetoothError  {
    
    public var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>?
    private let peripheralManager: CBPeripheralManager
    private var delegateWrapper : PeripheralManagerDelegateWrapper? = nil
    let psm : CBL2CAPPSM
    
    init(subscriber: SubscriberType, peripheralManager: CBPeripheralManager , withPSM psm : CBL2CAPPSM) {
        self.subscriber = AnySubscriber<SubscriberType.Input,SubscriberType.Failure>(receiveSubscription: { subscriber.receive(subscription: $0)}, receiveValue: {subscriber.receive($0)
        }, receiveCompletion: {subscriber.receive(completion: $0)})
        self.peripheralManager = peripheralManager
        self.psm = psm
        self.delegateWrapper = peripheralManager.delegate as? PeripheralManagerDelegateWrapper ??  {
            let delegate = PeripheralManagerDelegateWrapper()
            peripheralManager.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard let delegateWrapper = delegateWrapper else { return}
        guard delegateWrapper.didOpenL2CAPSubscribers[psm] == nil else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        delegateWrapper.didOpenL2CAPSubscribers[psm]  = subscriber
    }
    
    func cancel() {
        delegateWrapper?.didOpenL2CAPSubscribers.removeValue(forKey: psm)
        subscriber = nil
        delegateWrapper = nil
    }
}

struct BTDidOpenL2CAPChannelPublisher : Publisher {
    
    typealias Output = (CBL2CAPChannel,PubSubEvent)
    typealias Failure = BluetoothError
    
    let peripheralManager: CBPeripheralManager
    let psm : CBL2CAPPSM
    
    init(peripheralManager: CBPeripheralManager ,  withPSM psm : CBL2CAPPSM) {
        self.peripheralManager = peripheralManager
        self.psm = psm
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTDidOpenL2CAPChannelSubscription(subscriber: subscriber, peripheralManager: peripheralManager, withPSM : psm)
        subscriber.receive(subscription: subscription)
    }
}
