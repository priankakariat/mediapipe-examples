// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import MediaPipeTasksVision
import UniformTypeIdentifiers
import AVKit

class ViewController: UIViewController {

  // MARK: Storyboards Connections
  @IBOutlet weak var tabBarContainerView: UIView!
  @IBOutlet weak var overlayView: OverlayView!
  @IBOutlet weak var runningModeTabbar: UITabBar!
  @IBOutlet weak var bottomSheetViewBottomSpace: NSLayoutConstraint!
  @IBOutlet weak var bottomViewHeightConstraint: NSLayoutConstraint!
  
  // MARK: Constants
  private let inferenceIntervalMs: Double = 100
  private let inferenceBottomHeight = 220.0
  private let expandButtonHeight = 41.0
  private let edgeOffset: CGFloat = 2.0
  private let labelOffset: CGFloat = 10.0
  private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
  private let labelColors = [
    UIColor.red,
    UIColor(displayP3Red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0, alpha: 1.0),
    UIColor.green,
    UIColor.orange,
    UIColor.blue,
    UIColor.purple,
    UIColor.magenta,
    UIColor.yellow,
    UIColor.cyan,
    UIColor.brown
  ]
  private let playerViewController = AVPlayerViewController()
  private var generator:AVAssetImageGenerator?
  var orientation: UIImage.Orientation {
    get {
      switch UIDevice.current.orientation {
      case .landscapeLeft:
        return .left
      case .landscapeRight:
        return .right
      default:
        return .up
      }
    }
  }

  // MARK: Instance Variables
//  private var videoDetectTimer: Timer?
//  private var previousInferenceTimeMs = Date.distantPast.timeIntervalSince1970 * 1000
  private var maxResults = DefaultConstants.maxResults
  private var scoreThreshold = DefaultConstants.scoreThreshold
  private var model = DefaultConstants.model
  private var runningMode: RunningMode = .liveStream

//  let backgroundQueue = DispatchQueue(
//      label: "com.google.mediapipe.ObjectDetection",
//      qos: .userInteractive
//    )

  // MARK: Controllers that manage functionality
  // Handles the presenting of results on the screen
  private var inferenceViewController: InferenceViewController?
  private var cameraViewController: CameraViewController?
  private var mediaLibraryViewController: MediaLibraryViewController?

  // MARK: View Handling Methods
  override func viewDidLoad() {
    super.viewDidLoad()
    // Create object detector helper
    
    inferenceViewController?.isUIEnabled = false
    runningModeTabbar.selectedItem = runningModeTabbar.items?.first
    runningModeTabbar.delegate = self
    guard let viewController = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(withIdentifier: "CAMERA_VIEW_CONTROLLER") as? CameraViewController else {
      return
    }
    viewController.inferenceResultDeliveryDelegate = self
    viewController.interfaceUpdatesDelegate = self
    cameraViewController = viewController
    switchTo(childViewController: viewController, fromViewController: nil)
    
    overlayView.clearsContextBeforeDrawing = true
    
    NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  // MARK: notification methods
  @objc func orientationChanged(notification: Notification) {
    
    guard let tabBarItems = runningModeTabbar.items, tabBarItems.count == 2 else {
      return
    }
    switch runningModeTabbar.selectedItem {
      case tabBarItems[0]:
        break
      case tabBarItems[1]:
        mediaLibraryViewController?.orientationChanged(deviceOrientation: UIDevice.current.orientation)
     default:
        break
    }
//    switch orientation {
//      case .up:
//
//      case .left:
//      case .right:
//      default:
//        break
//    }
  }

  // MARK: Storyboard Segue Handlers
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    super.prepare(for: segue, sender: sender)
    if segue.identifier == "EMBED" {
      inferenceViewController = segue.destination as? InferenceViewController
      inferenceViewController?.maxResults = maxResults
      inferenceViewController?.modelChose = model
      inferenceViewController?.delegate = self
      bottomViewHeightConstraint.constant = inferenceBottomHeight
      bottomSheetViewBottomSpace.constant = -inferenceBottomHeight + expandButtonHeight
      view.layoutSubviews()
    }
  }

  // MARK: Handle ovelay function
  /**
   This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
   */
  private func drawAfterPerformingCalculations(onDetections detections: [Detection], orientation: UIImage.Orientation, withImageSize imageSize: CGSize) {

    self.overlayView.objectOverlays = []
    self.overlayView.setNeedsDisplay()

    guard !detections.isEmpty else {
      return
    }

    var objectOverlays: [ObjectOverlay] = []
    var index = 0
    for detection in detections {
      index += 1

      guard let category = detection.categories.first else { continue }

      // Translates bounding box rect to current view.
      var viewWidth = overlayView.bounds.size.width
      var viewHeight = overlayView.bounds.size.height
      var originX: CGFloat = 0
      var originY: CGFloat = 0

      if viewWidth / viewHeight > imageSize.width / imageSize.height {
        viewHeight = imageSize.height / imageSize.width  * overlayView.bounds.size.width
        originY = (overlayView.bounds.size.height - viewHeight) / 2
      } else {
        viewWidth = imageSize.width / imageSize.height * overlayView.bounds.size.height
        originX = (overlayView.bounds.size.width - viewWidth) / 2
      }
      var convertedRect = detection.boundingBox

      switch orientation {
      case .left:
        convertedRect = CGRect(
          x: convertedRect.origin.y, y: imageSize.height - convertedRect.origin.x - convertedRect.width, width: convertedRect.height, height: convertedRect.width)
      case .right:
        convertedRect = CGRect(
          x: imageSize.width - convertedRect.origin.y - convertedRect.height, y: convertedRect.origin.x, width: convertedRect.height, height: convertedRect.width)
      default:
        break
      }

      convertedRect = convertedRect
        .applying(CGAffineTransform(scaleX: viewWidth / imageSize.width, y: viewHeight / imageSize.height))
        .applying(CGAffineTransform(translationX: originX, y: originY))

      if convertedRect.origin.x < 0 && convertedRect.origin.x + convertedRect.size.width > edgeOffset {
        convertedRect.size.width += (convertedRect.origin.x - edgeOffset)
        convertedRect.origin.x = edgeOffset
      }

      if convertedRect.origin.y < 0 && convertedRect.origin.y + convertedRect.size.height > edgeOffset {
        convertedRect.size.height += (convertedRect.origin.y - edgeOffset)
        convertedRect.origin.y = edgeOffset
      }

      if convertedRect.maxY > self.overlayView.bounds.maxY {
        convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
      }

      if convertedRect.maxX > self.overlayView.bounds.maxX {
        convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
      }

      // if index = 0 class name is unknow

      let confidenceValue = Int(category.score * 100.0)
      let string = "\(category.categoryName ?? "Unknow")  (\(confidenceValue)%)"

      let displayColor = labelColors[index % labelColors.count]

      let size = string.size(withAttributes: [.font: displayFont])

      let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: displayColor, font: self.displayFont)

      objectOverlays.append(objectOverlay)
    }

    // Hands off drawing to the OverlayView
    self.draw(objectOverlays: objectOverlays)

  }

  /** Calls methods to update overlay view with detected bounding boxes and class names.
   */
  private func draw(objectOverlays: [ObjectOverlay]) {

    self.overlayView.objectOverlays = objectOverlays
    self.overlayView.setNeedsDisplay()
  }
}


// MARK: InferenceViewControllerDelegate Methods
extension ViewController: InferenceViewControllerDelegate {
  func viewController(
    _ viewController: InferenceViewController,
    needPerformActions action: InferenceViewController.Action
  ) {
    var isModelNeedsRefresh = false
    switch action {
    case .changeScoreThreshold(let scoreThreshold):
      if self.scoreThreshold != scoreThreshold {
        isModelNeedsRefresh = true
      }
      self.scoreThreshold = scoreThreshold
    case .changeMaxResults(let maxResults):
      if self.maxResults != maxResults {
        isModelNeedsRefresh = true
      }
      self.maxResults = maxResults
    case .changeModel(let model):
      if self.model != model {
        isModelNeedsRefresh = true
      }
      self.model = model
    default:
      break
    }
  }
  
  func viewController(_ viewController: InferenceViewController, didSwitchBottomSheetViewState isOpen: Bool) {
    
    var totalBottomSheetHeight: CGFloat = expandButtonHeight
    
    if isOpen == true {
      bottomSheetViewBottomSpace.constant = 0.0
      totalBottomSheetHeight = inferenceBottomHeight
    }
    else {
      bottomSheetViewBottomSpace.constant = -inferenceBottomHeight + expandButtonHeight
    }
  
    UIView.animate(withDuration: 0.3) {[weak self] in
      self?.view.layoutSubviews()
      self?.mediaLibraryViewController?.layoutUIElements(withInferenceViewHeight: totalBottomSheetHeight)
      
    }
  }
}

// MARK: UITabBarDelegate
extension ViewController: UITabBarDelegate {
  
  func switchTo(childViewController: UIViewController, fromViewController: UIViewController?) {
    fromViewController?.willMove(toParent: nil)
    fromViewController?.view.removeFromSuperview()
    fromViewController?.removeFromParent()
    
    addChild(childViewController)
    childViewController.view.translatesAutoresizingMaskIntoConstraints = false
    tabBarContainerView.addSubview(childViewController.view)
    NSLayoutConstraint.activate(
      [
        childViewController.view.leadingAnchor.constraint(equalTo: tabBarContainerView.leadingAnchor, constant: 0.0),
      childViewController.view.trailingAnchor.constraint(equalTo: tabBarContainerView.trailingAnchor, constant: 0.0),
      childViewController.view.topAnchor.constraint(equalTo: tabBarContainerView.topAnchor, constant: 0.0),
      childViewController.view.bottomAnchor.constraint(equalTo: tabBarContainerView.bottomAnchor, constant: 0.0)
      ]
    )
    childViewController.didMove(toParent: self)
  }
  
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    
    guard let tabBarItems = tabBar.items, tabBarItems.count == 2 else {
      return
    }
    
    switch item {
    case tabBarItems[0]:
      runningMode = .liveStream
      guard let viewController = cameraViewController else {
        return
      }
      switchTo(childViewController: viewController, fromViewController: mediaLibraryViewController)
    
    case tabBarItems[1]:
      if mediaLibraryViewController == nil {
        guard let viewController = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(withIdentifier: "MEDIA_LIBRARY_VIEW_CONTROLLER") as? MediaLibraryViewController else {
          return
        }
        mediaLibraryViewController = viewController
      }
        
      switchTo(childViewController: mediaLibraryViewController!, fromViewController: cameraViewController)
      
    default:
      break
    }
    overlayView.objectOverlays = []
    overlayView.setNeedsDisplay()
  }
}

extension ViewController: InferenceResultDeliveryDelegate {
  
  func didPerformInference(result: ResultBundle?) {
    var inferenceTimeString = ""
    
    if let inferenceTime = result?.inferenceTime {
      inferenceTimeString = String(format: "%.2fms", inferenceTime)
    }
    inferenceViewController?.update(inferenceTimeString: inferenceTimeString)
  }
}

extension ViewController: InterfaceUpdatesDelegate {
  func shouldClicksBeEnabled(_ isEnabled: Bool) {
    inferenceViewController?.isUIEnabled = isEnabled
  }
}
