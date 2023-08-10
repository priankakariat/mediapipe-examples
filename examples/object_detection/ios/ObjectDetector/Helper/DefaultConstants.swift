//
//  DefaultConstants.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 10/08/23.
//

import Foundation
import UIKit

// MARK: Define default constants
struct DefaultConstants {
  static let maxResults = 3
  static let scoreThreshold: Float = 0.2
  static let labelColors = [
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
  static let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
  static let model: Model = .efficientdetLite0
}

// MARK: Model
enum Model: String, CaseIterable {
  case efficientdetLite0 = "EfficientDet-Lite0"
  case efficientdetLite2 = "EfficientDet-Lite2"
  
  var modelPath: String? {
    switch self {
    case .efficientdetLite0:
      return Bundle.main.path(
        forResource: "efficientdet_lite0", ofType: "tflite")
    case .efficientdetLite2:
      return Bundle.main.path(
        forResource: "efficientdet_lite2", ofType: "tflite")
    }
  }
}
