//
//  ReviewPhotoViewController.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 10-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo
import Photos
import MobileCoreServices
import MapKit

class ReviewPhotoViewController: UIViewController {
    
    @IBOutlet weak var printImageView: UIImageView!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var scrollView: UIScrollView!

    var photoImage : UIImage!
    var userLocation : CLLocation? = nil
    var userHeading : CLHeading? = nil

    var printData : PrintData!

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        let swipeGesture = UIPanGestureRecognizer(target: self, action: #selector(ReviewPhotoViewController.adjustAlpha))
        swipeGesture.minimumNumberOfTouches = 1
        swipeGesture.maximumNumberOfTouches = 1
        printImageView.addGestureRecognizer(swipeGesture)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Keur goed", style: UIBarButtonItemStyle.done, target: self, action: #selector(approvePhoto))

    }
    
    override func viewWillAppear(_ animated: Bool) {
        //self.navigationItem.title = "Keur gemaakte foto"
        self.photoImageView.image = self.photoImage
        self.printImageView.alpha = 0.5

        self.photoImageView.transform = CGAffineTransform(rotationAngle: -.pi / 2.0) // aargh hack!!!
        
        //print("User location is: \(String(describing: self.userLocation))")
        //print("User heading is: \(String(describing: self.userHeading))")

        if let location = self.userLocation {
            let camera = MKMapCamera()
            camera.pitch = 45.0
            if let trueHeading = self.userHeading?.trueHeading, trueHeading > 0 {
                camera.heading = trueHeading
            }
            else {
                if let magneticHeading = self.userHeading?.magneticHeading {
                    camera.heading = magneticHeading
                }
            }
            camera.centerCoordinate = CLLocationCoordinate2D(latitude:location.coordinate.latitude, longitude:location.coordinate.longitude)

            camera.altitude = 500
            self.mapView.setCamera(camera, animated: false)
            
            let userLocAnnotation = MKPlacemark(coordinate: location.coordinate)
            self.mapView.addAnnotation(userLocAnnotation)
            
            self.mapView.showsBuildings = true
            self.mapView.showsCompass = true
            
        }
    }
    
    override func viewDidLayoutSubviews() {
        let newHeight : CGFloat = 1500.0
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: newHeight )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateScore() {
        let defaults = UserDefaults.standard
        let key = "pm_current_score"
        let posScore = defaults.integer(forKey: "pm_score_for_\(self.printData.identifier)")
        defaults.set(defaults.integer(forKey: key) + posScore, forKey: key)
    }
    
    @objc func adjustAlpha(_ gestureRecognizer : UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        
        if let view = gestureRecognizer.view {
            let width = view.frame.size.width
            let translation = gestureRecognizer.translation(in: printImageView)
            let alphaDelta = (translation.x/width);
            let newAlpha = max(0.0, min(1.0, printImageView.alpha + alphaDelta))
            printImageView.alpha = newAlpha
            gestureRecognizer.setTranslation(CGPoint.zero, in: printImageView)
        }
    }
    
    @objc func approvePhoto() {
        self.updateScore()
        self.navigationController?.popToRootViewController(animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
