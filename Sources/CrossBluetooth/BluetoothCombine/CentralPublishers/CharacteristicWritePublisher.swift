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

final class BTWritePacketsSubscription<SubscriberType: Subscriber>: Subscription where SubscriberType.Input == Data, SubscriberType.Failure == BluetoothError  {
    
    private var peripheralDelegateWrapper : PeripheralDelegateWrapper?
    
    private var subscriber: AnySubscriber<SubscriberType.Input , SubscriberType.Failure>? = nil
    private let characteristic: CBCharacteristic
    private let packetPublisherBuffer : AnyPublisher<(CBCharacteristicWriteType,Data), BluetoothError>
    private var isReadyToSendCancellable : AnyCancellable? = nil // write without response observation
    private var didWriteCancellable : AnyCancellable? = nil // write with response observation
    private var packetPublisherCancellable : AnyCancellable? = nil
    private var cursorData = 0
    private let peripheral : CBPeripheral?
    
    private var isReadyToWriteCancellable : AnyCancellable? = nil
    @Published private var isReadyToSend : Bool = true
    private var packetQueue = SynchronizedArray<(type : CBCharacteristicWriteType, data : Data)>()
    
    private lazy var mtuWriteWithoutResponse : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withoutResponse) ?? 0
    }()
    private lazy var mtuWriteWithResponse : Int = {
        //20
        peripheral?.maximumWriteValueLength(for: .withResponse) ?? 0
    }()
    
    init(subscriber: SubscriberType, characteristic : CBCharacteristic , publisher : AnyPublisher<(CBCharacteristicWriteType,Data), BluetoothError>) {
        self.subscriber = AnySubscriber(subscriber)
        self.characteristic = characteristic
        self.packetPublisherBuffer = publisher
        
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
        guard isReadyToWriteCancellable == nil else { return } // should not happen but in case of mis-used
        isReadyToWriteCancellable = peripheral.readyToWriteWithoutResponsePublisher(forAttribute: characteristic)
            .sink(receiveCompletion: {_ in}, receiveValue: { [weak self] _ in
                self?.isReadyToSend = true
            })
        didWriteCancellable = peripheral.didWritePublisher(forAttribute: characteristic)
            .sink(receiveCompletion: { completion in
                
            }, receiveValue: { [weak self]_ in
                guard let self = self else { return }
                guard let packet = self.packetQueue.first else { return }
                let _ = self.subscriber?.receive(packet.data)
                self.isReadyToSend = true
                
            })
        
        
        isReadyToSendCancellable = $isReadyToSend
            .sink { [weak self] value in
                guard let self = self else { return }
                guard value else { return }
                repeat {
                    guard let packet = self.packetQueue.first else { return }
                    guard self.send(packet : packet) else { return }
                    self.packetQueue.removeFirst()
                } while !self.packetQueue.isEmpty
            }
        
        packetPublisherCancellable = packetPublisherBuffer
            .sink { [weak self] complet in
                self?.subscriber?.receive(completion: complet)
            } receiveValue: { [weak self]  packet in
                guard let self = self else { return }
                if  self.packetQueue.isEmpty {
                    if self.send(packet : packet) {
                        // if sent don't queue it
                        return
                    }
                }
                self.packetQueue.append(packet)
                
            }
    }
    
    private func send(packet : (type : CBCharacteristicWriteType,data :Data)) -> Bool {
        guard let peripheral = peripheral else { return false }
        if packet.type == .withoutResponse {
            guard packet.data.count <= mtuWriteWithoutResponse else {
                let _ = subscriber?.receive(completion: .failure(.peripheralMTUMissMatch((mtuWriteWithoutResponse,packet.data.count))))
                return false
            }
            if peripheral.canSendWriteWithoutResponse {
                peripheral.writeValue(packet.data, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
                let _ = subscriber?.receive(packet.data)
                return true
            } else {
                isReadyToSend = false
                return false
                
            }
        } else {
            guard packet.data.count <= mtuWriteWithResponse else {
                let _ = subscriber?.receive(completion: .failure(.peripheralMTUMissMatch((mtuWriteWithResponse,packet.data.count))))
                return false
            }
            
            isReadyToSend = false
            peripheral.writeValue(packet.data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
            //let _ = subscriber?.receive(packet.data)
            // dont dequeue packet until we have been notified that the packet has been sent or not
            return false
            
        }
    }
    
    func cancel() {
        isReadyToWriteCancellable = nil
        isReadyToSendCancellable = nil
        packetPublisherCancellable = nil
        peripheralDelegateWrapper = nil
        subscriber = nil
    }
    
}

struct BTWritePacketsPublisher: Publisher {
    
    typealias Output = Data
    typealias Failure = BluetoothError
    
    private let characteristic: CBCharacteristic
    private let publisher : AnyPublisher<(CBCharacteristicWriteType,Data), BluetoothError>
    
    init(withCharacteristic characteristic: CBCharacteristic , publisher : AnyPublisher<(CBCharacteristicWriteType,Data), BluetoothError>) {
        self.characteristic = characteristic
        self.publisher = publisher
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Self.Failure, S.Input == Self.Output {
        let subscription = BTWritePacketsSubscription(subscriber: subscriber , characteristic: characteristic, publisher : publisher)
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
