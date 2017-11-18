//
//  SafariViewController.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 15/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

class SafariViewController: UICollectionViewController, UICollectionViewDelegateSafariLayout, SafariLayoutContaining {    
    var elements: [Int] = Array(0...10)
    var safariCollectionView: UICollectionView {
        return collectionView!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        transitioningDelegate = self
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
    
    var animator: SafariAnimator?
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        modalPresentationStyle = .custom
        
        let controller = UIViewController()
        controller.transitioningDelegate = self
        present(controller, animated: true, completion: nil)
    }
}

extension SafariViewController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let indexPath = collectionView?.indexPathsForSelectedItems?.first else { return nil }
        return (collectionView?.collectionViewLayout as? LNZSafariLayout)?.animator(forItem: indexPath)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return nil
    }
}
