//
//  LaunchViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

/// Settings for the demo.
enum DemoConfig {
    /// The address of YOUR back end (the `backend/` folder in this repo). This app never talks to ScreenlyyID directly.
    ///
    /// The API key and the CorrelationId (the ScreenlyyID session token) live only in the back end. An API key inside an app can be
    /// extracted by anyone who has the app, so the ScreenlyyID API must be called from a server you control.
    ///
    /// Running on a real device (the camera needs one)? `localhost` is the phone itself. Use your Mac's address on the same Wi-Fi,
    /// for example "http://192.168.1.20:3000".
    static let backendURL = "http://localhost:3000"
}

/// What the back end returns from `POST /verifications`. There is no API key and no CorrelationId here: those stay on the server.
struct VerificationSession {
    /// Your back end's id for this verification. Use it to ask the back end for the result.
    let verificationId: String
    /// The hosted document and selfie capture page to open in the WebView.
    let webEnrolmentUrl: String
}

/// All the app's network calls. They go to your back end only.
enum Backend {
    /// Step 1: ask the back end to create a verification session. The back end calls ScreenlyyID `instance/create` with the API key.
    static func createVerification(completion: @escaping (Result<VerificationSession, Error>) -> Void) {
        guard let url = URL(string: DemoConfig.backendURL + "/verifications") else {
            return completion(.failure(BackendError.message("DemoConfig.backendURL is not a valid URL.")))
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        run(request) { result in
            completion(result.flatMap { json in
                guard let id = json["verificationId"] as? String, let url = json["webEnrolmentUrl"] as? String else {
                    return .failure(BackendError.message("Unexpected response from the back end."))
                }
                return .success(VerificationSession(verificationId: id, webEnrolmentUrl: url))
            })
        }
    }

    /// Step 4: ask the back end for the result. It returns `["status": "pending"]` until the result is ready, then `["status": "ready", "result": ...]`.
    static func fetchResult(verificationId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: DemoConfig.backendURL + "/verifications/" + verificationId) else {
            return completion(.failure(BackendError.message("DemoConfig.backendURL is not a valid URL.")))
        }
        run(URLRequest(url: url, timeoutInterval: 30), completion: completion)
    }

    private static func run(_ request: URLRequest, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } ?? [:]
            if (200..<300).contains(status) { return completion(.success(json)) }
            completion(.failure(BackendError.message((json["error"] as? String) ?? "The back end returned HTTP \(status).")))
        }.resume()
    }
}

enum BackendError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }
}

class LaunchViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Backend.createVerification { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let session): self?.showHome(with: session)
                case .failure(let error): self?.showError("Could not start a verification: \(error.localizedDescription)\n\nIs the back end running? See the README.")
                }
            }
        }
    }

    private func showHome(with session: VerificationSession) {
        guard let home = storyboard?.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController else { return }
        home.session = session
        navigationController?.pushViewController(home, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
        present(alert, animated: true)
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
