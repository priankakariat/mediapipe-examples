//
//  WebView.swift
//  InferenceExample
//
//  Created by Prianka Kariat on 02/04/25.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
  let url: URL
  
  func makeUIView(context: Context) -> WKWebView {
    return WKWebView()
  }
  
  func updateUIView(_ webView: WKWebView, context: Context) {
    let request = URLRequest(url: url)
    webView.load(request)
  }
}
//
//struct ContentView: View {
//  var body: some View {
//    WebView(url: URL(string: "https://www.apple.com")!)
//      .edgesIgnoringSafeArea(.all)
//  }
//}
