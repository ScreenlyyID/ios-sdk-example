//
//  LaunchViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

/// Settings for the demo. Replace the placeholders with your own values.
enum DemoConfig {
    /// ScreenlyyID API base URL.
    static let apiBaseURL = "https://api.screenlyyid.com"
    /// A **test** API key (it starts with `test_`) from the dashboard: Integrations > create key > test environment.
    ///
    /// DEMO ONLY. A real app must never contain an API key. In production, your own back end calls `instance/create`
    /// and returns the `webEnrolmentUrl` (and keeps the `CorrelationId`) for this app to use. See the docs:
    /// https://www.screenlyyid.com/docs/integrations/mobile-app/
    static let apiKey = "YOUR_TEST_API_KEY"

    static var isConfigured: Bool { !apiKey.isEmpty && apiKey != "YOUR_TEST_API_KEY" }
}

/// What `POST /api/v1/instance/create` returns. The JSON property names are exactly `CorrelationId` and `webEnrolmentUrl`.
struct VerificationSession {
    /// The session token. Keep it: your back end sends it in the `x-correlation-id` header when it fetches the results (step 4).
    let correlationId: String
    /// The hosted document and selfie capture page to open in the WebView.
    let webEnrolmentUrl: String
}

class LaunchViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        createSession()
    }

    /// Step 1: create a verification session with the Instance API.
    private func createSession() {
        guard DemoConfig.isConfigured else {
            showError("Set DemoConfig.apiKey in LaunchViewController.swift to a test API key from the ScreenlyyID dashboard.")
            return
        }
        guard let url = URL(string: DemoConfig.apiBaseURL + "/api/v1/instance/create") else {
            showError("DemoConfig.apiBaseURL is not a valid URL.")
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(DemoConfig.apiKey, forHTTPHeaderField: "x-api-key")
        // "idv" is the identity verification product. It must be activated on your account.
        let body: [String: Any] = ["GlobalScreening": ["idv"], "CustomerIntelligence": [String]()]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                self.showError("Could not reach ScreenlyyID: \(error.localizedDescription)")
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                guard let data = data,
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let correlationId = json["CorrelationId"] as? String,
                      let webEnrolmentUrl = json["webEnrolmentUrl"] as? String else {
                    self.showError("Unexpected response from instance/create.")
                    return
                }
                let session = VerificationSession(correlationId: correlationId, webEnrolmentUrl: webEnrolmentUrl)
                DispatchQueue.main.async { self.showHome(with: session) }
            case 401:
                self.showError("The API key was not accepted (HTTP 401). Check the key, including its test_ prefix.")
            case 400:
                // instance/create returns 400 with an empty body, so there is no message to show.
                self.showError("The request was rejected (HTTP 400). Check that the idv product is activated on your account.")
            default:
                self.showError("instance/create failed (HTTP \(status)).")
            }
        }.resume()
    }

    private func showHome(with session: VerificationSession) {
        guard let home = storyboard?.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController else { return }
        home.session = session
        navigationController?.pushViewController(home, animated: true)
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
            self.present(alert, animated: true)
        }
    }
}

extension String {
    /// Parses a JSON object. Returns an empty dictionary when the text is not a JSON object.
    func convertToAnyObjectDictionary() -> [String: AnyObject] {
        guard let data = self.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)) as? [String: AnyObject] else {
            return [String: AnyObject]()
        }
        return dict
    }
}
