//
//  LaunchViewController.swift
//  DemoCamera
//
//  Created by Sagar on 17/01/25.
//

import UIKit

class LaunchViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let parameters = "{\n\"ClientLookupId\": null,\n\"GlobalScreening\": [\"idv\"],\n\"CustomerIntelligence\": []\n}"
        let postData = parameters.data(using: .utf8)
        
        var request = URLRequest(url: URL(string: "{{ ADD API URL HERE }}/api/v1/instance/create")!,timeoutInterval: Double.infinity)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("{{ ADD YOUR API KEY HERE }}", forHTTPHeaderField: "x-api-key")
        request.addValue("ARRAffinity=e056118c14e70b1edf2d787c77dc6552a73db953ae51c74a6abe0491703419b2; ARRAffinitySameSite=e056118c14e70b1edf2d787c77dc6552a73db953ae51c74a6abe0491703419b2", forHTTPHeaderField: "Cookie")
        
        request.httpMethod = "POST"
        request.httpBody = postData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print(String(describing: error))
                return
            }
            let stData: String = String(data: data, encoding: .utf8)!
            print("Response",stData)
            var dictServiceData: [String:AnyObject] =  [String:AnyObject]()
            dictServiceData = stData.convertToAnyObjectDictionary() as [String:AnyObject]
            if dictServiceData.isEmpty{
                let alertView = UIAlertController(title: "Error", message: "", preferredStyle: .alert)
                let cancelAction: UIAlertAction = UIAlertAction(title: "Okay", style: .cancel) { action -> Void in
                    alertView.dismiss(animated: true, completion: nil)
                }
                alertView.addAction(cancelAction)
                DispatchQueue.main.async {
                    self.present(alertView, animated: true, completion: nil)
                }
            }else{
                if dictServiceData["title"] !=  nil{
                    let alertView = UIAlertController(title: "Error", message: "\((dictServiceData["title"] as? String) ?? "")", preferredStyle: .alert)
                    let cancelAction: UIAlertAction = UIAlertAction(title: "Okay", style: .cancel) { action -> Void in
                        alertView.dismiss(animated: true, completion: nil)
                    }
                    alertView.addAction(cancelAction)
                    DispatchQueue.main.async {
                        self.present(alertView, animated: true, completion: nil)
                    }
                }else{
                    DispatchQueue.main.async {
                        let webEnrolmentUrl = ((dictServiceData["webEnrolmentUrl"] as? String) ?? "")
                        let vc = (self.storyboard?.instantiateViewController(withIdentifier: "HomeViewController"))! as! HomeViewController
                        vc.stUrlToken = webEnrolmentUrl
                        self.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            }
        }
        
        task.resume()
        
        let vc = (self.storyboard?.instantiateViewController(withIdentifier: "HomeViewController"))! as! HomeViewController
        self.navigationController?.pushViewController(vc, animated: true)


    }

}

extension String{
    func convertToAnyObjectDictionary() -> [String:AnyObject] {
        let jsonData: Data = self.data(using: String.Encoding.utf8)!
        do {
            let dict: [String:AnyObject] = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as! [String:AnyObject]
            return dict
        } catch let error as NSError { print(error) }
        
        return [String:AnyObject]()
    }
}
