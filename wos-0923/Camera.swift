//
//  Camera.swift
//  Ways Of Seeing 23
//  maybe we can use this for training? -> https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest
//  Created by Juan Aboites on 6/23/23.
//  time interval for inference is roughly 70ms.

import UIKit
import AVFoundation
import Foundation
import Atomics
import CoreML
import Vision

class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var mlSignal: ManagedAtomic<Bool>
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var visionRequests = [VNRequest]()
    private let audio = Audio()
    
    //class constructor, mlSignal is passed by reference
    init(_ _mlSignal: inout ManagedAtomic<Bool>){
        self.mlSignal = _mlSignal
        //super.init()//dont know what this does
    }
    
    private func configCameraIO() -> String {
        
        var status: String = "OK"
        
        guard let camera = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        else {
            status = "No camera found"
            return status
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: camera)
        else {
            status = "Could not create video device input"
            return status
        }
        
        deviceInput.device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        guard captureSession.canAddInput(deviceInput)
        else {
            status = "Could not add video device input to the captureSession"
            captureSession.commitConfiguration()
            print(status)
            return status
        }
        
        captureSession.addInput(deviceInput)
        
        guard captureSession.canAddOutput(videoOutput)
        else {
            status = "Could not add video data output to the captureSession"
            captureSession.commitConfiguration()
            print(status)
            return status
        }
        
        captureSession.addOutput(videoOutput)
        
//        let captureConnection = videoOutput.connection(with: .video)
//        captureConnection.frame
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "frame-callback-queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)) //self here contains the captureOutput function
        captureSession.commitConfiguration()
        captureSession.startRunning()
        
        return status
    }
    
    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
            case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
                exifOrientation = .left
            case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
                exifOrientation = .upMirrored
            case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
                exifOrientation = .down
            case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
                exifOrientation = .up
            default:
                exifOrientation = .up
        }
        
        return exifOrientation
    }

    
    private func configModel () -> String {
        
        var status: String = "OK"
        let config = MLModelConfiguration()
        config.computeUnits = MLComputeUnits.cpuOnly //this yields much better performance. Less time between inferences and lower power consumption
        guard let model = try? VNCoreMLModel(for: yolo(configuration: config).model)
        else {
            status = "Error Loading Model"
            return status
        }
        
        //https://developer.apple.com/documentation/vision/vntrackobjectrequest --> some kind of optical flow type thing
        
        let visionRequest = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
            
            if let error = error {
                print("[Inference Error]: \(error)")
            }
            
            if let results = request.results {
                
                for observation in results where observation is VNRecognizedObjectObservation {
                    guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                        continue
                    }
                    
                    let topObservations = objectObservation.labels.filter{ $0.confidence > 0.88}
                    self.audio.update(preds: topObservations, box: objectObservation.boundingBox)
                    
                    //print(topLabelObservation, objectObservation.boundingBox)
                    //perform distance
                    //dispatch to audio queue (class, coordinates, distance)
                }
                //ui update
                DispatchQueue.main.async(execute: {
                  
                })
            }
            
            else {
                print("[No Results]")
            }
        })

        visionRequest.imageCropAndScaleOption = .scaleFit
        //what other config options are there?
        self.visionRequests = [visionRequest]
        return status
    }
    

    //Entry point, called inside of its own dispatch queue by Core
    func start() -> (Bool, String) {
        
        var status: String = "OK"
        
        print("[Loading model]")

        status = configModel()
        if (status != "OK") {
            return (false, status)
        }
        print("[Model loaded]")
        
        
        print("[Starting camera]")
        status = configCameraIO()
        if (status != "OK")  {
            print(status)
            return (false, status)
        }
    
        return (true, status)
        
    }
    

    //must not be private
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //let start = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Pixel Buffer Error")
            return
        }

        let exifOrientation = exifOrientationFromDeviceOrientation() //gets device orientation so model wrappers can re-orient where needed
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
            //let end = Date()
            //print(end.timeIntervalSince(start))
            
        } catch {
            print("Prediction Error: \(error)")
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("**** Dropped Frame *****")
    }
}

