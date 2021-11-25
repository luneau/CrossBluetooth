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


// MARK: -  CENTRAL : WriteWithoutResponse publisher

final class BTWriteWithoutResponseSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Int, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input , SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let payload : Data
    private var isReadyToWriteCancelable : AnyCancellable? = nil
    private var cursorData = 0
    private let peripheral : CBPeripheral?
    
    private lazy var maximumTransmissionUnit : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withoutResponse) ?? 0
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , payload : Data) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.payload = payload
        
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
        guard isReadyToWriteCancelable == nil else { return } // should not happen but in case of mis-used
        
        
        isReadyToWriteCancelable = peripheral.readyToWriteWithoutResponsePublisher(forAttribute: characteristic)
            .filter { $0 }
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  isReady in
                guard let self = self else { return }
                let dataSent = self.flushDataToSend()
                if dataSent >= self.payload.count {
                    let _ = self.subscriber?.receive(completion: .finished)
                }
            }
        
    }
    
    private func  flushDataToSend() -> Int {
        guard let peripheral = peripheral else {
            return 0
        }
        if peripheral.canSendWriteWithoutResponse {
            while (cursorData < payload.count) {
                let chunkSize = payload.count - cursorData > maximumTransmissionUnit ? maximumTransmissionUnit : payload.count - cursorData
                let range = cursorData..<(cursorData + chunkSize)
                peripheral.writeValue(payload.subdata(in: range), for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
                let _ = subscriber?.receive(cursorData + range.count)
                cursorData += chunkSize
                if !peripheral.canSendWriteWithoutResponse {
                    return cursorData
                }
            }
        }
        return cursorData
    }
    
    func cancel() {
        isReadyToWriteCancelable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}
struct BTWriteWithoutResponsePublisher: Publisher {
    
    typealias Output = Int
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

final class BTDataWriteWithoutResponseSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input , SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let dataPublisherBuffer : AnyPublisher<Data, BluetoothError>
    private var isReadyToWriteCancelable : AnyCancellable? = nil
    private var isReadyToSendCancelable : AnyCancellable? = nil
    private var dataPublisherCancelable : AnyCancellable? = nil
    private var cursorData = 0
    private let peripheral : CBPeripheral?
    
    @Published private var isReadyToSend : Bool = true
    private var dataQueue = SynchronizedArray<Data>()
    
    private lazy var maximumTransmissionUnit : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withoutResponse) ?? 0
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , publisher : AnyPublisher<Data, BluetoothError>) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.dataPublisherBuffer = publisher
        
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
        guard isReadyToWriteCancelable == nil else { return } // should not happen but in case of mis-used
        isReadyToWriteCancelable = peripheral.readyToWriteWithoutResponsePublisher(forAttribute: characteristic)
            .sink(receiveCompletion: {_ in}, receiveValue: { [weak self] _ in
                self?.isReadyToSend = true
            })
        isReadyToSendCancelable = $isReadyToSend
            .dropFirst()
            .sink { [weak self] value in
                guard let self = self else { return }
                guard value else { return }
                repeat {
                    guard let data = self.dataQueue.first else { return }
                    guard self.sendPacket(data: data) else { return }
                    self.dataQueue.removeFirst()
                } while !self.dataQueue.isEmpty
            }
        
        dataPublisherCancelable = self.dataPublisherBuffer
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  data in
                guard let self = self else { return }
                if  self.dataQueue.isEmpty {
                    guard  !self.sendPacket(data: data) else {
                        // if sent don't queue it
                        return
                    }
                }
                self.dataQueue.append(data)
                
            }
    }
    
    private func sendPacket(data : Data) -> Bool {
        guard let peripheral = peripheral else { return false }
        guard data.count <= maximumTransmissionUnit else {
            let _ = subscriber?.receive(completion: .failure(.peripheralMTUMissMatch((maximumTransmissionUnit,data.count))))
            return false
        }
        if peripheral.canSendWriteWithoutResponse {
            peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
            let _ = subscriber?.receive(data)
            return true
        } else {
            isReadyToSend = false
            return false
            
        }
    }
    
    func cancel() {
        isReadyToWriteCancelable = nil
        isReadyToSendCancelable = nil
        dataPublisherCancelable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTDataWriteWithoutResponsePublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let publisher : AnyPublisher<Data, BluetoothError>
    
    init(withCharacteristic characteristic: CBCharacteristic , publisher : AnyPublisher<Data, BluetoothError>) {
        self.characteristic = characteristic
        self.publisher = publisher
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTDataWriteWithoutResponseSubscription(subscriber: subscriber , characteristic: characteristic, publisher : publisher)
        subscriber.receive(subscription: subscription)
    }
}
// MARK: -  CENTRAL : WriteWithResponse publisher

final class BTWriteWithResponseSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let payload : Data
    private var didWriteCancelable : AnyCancellable? = nil
    private var cursorData = 0
    private let peripheral : CBPeripheral?
    private lazy var maximumTransmissionUnit : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withResponse) ?? 0
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , payload : Data) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.payload = payload
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
        
        guard didWriteCancelable == nil else { return } // should not happen but in case of mis-used
        
        
        didWriteCancelable = peripheral.didWritePublisher(forAttribute: characteristic)
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  _ in
                guard let self = self else { return }
                if self.cursorData >= self.payload.count {
                    let _ = self.subscriber?.receive(completion: .finished)
                }
                let _ = self.flushDataToSend()
                
            }
        let _ = self.flushDataToSend()
    }
    
    private func  flushDataToSend() -> Int {
        guard let peripheral = peripheral else {
            return 0
        }
        if cursorData < payload.count {
            let chunkSize = payload.count - cursorData > maximumTransmissionUnit ? maximumTransmissionUnit : payload.count - cursorData
            let range = cursorData..<(cursorData + chunkSize)
            let subdata = payload.subdata(in: range)
            peripheral.writeValue(subdata, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            let _ = subscriber?.receive(subdata)
            cursorData += chunkSize
        }
        return cursorData
    }
    
    func cancel() {
        didWriteCancelable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTWriteWithResponsePublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let payload : Data
    
    init(withCharacteristic characteristic: CBCharacteristic , payload : Data) {
        self.characteristic = characteristic
        self.payload = payload
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTWriteWithResponseSubscription(subscriber: subscriber , characteristic: characteristic, payload : payload)
        subscriber.receive(subscription: subscription)
    }
}

final class BTDataPublisherWriteWithResponseSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input, SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let dataPublisherBuffer : Publishers.Buffer<AnyPublisher<Data, BluetoothError>>
    private var didWriteCancelable : AnyCancellable? = nil
    private var dataBufferCancelable : AnyCancellable? = nil
    private var cursorData = 0
    private let peripheral : CBPeripheral?
    private lazy var maximumTransmissionUnit : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withResponse) ?? 0
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , publisher : AnyPublisher<Data, BluetoothError>) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.dataPublisherBuffer = publisher.buffer(size: 2048, prefetch: .byRequest, whenFull: .dropNewest)
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
        
        guard didWriteCancelable == nil else { return } // should not happen but in case of mis-used
        
        didWriteCancelable = peripheral.didWritePublisher(forAttribute: characteristic)
            .flatMap { _ in
                self.dataPublisherBuffer
            }
            .removeDuplicates()
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  data in
                self?.sendPacket(data:data)
            }
        dataBufferCancelable = dataPublisherBuffer.first()
            .sink (receiveCompletion: { [weak self] completion in
                self?.subscriber?.receive(completion: completion)
            } ) { [weak self] data in
                self?.sendPacket(data: data)
            }
    }
    
    private func  sendPacket(data : Data)  {
        guard let peripheral = peripheral else { return }
        guard data.count <= maximumTransmissionUnit else {
            let _ = subscriber?.receive(completion: .failure(.peripheralMTUMissMatch((maximumTransmissionUnit,data.count))))
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
        let _ = subscriber?.receive(data)
        
    }
    
    func cancel() {
        didWriteCancelable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTDataWriteWithResponsePublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let publisher : AnyPublisher<Data, BluetoothError>
    
    init(withCharacteristic characteristic: CBCharacteristic , publisher : AnyPublisher<Data, BluetoothError>) {
        self.characteristic = characteristic
        self.publisher = publisher
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTDataPublisherWriteWithResponseSubscription(subscriber: subscriber , characteristic: characteristic, publisher: publisher)
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

// MARK: -
// MARK: Utilities
private class SynchronizedArray<T>  {
    private var array: [T] = []
    private let accessQueue = DispatchQueue(label: "SynchronizedArrayAccess", attributes: .concurrent)
    
    public func append(_ newElement: T) {
        
        self.accessQueue.async(flags:.barrier) {
            self.array.append(newElement)
        }
    }
    
    public func removeAtIndex(index: Int) {
        
        self.accessQueue.async(flags:.barrier) {
            self.array.remove(at: index)
        }
    }
    public func removeFirst() {
        removeAtIndex(index: 0)
    }
    public var count: Int {
        var count = 0
        
        self.accessQueue.sync {
            count = self.array.count
        }
        return count
    }
    var isEmpty : Bool  {
        get {
            count == 0
        }
    }
    public var first : T? {
        get {
            var element: T?
            
            self.accessQueue.sync {
                if !self.array.isEmpty {
                    element = self.array[0]
                }
            }
            return element
        }
    }
    
    public func dequeue() -> T? {
        guard  let element = first else { return nil }
        removeAtIndex(index: 0)
        return element
    }
    public subscript(index: Int) -> T {
        set {
            self.accessQueue.async(flags:.barrier) {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            self.accessQueue.sync {
                element = self.array[index]
            }
            return element
        }
    }
}
