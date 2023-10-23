//  swift-tools-version:5.6
//  Core.swift
//  Ways Of Seeing 23
//
//  Created by Juan Aboites on 7/3/23.
//

import Dispatch
import Foundation
import AVFoundation
import Atomics

class Core: ObservableObject {

    //any other stuff that we want to show to the UI we can add here with the @Published tag
    @Published var errorState: String = "OK"
    var mlSignal = ManagedAtomic<Bool>(false)
    var camera: Camera? = nil

    init () {
        getSetPermission{granted in
            if (granted){
                self.load()
            } else { self.errorState = "App requires camera permission" }
        }
    }

    
    func getSetPermission(completion: @escaping (_ granted: Bool) -> Void) {

        switch AVCaptureDevice.authorizationStatus(for: .video){
            case .authorized:
                completion(true)

            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                })

            case .denied, .restricted:
                completion(false)

            @unknown default:
                completion(false)
        }
    }
    
        
    
    func load() {
        
        let cameraQueue = DispatchQueue(label: "camera-queue", qos: .userInitiated)
        
        self.camera = Camera(&self.mlSignal)
                
        cameraQueue.async {
            
            let (success, msg) = self.camera!.start() //! is a force optional unwrap
            if (!success){
                print("[Camera failed to start]: ", msg)
                //self.errorState = msg //"Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates."
            }
            
        }
        
    }
}


//var modelHandler: ModelHandler = ModelHandler()
//let mlQueue = DispatchQueue(label: "mlQueue", qos: .userInitiated)
//init model
//print("[Loading Model]")
//self.modelHandler.start() //add error catch here
//mlQueue.async {
//
//}

