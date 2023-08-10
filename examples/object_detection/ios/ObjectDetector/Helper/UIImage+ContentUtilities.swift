//
//  UIImage+ContentUtilities.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 09/08/23.
//

import Foundation
import UIKit

extension UIView {
  
  func contentFrame(withOriginalSize originalSize: CGSize) -> CGRect? {
    switch self.contentMode {
      case .scaleAspectFit:
      let widthScale = self.bounds.size.width / originalSize.width
      let heightScale = self.bounds.size.height / originalSize.height
      
      let aspectFitFactor = min(widthScale, heightScale)
      var imageFrame = CGRect(x: 0.0, y: 0.0, width: originalSize.width * aspectFitFactor, height: originalSize.height * aspectFitFactor)
      
      imageFrame.origin.x = (self.bounds.size.width - imageFrame.size.width) / 2
      imageFrame.origin.y = (self.bounds.size.height - imageFrame.size.height) / 2

      return imageFrame
      
      default:
        return nil
      
    }
  }
}
