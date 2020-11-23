//
//  CentralCharacteristicPublishers.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 13/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine
// MARK: -  CENTRAL : Scan Descriptor publisher

final class BTDescriptorSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBCharacteristic,[CBDescriptor]), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<(CBCharacteristic,[CBDescriptor]), BluetoothError>? = nil
    private let characteristic: CBCharacteristic
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic ) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.peripheralDelegateWrapper = characteristic.service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            characteristic.service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.descriptorSubscribers[characteristic] == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        
        peripheralDelegateWrapper.descriptorSubscribers[characteristic] = subscriber
        characteristic.service.peripheral.delegate = peripheralDelegateWrapper
        if characteristic.service.peripheral.state == .connected {
            characteristic.service.peripheral.discoverDescriptors(for: characteristic)
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(characteristic.service.peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.descriptorSubscribers.removeValue(forKey: characteristic)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTDescriptorPublisher: Publisher {
    
    typealias Output = (CBCharacteristic,[CBDescriptor])
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    
    init(withCharacteristic characteristic: CBCharacteristic ) {
        self.characteristic = characteristic
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTDescriptorSubscription(subscriber: subscriber , characteristic: characteristic)
        subscriber.receive(subscription: subscription)
    }
}


// MARK: -  CENTRAL : WriteWithoutResponse publisher

final class BTWriteWithoutResponseSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBCharacteristic,Int), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<(CBCharacteristic,Int), BluetoothError>? = nil
    private let characteristic: CBCharacteristic
    private let payload : Data
    private var isReadyToWriteCancelable : AnyCancellable? = nil
    private var cursorData = 0
    private lazy var maximumTransmissionUnit : Int = {
        //20
       characteristic.service.peripheral.maximumWriteValueLength(for: .withoutResponse)
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , payload : Data) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.payload = payload
        self.peripheralDelegateWrapper = characteristic.service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            characteristic.service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        
        guard isReadyToWriteCancelable == nil else { return } // should not happen but in case of mis-used
        
        
        isReadyToWriteCancelable = characteristic.service.peripheral.readyToWriteWithoutResponsePublisher(forAttribute: characteristic)
            .filter { $0 }
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  isReady in
                guard let self = self else { return }
                let dataSent = self.flushDataToSend()
               // let _ = self.subscriber?.receive((self.characteristic,dataSent))
                if dataSent >= self.payload.count {
                    let _ = self.subscriber?.receive(completion: .finished)
                    //let _ = self.subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
                }
            }
    }
    
    private func  flushDataToSend() -> Int {
        let peripheral = characteristic.service.peripheral
        if peripheral.canSendWriteWithoutResponse {
            while (cursorData < payload.count) {
                let chunkSize = payload.count - cursorData > maximumTransmissionUnit ? maximumTransmissionUnit : payload.count - cursorData
                let range = cursorData..<(cursorData + chunkSize)
                peripheral.writeValue(payload.subdata(in: range), for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
                let _ = subscriber?.receive((characteristic,cursorData + range.count))
                cursorData += chunkSize
                if !peripheral.canSendWriteWithoutResponse {
                    return cursorData
                }
            }
        }
        return cursorData
    }
    
    func cancel() {
        isReadyToWriteCancelable?.cancel()
        isReadyToWriteCancelable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTWriteWithoutResponsePublisher: Publisher {
    
    typealias Output = (CBCharacteristic,Int)
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let payload : Data
    
    init(withCharacteristic characteristic: CBCharacteristic , payload : Data) {
        self.characteristic = characteristic
        self.payload = payload
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTWriteWithoutResponseSubscription(subscriber: subscriber , characteristic: characteristic, payload : payload)
        subscriber.receive(subscription: subscription)
    }
}


// MARK: - CENTRAL : UpdateValue publisher

final class BTDidUpdateValueSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBAttribute,Data), SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<(CBAttribute,Data), BluetoothError>? = nil
    private let characteristic: CBCharacteristic
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic ) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.peripheralDelegateWrapper = characteristic.service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            characteristic.service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return
        }
        guard let subscriber = subscriber else { return }
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = subscriber
        let _ = subscriber.receive((characteristic,Data()))
        
    }
  
    
    func cancel() {
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTDidUpdateValuePublisher: Publisher {
    
    typealias Output = (CBAttribute,Data)
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

    init(subscriber: SubscriberType, characteristic : CBCharacteristic, setValue : Bool) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.setValue = setValue
        self.peripheralDelegateWrapper = characteristic.service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            characteristic.service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        guard peripheralDelegateWrapper?.notifySubscribers[characteristic] == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        peripheralDelegateWrapper?.notifySubscribers[characteristic] = subscriber
        characteristic.service.peripheral.setNotifyValue(setValue, for: characteristic)
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




// MARK: - CENTRAL : UpdateValue publisher

final class BTReadValueSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == (CBAttribute,Data), SubscriberType.Failure == BluetoothError  {
    
    
    private var subscriber: AnySubscriber<SubscriberType.Input,SubscriberType.Failure >? = nil
    private let characteristic: CBCharacteristic
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic ) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.peripheralDelegateWrapper = characteristic.service.peripheral.delegate as? PeripheralDelegateWrapper ??  {
            let delegate = PeripheralDelegateWrapper()
            characteristic.service.peripheral.delegate = delegate
            return delegate
        }()
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard demand != .none else { return}
        guard let subscriber = subscriber else { return }
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = subscriber
        characteristic.service.peripheral.readValue(for: characteristic)
        
    }
  
    
    func cancel() {
        peripheralDelegateWrapper?.valuesSubscribers[characteristic] = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTReadValuePublisher: Publisher {
    
    typealias Output = (CBAttribute,Data)
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
