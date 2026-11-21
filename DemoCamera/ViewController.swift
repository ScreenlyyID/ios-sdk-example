//
//  ViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit
import WebKit



class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    
    var webView: WKWebView!
    var stLoadUrl: String = ""
    /// Your back end's id for this verification. The app uses it to ask the back end for the result (step 4).
    var verificationId: String = ""
    private var finished = false
    
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
    
    /// Step 3: events from the hosted page arrive as postMessage. They look like { eventName, isError, error }.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !finished,
              let body = message.body as? String,
              let name = body.convertToAnyObjectDictionary()["eventName"] as? String else { return }
        let event = body.convertToAnyObjectDictionary()
        let isError = (event["isError"] as? Bool) ?? false

        switch name {
        case "IDV_SESSION_COMPLETE" where !isError:
            // The document and selfie have been collected. It is safe to close the WebView and carry on.
            finished = true
            // Step 4: the result is read by YOUR back end, which holds the API key and the CorrelationId.
            // The app only asks the back end for the outcome (see SuccessViewController).
            if let vc = storyboard?.instantiateViewController(withIdentifier: "SuccessViewController") as? SuccessViewController {
                vc.verificationId = verificationId
                navigationController?.pushViewController(vc, animated: true)
            }
        case "ERROR":
            // A fatal, non-recoverable error while processing the images. Restart the flow, or carry on without verification.
            finished = true
            let reason = (event["error"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Verification could not be completed."
            let alert = UIAlertController(title: "Verification failed", message: reason, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Try again", style: .default) { [weak self] _ in self?.navigationController?.popViewController(animated: true) })
            present(alert, animated: true)
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
        } else {
            decisionHandler(.allow)
        }
    }
}
