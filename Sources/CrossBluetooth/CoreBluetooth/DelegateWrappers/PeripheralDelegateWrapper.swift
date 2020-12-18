//
//  PeripheralDelegateWrapper.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 28/10/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//
import CoreBluetooth
import Combine
import os.log


final class PeripheralDelegateWrapper: NSObject, CBPeripheralDelegate {
    
    public var nameSubscriber : AnySubscriber<(CBPeripheral,String), Never>? = nil
    //public var rssiSubscriber : AnySubscriber<(CBPeripheral,Int), BluetoothError>? = nil
    public var servicesSubscriber : AnySubscriber<([CBService],[CBService]), BluetoothError>? = nil
    public var includedServiceSubscribers = [CBService : AnySubscriber<[CBService], BluetoothError>]()
    public var characteristicSubscribers = [CBService :AnySubscriber<[CBCharacteristic], BluetoothError>]()
    public var descriptorSubscribers = [CBCharacteristic :AnySubscriber<[CBDescriptor], BluetoothError>]()
    public var valuesSubscribers = [CBAttribute : AnySubscriber<Data, BluetoothError>]()
    public var didWriteSubscribers = [CBAttribute : AnySubscriber<CBAttribute, BluetoothError>]()
    public var notifySubscribers = [CBCharacteristic :AnySubscriber<CBCharacteristic, BluetoothError>]()
    public var peripheralReadySubscribers  = [CBAttribute : AnySubscriber<Bool, BluetoothError>]()
    public var peripheralDidOpenL2CAPSubscribers  = [CBL2CAPPSM : AnySubscriber<CBL2CAPChannel, BluetoothError>]()
    
    func finishAllSubscritions() {
        let _ = nameSubscriber?.receive(completion: .finished)
       // let _ = rssiSubscriber?.receive(completion: .finished)
        let _ = servicesSubscriber?.receive(completion: .finished)
        let _ = includedServiceSubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = characteristicSubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = descriptorSubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = valuesSubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = didWriteSubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = notifySubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = peripheralReadySubscribers.map{ $0.value.receive(completion: .finished)}
        let _ = peripheralDidOpenL2CAPSubscribers.map{ $0.value.receive(completion: .finished)}
    }
    /**
     *  @method peripheralDidUpdateName:
     *
     *  @param peripheral    The peripheral providing this update.
     *
     *  @discussion            This method is invoked when the @link name @/link of <i>peripheral</i> changes.
     */
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        let _ = nameSubscriber?.receive((peripheral,peripheral.name!))
    }
   
    /**
     *  @method peripheral:didModifyServices:
     *
     *  @param peripheral            The peripheral providing this update.
     *  @param invalidatedServices    The services that have been invalidated
     *
     *  @discussion            This method is invoked when the @link services @/link of <i>peripheral</i> have been changed.
     *                        At this point, the designated <code>CBService</code> objects have been invalidated.
     *                        Services can be re-discovered via @link discoverServices: @/link.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        let _ = invalidatedServices.map { service in
            includedServiceSubscribers[service]?.receive(completion: .finished)
            characteristicSubscribers[service]?.receive(completion: .finished)
            includedServiceSubscribers.removeValue(forKey: service)
            characteristicSubscribers.removeValue(forKey: service)
        }
            let _ = servicesSubscriber?.receive((peripheral.services ?? [CBService](),invalidatedServices))
    }


    
    /**
     *  @method peripheral:didReadRSSI:error:
     *
     *  @param peripheral    The peripheral providing this update.
     *  @param RSSI            The current RSSI of the link.
     *  @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion            This method returns the result of a @link readRSSI: @/link call.
     */
     func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
       /* guard error == nil else {
            let _ = rssiSubscriber?.receive(completion: .failure(BluetoothError.peripheralRSSIReadFailed(peripheral, error)))
            return
        }
        let _ = rssiSubscriber?.receive((peripheral, RSSI.intValue))*/
    }

    
    /**
     *  @method peripheral:didDiscoverServices:
     *
     *  @param peripheral    The peripheral providing this information.
     *    @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion            This method returns the result of a @link discoverServices: @/link call. If the service(s) were read successfully, they can be retrieved via
     *                        <i>peripheral</i>'s @link services @/link property.
     *
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            let _ = servicesSubscriber?.receive(completion: .failure(BluetoothError.servicesDiscoveryFailed(peripheral, error)))
            return
        }
            let _ = servicesSubscriber?.receive((peripheral.services ?? [CBService](),[CBService]()))
    }

    
    /**
     *  @method peripheral:didDiscoverIncludedServicesForService:error:
     *
     *  @param peripheral    The peripheral providing this information.
     *  @param service        The <code>CBService</code> object containing the included services.
     *    @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion            This method returns the result of a @link discoverIncludedServices:forService: @/link call. If the included service(s) were read successfully,
     *                        they can be retrieved via <i>service</i>'s <code>includedServices</code> property.
     */
     func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        guard let includedServicesSubscriber = includedServiceSubscribers[service] else { return }
        guard error == nil else {
            let _ = includedServicesSubscriber.receive(completion: .failure(BluetoothError.servicesDiscoveryFailed(peripheral, error)))
            return
        }
        let _ = includedServicesSubscriber.receive(service.includedServices ?? [CBService]())
    }

    
    /**
     *  @method peripheral:didDiscoverCharacteristicsForService:error:
     *
     *  @param peripheral    The peripheral providing this information.
     *  @param service        The <code>CBService</code> object containing the characteristic(s).
     *    @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion            This method returns the result of a @link discoverCharacteristics:forService: @/link call. If the characteristic(s) were read successfully,
     *                        they can be retrieved via <i>service</i>'s <code>characteristics</code> property.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristicsSubscriber = characteristicSubscribers[service] else { return }
        guard error == nil else {
            let _ = characteristicsSubscriber.receive(completion: .failure(BluetoothError.characteristicsDiscoveryFailed(service,error)))
            return
        }
        let _ = characteristicsSubscriber.receive(service.characteristics ?? [CBCharacteristic]())
    }

    
    /**
     *  @method peripheral:didUpdateValueForCharacteristic:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param characteristic    A <code>CBCharacteristic</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method is invoked after a @link readValueForCharacteristic: @/link call, or upon receipt of a notification/indication.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let valueSubscriber = valuesSubscribers[characteristic] else { return }
        guard error == nil else {
            let _ = valueSubscriber.receive(completion: .failure(BluetoothError.characteristicUpdateValueFailed(characteristic, error)))
            return
        }
        let _ = valueSubscriber.receive(characteristic.value ?? Data())
    }

    
    /**
     *  @method peripheral:didWriteValueForCharacteristic:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param characteristic    A <code>CBCharacteristic</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a {@link writeValue:forCharacteristic:type:} call, when the <code>CBCharacteristicWriteWithResponse</code> type is used.
     */
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let didWriteSubscriber = didWriteSubscribers[characteristic] else { return }
        guard error == nil else {
            let _ = didWriteSubscriber.receive(completion: .failure(BluetoothError.characteristicWriteFailed(characteristic, error)))
            return
        }
        
        let _ = didWriteSubscriber.receive(characteristic)
    }

    
    /**
     *  @method peripheral:didUpdateNotificationStateForCharacteristic:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param characteristic    A <code>CBCharacteristic</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a @link setNotifyValue:forCharacteristic: @/link call.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let notifySubscriber = notifySubscribers[characteristic] else { return }
        guard error == nil else {
            let _ = notifySubscriber.receive(completion: .failure(BluetoothError.characteristicSetNotifyValueFailed(characteristic, error)))
            return
        }
        let _ = notifySubscriber.receive(characteristic)
        let _ = notifySubscriber.receive(completion: .finished)
    }

    
    /**
     *  @method peripheral:didDiscoverDescriptorsForCharacteristic:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param characteristic    A <code>CBCharacteristic</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a @link discoverDescriptorsForCharacteristic: @/link call. If the descriptors were read successfully,
     *                            they can be retrieved via <i>characteristic</i>'s <code>descriptors</code> property.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let descriptorSubscribers = descriptorSubscribers[characteristic] else { return }
        guard error == nil else {
            let _ = descriptorSubscribers.receive(completion: .failure(BluetoothError.descriptorsDiscoveryFailed(characteristic,error)))
            return
        }
        let _ = descriptorSubscribers.receive(characteristic.descriptors ?? [CBDescriptor]())
    }

    
    /**
     *  @method peripheral:didUpdateValueForDescriptor:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param descriptor        A <code>CBDescriptor</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a @link readValueForDescriptor: @/link call.
     */
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard let valueSubscriber = valuesSubscribers[descriptor] else { return }
        guard error == nil else {
            let _ = valueSubscriber.receive(completion: .failure(BluetoothError.descriptorReadFailed(descriptor, error)))
            return
        }
        //let _ = valueSubscriber.receive((descriptor,descriptor.value ?? Data()))
        print ("didUpdateValueFor descriptor: missing handling data")
    }

    
    /**
     *  @method peripheral:didWriteValueForDescriptor:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param descriptor        A <code>CBDescriptor</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a @link writeValue:forDescriptor: @/link call.
     */
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
       /* guard let valueSubscriber = valuesSubscribers[descriptor] else { return }
        guard error == nil else {
            let _ = valueSubscriber.receive(completion: .failure(BluetoothError.descriptorWriteFailed(descriptor, error)))
            return
        }*/
        // need work
        print ("didWriteValueFor descriptor: missing handling data")
    }

    
    /**
     *  @method peripheralIsReadyToSendWriteWithoutResponse:
     *
     *  @param peripheral   The peripheral providing this update.
     *
     *  @discussion         This method is invoked after a failed call to @link writeValue:forCharacteristic:type: @/link, when <i>peripheral</i> is again
     *                      ready to send characteristic value updates.
     *
     */
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        
        guard let characteristicSubscriber = peripheralReadySubscribers.first?.value else { return }
       
        let _ = characteristicSubscriber.receive(peripheral.canSendWriteWithoutResponse)

    }
   
    
    /**
     *  @method peripheral:didOpenL2CAPChannel:error:
     *
     *  @param peripheral        The peripheral providing this information.
     *  @param channel            A <code>CBL2CAPChannel</code> object.
     *    @param error            If an error occurred, the cause of the failure.
     *
     *  @discussion                This method returns the result of a @link openL2CAPChannel: @link call.
     */
    
     func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let channel = channel else { return }
        guard let subscriber = peripheralDidOpenL2CAPSubscribers[channel.psm] else { return }
        guard error == nil else {
            let _ = subscriber.receive(completion: .failure(BluetoothError.servicesDiscoveryFailed(peripheral, error)))
            return
        }
        let _ = subscriber.receive(channel)
    }
}
