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
        fetchResult()
    }

    /// Step 4: ask the back end for the result. IDV_SESSION_COMPLETE is sent only after the hosted page has processed the
    /// document and selfie and the results are stored, so one request is enough: no polling.
    private func fetchResult() {
        guard !verificationId.isEmpty else { return }
        Backend.fetchResult(verificationId: verificationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let json) where (json["status"] as? String) == "ready":
                    // In a real app: decide what to do next. The full decision stays on your back end.
                    self.showMessage("Verification result is ready.")
                case .success:
                    self.showMessage("The result is not available yet.", retry: true)
                case .failure(let error):
                    self.showMessage("Could not get the result: \(error.localizedDescription)", retry: true)
                }
            }
        }
    }

    private func showMessage(_ message: String, retry: Bool = false) {
        let alert = UIAlertController(title: "Verification", message: message, preferredStyle: .alert)
        if retry { alert.addAction(UIAlertAction(title: "Try again", style: .default) { [weak self] _ in self?.fetchResult() }) }
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
