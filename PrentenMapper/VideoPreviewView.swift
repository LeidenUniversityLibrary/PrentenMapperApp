//
//  VideoPreviewView.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 03-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation


class VideoPreviewView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    var session: AVCaptureSession? {
        get { return videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    func updateVideoOrientationForDeviceOrientation() {
        if let videoPreviewLayerConnection = videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard deviceOrientation.isPortrait
                else { return }
            videoPreviewLayerConnection.videoOrientation = .portrait
        }
    }
}
