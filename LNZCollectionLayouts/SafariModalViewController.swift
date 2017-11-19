//
//  SafariModalViewController.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/11/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

class SafariModalViewController: UIViewController {
    var presentedElement: Int!
    
    
    @IBOutlet weak var elementTitle: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        elementTitle.text = "\(presentedElement!)"
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
