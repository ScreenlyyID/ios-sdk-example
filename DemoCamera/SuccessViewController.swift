//
//  SuccessViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

class SuccessViewController: UIViewController {

    /// Set by ViewController after IDV_SESSION_COMPLETE.
    var verificationId: String = ""

    //MARK: - UIView Controller Methods
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pollResult(attempt: 1)
    }

    /// Step 4: ask the back end for the result. The back end reads it from ScreenlyyID; webhooks are not available, so we poll.
    private func pollResult(attempt: Int) {
        guard !verificationId.isEmpty else { return }
        Backend.fetchResult(verificationId: verificationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let json) where (json["status"] as? String) == "ready":
                    // In a real app: decide what to do next. The full decision stays on your back end.
                    self.showMessage("Verification result is ready.")
                case .success where attempt < 20:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.pollResult(attempt: attempt + 1) }
                case .success:
                    self.showMessage("The result is not ready yet. Try again later.")
                case .failure(let error):
                    self.showMessage("Could not get the result: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Verification", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
        present(alert, animated: true)
    }

    //MARK: - UIButton Action
    @IBAction func btnScanAgainAction(_ sender: UIButton) {
        if let viewControllers = navigationController?.viewControllers {
            for viewController in viewControllers {
                if let targetVC = viewController as? HomeViewController {
                    navigationController?.popToViewController(targetVC, animated: true)
                    break
                }
            }
        }
    }
}
