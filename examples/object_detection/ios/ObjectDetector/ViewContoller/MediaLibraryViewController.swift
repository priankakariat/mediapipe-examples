//
//  GalleryViewController.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 07/08/23.
//

import UIKit
import UniformTypeIdentifiers
import AVKit
import MediaPipeTasksVision

class MediaLibraryViewController: UIViewController {
  
  private struct Constants {
    static let inferenceTimeIntervalMs: Int64 = 300
    static let kMilliSeconds: Int32 = 1000
    static let savedPhotosNotAvailableText = "Saved photos album is not available."
    static let pickFromGalleryButtonInset: CGFloat = 20.0
  }

  @IBOutlet weak var progressView: UIProgressView!
  @IBOutlet weak var imageEmptyLabel: UILabel!
  @IBOutlet weak var pickedImageView: UIImageView!
  @IBOutlet weak var overlayView: OverlayView!
  @IBOutlet weak var pickFromGalleryButton: UIButton!
  @IBOutlet weak var pickFromGalleryButtonBottomSpace: NSLayoutConstraint!
  
  private lazy var pickerController = UIImagePickerController()
  private var playerViewController: AVPlayerViewController?
    
  private var objectDetectorService: ObjectDetectorService?
    
  override func viewDidLoad() {
    super.viewDidLoad()
  
    if !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
      self.imageEmptyLabel.text = Constants.savedPhotosNotAvailableText
      pickFromGalleryButton.isEnabled = false
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    removePlayerViewController()
  }
    
  private func configurePickerController() {
    pickerController.delegate = self
    pickerController.sourceType = .savedPhotosAlbum
    pickerController.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
    pickerController.allowsEditing = false
  }
  
  private func removePlayerViewController() {
    playerViewController?.player?.pause()
    playerViewController?.player = nil
    playerViewController?.view.removeFromSuperview()
    playerViewController?.willMove(toParent: nil)
    playerViewController?.removeFromParent()
  }
  
  @IBAction func onClickPickFromGallery(_ sender: Any) {
    if !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
      return
    }
    configurePickerController()
    present(pickerController, animated: true)
  }
  
  func openMediaLibrary() {
    if !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
      return
    }
    configurePickerController()
    present(pickerController, animated: true)
  }
  
  func showProgressView() {
    progressView.superview?.isHidden = false
    progressView.progress = 0.0
    progressView.observedProgress = nil
  }
  
  func hideProgressView() {
    self.progressView.superview?.isHidden = true
  }
  
  func orientationChanged(deviceOrientation: UIDeviceOrientation) {
    overlayView.redrawObjectOverlays(forNewDeviceOrientation: deviceOrientation)
  }
  
  func layoutUIElements(withInferenceViewHeight height: CGFloat) {
    pickFromGalleryButtonBottomSpace.constant = height + Constants.pickFromGalleryButtonInset
    view.layoutSubviews()
    
  }
}

extension MediaLibraryViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  private func draw(
    detections: [Detection],
    originalImageSize: CGSize,
    andOrientation orientation: UIImage.Orientation,
    inFrame frame: CGRect) {
    // Hands off drawing to the OverlayView
    self.view.bringSubviewToFront(overlayView)
    overlayView.draw(
      objectOverlays:ObjectOverlayHelper.objectOverlays(
                      fromDetections: detections,
                      inferredOnImageOfSize: originalImageSize,
                      andOrientation: orientation),
      inBoundsOfContentImageOfSize: originalImageSize,
      edgeOffset: 0.0,
      imageContentMode: .scaleAspectFit)
  }
  
  private func playVideo(asset: AVAsset) {
    let playerItem = AVPlayerItem(asset: asset)
    
    if playerViewController == nil {
      let playerViewController = AVPlayerViewController()
      playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerViewController.videoBounds), options: [.old, .new], context: nil)
      self.playerViewController = playerViewController
    }
    
    if playerViewController?.player == nil {
      playerViewController?.player = AVPlayer(playerItem: playerItem)
    }
    else {
      playerViewController?.player?.replaceCurrentItem(with: playerItem)
    }
    
    
    guard let playerViewController = self.playerViewController, let player = playerViewController.player else{
      return
    }
    
    playerViewController.showsPlaybackControls = true
    playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
    
    self.addChild(playerViewController)
    self.view.addSubview(playerViewController.view)
    NSLayoutConstraint.activate([
      playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0.0),
      playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0.0),
      playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 0.0),
      playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0.0)
    ])
    playerViewController.didMove(toParent: self)
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(self.playerDidFinishPlaying),
                   name: .AVPlayerItemDidPlayToEndTime,
                   object: player.currentItem
      )
    player.play()
  }
  
  override class func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    print()
  
  }
  
  @objc func playerDidFinishPlaying(notification: NSNotification) {
    
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
  
  func clearAndInitializeObjectDetectorService(runningMode: RunningMode) {
    objectDetectorService = nil
    
    switch runningMode {
      case .image:
        objectDetectorService = ObjectDetectorService.stillImageDetectorService(model: DefaultConstants.model, maxResults: DefaultConstants.maxResults, scoreThreshold: DefaultConstants.scoreThreshold)
      case .video:
        objectDetectorService = ObjectDetectorService.videoObjectDetectorService(model: DetectorMetaData.sharedInstance.model, maxResults: DetectorMetaData.sharedInstance.maxResults, scoreThreshold: DetectorMetaData.sharedInstance.scoreThreshold, videoDelegate: self)
      default:
        break;
    }
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    
    guard let mediaType = info[.mediaType] as? String else {
      return
    }
    
    switch mediaType {
    case UTType.movie.identifier:
      guard let mediaURL = info[.mediaURL] as? URL else {
        return
      }
      clearAndInitializeObjectDetectorService(runningMode: .video)
      overlayView.clear()
      let asset = AVAsset(url: mediaURL)
      Task {
        showProgressView()
        let resultBundle = await objectDetectorService?.detect(videoAsset:asset, inferenceIntervalMs: Double(Constants.inferenceTimeIntervalMs))
        hideProgressView()
        
        playVideo(asset: AVAsset(url: mediaURL))
        
        playerViewController?.player?.addPeriodicTimeObserver(forInterval: CMTime(value: Constants.inferenceTimeIntervalMs, timescale: Constants.kMilliSeconds), queue: DispatchQueue(label: "timeObserverQueue"), using: { [weak self] (time: CMTime) in
          DispatchQueue.main.async {
            let index =  Int(time.value / Constants.inferenceTimeIntervalMs)
            if let resultBundle = resultBundle, index < resultBundle.objectDetectorResults.count, let objectDetectorResult = resultBundle.objectDetectorResults[index], let bounds = self?.playerViewController?.videoBounds {
              self?.draw(detections: objectDetectorResult.detections, originalImageSize: resultBundle.size, andOrientation: .up, inFrame: bounds)
            }
          }
        })
      }
      //        guard let mediaURL = info[.mediaURL] as? URL else { return }
      //        imageEmptyLabel.isHidden = true
      //        processVideo(url: mediaURL)
    case UTType.image.identifier:
      removePlayerViewController()
      overlayView.clear()
      guard let image = info[.originalImage] as? UIImage else {
        pickedImageView.image = nil
        return
      }
      pickedImageView.image = image
      print(image.imageOrientation.rawValue)
      showProgressView()
      clearAndInitializeObjectDetectorService(runningMode: .image)
      DispatchQueue.global(qos: .userInteractive).async { [weak self] in
        if let weakSelf = self, let objectDetectorResult = weakSelf.objectDetectorService?.detect(image: image)?.objectDetectorResults.first as? ObjectDetectorResult {
          DispatchQueue.main.async {
            weakSelf.hideProgressView()
            weakSelf.draw(detections: objectDetectorResult.detections, originalImageSize: image.size, andOrientation: image.imageOrientation, inFrame: weakSelf.overlayView.bounds)
          }
        }
      }
      
    default:
      break
    }
  }
}

extension MediaLibraryViewController: ObjectDetectorServiceVideoDelegate {
  
  func objectDetectorService(_ objectDetectorService: ObjectDetectorService, didFinishDetectionOnVideoFrame index: Int) {
    progressView.observedProgress?.completedUnitCount = Int64(index + 1)
  }
  
  func objectDetectorService(_ objectDetectorService: ObjectDetectorService, willBeginDetection totalframeCount: Int) {
    progressView.observedProgress = Progress(totalUnitCount: Int64(totalframeCount))
  }
}


