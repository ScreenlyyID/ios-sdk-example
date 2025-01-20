//
//  SuccessViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

class SuccessViewController: UIViewController {

    //MARK: - UIView Controller Methods
    override func viewDidLoad() {
        super.viewDidLoad()

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
