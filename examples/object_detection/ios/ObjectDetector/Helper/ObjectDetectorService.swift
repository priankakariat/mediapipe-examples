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
import AVFoundation

protocol ObjectDetectorServiceLiveStreamDelegate: AnyObject {
  func objectDetectorService(_ objectDetectorService: ObjectDetectorService,
                             didFinishDetection result: ResultBundle?,
                             error: Error?)
}

protocol ObjectDetectorServiceVideoDelegate: AnyObject {
 func objectDetectorService(_ objectDetectorService: ObjectDetectorService,
                                  didFinishDetectionOnVideoFrame index: Int)
 func objectDetectorService(_ objectDetectorService: ObjectDetectorService,
                             willBeginDetection totalframeCount: Int)
}


class ObjectDetectorService: NSObject {

  weak var liveStreamDelegate: ObjectDetectorServiceLiveStreamDelegate?
  weak var videoDelegate: ObjectDetectorServiceVideoDelegate?

  var objectDetector: ObjectDetector?
  private(set) var runningMode = RunningMode.image
  private var maxResults = 3
  private var scoreThreshold: Float = 0.5
  var modelPath: String

  private init?(model: Model, maxResults: Int, scoreThreshold: Float, runningMode:RunningMode) {
    guard let modelPath = model.modelPath else {
      return nil
    }
    self.modelPath = modelPath
    self.maxResults = maxResults
    self.scoreThreshold = scoreThreshold
    self.runningMode = runningMode
    
    super.init()
  }
  
  static func videoObjectDetectorService(model: Model, maxResults: Int, scoreThreshold: Float, videoDelegate: ObjectDetectorServiceVideoDelegate?) -> ObjectDetectorService? {
    let objectDetectorService = ObjectDetectorService(model: model, maxResults: maxResults, scoreThreshold: scoreThreshold, runningMode: .video)
    objectDetectorService?.videoDelegate = videoDelegate
    
    return objectDetectorService
  }
  
  static func liveStreamDetectorService(model: Model, maxResults: Int, scoreThreshold: Float, liveStreamDelegate: ObjectDetectorServiceLiveStreamDelegate?) -> ObjectDetectorService? {
    let objectDetectorService = ObjectDetectorService(model: model, maxResults: maxResults, scoreThreshold: scoreThreshold, runningMode: .liveStream)
    objectDetectorService?.liveStreamDelegate = liveStreamDelegate
    return objectDetectorService
  }
  
  static func stillImageDetectorService(model: Model, maxResults: Int, scoreThreshold: Float) -> ObjectDetectorService? {
    let objectDetectorService = ObjectDetectorService(model: model, maxResults: maxResults, scoreThreshold: scoreThreshold, runningMode: .image)
    return objectDetectorService
  }
  
  func liveStreamObjectDetectorService(model: Model, maxResults: Int, scoreThreshold: Float, videDelegate: ObjectDetectorServiceVideoDelegate?) {
    
    
  }

  
  private func createObjectDetector(runningMode: RunningMode) -> ObjectDetector? {
    let objectDetectorOptions = ObjectDetectorOptions()
    objectDetectorOptions.runningMode = runningMode
    objectDetectorOptions.maxResults = self.maxResults
    objectDetectorOptions.scoreThreshold = self.scoreThreshold
    objectDetectorOptions.baseOptions.modelAssetPath = modelPath
    if runningMode == .liveStream {
      objectDetectorOptions.objectDetectorLiveStreamDelegate = self
    }
    do {
      return try ObjectDetector(options: objectDetectorOptions)
    }
    catch {
      return nil
    }
  }
  /**
   This method return ObjectDetectorResult and infrenceTime when receive an image
   **/
  func detect(image: UIImage) -> ResultBundle? {
    guard let objectDetector = objectDetector(runningMode:.image), let mpImage = try? MPImage(uiImage: image) else {
      return nil
    }
    
    print(image.imageOrientation)
    var resultBundle:ResultBundle?
    
      do {
        let startDate = Date()
        let result = try objectDetector.detect(image: mpImage)
        let inferenceTime = Date().timeIntervalSince(startDate) * 1000
        resultBundle = ResultBundle(inferenceTime: inferenceTime, objectDetectorResults: [result])
      } catch {
        print(error)
      }
    return resultBundle
  }

  func detectAsync(videoFrame: CMSampleBuffer, orientation: UIImage.Orientation, timeStamps: Int) {
    guard let objectDetector = objectDetector(runningMode:.liveStream), let image = try? MPImage(sampleBuffer: videoFrame, orientation: orientation) else {
      return
    }
      do {
        try objectDetector.detectAsync(image: image, timestampInMilliseconds: timeStamps)
      } catch {
        print(error)
      }
  }

  func detect(videoAsset: AVAsset, inferenceIntervalMs: Double) async -> ResultBundle? {
    guard let objectDetector = objectDetector(runningMode:.video) else {
      return nil
    }
    let startDate = Date()
    let generator = AVAssetImageGenerator(asset:videoAsset)
    generator.requestedTimeToleranceBefore = CMTimeMake(value: 1, timescale: 25)
    generator.requestedTimeToleranceAfter = CMTimeMake(value: 1, timescale: 25)
    generator.appliesPreferredTrackTransform = true
    guard let videoDurationMs = try? await videoAsset.load(.duration).seconds * 1000 else { return nil }
    
    let frameCount = Int(videoDurationMs / inferenceIntervalMs)
    var objectDetectorResults: [ObjectDetectorResult?] = []
    var videoSize: CGSize = .zero
    
    Task { @MainActor in
      videoDelegate?.objectDetectorService(self, willBeginDetection: frameCount)
    }
    
    for i in 0..<frameCount {
      let timestampMs = Int(inferenceIntervalMs) * i // ms
      let image: CGImage?
      do {
        let time = CMTime(value: Int64(timestampMs), timescale: 1000)
//        CMTime(seconds: Double(timestampMs) / 1000, preferredTimescale: 1000)
        image = try generator.copyCGImage(at: time, actualTime:nil)
        
      } catch {
        print(error)
        return nil
      }
      
      guard let image = image else {
        return nil
      }
      
      let uiImage = UIImage(cgImage:image)

      videoSize = uiImage.size
      
      do {
        let result = try objectDetector.detect(videoFrame: MPImage(uiImage: uiImage), timestampInMilliseconds: timestampMs)
        objectDetectorResults.append(result)
        Task { @MainActor in
          videoDelegate?.objectDetectorService(self, didFinishDetectionOnVideoFrame: i)
        }
      } catch {
        print(error)
      }
    }
    let inferenceTime = Date().timeIntervalSince(startDate) / Double(frameCount) * 1000

    return ResultBundle(inferenceTime: inferenceTime, objectDetectorResults: objectDetectorResults, size: videoSize)
  }
  
  private func updateModel(modelPath: String, maxResults: Int, scoreThreshold: Float) {
      if (self.modelPath == modelPath && self.maxResults == maxResults && self.scoreThreshold == scoreThreshold) {
        return
      }
      self.modelPath = modelPath
      self.maxResults = maxResults
      self.scoreThreshold = scoreThreshold
      self.objectDetector = nil
    }
  
  private func objectDetector(runningMode: RunningMode) -> ObjectDetector? {
    guard self.runningMode == runningMode else {
      return nil
    }
    
    if objectDetector == nil {
      objectDetector = createObjectDetector(runningMode: runningMode)
    }
    
    return objectDetector
  }
}

// MARK: - ObjectDetectorLiveStreamDelegate
extension ObjectDetectorService: ObjectDetectorLiveStreamDelegate {
  func objectDetector(_ objectDetector: ObjectDetector, didFinishDetection result: ObjectDetectorResult?, timestampInMilliseconds: Int, error: Error?) {
    guard let result = result else {
      liveStreamDelegate?.objectDetectorService(self, didFinishDetection: nil, error: error)
      return
    }
    let resultBundle = ResultBundle(
      inferenceTime: Date().timeIntervalSince1970 * 1000 - Double(timestampInMilliseconds),
      objectDetectorResults: [result])
    liveStreamDelegate?.objectDetectorService(self, didFinishDetection: resultBundle, error: nil)
  }
}

/// A result from the `ObjectDetectorHelper`.
struct ResultBundle {
  let inferenceTime: Double
  let objectDetectorResults: [ObjectDetectorResult?]
  var size: CGSize = .zero
}
