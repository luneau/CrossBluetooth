//
//  PeripheralManagerDelegateWrapper.swift
//  XBluetooth
//
//  Created by Sébastien Luneau on 06/11/2020.
//  Copyright © 2020 Sébastien Luneau. All rights reserved.
//

import CoreBluetooth
import Combine
import os.log
public enum PubSubEvent {
    case added
    case removed
}

final class PeripheralManagerDelegateWrapper: NSObject, CBPeripheralManagerDelegate {
    
    public var stateSubscriber : AnySubscriber<CBManagerState, Never>? = nil
    public var advertisingSubscriber : AnySubscriber<CBPeripheralManager, BluetoothError>? = nil
    public var addServiceSubscribers =  [CBService : AnySubscriber<CBService, BluetoothError>]()
    public var notifySubscribers =  [CBCharacteristic : AnySubscriber<(CBCentral,PubSubEvent), Never>]()
    public var readRequestSubscribers =  [CBCharacteristic : AnySubscriber<(CBPeripheralManager,CBATTRequest), BluetoothError>]()
    public var writeRequestSubscribers =  [CBCharacteristic : AnySubscriber<(CBPeripheralManager,CBATTRequest), BluetoothError>]()
    public var updateValueSubscribers =  [CBCharacteristic : AnySubscriber<(CBPeripheralManager,CBATTRequest), BluetoothError>]()
    public var peripheralReadySubscribers  = [CBAttribute : AnySubscriber<CBPeripheralManager, BluetoothError>]()
    public var advertisingL2CAPSubscriber : AnySubscriber<(CBL2CAPPSM,PubSubEvent), BluetoothError>? = nil
    public var didOpenL2CAPSubscribers  = [CBL2CAPPSM : AnySubscriber<(CBL2CAPChannel,PubSubEvent), BluetoothError>]()
    
    deinit {
        print ("deinit PeripheralManagerDelegateWrapper")
    }
    
    /**
     *  @method peripheralManagerDidUpdateState:
     *
     *  @param peripheral   The peripheral manager whose state has changed.
     *
     *  @discussion         Invoked whenever the peripheral manager's state has been updated. Commands should only be issued when the state is
     *                      <code>CBPeripheralManagerStatePoweredOn</code>. A state below <code>CBPeripheralManagerStatePoweredOn</code>
     *                      implies that advertisement has paused and any connected centrals have been disconnected. If the state moves below
     *                      <code>CBPeripheralManagerStatePoweredOff</code>, advertisement is stopped and must be explicitly restarted, and the
     *                      local database is cleared and all services must be re-added.
     *
     *  @see                state
     *
     */

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager){
        let _ = stateSubscriber?.receive(peripheral.state)
    }
    
    /**
     *  @method peripheralManager:willRestoreState:
     *
     *  @param peripheral    The peripheral manager providing this information.
     *  @param dict            A dictionary containing information about <i>peripheral</i> that was preserved by the system at the time the app was terminated.
     *
     *  @discussion            For apps that opt-in to state preservation and restoration, this is the first method invoked when your app is relaunched into
     *                        the background to complete some Bluetooth-related task. Use this method to synchronize your app's state with the state of the
     *                        Bluetooth system.
     *
     *  @seealso            CBPeripheralManagerRestoredStateServicesKey;
     *  @seealso            CBPeripheralManagerRestoredStateAdvertisementDataKey;
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]){
        print ("peripheralManager willRestoreState \(dict)")
    }

    
    /**
     *  @method peripheralManagerDidStartAdvertising:error:
     *
     *  @param peripheral   The peripheral manager providing this information.
     *  @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion         This method returns the result of a @link startAdvertising: @/link call. If advertisement could
     *                      not be started, the cause will be detailed in the <i>error</i> parameter.
     *
     */
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?){
        guard error == nil else {
            let _ = advertisingSubscriber?.receive(completion: .failure(BluetoothError.advertisingStartFailed(error!)))
            return
        }
        
        let _ = advertisingSubscriber?.receive(peripheral)
    }

    
    /**
     *  @method peripheralManager:didAddService:error:
     *
     *  @param peripheral   The peripheral manager providing this information.
     *  @param service      The service that was added to the local database.
     *  @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion         This method returns the result of an @link addService: @/link call. If the service could
     *                      not be published to the local database, the cause will be detailed in the <i>error</i> parameter.
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?){
        guard let subscriber = addServiceSubscribers[service] else { return }
        guard error == nil else {
            let _ = subscriber.receive(completion: .failure(BluetoothError.addingServiceFailed(service, error)))
            return
        }
        let _ = subscriber.receive(service)
    }

    
    /**
     *  @method peripheralManager:central:didSubscribeToCharacteristic:
     *
     *  @param peripheral       The peripheral manager providing this update.
     *  @param central          The central that issued the command.
     *  @param characteristic   The characteristic on which notifications or indications were enabled.
     *
     *  @discussion             This method is invoked when a central configures <i>characteristic</i> to notify or indicate.
     *                          It should be used as a cue to start sending updates as the characteristic value changes.
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic){
        guard let subscriber = notifySubscribers[characteristic] else { return }
        let _ = subscriber.receive((central,.added))
    }

    
    /**
     *  @method peripheralManager:central:didUnsubscribeFromCharacteristic:
     *
     *  @param peripheral       The peripheral manager providing this update.
     *  @param central          The central that issued the command.
     *  @param characteristic   The characteristic on which notifications or indications were disabled.
     *
     *  @discussion             This method is invoked when a central removes notifications/indications from <i>characteristic</i>.
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic){
        guard let subscriber = notifySubscribers[characteristic] else { return }
        let _ = subscriber.receive((central,.removed))
    }

    
    /**
     *  @method peripheralManager:didReceiveReadRequest:
     *
     *  @param peripheral   The peripheral manager requesting this information.
     *  @param request      A <code>CBATTRequest</code> object.
     *
     *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request for a characteristic with a dynamic value.
     *                      For every invocation of this method, @link respondToRequest:withResult: @/link must be called.
     *
     *  @see                CBATTRequest
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest){
        guard let subscriber = readRequestSubscribers[request.characteristic] else { return }
        let _ = subscriber.receive((peripheral,request))
    }

    
    /**
     *  @method peripheralManager:didReceiveWriteRequests:
     *
     *  @param peripheral   The peripheral manager requesting this information.
     *  @param requests     A list of one or more <code>CBATTRequest</code> objects.
     *
     *  @discussion         This method is invoked when <i>peripheral</i> receives an ATT request or command for one or more characteristics with a dynamic value.
     *                      For every invocation of this method, @link respondToRequest:withResult: @/link should be called exactly once. If <i>requests</i> contains
     *                      multiple requests, they must be treated as an atomic unit. If the execution of one of the requests would cause a failure, the request
     *                      and error reason should be provided to <code>respondToRequest:withResult:</code> and none of the requests should be executed.
     *
     *  @see                CBATTRequest
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]){
        requests.forEach { request in
            guard let subscriber = writeRequestSubscribers[request.characteristic] else { return }
            let _ = subscriber.receive((peripheral,request))
        }
    }

    
    /**
     *  @method peripheralManagerIsReadyToUpdateSubscribers:
     *
     *  @param peripheral   The peripheral manager providing this update.
     *
     *  @discussion         This method is invoked after a failed call to @link updateValue:forCharacteristic:onSubscribedCentrals: @/link, when <i>peripheral</i> is again
     *                      ready to send characteristic value updates.
     *
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager){
        guard let characteristicSubscriber = peripheralReadySubscribers.first?.value else { return }
        let _ = characteristicSubscriber.receive(peripheral)
    }

    
    /**
     *  @method peripheralManager:didPublishL2CAPChannel:error:
     *
     *  @param peripheral   The peripheral manager requesting this information.
     *  @param PSM            The PSM of the channel that was published.
     *  @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion         This method is the response to a  @link publishL2CAPChannel: @/link call.  The PSM will contain the PSM that was assigned for the published
     *                        channel
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?){
        guard let subscriber = advertisingL2CAPSubscriber else { return }
        guard error == nil else {
            let _ = subscriber.receive(completion: .failure(BluetoothError.publishingL2CAPChannelFailed(PSM, error)))
            return
        }
        let _ = subscriber.receive((PSM,.added))
    }

    
    /**
     *  @method peripheralManager:didUnublishL2CAPChannel:error:
     *
     *  @param peripheral   The peripheral manager requesting this information.
     *  @param PSM            The PSM of the channel that was published.
     *  @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion         This method is the response to a  @link unpublishL2CAPChannel: @/link call.
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?){
        guard let subscriber = advertisingL2CAPSubscriber else { return }
        guard error == nil else {
            let _ = subscriber.receive(completion: .failure(BluetoothError.publishingL2CAPChannelFailed(PSM, error)))
            return
        }
        let _ = subscriber.receive((PSM,.removed))
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
    /*!
     *  @method peripheralManager:didOpenL2CAPChannel:error:
     *
     *  @param peripheral       The peripheral manager requesting this information.
     *  @param channel              A <code>CBL2CAPChannel</code> object.
     *    @param error        If an error occurred, the cause of the failure.
     *
     *  @discussion            This method returns the result of establishing an incoming L2CAP channel , following publishing a channel using @link publishL2CAPChannel: @link call.
     *
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?){
        guard let channel = channel else { return }
        guard let subscriber = didOpenL2CAPSubscribers[channel.psm] else { return }
        guard error == nil else {
            let _ = subscriber.receive(completion: .failure(BluetoothError.publishingL2CAPChannelFailed(channel.psm, error)))
            return
        }
        let _ = subscriber.receive((channel,.added))
    }
    
}
