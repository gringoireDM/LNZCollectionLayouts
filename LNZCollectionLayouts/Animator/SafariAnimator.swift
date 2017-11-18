//
//  SafariAnimator.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 17/11/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

public protocol SafariLayoutContaining {
    var safariCollectionView: UICollectionView { get }
}

public class SafariAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    public let presentingIndexPath: IndexPath
    public var reversed: Bool = false
    
    private let animationDuration: TimeInterval = 1
    private let transformForItem: (_ origin: CGPoint, _ size: CGSize, _ angle: CGFloat) -> CATransform3D
    
    public init(presentingIndexPath: IndexPath, transformFunction: @escaping (_ origin: CGPoint, _ size: CGSize, _ angle: CGFloat) -> CATransform3D) {
        self.presentingIndexPath = presentingIndexPath
        self.transformForItem = transformFunction
        
        super.init()
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animationDuration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if !reversed {
            performTransition(using: transitionContext)
        } else {
            performReversed(using: transitionContext)
        }
    }
    
    private func performTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from) else { return }
        
        var safariController: SafariLayoutContaining! = from as? SafariViewController
        if safariController == nil {
            safariController = from.childViewControllers.last as? SafariViewController
        }
        
        assert(safariController != nil)
        
        let containerView = transitionContext.containerView
        containerView.backgroundColor = .clear
        
        var frame = safariController.safariCollectionView.superview!.convert(safariController.safariCollectionView.frame, to: containerView)
        
        var contentInset = safariController.safariCollectionView.contentInset
        if #available(iOS 11.0, *) {
            contentInset = safariController.safariCollectionView.adjustedContentInset
        }
        
        frame.origin.y += contentInset.top
        frame.size.height -= contentInset.top - contentInset.bottom
        
        let mockCollectionView = UIView(frame: frame)
        mockCollectionView.backgroundColor = safariController.safariCollectionView.backgroundColor
        mockCollectionView.clipsToBounds = true
        
        containerView.addSubview(mockCollectionView)
        
        var mockCells = [IndexPath: UIView]()
        
        let visibleCellsMap = safariController.safariCollectionView.indexPathsForVisibleItems.reduce([IndexPath: UICollectionViewCell]()) {
            var mutableInitial = $0
            mutableInitial[$1] = safariController.safariCollectionView.cellForItem(at: $1)
            return mutableInitial
        }
        
        for (indexPath, cell) in visibleCellsMap {
            guard let cellClone = cell.snapshotView(afterScreenUpdates: true) else { continue }
            let transform = cell.layer.transform
            
            cell.layer.transform = CATransform3DIdentity
            
            cellClone.frame = safariController.safariCollectionView.convert(cell.frame, to: mockCollectionView)
            cellClone.layer.transform = transform
            cell.layer.transform = transform
            
            mockCollectionView.addSubview(cellClone)
            mockCells[indexPath] = cellClone
        }
        
        safariController.safariCollectionView.alpha = 0
        
        let cellAnimation = {(indexPath: IndexPath, cell: UIView) in
            guard indexPath.item != self.presentingIndexPath.item else { return }
            
            let size = cell.bounds.size
            var targetOrigin: CGPoint!
            
            if indexPath.item < self.presentingIndexPath.item {
                targetOrigin = CGPoint(x: 0, y: 0)
            } else if indexPath.item > self.presentingIndexPath.item{
                targetOrigin = CGPoint(x: 0, y: mockCollectionView.bounds.height)
            }
            
            cell.frame = CGRect(origin: targetOrigin, size: size)
            cell.layer.transform = self.transformForItem(targetOrigin, size, -.pi/2)
            cell.alpha = 0
        }
        
        UIView.animate(withDuration: animationDuration/2.0, animations: {
            for (indexPath, cell) in mockCells {
                cellAnimation(indexPath, cell)
            }
        }) {(finished) in
            mockCollectionView.clipsToBounds = false
        }
        
        UIView.animate(withDuration: animationDuration, animations: {
            let presentingCell = mockCells[self.presentingIndexPath]
            presentingCell?.layer.transform = CATransform3DIdentity
            presentingCell?.frame = containerView.convert(containerView.bounds, to: mockCollectionView)
            
            for (indexPath, cell) in mockCells.filter({ $0.key.item < self.presentingIndexPath.item }) {
                cellAnimation(indexPath, cell)
            }
        }) { (finished) in
            mockCollectionView.removeFromSuperview()
            transitionContext.completeTransition(finished)
        }
    }
    
    private func performReversed(using transitionContext: UIViewControllerContextTransitioning) {
        
    }
}
