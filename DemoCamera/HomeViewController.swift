//
//  HomeViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit
import AVFoundation

class HomeViewController: UIViewController {

    //MARK: - Variables
    /// Set by LaunchViewController after `instance/create` succeeds.
    var session: VerificationSession?

    //MARK: - UIView Controller Methods
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    //MARK: - UIButton Action
    @IBAction func btnWebOpenAction(_ sender: UIButton) {
        openCapture(skipIntro: false)
    }

    @IBAction func btnWebOpenSkipWelcomeAction(_ sender: UIButton) {
        openCapture(skipIntro: true)
    }

    //MARK: - Step 2: open the hosted capture page in a WebView
    private func openCapture(skipIntro: Bool) {
        guard let session = session else { return }
        // The WebView needs the camera, so ask for permission first. The hosted page cannot ask on its own.
        requestCameraAccess { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard granted else { self.showCameraDenied(); return }
                guard let vc = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController else { return }
                // ?skipIntro=true goes straight to image capture.
                vc.stLoadUrl = skipIntro ? session.webEnrolmentUrl + "?skipIntro=true" : session.webEnrolmentUrl
                vc.verificationId = session.verificationId
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    //MARK: - Camera permission
    private func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { completion($0) }
        case .restricted, .denied:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func showCameraDenied() {
        let alert = UIAlertController(title: "Camera access needed",
                                      message: "Identity verification photographs the ID document and a selfie. Allow camera access in Settings to continue.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        present(alert, animated: true)
    }
}
