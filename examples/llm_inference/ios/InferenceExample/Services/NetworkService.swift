//
//  OAuthService.swift
//  InferenceExample
//
//  Created by Prianka Kariat on 20/03/25.
//

import Foundation
import Alamofire


enum NetworkError: LocalizedError {
  case invalidURL
  case unauthorized(String)
  case forbidden(String)
  case invalidResponseCode(String)
  case invalidJson
  case noResponse
  case fileDownloadFailed
  
  public var errorDescription: String? {
    switch self {
      case .invalidURL:
        return "Invalid URL"
      case .unauthorized:
        return "Unauthorized Request"
      case .forbidden:
        return "Forbidden Request"
      case .invalidResponseCode:
        return "Invalid Response Dode"
      case .fileDownloadFailed:
        return "File Download Failed"
      case .invalidJson:
        return "Invalid JSON response."
      case .noResponse:
        return "No Response"
    }
  }
  
  public var failureReason: String {
    switch self {
      case .invalidURL:
        return "The request URL is invalid."
      case .unauthorized(let response):
        return "The request could not be authorized. Please refresh the access token. \(response)"
      case .invalidResponseCode(let response):
        return "Some error occured. \(response)"
      case .forbidden(let response):
        return "The request is forbidden. \(response))"
      case .fileDownloadFailed:
        return "File download failed."
      case .invalidJson:
        return "The server returned an invalid JSON Response."
      case .noResponse:
        return "The server did not respond."

    }
  }
}

enum DownloadEvent {
  case progress(Double) // Percentage 0-100
  case completed(URL)
}

class NetworkService {
  
  static let shared = NetworkService()
  
  private init() {}
  
  func postRequest(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> [String: Any] {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    
    if let headers = headers {
      for (key, value) in headers {
        request.addValue(value, forHTTPHeaderField: key)
      }
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.noResponse
    }
            
    try NetworkService.localizedMessage(httpResponse: httpResponse)
    
    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
      throw NetworkError.invalidJson
    }
    
    return json
  }
  
  static func localizedMessage(httpResponse: HTTPURLResponse) throws {
      let localizedMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
    
      guard httpResponse.statusCode != 401 else {
        throw NetworkError.unauthorized(localizedMessage)
      }
    
      guard httpResponse.statusCode != 431 else {
        throw NetworkError.forbidden(localizedMessage)
      }
    
      guard (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponseCode(localizedMessage)
      }
  }
  
//  guard httpResponse.statusCode != 401 else {
//    throw NetworkError.unauthorized
//  }
//  
//  guard httpResponse.statusCode != 431 else {
//    throw NetworkError.forbidden
//  }
//  
//  guard (200...299).contains(httpResponse.statusCode) else {
//    throw NetworkError.invalidResponse(code: httpResponse.statusCode)
//  }
//  
//  guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
//    throw NetworkError.invalidResponse
//  }
//  
  func downloadFile(from url: URL, to destinationURL: URL, headers: [String: String]? = nil) -> AsyncThrowingStream<DownloadEvent, Error> {
    AsyncThrowingStream { continuation in
      
      var request = URLRequest(url: url)
      
      if let headers = headers {
        for (key, value) in headers {
          print(value)
          print(key)

          request.addValue(value, forHTTPHeaderField: key)
        }
      }
      
      let downloadTask = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
        if let error = error {
          continuation.finish(throwing: error)
          return
        }
        
        guard let httpResponse = response as? HTTPURLResponse, let tempURL = tempURL else {
          continuation.finish(throwing: NetworkError.noResponse)
          return
        }
        
        do {
          try NetworkService.localizedMessage(httpResponse: httpResponse)
        }
        catch {
          continuation.finish(throwing: error)
        }

        do {
          try NetworkService.localizedMessage(httpResponse: httpResponse)
          try NetworkService.moveFile(from: tempURL, to: destinationURL)
          continuation.yield(.progress(100.0))
          continuation.yield(.completed(destinationURL))
          continuation.finish()
        } catch let error as NetworkError{
          continuation.finish(throwing: error)
        }
        catch {
          continuation.finish(throwing: NetworkError.fileDownloadFailed)
        }
      }
      
      let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
        let percentage = progress.fractionCompleted * 100
        continuation.yield(.progress(percentage))
      }
      
      // Start the download
      downloadTask.resume()
      
      // Handle cancellation
      continuation.onTermination = { @Sendable _ in // Explicitly mark as Sendable
        downloadTask.cancel()
        observation.invalidate()
      }
    }
  }
  
  class func moveFile(from sourceURL: URL, to destinationURL: URL) throws {
    
    let directory = destinationURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    
    try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
  }
}
