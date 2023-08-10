//
//  ObjectOverlayExtension.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 09/08/23.
//

import Foundation
import UIKit

import MediaPipeTasksVision

class ObjectOverlayHelper {
  
  static func offsetsAndScaleFactor(
    forImageOfSize imageSize: CGSize,
    tobeDrawnInViewOfSize viewSize: CGSize,
    withContentMode contentMode: UIView.ContentMode) -> (xOffset: CGFloat, yOffset: CGFloat, scaleFactor: Double) {
    
    let widthScale = viewSize.width / imageSize.width;
    let heightScale = viewSize.height / imageSize.height;
    
    var scaleFactor = 0.0
    
    switch contentMode {
    case .scaleAspectFill:
      scaleFactor = max(widthScale, heightScale)
    case .scaleAspectFit:
      scaleFactor = min(widthScale, heightScale)
    default:
      scaleFactor = 1.0
    }
    
    print(widthScale)
    print(heightScale)
    let scaledSize = CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor)
    let xOffset = (viewSize.width - scaledSize.width) / 2
    let yOffset = (viewSize.height - scaledSize.height) / 2
    
    return (xOffset, yOffset, scaleFactor)
  }
 
  static func objectOverlays(
    fromDetections detections: [Detection],
    inferredOnImageOfSize originalImageSize: CGSize,
    andOrientation orientation: UIImage.Orientation) -> [ObjectOverlay] {
      
      var objectOverlays: [ObjectOverlay] = []
      
      for (index, detection) in detections.enumerated() {
        guard let category = detection.categories.first else {
          continue
          
        }
        var newRect = detection.boundingBox

        switch orientation {
        case .left:
          newRect = CGRect(
            x: detection.boundingBox.origin.y, y: originalImageSize.height - detection.boundingBox.origin.x - detection.boundingBox.width, width: detection.boundingBox.height, height: detection.boundingBox.width)
        case .right:
          newRect = CGRect(
            x: originalImageSize.width - detection.boundingBox.origin.y - detection.boundingBox.height, y: detection.boundingBox.origin.x, width: detection.boundingBox.height, height: detection.boundingBox.width)
        default:
          break
        }

        let confidenceValue = Int(category.score * 100.0)
        let string = "\(category.categoryName ?? "Unknown")  (\(confidenceValue)%)"
        
        let displayColor = DefaultConstants.labelColors[index %  DefaultConstants.labelColors.count]
        
        let size = string.size(withAttributes: [.font: DefaultConstants.displayFont])
        
        let objectOverlay = ObjectOverlay(name: string, borderRect: newRect, nameStringSize: size, color: displayColor, font: DefaultConstants.displayFont)
        
        objectOverlays.append(objectOverlay)
      }
      
     return objectOverlays
    
  }
}


