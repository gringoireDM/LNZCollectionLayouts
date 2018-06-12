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

/**
 This transition will animate a specified collectionViewCell in an LNZSafariLayout in order to be perspectically
 corrected to be shown as presented ViewController. The animation includes an interpolation between the content
 of the collectionViewCell and the content of the presented ViewController.
 */
public class SafariAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    ///The indexPath of the cell that is going to be animated to be presented as modal view controller
    public let presentingIndexPath: IndexPath
    
    ///Set to true this property if you want to use this transition for dismissing controllers
    public var reversed: Bool = false
    
    ///The duration of the whole animation
    public var animationDuration: TimeInterval = 1
    
    public var shouldInterpolateToViewController: Bool = true
    
    private let transformForItem: (_ origin: CGPoint, _ size: CGSize, _ angle: CGFloat) -> CATransform3D
    
    /**
     Initialize a SafariAnimator object. The indexPAth to be presented and the transform function must be provided.
     - parameter presentingIndexPath: The indexPath of the cell that is going to be presented as new modal ViewController
     - parameter transformFunction: the function returning the 3d Transform matrix to manipulate the cells inclination
     in the collection
     - parameter origin: The origin point of the cell that is going to be transformed. This value is an absolute value
     fetched when the cell has as transform matrix the identity matrix.
     - parameter size: The size of the cell that is going to be transformed. This value is an absolute value fetched
     when the cell has as transform matrix the identity matrix.
     */
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
    
    ///This method generates a mock collectionView that will be overlapped to the real safari collection view.
    ///This mock will be the container for the whole animation.
    private func setupMockCollection(inContainer containerView: UIView, from safariController: SafariLayoutContaining) -> UIView {
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
        return mockCollectionView
    }
    
    ///This method returns the cells that are currently visible in the collectionView
    private func visibleCells(in safariController: SafariLayoutContaining) -> [IndexPath: UICollectionViewCell] {
        return safariController.safariCollectionView.indexPathsForVisibleItems.reduce([IndexPath: UICollectionViewCell]()) {
            var mutableInitial = $0
            mutableInitial[$1] = safariController.safariCollectionView.cellForItem(at: $1)
            return mutableInitial
        }
    }
    
    ///This method will perform the actual animation for the present modal
    private func performTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from),
            let to = transitionContext.viewController(forKey: .to) else { return }
        
        to.view.alpha = 0
        
        var safariController: SafariLayoutContaining! = from as? SafariLayoutContaining
        if safariController == nil {
            safariController = from.children.last as? SafariLayoutContaining
        }
        
        //This Transition must be performed from a SafariLayoutContaining viewController to a ViewController
        assert(safariController != nil, "This Transition must be performed from a SafariLayoutContaining viewController to a ViewController")
        
        let containerView = transitionContext.containerView
        containerView.backgroundColor = .clear
        
        let mockCollectionView = setupMockCollection(inContainer: containerView, from: safariController)
        
        var mockCells = [IndexPath: UIView]()
        
        let visibleCellsMap = visibleCells(in: safariController)
        
        //Here we must generate mocks for the visible cells in the collection view, to animate them.
        //We don't want to manipulate real cell frames outside of the layout's context, as it is the layout
        //job to do that
        for (indexPath, cell) in visibleCellsMap {
            guard let cellClone = cell.snapshotView(afterScreenUpdates: true) else { continue }
            let transform = cell.layer.transform
            
            //To fetch the real frame of the cell we need to temporary remove its transform because it might
            //alter the final bounds.
            cell.layer.transform = CATransform3DIdentity
            
            //not the cell.frame property reflects perfectly the real frame of the cell in the collectionView
            //before the transform is applied.
            cellClone.frame = safariController.safariCollectionView.convert(cell.frame, to: mockCollectionView)
            
            //Now we are ready to apply the transform to the mock cell, and re apply it to the original cell.
            cellClone.layer.transform = transform
            cell.layer.transform = transform
            
            //If the cell is the one we want to animate we need to add the view of the destination view controller to it
            //to allow the interpolation effect during the animation.
            if indexPath == presentingIndexPath {
                to.view.frame = cellClone.bounds
                to.view.frame.origin = .zero
                
                cellClone.addSubview(to.view)
                to.view.setNeedsLayout()
                to.view.layoutIfNeeded()
            }
            
            mockCollectionView.addSubview(cellClone)
            mockCells[indexPath] = cellClone
        }
        
        //The real collection now must be hidden. The mockCollectionView might be transparent at this point and if we
        //animate the mock cells we will most certainly see the real cells under... we don't want that.
        safariController.safariCollectionView.alpha = 0
        
        //Ready to animate
        
        DispatchQueue.main.asyncAfter(deadline: .now()+animationDuration/2.0) {
            //At this point the first part of the animation is finished. All the cells that are not the ones that should
            //be animated are now transparent, but we want the presenting cell to go full screen and the mock collection
            //view might be not full screen. We cannot add the presenting mock cell on top of the mockCollection as
            //subView of the container view because the perspective transform adjustment would create an unexpected view
            //hierarchy with as consequence a really bad user experience.
            mockCollectionView.clipsToBounds = false
        }
        
        UIView.animateKeyframes(withDuration: animationDuration, delay: 0, options: UIView.KeyframeAnimationOptions.beginFromCurrentState, animations: {
            let presentingCell = mockCells[self.presentingIndexPath]
            presentingCell?.layer.transform = CATransform3DIdentity
            presentingCell?.frame = containerView.convert(containerView.bounds, to: mockCollectionView)
            if self.shouldInterpolateToViewController {
                to.view.alpha = 1
            }

            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: self.animationDuration/2.0, animations: {
                for (indexPath, cell) in mockCells {
                    self.cellOpenTransform(indexPath: indexPath, cell: cell, inRect: mockCollectionView.bounds)
                }
            })
        }) { (finished) in
            to.view.alpha = 1
            
            containerView.addSubview(to.view)
            to.view.layer.mask = nil
            
            mockCollectionView.removeFromSuperview()
            transitionContext.completeTransition(finished)
            
            safariController.safariCollectionView.alpha = 1
        }
    }
    
    private func cellOpenTransform(indexPath: IndexPath, cell: UIView, inRect rect: CGRect) {
        guard indexPath.item != self.presentingIndexPath.item else { return }
        
        let size = cell.bounds.size
        var targetOrigin: CGPoint!
        
        if indexPath.item < self.presentingIndexPath.item {
            targetOrigin = CGPoint(x: 0, y: 0)
        } else if indexPath.item > self.presentingIndexPath.item{
            targetOrigin = CGPoint(x: 0, y: rect.height)
        }
        
        cell.frame = CGRect(origin: targetOrigin, size: size)
        cell.layer.transform = self.transformForItem(targetOrigin, size, -.pi/2)
        cell.alpha = 0

    }
    
    private func performReversed(using transitionContext: UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from),
            let to = transitionContext.viewController(forKey: .to),
            let fromClone = from.view.snapshotView(afterScreenUpdates: true) else { return }

        from.view.removeFromSuperview()

        var safariController: SafariLayoutContaining! = to as? SafariLayoutContaining
        if safariController == nil {
            safariController = to.children.last as? SafariLayoutContaining
        }
        
        //This Transition must be performed from  a ViewController to a SafariLayoutContaining viewController
        assert(safariController != nil, "This Transition must be performed from  a ViewController to a SafariLayoutContaining viewController")
        
        let containerView = transitionContext.containerView
        containerView.backgroundColor = .clear
        
        let mockCollectionView = setupMockCollection(inContainer: containerView, from: safariController)
        mockCollectionView.clipsToBounds = false
        
        var mockCells = [IndexPath: (cell: UIView, originalFrame: CGRect, originalTransform: CATransform3D)]()

        let visibleCellsMap = visibleCells(in: safariController)
        
        for (indexPath, cell) in visibleCellsMap {
            guard let cellClone = cell.snapshotView(afterScreenUpdates: true) else { continue }
            let originalTransform = cell.layer.transform
            
            cell.layer.transform = CATransform3DIdentity
            let originalFrame = safariController.safariCollectionView.convert(cell.frame, to: mockCollectionView)
            
            cell.layer.transform = originalTransform
            if indexPath == presentingIndexPath {
                cellClone.frame = containerView.convert(containerView.bounds, to: mockCollectionView)
                cellClone.layer.transform = CATransform3DIdentity
                fromClone.frame = from.view.bounds
                cellClone.addSubview(fromClone)
            } else {
                cellOpenTransform(indexPath: indexPath, cell: cellClone, inRect: mockCollectionView.bounds)
            }
            
            mockCollectionView.addSubview(cellClone)
            
            mockCells[indexPath] = (cellClone, originalFrame, originalTransform)
        }
        safariController.safariCollectionView.alpha = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration/2) {
            mockCollectionView.clipsToBounds = true
        }
        
        UIView.animateKeyframes(withDuration: animationDuration, delay: 0, options: UIView.KeyframeAnimationOptions.beginFromCurrentState, animations: {
            let presentingCell = mockCells[self.presentingIndexPath]
            presentingCell?.cell.layer.transform = presentingCell!.originalTransform
            presentingCell?.cell.frame = presentingCell!.originalFrame
            
            fromClone.alpha = 0

            UIView.addKeyframe(withRelativeStartTime: self.animationDuration/2.0, relativeDuration: self.animationDuration/2.0, animations: {
                var cells = mockCells
                cells[self.presentingIndexPath] = nil
                for (cell, originalFrame, originalTransform) in cells.values {
                    cell.frame = originalFrame
                    cell.layer.transform = originalTransform
                    cell.alpha = 1
                }
            })
        }) { (finished) in
            safariController.safariCollectionView.alpha = 1
            
            mockCollectionView.removeFromSuperview()
            if to.view.superview == nil {
                containerView.addSubview(to.view)
            }
            transitionContext.completeTransition(finished)
        }
    }
}
