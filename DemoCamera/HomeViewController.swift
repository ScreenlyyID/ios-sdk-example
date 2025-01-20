//
//  HomeViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit
import AVFoundation

class HomeViewController: UIViewController {
    
    //MARK: - Varibale
    var stUrlToken: String = ""
    
    
    //MARK: - UIView Controller Methods
    override func viewDidLoad() {
//        labelOne.textAlignment = NSTextAlignmentCenter;
        super.viewDidLoad()
        
    }
    
    //MARK: - UIButton Action
    @IBAction func btnWebOpenAction(_ sender: UIButton) {
        DispatchQueue.main.async {
            if  self.checkCameraPermission(){
                let vc = (self.storyboard?.instantiateViewController(withIdentifier: "ViewController"))! as! ViewController
                vc.stLoadUrl = self.stUrlToken
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @IBAction func btnWebOpenSkipWelcomeAction(_ sender: UIButton) {
        DispatchQueue.main.async {
            if  self.checkCameraPermission(){
                let vc = (self.storyboard?.instantiateViewController(withIdentifier: "ViewController"))! as! ViewController
                vc.stLoadUrl = self.stUrlToken + "?skipIntro=true"
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    //MARK: - Other Methdos
    func checkCameraPermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            // Request access
            AVCaptureDevice.requestAccess(for: .video) { response in
                if response {
                    DispatchQueue.main.async {
                        let vc = (self.storyboard?.instantiateViewController(withIdentifier: "ViewController"))! as! ViewController
                        vc.stLoadUrl = self.stUrlToken
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }
            return false
        case .restricted, .denied:
            return false
        @unknown default:
            return false
        }
    }
    
}
