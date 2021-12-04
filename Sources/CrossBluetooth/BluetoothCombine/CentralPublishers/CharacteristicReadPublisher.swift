//
//  CharacteristicWritePublisher.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 13/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.

import Foundation
import CoreBluetooth
import Combine



// MARK: - CENTRAL : UpdateValue publisher

final class BTReadValueSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    
    private var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure >? = nil
    private let characteristic: CBCharacteristic
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    private let peripheral : CBPeripheral?
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic ) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
#if compiler(>=5.5)
        guard let service = characteristic.service, let peripheral = service.peripheral else {
            self.peripheralDelegateWrapper = nil
            self.peripheral = nil
            return
        }
#else
        let peripheral = characteristic.service.peripheral
#endif
        self.peripheral = peripheral
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return}
        guard let subscriber = subscriber else { return }
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = subscriber
        peripheral?.readValue(for: characteristic)
    }
    
    func cancel() {
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
}

struct BTReadValuePublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    
    init(withCharacteristic characteristic: CBCharacteristic ) {
        self.characteristic = characteristic
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTReadValueSubscription(subscriber: subscriber , characteristic: characteristic)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - CENTRAL : DidUpdateValue publisher

final class BTDidUpdateValueSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input , SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let peripheral : CBPeripheral?
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic ) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
#if compiler(>=5.5)
        guard let service = characteristic.service, let peripheral = service.peripheral else {
            self.peripheralDelegateWrapper = nil
            self.peripheral = nil
            return
        }
#else
        let peripheral = characteristic.service.peripheral
#endif
        self.peripheral = peripheral
        self.peripheralDelegateWrapper = peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return }
        guard let subscriber = subscriber else { return }
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = subscriber
        let _ = subscriber.receive(Data())
    }
    
    func cancel() {
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTDidUpdateValuePublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    
    init(withCharacteristic characteristic: CBCharacteristic ) {
        self.characteristic = characteristic
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTDidUpdateValueSubscription(subscriber: subscriber , characteristic: characteristic)
        subscriber.receive(subscription: subscription)
    }
}

// MARK: - CENTRAL : ask for notfication publisher

final class BTSetNotificationSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == CBCharacteristic, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let setValue : Bool
    private let peripheral : CBPeripheral?
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic, setValue : Bool) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.setValue = setValue
#if compiler(>=5.5)
        guard let service = characteristic.service, let peripheral = service.peripheral else {
            self.peripheralDelegateWrapper = nil
            self.peripheral = nil
            return
        }
#else
        let peripheral = characteristic.service.peripheral
#endif
        self.peripheral = peripheral
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
        
        guard let peripheral = peripheral else {
            return
        }
        
        guard peripheralDelegateWrapper?.notifySubscribers[characteristic] == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        peripheralDelegateWrapper?.notifySubscribers[characteristic] = subscriber
        peripheral.setNotifyValue(setValue, for: characteristic)
    }
    
    func cancel() {
        peripheralDelegateWrapper?.notifySubscribers.removeValue(forKey: characteristic)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTSetNotificationPublisher: Publisher {
    
    typealias Output = CBCharacteristic
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let setValue : Bool
    
    init(withCharacteristic characteristic: CBCharacteristic, setValue : Bool) {
        self.characteristic = characteristic
        self.setValue = setValue
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTSetNotificationSubscription(subscriber: subscriber , characteristic: characteristic, setValue : setValue)
        subscriber.receive(subscription: subscription)
    }
}
