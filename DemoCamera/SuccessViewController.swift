//
//  SuccessViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

class SuccessViewController: UIViewController {

    var verificationId: String = ""

    /// The result rows, built in code above the "Your ID scanned successfully" label from the storyboard.
    private let resultStack = UIStackView()
    private var titleLabel: UILabel? { view.subviews.compactMap { $0 as? UILabel }.first }

    override func viewDidLoad() {
        super.viewDidLoad()
        resultStack.axis = .vertical
        resultStack.spacing = 8
        resultStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultStack)
        var constraints = [
            resultStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 30),
            resultStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
        ]
        if let title = titleLabel {
            constraints.append(resultStack.bottomAnchor.constraint(equalTo: title.topAnchor, constant: -24))
        }
        NSLayoutConstraint.activate(constraints)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchResult()
    }

    /// Step 4: ask the back end for the result. The back end read it from ScreenlyyID once, after IDV_SESSION_COMPLETE.
    private func fetchResult() {
        guard !verificationId.isEmpty else { return }
        Backend.fetchResult(verificationId: verificationId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let json) where (json["status"] as? String) == "ready":
                    self.show(result: json["result"] as? [String: Any] ?? [:])
                case .success:
                    self.showMessage("The result is not available yet.", retry: true)
                case .failure(let error):
                    self.showMessage("Could not get the result: \(error.localizedDescription)", retry: true)
                }
            }
        }
    }

    /// Shows the decision from `document/result`: `Decision.Level` (HIGH, MEDIUM, LOW), `LivenessResult.Result` (Live or Not Live),
    /// `FaceMatchResult.IsMatch`, and the level of each data point in `Verifications`. These fields hold no personal data.
    /// In a real app the back end applies this rule and tells the app only the outcome.
    private func show(result: [String: Any]) {
        let level = (result["Decision"] as? [String: Any])?["Level"] as? String ?? "UNKNOWN"
        let liveness = (result["LivenessResult"] as? [String: Any])?["Result"] as? String ?? "Unknown"
        let isMatch = (result["FaceMatchResult"] as? [String: Any])?["IsMatch"] as? Bool ?? false
        let isLive = liveness == "Live"

        let outcome: String
        if level == "HIGH" && isLive && isMatch {
            outcome = "Approved"
        } else if level == "LOW" || !isLive || !isMatch {
            outcome = "Rejected"
        } else {
            outcome = "Needs review"
        }
        titleLabel?.text = outcome

        resultStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addRow("Overall decision", level, bold: true)
        addRow("Liveness", liveness)
        addRow("Face match", isMatch ? "Matches the ID photo" : "Does not match")

        let names = [
            "DateOfExpiration": "Document expiry", "DocumentLiveness": "Document is genuine", "FaceVerification": "Face verification",
            "MrzOcrCrossCheck": "MRZ cross check", "OverallOcrFieldsConfidence": "Data read from the ID", "PassiveLiveness": "Passive liveness",
        ]
        if let checks = result["Verifications"] as? [String: Any] {
            for key in names.keys.sorted() {
                if let item = checks[key] as? [String: Any], let itemLevel = item["Level"] as? String {
                    addRow(names[key] ?? key, itemLevel)
                }
            }
        }
    }

    private func addRow(_ name: String, _ value: String, bold: Bool = false) {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 15, weight: bold ? .semibold : .regular)
        nameLabel.numberOfLines = 0
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: bold ? .semibold : .regular)
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        row.axis = .horizontal
        row.spacing = 12
        resultStack.addArrangedSubview(row)
    }

    private func showMessage(_ message: String, retry: Bool = false) {
        let alert = UIAlertController(title: "Verification", message: message, preferredStyle: .alert)
        if retry { alert.addAction(UIAlertAction(title: "Try again", style: .default) { [weak self] _ in self?.fetchResult() }) }
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
        present(alert, animated: true)
    }

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
