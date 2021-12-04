//
//  CharacteristicDescriptorPublisher.swift
//  
//
//  Created by Sébastien Luneau on 04/12/2021.
//

import Foundation
import CoreBluetooth
import Combine

// MARK: -  CENTRAL : Scan Descriptor publisher

final class BTDescriptorSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == [CBDescriptor], SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>? = nil
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
        guard demand != .none else {
            return
        }
        guard let peripheral = peripheral else {
            return
        }
        guard let peripheralDelegateWrapper = self.peripheralDelegateWrapper else  { return }
        guard peripheralDelegateWrapper.descriptorSubscribers[characteristic] == nil else {
            // only one subscription per  manager
            let _ = subscriber?.receive(completion: .failure(BluetoothError.onlyOneSubscriberAuthorized))
            return
        }
        
        peripheralDelegateWrapper.descriptorSubscribers[characteristic] = subscriber
        peripheral.delegate = peripheralDelegateWrapper
        if peripheral.state == .connected {
            peripheral.discoverDescriptors(for: characteristic)
        } else {
            let _ = subscriber?.receive(completion: .failure(BluetoothError.peripheralIsNotConnected(peripheral)))
        }
    }
    
    func cancel() {
        peripheralDelegateWrapper?.descriptorSubscribers.removeValue(forKey: characteristic)
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTDescriptorPublisher: Publisher {
    
    typealias Output = [CBDescriptor]
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
