//
//  ViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit
import WebKit



class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
//    // Handle JavaScript message
//    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        // Check if the eventName is 'IDV_SESSION_COMPLETE'
//        if let messageBody = message.body as? [String: Any], let eventName = messageBody["eventName"] as? String, eventName == "IDV_SESSION_COMPLETE" {
//            print("Session Complete event received from JavaScript!")
//            // Handle the event (e.g., navigate to another screen)
//        }
//    }
    
    var webView: WKWebView!
    var stLoadUrl: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Set up WKWebView configuration
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.preferences.javaScriptEnabled = true
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = .all
        webViewConfiguration.allowsInlineMediaPlayback = true
        // Allow access to the camera and microphone
        webViewConfiguration.allowsAirPlayForMediaPlayback = true
        webViewConfiguration.mediaPlaybackRequiresUserAction = true
        
        
        let source = """
           window.addEventListener('message', function(e) { window.webkit.messageHandlers.iosListener.postMessage(JSON.stringify(e.data)) } )
           """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webViewConfiguration.userContentController.addUserScript(script)
        
        webViewConfiguration.userContentController.add(self, name: "iosListener")
        
        // Create the WKWebView
        webView = WKWebView(frame: self.view.bounds, configuration: webViewConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view.addSubview(webView)
        
        // Load a webpage with camera permissions
        if let url = URL(string: stLoadUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    // WKUIDelegate and WKNavigationDelegate methods for handling media capture permissions
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction) -> WKWebView? {
        // Handle new window or media capture requests if needed
        return nil
    }
    
    // Handle request for camera access from the web page
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        // You might need to handle permissions from the webpage here
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        print("message body: \(message.body)")
//        print("message frameInfo: \(message.frameInfo)")
        if let messageBody = message.body as? String {
            var dictServiceData: [String:AnyObject] =  [String:AnyObject]()
            dictServiceData = messageBody.convertToAnyObjectDictionary() as [String:AnyObject]
            if !dictServiceData.isEmpty{
                if ((dictServiceData["eventName"] as? String) ?? "") == "IDV_SESSION_COMPLETE"{
                    if !((dictServiceData["isError"] as? Bool) ?? false){
                        let vc = (self.storyboard?.instantiateViewController(withIdentifier: "SuccessViewController"))! as! SuccessViewController
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else {
            decisionHandler(.allow)
        }
        if let url = navigationAction.request.url {
            print(url)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Called when the page finishes loading
        print("WebView Finished Loading")
        
        // Now, you can check for specific text or elements on the page
        checkForTextInWebView()
    }
    
    func checkForTextInWebView() {//Process complete!
        let script = "document.body.innerText.includes('Process complete!');" // Replace with your specific text
        
        webView.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("JavaScript evaluation error: \(error.localizedDescription)")
                return
            }
            
            if let containsText = result as? Bool {
                if containsText {
                    print("Text found in the WebView!")
                } else {
                    print("Text not found in the WebView.")
                }
            }
        }
    }
}

