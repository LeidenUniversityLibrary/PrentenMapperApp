//
//  PrintListViewController.swift
//  PrentenMapper
//
//  Created by Lucas van Schaik on 09-02-18.
//  Copyright © 2018 LuuX software. All rights reserved.
//

import UIKit

struct PrintData {
    var identifier : String
    var title : String
    var description : String
    var place : String
    var printUrl : URL
}

class PrintListViewController: UITableViewController {

    var cachedPrintDataList : [PrintData]!
    let defaults = UserDefaults.standard

    var currentScore : Int {
        get {
            return defaults.integer(forKey: "pm_current_score")
        }
        set(newValue) {
            defaults.set(newValue, forKey: "pm_current_score")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        self.navigationItem.title = "PrentenMapper"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "info", style: .plain, target: self, action:#selector(showInfo))
        
        self.cachedPrintDataList = []
        
        loadListPrintData({ list in
            DispatchQueue.main.async {
                self.cachedPrintDataList = list
                self.tableView.reloadData()
            }
        })
        
        showInfo()
    }
    
    @objc func showInfo() {
        let title = "Welkom bij de PrentenMapper"
        let message = "\nWandel mee en zet zoveel mogelijk prenten op de kaart.\nWaar stond de maker van de prent toen hij dit monument verbeeldde?\nProbeer de exacte plek te achterhalen en maak een foto.\nVoor elke geslaagde match krijg je 50 meppen.\nKom je er niet uit? Je kan tips krijgen, maar dat kost je wel meppen.\n\nHuidig aantal meppen: \(self.currentScore)\n"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sluiten", style: .`default`, handler: { _ in
            if (self.cachedPrintDataList.count == 0) {
                DispatchQueue.main.async {
                    self.loadListPrintData({ list in
                        DispatchQueue.main.async {
                            self.cachedPrintDataList = list
                            self.tableView.reloadData()
                        }
                    })
                }
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadListPrintData(_ completionHandler: @escaping ((_ listPrintData: [PrintData]) -> Void)) {
        var list = [PrintData]()
        
        let bensUrlString = "https://bencomp.nl/prentenmapper/"
        guard let bensUrl = URL(string: bensUrlString) else {
            print("\(bensUrlString) is not valid")
            return
        }
        URLSession.shared.dataTask(with: bensUrl, completionHandler: {(data, response, error) -> Void in
            guard let jsonObj = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) else {
                print("Not well formatted data")
                return
            }
            guard let jsonData = jsonObj as? NSDictionary else {
                print("Data is not a dictionary")
                return
            }
            guard let results = jsonData.value(forKey:"results") as? NSDictionary else {
                print("results is not a dictionary")
                return
            }
            guard let bindings = results.value(forKey: "bindings") as? Array<NSDictionary> else {
                print("bindings is not an array")
                return
            }
            for binding in bindings {
                var printData = PrintData(identifier: "", title: "", description: "", place: "", printUrl: URL(string:"missing.jpg")!)
                if let photo = binding.value(forKeyPath:"photo.value") as? String {
                    printData.identifier = photo
                }
                if let title = binding.value(forKeyPath:"title.value") as? String {
                    printData.title = title
                }
                if let description = binding.value(forKeyPath:"description.value") as? String {
                    printData.description = description
                }
                if let place = binding.value(forKeyPath:"place.value") as? String {
                    printData.place = place
                }
                if let urlString = binding.value(forKeyPath:"image.value") as? String {
                    if let url = URL(string: urlString) {
                        printData.printUrl = url
                        list.append(printData)
                    }
                }
            }
            
            completionHandler(list)
        }).resume()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return cachedPrintDataList.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PrintCell", for: indexPath) as! PrintCell
        
        // clear image
        cell.printImageView.image = nil
        
        let printData = cachedPrintDataList[indexPath.row]
        //cell.textLabel?.text = printData.identifier
        //cell.detailTextLabel?.text = printData.printUrl.absoluteString
        
        cell.loadImageForURL(printData.printUrl)
        /*
        do {
            let printImageData = try Data(contentsOf:printData.printUrl)
            
            if let printImage = UIImage(data: printImageData) {
                cell.printImageView.image = printImage
            }
        }
        catch {
            print("Unexpected error: \(error).")
        }*/
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if (segue.identifier == "showDetail") {
            let indexPath = self.tableView.indexPathForSelectedRow
            let destinationViewController = segue.destination as! PrintViewController
            guard let row = indexPath?.row else {
                    print("Error: unknown detail")
                    return
            }
            let printData = cachedPrintDataList[row]
            destinationViewController.printData = printData
        }
    }

}
