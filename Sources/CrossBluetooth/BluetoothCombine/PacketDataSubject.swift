//
//  PacketDataPublisher.swift
//  
//
//  Created by Sébastien Luneau on 03/11/2021.
//

import Foundation
import Combine

public class PacketDataSubject : Subject {
    
    var upstreamSubscription : Subscription!
    var downstreamSubscriber : AnySubscriber<Output,Failure>? = nil
    var mtu : Int
    
    init(withMtu mtu : Int) {
        self.mtu = mtu
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        downstreamSubscriber = AnySubscriber(subscriber)
    }
    
    public func send(_ value: Output) {
        if value.count <= mtu {
            let _ = downstreamSubscriber?.receive(value)
        } else {
            let _ = downstreamSubscriber?.receive(completion: .failure(BluetoothError.peripheralMTUMissMatch((mtu, value.count))))
        }
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        downstreamSubscriber?.receive(completion: completion)
    }
    
    public func send(subscription: Subscription) {
        upstreamSubscription = subscription
    }
    
    public typealias Output = Data
    
    public typealias Failure = BluetoothError
    
    
}
/*
public class PacketDataQueue {
    private let packetQueue = SynchronizedArray<Data>()
    private let mtu : Int
    public init(withMTU mtu : Int) {
        self.mtu = mtu
    }
    // Data packet size must be < MTU
    public func append(packet: Data) -> Bool {
        guard packet.count <= mtu else { return false }
        packetQueue.append(newElement: packet)
        return true
    }
    public func dequeue() -> Data? {
        return packetQueue.dequeue()
    }
    public func clearQueue() {
        packetQueue.clear()
    }
    public var count : Int {
        packetQueue.count
    }
}


// MARK: -
// MARK: Utilities
private class SynchronizedArray<T>  {
    private var array: [T] = []
    private let accessQueue = DispatchQueue(label: "PacketDataQueue", attributes: .concurrent)
    
    public func append(newElement: T) {
        
        self.accessQueue.async(flags:.barrier) {
            self.array.append(newElement)
        }
    }
    
    public func removeAtIndex(index: Int) {
        
        self.accessQueue.async(flags:.barrier) {
            self.array.remove(at: index)
        }
    }
    
    public func clear() {
        self.accessQueue.async(flags:.barrier) {
            self.array.removeAll()
        }
    }
    public var count: Int {
        var count = 0
        
        self.accessQueue.sync {
            count = self.array.count
        }
        return count
    }
    
    public func first() -> T? {
        var element: T?
        
        self.accessQueue.sync {
            if !self.array.isEmpty {
                element = self.array[0]
            }
        }
        return element
    }
    
    public func dequeue() -> T? {
        guard  let element = first() else { return nil }
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
*/
