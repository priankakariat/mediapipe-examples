//
//  CameraViewController.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 07/08/23.
//

import UIKit
import CoreMedia

protocol InferenceResultDeliveryDelegate: AnyObject {
  func didPerformInference(result: ResultBundle?)
}

@objc protocol InterfaceUpdatesDelegate: AnyObject {
  func shouldClicksBeEnabled(_ isEnabled: Bool)
}

class CameraViewController: UIViewController {
  
  @IBOutlet var previewView: PreviewView!
  @IBOutlet weak var cameraUnavailableLabel: UILabel!
  @IBOutlet weak var resumeButton: UIButton!
  @IBOutlet weak var overlayView: OverlayView!
  
  private var isSessionRunning = false
  private let backgroundQueue = DispatchQueue(label: "com.cameraController.backgroundQueue")
  
  // MARK: Controllers that manage functionality
  // Handles all the camera related functionality
  private lazy var cameraCapture = CameraFeedManager(previewView: previewView)
  private var objectDetectorService: ObjectDetectorService?
  
  weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?
  weak var interfaceUpdatesDelegate: InterfaceUpdatesDelegate?
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("CameraController Appear")
#if !targetEnvironment(simulator)
    cameraCapture.checkCameraConfigurationAndStartSession()
#endif
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    print("CameraController Disappear")
  #if !targetEnvironment(simulator)
    cameraCapture.stopSession()
  #endif

  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    #if !targetEnvironment(simulator)
      objectDetectorService = ObjectDetectorService.liveStreamDetectorService(model: DetectorMetaData.sharedInstance.model, maxResults: DetectorMetaData.sharedInstance.maxResults, scoreThreshold: DetectorMetaData.sharedInstance.scoreThreshold, liveStreamDelegate: self)
    #endif
    // Do any additional setup after loading the view.
  }
  
  @IBAction func onClickResume(_ sender: Any) {
          if isSessionRunning {
            self.resumeButton.isHidden = true
            self.cameraUnavailableLabel.isHidden = true
          }
  }
  
}
  
//
//  // Resume camera session when click button resume
//  @IBAction func resumeButtonTouchUpInside(_ sender: Any) {
//    cameraCapture.resumeInterruptedSession { isSessionRunning in
//      if isSessionRunning {
//        self.resumeButton.isHidden = true
//        self.cameraUnavailableLabel.isHidden = true
//      }
//    }
//  }
//
  extension CameraViewController: CameraFeedManagerDelegate {

    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
      let currentTimeMs = Date().timeIntervalSince1970 * 1000
      
      // Pass the pixel buffer to mediapipe
      backgroundQueue.async { [weak self] in
        self?.objectDetectorService?.detectAsync(videoFrame: sampleBuffer, orientation: orientation, timeStamps: Int(currentTimeMs))
      }
    }

    // MARK: Session Handling Alerts
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {

      // Updates the UI when session is interupted.
      if resumeManually {
        resumeButton.isHidden = false
      } else {
        cameraUnavailableLabel.isHidden = false
      }
    }

    func sessionInterruptionEnded() {
      // Updates UI once session interruption has ended.
      if !cameraUnavailableLabel.isHidden {
        cameraUnavailableLabel.isHidden = true
      }

      if !resumeButton.isHidden {
       resumeButton.isHidden = true
      }
    }

    func sessionRunTimeErrorOccured() {
      // Handles session run time error by updating the UI and providing a button if session can be
      // manually resumed.
      resumeButton.isHidden = false
    }

    func presentCameraPermissionsDeniedAlert() {
      let alertController = UIAlertController(
        title: "Camera Permissions Denied",
        message:
          "Camera permissions have been denied for this app. You can change this by going to Settings",
        preferredStyle: .alert)

      let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
      let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
        UIApplication.shared.open(
          URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
      }
      alertController.addAction(cancelAction)
      alertController.addAction(settingsAction)

      present(alertController, animated: true, completion: nil)

//      previewView.shouldUseClipboardImage = true
    }

    func presentVideoConfigurationErrorAlert() {
      let alert = UIAlertController(
        title: "Camera Configuration Failed", message: "There was an error while configuring camera.",
        preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

      self.present(alert, animated: true)
//      previewView.shouldUseClipboardImage = true
    }
  }

  // MARK: ObjectDetectorHelperDelegate
  extension CameraViewController: ObjectDetectorServiceLiveStreamDelegate {
    func objectDetectorService(_ objectDetectorService: ObjectDetectorService, didFinishDetection result: ResultBundle?, error: Error?) {
      DispatchQueue.main.async {
          self.inferenceResultDeliveryDelegate?.didPerformInference(result: result)
        if let objectDetectorResult = result?.objectDetectorResults.first {
          overlayView.draw(
            objectOverlays: [ObjectOverlay],
            inBoundsOfContentImageOfSize: <#T##CGSize#>,
            imageContentMode: <#T##UIView.ContentMode#>)
          ObjectOverlayHelper.objectOverlays(
            fromDetections: objectDetectorResult?.detections,
            inferredOnImageOfSize: <#T##CGSize#>,
            andOrientation: cameraCapture.orientation)
        }
      }
    }
  }

