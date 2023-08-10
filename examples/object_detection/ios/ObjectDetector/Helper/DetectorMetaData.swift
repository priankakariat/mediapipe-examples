//
//  DetectorMetaData.swift
//  ObjectDetector
//
//  Created by Prianka Kariat on 07/08/23.
//

import Foundation

class DetectorMetaData {
  var model: Model = DefaultConstants.model
  var maxResults: Int = DefaultConstants.maxResults
  var scoreThreshold: Float = DefaultConstants.scoreThreshold
  
  static let sharedInstance = DetectorMetaData()
  
  private init() {
    
  }

}
