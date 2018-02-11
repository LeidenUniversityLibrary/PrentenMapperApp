//
//  PrintCell.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 09-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import UIKit

class PrintCell: UITableViewCell {

    @IBOutlet weak var printImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func loadImageForURL(_ imageURL: URL) {
        URLSession.shared.dataTask(with: imageURL, completionHandler: { (data, response, error) in
            if error != nil {
                print(error!)
                return
            }
            
            DispatchQueue.main.async {
                if let image = UIImage(data: data!) {
                    self.printImageView.image = image
                }
                else {
                    self.printImageView.image = UIImage(named: "missing.jpg")
                }
            }
            
        }).resume()
    }
}
