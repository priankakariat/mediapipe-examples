//
//  DownloadViewModel.swift
//  InferenceExample
//
//  Created by Prianka Kariat on 28/03/25.
//

import Foundation

@MainActor
class DownloadViewModel: ObservableObject {
  
  enum State: Equatable {
    case notInitiated
    case progress
    case completed
    case error(error: NetworkError)
    
    static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
        case (.notInitiated, .notInitiated),
          (.progress, .progress),
          (.completed, .completed),
          (.error, .error):
          return true
        default:
          return false
      }
    }
    
    var error: NetworkError? {
      switch self {
        case let .error(error):
          return error
        default:
          return nil
      }
    }
  }
  
  @Published var state = State.notInitiated
  @Published var progress: Double = 0.0
  
  private let url: URL?
  private let licenseAcknowledgedKey: String?
  
  init(url: URL?, licenseAcknowledgedKey: String?) {
    self.url = url
    self.licenseAcknowledgedKey = licenseAcknowledgedKey
  }
  
  func download() {
    Task {
      let documentsDirectory = try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      
      // Not handing an error here since there will be a url always.
      guard let url = url, let accessToken = KeyChainHelper.load(key: "access-token") else {
        return
      }
      
      let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
      do {
        state = .progress
        for try await event in NetworkService.shared.downloadFile(from: url, to: destinationURL, headers: ["Authorization" : "Bearer " + accessToken]) {
          switch event {
            case .progress(let percentage):
              progress = percentage
            case .completed:
              progress = 100.0
          }
        }
        state = .completed
      } catch let error as NetworkError {
        self.state = .error(error: error)
        switch error {
          case .unauthorized:
            guard let licenseAcknowledgedKey = self.licenseAcknowledgedKey else {
              return
            }
            KeyChainHelper.checkAndClearKeys([OAuthService.accessTokenKey, licenseAcknowledgedKey])
          case .forbidden:
            guard let licenseAcknowledgedKey = self.licenseAcknowledgedKey else {
              return
            }
            KeyChainHelper.checkAndClearKeys([licenseAcknowledgedKey])
          default:
            return
        }
      }
    }
  }
  
  func handleDownloadErrorDismissed() -> Bool {
    guard case let .error(networkError) = self.state else {
      return false
    }
    switch networkError {
      case .unauthorized, .forbidden:
        return true
      default:
        return false
    }
  }
}
