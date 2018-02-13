//
//  ViewController.swift
//  BarCodeDemo
//
//  Created by Anders Ulfheden on 2018-02-10.
//  Created as a demo application for CocoaHeads-Sthlm #88
//

import UIKit
import AVFoundation
import AudioToolbox

class ViewController: UIViewController {
    
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var codeLabel: UILabel!

    internal var captureSession: AVCaptureSession!
    internal var metaDataOutput: AVCaptureMetadataOutput!
    internal var previewLayer: AVCaptureVideoPreviewLayer!
    
    internal var cameraPosition: AVCaptureDevice.Position = .back
    internal var defaultFocusPointOfInterest: CGPoint {
        return CGPoint(x: 0.5, y: 0.5)
    }
    internal var defaultMetaDataObjectTypes: [AVMetadataObject.ObjectType] = [.qr, .upce, .aztec, .code128,
                                                                              .code39, .code39Mod43, .code93,
                                                                              .dataMatrix, .ean13, .ean8,
                                                                              .face, .interleaved2of5, .itf14, .pdf417]

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let camera = findVideoCamera(),
            let (captureSession, metaDataOutput, previewLayer) = captureSession(forDevice: camera, preview: cameraPreview) {
            
            self.captureSession = captureSession
            self.metaDataOutput = metaDataOutput
            self.previewLayer = previewLayer
            
            self.cameraPreview.layer.insertSublayer(self.previewLayer, at: 0)
            captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = cameraPreview.layer.bounds
    }
    
    func findVideoCamera(atPosition cameraPosition: AVCaptureDevice.Position = .back,
                         deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]) -> AVCaptureDevice? {
        
        // Uncomment rows below to use different ways of getting a camera: either any camera or a specific camera

//        if false {
//            return AVCaptureDevice.default(for: AVMediaType.video)
//        } else {
            let mediaType = AVMediaType.video
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: mediaType, position: cameraPosition)
            
            guard let device = session.devices.first else { return nil }
            
            return device
//        }
    }
    
    
    
    func captureSession(forDevice captureDevice: AVCaptureDevice, preview: UIView) -> (AVCaptureSession, AVCaptureMetadataOutput, AVCaptureVideoPreviewLayer)? {
        guard let deviceInput = captureDeviceInput(from: captureDevice) else { return nil }
        
        guard configure(deviceInput: deviceInput, with: { (device) in
            device.autoFocusRangeRestriction = .near
            device.focusPointOfInterest = defaultFocusPointOfInterest
        }) else { return nil }
        
        // Add device input
        let captureSession = AVCaptureSession()
        captureSession.addInput(deviceInput)
        
        
        // Maybe add still image output as well, in case we like to grab a picture?
//        let photoOutput = AVCapturePhotoOutput()
//        photoOutput.isHighResolutionCaptureEnabled = true
//        captureSession.addOutput(photoOutput)
        
        
        // Add Metadata output, i.e where the barcodes and faces are detected
        let metaDataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metaDataOutput)
        metaDataOutput.setMetadataObjectsDelegate(self, queue:DispatchQueue.main)
        // The metadataObjectTypes property needs to be assigned *after* assigning the metaDataOutput to the captureSession
        metaDataOutput.metadataObjectTypes = defaultMetaDataObjectTypes
        
        
        // Add a preview layer for display
        let capturePreviewLayer = AVCaptureVideoPreviewLayer(session:captureSession)
        capturePreviewLayer.videoGravity = .resizeAspectFill
        capturePreviewLayer.frame = preview.layer.bounds
        
        return (captureSession, metaDataOutput, capturePreviewLayer)
    }
    
    //
    // ===================== Misc convenience methods =====================
    //
    
    
    // -------------------------------
    // Create DeviceInput from Device
    
    func captureDeviceInput(from captureDevice: AVCaptureDevice) -> AVCaptureDeviceInput? {
        do {
            return try AVCaptureDeviceInput(device: captureDevice)
        }
        catch _ {
            return nil
        }
    }
    
    
    // -------------------------------
    // Configuring Devices requires locking
    
    typealias AVCaptureDeviceConfigurationHandler = (AVCaptureDevice)->Void
    
    func configure(device: AVCaptureDevice, with configureblock: AVCaptureDeviceConfigurationHandler) -> Bool {
        do {
            try device.lockForConfiguration()
            configureblock(device)
            device.unlockForConfiguration()
            return true
        }
        catch _ {
            return false
        }
    }
    
    func configure(deviceInput: AVCaptureDeviceInput, with configureblock: AVCaptureDeviceConfigurationHandler) -> Bool {
        return configure(device: deviceInput.device, with: configureblock)
    }

}


extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        for metadataObject in metadataObjects {
            var type = ""
            switch metadataObject.type {
            case .qr:              type = "QR-code"
            case .upce:            type = "UPCE-code"
            case .aztec:           type = "Aztec-code"
            case .code128:         type = "Code128-code"
            case .code39:          type = "Code39-code"
            case .code39Mod43:     type = "Code39Mod43-code"
            case .code93:          type = "Code93-code"
            case .dataMatrix:      type = "DataMatrix-code"
            case .ean13:           type = "EAN13-code"
            case .ean8:            type = "EAN8-code"
            case .face:            type = "Face"
            case .interleaved2of5: type = "Inteleaved2of5-code"
            case .itf14:           type = "ITF14-code"
            case .pdf417:          type = "pdf417-code"
            default:               type = "Other: \(metadataObject.type.rawValue)"
            }
            
            let codeObject = self.previewLayer.transformedMetadataObject(for: metadataObject)
            
            if let barcodeObject = codeObject as? AVMetadataMachineReadableCodeObject {
                codeLabel.text = "Barcode \(type): \(barcodeObject.stringValue ?? "")"
            } else if let faceObject = codeObject as? AVMetadataFaceObject {
                let yawValue = faceObject.hasYawAngle ? "Yaw: \(faceObject.yawAngle) " : ""
                let rollAngle = faceObject.hasRollAngle ? "Roll: \(faceObject.rollAngle)" : ""
                codeLabel.text = "\(type) \(yawValue) \(rollAngle)"
            }
        }
    }
}

