//
//  PrintViewController.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 09-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import UIKit
import WebKit

class PrintViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var printImageView : UIImageView!
    
    @IBOutlet weak var printTextView: UITextView!

    var printData : PrintData!
    let defaults = UserDefaults.standard

    var possibleScore : Int {
        get {
            var score = defaults.integer(forKey: "pm_score_for_\(printData.identifier)")
            if score == 0 {
                score = 50
            }
            return score
        }
        set(newValue) {
            guard newValue > 1 else {
                return
            }
            defaults.set(newValue, forKey: "pm_score_for_\(printData.identifier)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        
        var attrString : NSMutableAttributedString?
        if (printData.title.isEmpty && printData.description.isEmpty) {
            attrString = NSMutableAttributedString(string: "Helaas, er is geen extra informatie beschikbaar\n\n\n", attributes: [NSAttributedStringKey.font:UIFont.systemFont(ofSize: 18)])
        }
        else {
            printTextView.isHidden = true

            attrString = NSMutableAttributedString(string: printData.title, attributes: [NSAttributedStringKey.font:UIFont.systemFont(ofSize: 22)])
            attrString!.append(NSAttributedString(string: "\n", attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)]))
            attrString!.append(NSAttributedString(string: printData.description, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)]))
            if !printData.place.isEmpty {
                attrString!.append(NSAttributedString(string: "\nLocatie: ", attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)]))
                attrString!.append(NSAttributedString(string: printData.place, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)]))
            }
        }

        printTextView.attributedText = attrString!
        printTextView.sizeToFit()
        
        URLSession.shared.dataTask(with: printData.printUrl, completionHandler: { (data, response, error) in
            if error != nil {
                print(error!)
                return
            }
            
            DispatchQueue.main.async {
                if let image = UIImage(data: data!) {
                    self.printImageView.image = image
                }
            }
            
        }).resume()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupTitle()
    }
    
    func setupTitle() {
        self.navigationItem.title = "\(self.possibleScore) meppen waard"
    }
    
    override func viewDidLayoutSubviews() {
        let newHeight = 500 + printTextView.frame.size.height
        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: newHeight )
    }

    @IBAction func giveExtraInformation(_ sender: UIButton) {
        let title = "Extra informatie"
        let message = ""
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Annuleren", style: .cancel, handler: { _ in
            NSLog("The \"annuleren\" alert occured.")
        }))
        alert.addAction(UIAlertAction(title: "Koop informatie voor 5 meppen", style: .destructive, handler: { _ in
            self.possibleScore = self.possibleScore - 5
            self.setupTitle()
            sender.isHidden = true
            self.printTextView.isHidden = false
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func takingPhoto(_ sender: Any) {
        let title = "Maak een foto"
        let message = "Weet je precies waar de maker van de prent stond en kan je dezelfde foto maken als op de prent staat?\nMaak de foto dan snel en verdien \(possibleScore) meppen!"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Annuleren", style: .cancel, handler: { _ in
            NSLog("The \"annuleren\" alert occured.")
        }))
        alert.addAction(UIAlertAction(title: "Maak de foto en verdien \(possibleScore) meppen", style: .destructive, handler: { _ in
            self.performSegue(withIdentifier: "MakePhoto", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "MakePhoto") {
            let destinationViewController = segue.destination as! MakePhotoViewController

            destinationViewController.printData = printData
        }
    }

}
