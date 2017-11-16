//
//  SafariViewController.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 15/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

class SafariViewController: UICollectionViewController, UICollectionViewDelegateSafariLayout {
    var elements: [Int] = Array(0...10)

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return elements.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        
        cell.layer.borderColor = UIColor.darkGray.cgColor
        cell.layer.borderWidth = 1
        
        let el = elements[indexPath.item]
        
        let label = cell.contentView.viewWithTag(10)! as! UILabel
        label.text = "\(el)"
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return view.bounds.size
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, canDeleteItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, didDeleteItemAt indexPath: IndexPath) {
        elements.remove(at: indexPath.item)
        collectionView.deleteItems(at: [indexPath])
    }

    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    
}
