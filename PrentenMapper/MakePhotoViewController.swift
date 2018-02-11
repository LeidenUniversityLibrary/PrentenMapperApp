//
//  MakePhotoViewController.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 09-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo
import Photos
import MobileCoreServices

class MakePhotoViewController: UIViewController, AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var printImageView: UIImageView!
    
    var printData : PrintData!
    @IBOutlet weak var zoomSlider: UISlider!
    
    var captureSession: AVCaptureSession!
    var capturePhotoOutput: AVCapturePhotoOutput!
    var isCaptureSessionConfigured = false
    let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    var isFullScreenPrintImage = false
    
    var locationManager : CLLocationManager? = nil
    
    var photoImage : UIImage? = nil
    
    var lastUserLocation : CLLocation? = nil
    var lastUserHeading : CLHeading? = nil
    
    // MARK: - Properties
    
    @IBOutlet weak private var videoPreviewView: VideoPreviewView!
    //@IBOutlet weak var takenPhotoImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.checkCameraAuthorization { authorized in
            if authorized {
                self.setupCaptureSession()
            } else {
                print("Permission to use camera denied.")
            }
        }
        self.videoPreviewView.session = self.captureSession
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Maak foto", style: UIBarButtonItemStyle.plain, target: self, action: #selector(takePhoto))
        
        URLSession.shared.dataTask(with: printData.printUrl, completionHandler: { (data, response, error) in
            if error != nil {
                print(error!)
                return
            }
            
            DispatchQueue.main.async {
                if let image = UIImage(data: data!) {
                    self.printImageView.image = image
                }
            }
            
        }).resume()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(MakePhotoViewController.tappedOnPrintImage))
        printImageView.addGestureRecognizer(tapGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(MakePhotoViewController.rotatePrintImage))
        printImageView.addGestureRecognizer(rotationGesture)
        
        let swipeGesture = UIPanGestureRecognizer(target: self, action: #selector(MakePhotoViewController.adjustAlpha))
        swipeGesture.minimumNumberOfTouches = 1
        swipeGesture.maximumNumberOfTouches = 1
        printImageView.addGestureRecognizer(swipeGesture)
        
        //let zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(MakePhotoViewController.zoomPhoto))
        //videoPreviewView.addGestureRecognizer(zoomGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.backBarButtonItem?.title = "Terug"
        if self.isCaptureSessionConfigured {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            setupSlider()
        } else {
            // First time: request camera access, configure capture session and start it.
            self.checkCameraAuthorization({ authorized in
                guard authorized else {
                    print("Permission to use camera denied.")
                    return
                }
                self.videoPreviewView.videoPreviewLayer.videoGravity = .resizeAspectFill
                self.sessionQueue.async {
                    self.configureCaptureSession({ success in
                        guard success else { return }
                        self.isCaptureSessionConfigured = true
                        self.captureSession.startRunning()
                        DispatchQueue.main.async {
                            self.videoPreviewView.updateVideoOrientationForDeviceOrientation()
                            
                            self.setupSlider()
                        }
                    })
                }
            })
        }
        
        self.startStandardUpdates()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.locationManager?.stopUpdatingLocation()
        self.locationManager?.stopUpdatingHeading()
    }
    
    func setupSlider() {
        let device = self.defaultDevice()
        self.zoomSlider.minimumValue = Float(log(device.minAvailableVideoZoomFactor))
        self.zoomSlider.maximumValue = Float(log(device.maxAvailableVideoZoomFactor / 10.0))
        self.zoomSlider.value = Float(log(device.videoZoomFactor))
        self.zoomSlider.superview?.bringSubview(toFront: self.zoomSlider)
        self.zoomSlider.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            //The user has previously granted access to the camera.
            completionHandler(true)
            
        case .notDetermined:
            // The user has not yet been presented with the option to grant video access so request access.
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { success in
                completionHandler(success)
            })
            
        case .denied:
            // The user has previously denied access.
            completionHandler(false)
            
        case .restricted:
            // The user doesn't have the authority to request access e.g. parental restriction.
            completionHandler(false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setupCaptureSession() {
        self.captureSession = AVCaptureSession()
    }
    
    private func defaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInDualCamera,
                                                for: AVMediaType.video,
                                                position: .back) {
            return device // use dual camera on supported devices
        } else if let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                                       for: AVMediaType.video,
                                                       position: .back) {
            return device // use default back facing camera otherwise
        } else {
            fatalError("All supported devices are expected to have at least one of the queried capture devices.")
        }
    }
    
    func configureCaptureSession(_ completionHandler: ((_ success: Bool) -> Void)) {
        var success = false
        defer { completionHandler(success) } // Ensure all exit paths call completion handler.
        
        // Get video input for the default camera.
        let videoCaptureDevice = defaultDevice()
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Unable to obtain video input for default camera.")
            return
        }
        
        // Create and configure the photo output.
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        capturePhotoOutput.isLivePhotoCaptureEnabled = false //capturePhotoOutput.isLivePhotoCaptureSupported
        
        // Make sure inputs and output can be added to session.
        guard self.captureSession.canAddInput(videoInput) else { return }
        guard self.captureSession.canAddOutput(capturePhotoOutput) else { return }
        
        // Configure the session.
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSession.Preset.photo
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.commitConfiguration()
        
        self.capturePhotoOutput = capturePhotoOutput
        
        success = true
    }
    
    @IBAction func takePhoto() {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])
        
        guard let capturePhotoOutput = self.capturePhotoOutput else {
            print("No capture photo output")
            return
        }
        guard let videoPreviewLayerOrientation = self.videoPreviewView.videoPreviewLayer.connection?.videoOrientation else {
            print("No connection")
            return
        }
        self.sessionQueue.async {
            // Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = capturePhotoOutput.connection(with: AVMediaType.video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation
            }
            
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.flashMode = .auto
            
            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        guard let imageData = photo.fileDataRepresentation() else {
            print("Cannot represent as imageData")
            return
        }
        DispatchQueue.main.async {
            guard let newImage = UIImage(data: imageData) else {
                print("Cannot make a image from data")
                return
            }
            let orientation = photo.metadata["Orientation"]
            print("orientation = \(String(describing: orientation))")
            self.photoImage = newImage
            
            self.performSegue(withIdentifier: "ReviewPhoto", sender: self)
        }
    }
    
    
    @objc func tappedOnPrintImage() {
        if (isFullScreenPrintImage) {
            isFullScreenPrintImage = false
            UIView.animate(withDuration: 1, animations: {
                self.printImageView.frame = CGRect(x: 246, y: 504, width: 160, height: 160)
                self.printImageView.alpha = 1.0
            })
        }
        else {
            isFullScreenPrintImage = true
            UIView.animate(withDuration: 1, animations: {
                let h = self.videoPreviewView.frame.size.height
                let w = self.videoPreviewView.frame.size.width
                self.printImageView.frame = CGRect(x:(w - h) / 2.0, y:0.0, width:h, height:h)
                self.printImageView.alpha = 0.5
            })
        }
    }
    
    @objc func rotatePrintImage(_ gestureRecognizer : UIRotationGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        if (isFullScreenPrintImage) {
            if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
                gestureRecognizer.view?.transform = gestureRecognizer.view!.transform.rotated(by: gestureRecognizer.rotation)
                gestureRecognizer.rotation = 0
            }
            
            if gestureRecognizer.state == .ended || gestureRecognizer.state == .cancelled {
                let radians = atan2( Double((gestureRecognizer.view?.transform.b)!), Double((gestureRecognizer.view?.transform.a)!))
                let degrees = radians * Double((180 / Float.pi))
                
                var degreeToAnimate:CGFloat = 0
                
                switch degrees {
                case -45...45:
                break //print("the default value 0, no need to any assign...")
                case 46...135:
                    degreeToAnimate = .pi / 2.0
                case 136...180, -180 ... -136:
                    degreeToAnimate = .pi
                case -135 ... -46:
                    degreeToAnimate = -.pi / 2.0
                default:
                    break //print("!")
                }
                
                UIView.animate(withDuration: 0.5, animations: {
                    gestureRecognizer.view?.transform = CGAffineTransform(rotationAngle: degreeToAnimate)
                }, completion: { _ in
                    gestureRecognizer.rotation = 0
                })
            }
            
        }
    }
    
    @objc func adjustAlpha(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        if (isFullScreenPrintImage) {
            if let view = gestureRecognizer.view {
                let width = view.frame.size.width
                let translation = gestureRecognizer.translation(in: printImageView)
                let alphaDelta = (translation.x/width);
                let newAlpha = max(0.0, min(1.0, printImageView.alpha + alphaDelta))
                printImageView.alpha = newAlpha
                gestureRecognizer.setTranslation(CGPoint.zero, in: printImageView)
            }
        }
    }
    
    @objc func zoomPhoto(_ gestureRecognizer : UIPinchGestureRecognizer) {
        let scale = gestureRecognizer.scale
        let device = defaultDevice()
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        let currentZoom = device.videoZoomFactor
        let newZoom = max(minZoom, min(currentZoom * scale, maxZoom))
        
        do {
            defer { device.unlockForConfiguration() }
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: newZoom, withRate: 1.0)
        }
        catch {
            
        }
        
        gestureRecognizer.scale = 1.0
    }
    
    @IBAction func zoomSliderChanged(_ slider: UISlider) {
        let device = defaultDevice()
        do {
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            let newZoom = max(minZoom, min(CGFloat(exp(slider.value)), maxZoom))
            
            defer { device.unlockForConfiguration() }
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: newZoom, withRate: 5.0)
        }
        catch {
            print("Error while zooming: \(error)")
        }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "ReviewPhoto") {
            let destinationViewController = segue.destination as! ReviewPhotoViewController
            
            destinationViewController.printData = printData
            destinationViewController.photoImage = self.photoImage
            destinationViewController.userLocation = self.lastUserLocation
            destinationViewController.userHeading = self.lastUserHeading
        }
    }
    
    // MARK: - location
    
    func startStandardUpdates() {
        if self.locationManager == nil {
            self.locationManager = CLLocationManager()
            if let locationManager = self.locationManager {
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.distanceFilter = kCLDistanceFilterNone
                
                locationManager.requestWhenInUseAuthorization()
                
                if CLLocationManager.locationServicesEnabled() {
                    locationManager.startUpdatingLocation()
                }
                
                if CLLocationManager.headingAvailable() {
                    locationManager.headingFilter = 1
                    locationManager.startUpdatingHeading()
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation = locations[0] as CLLocation
        
        self.lastUserLocation = userLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error getting location: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedWhenInUse) {
            if CLLocationManager.locationServicesEnabled() {
                locationManager?.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else {
            print("heading not accurate enough")
            return
        }
        self.lastUserHeading = newHeading
    }
}

