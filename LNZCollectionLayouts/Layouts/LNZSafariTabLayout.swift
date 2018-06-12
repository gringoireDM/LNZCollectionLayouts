//
//  LNZSafariTabLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 15/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@objcMembers
internal class LNZSafariLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {
    var interactivelyDeleting: Bool = false
    var interactivelyDeletingIndexPaths: [(indexPath: IndexPath, deltaOffset: CGPoint)]?
}

@IBDesignable @objcMembers
public class LNZSafariLayout: UICollectionViewLayout, UIGestureRecognizerDelegate {
    // MARK: Customization Properties
    ///The spacing between consecutive items
    @IBInspectable public var maxInteritemSpacing: CGFloat = 200
    
    ///The space between the items and the top border of the collection view
    @IBInspectable public var sectionInsetTop: CGFloat = 20
    
    ///The space between the items and the bottom border of the collection view
    @IBInspectable public var sectionInsetBottom: CGFloat = 20
    
    ///The size for each element in the collection
    @IBInspectable public var itemSize: CGSize = CGSize(width: 100, height: 100)
    
    ///This value allows to control the distance from the screen of the top part of each item.
    ///0 means on the screen, positive values indicates the items to zoom in perspectically like they
    ///were going out from the screen, and negative values indicates the items top be pushed back on
    ///the screen (the effect will be a perspective zoom out
    @IBInspectable public var zOffset: CGFloat = -60
    
    // MARK: - Private vars -
    private var itemCount: Int?
    
    // MARK: Delete related vars
    private var deleteGestureRecognizer: UIPanGestureRecognizer?
    private var offsetsForDeletingItems: [IndexPath: CGPoint]?
    private var deletingIndexPaths = [IndexPath]()
    private var currentDeletingIndexPath: IndexPath?

    // MARK: Perspective related
    private let perspectiveCorrection: CGFloat = -1.0/1000.0
    
    private var rotationAngleAt0: CGFloat {
        let controllers = itemCount ?? 0
        let multiplier: CGFloat = min(CGFloat(controllers), 5.0) - 1.0
        
        return -CGFloat.pi/10.0 - CGFloat.pi/10.0 * multiplier/4.0
    }
    
    private let maxRotationAngle = -CGFloat.pi/2.5
    
    // MARK: - Perspective related methods
    private func computeAngle(forItemOrigin attributesOrigin: CGPoint) -> CGFloat {
        var rotationAngle = rotationAngleAt0
        
        if let collectionBounds = collectionView?.bounds {
            
            var yOnScreen = attributesOrigin.y - collectionBounds.origin.y - sectionInsetTop
            if yOnScreen < 0 {
                yOnScreen = 0
            } else if yOnScreen > collectionBounds.height {
                yOnScreen = collectionBounds.height
            }
            
            let maxRotationVariance = maxRotationAngle - rotationAngleAt0
            rotationAngle += (maxRotationVariance/collectionBounds.height) * yOnScreen
        }

        return rotationAngle
    }
    
    private func final3dTransform(forItemOrigin attributesOrigin: CGPoint, andSize attributesSize: CGSize, enforcingAngle angle: CGFloat? = nil) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform.m34 = perspectiveCorrection
        
        let rotationAngle = angle ?? computeAngle(forItemOrigin: attributesOrigin)
        
        //The anchor point is in the center of the view. We want to translate the view back and correct its
        //origin point so that the effect will not be views going out from the screen. To do so we need some
        //trigonometry. We will use r as radius to determine how much we must translate back on the z axis and
        //on the y axis to ensure that all the view will be contained *below* the plane of the screen.
        //r is the distance between the prolongation of the view after rotation on the screen, and its center.
        let r = attributesSize.height/2.0 + abs(zOffset/sin(rotationAngle))
        
        //how much we must push the view below the plane of the screen is exactly r * sin(alpha) with alpha to be
        //the desired rotation in radiants.
        let zTranslation = r * sin(rotationAngle)
        
        //For the y we want that the projection on the screen of the top part of the view is exactly the same as
        //the view before it was rotated. The rotation will obviously describe an arc therefore the projection
        //on the plane of the screen will be different. The delta will be exactly r - r * cos(alpha)
        let yTranslation: CGFloat = r * (1 - cos(rotationAngle))
        
        //We can translate on y and z
        let zTranslateTransform = CATransform3DTranslate(transform, 0.0, -yTranslation, zTranslation)
        
        //and now we are ready to rotate around the x axis.
        let rotateTransform = CATransform3DRotate(zTranslateTransform, rotationAngle, 1.0, 0.0, 0.0)
        
        //the order is important because the translation matrix is relative to the view's plane, and not the
        //screen's plane. This means that if we were rotating first, we were not getting the wanted result.
        return rotateTransform
    }
    
    // MARK: - Methods override -
    // MARK: Preparation
    
    public override var collectionViewContentSize: CGSize {
        guard let itemCount = itemCount,
            let collection = collectionView else { return .zero }
        
        let lastIndexPath = IndexPath(item: itemCount-1, section: 0)
        let frame = frameForAttribute(at: lastIndexPath)
        
        let lastAttribute = UICollectionViewLayoutAttributes(forCellWith: lastIndexPath)
        lastAttribute.frame = frame
        
        //We need here to override the bounds so that the content size is not dependant on
        //the current state of the collectionView
        
        lastAttribute.transform3D = final3dTransform(forItemOrigin: lastAttribute.frame.origin, andSize: lastAttribute.bounds.size, enforcingAngle: rotationAngleAt0)
        
        let h = lastAttribute.frame.maxY + sectionInsetBottom
        var size = collection.bounds.size
        size.height = h
        
        return size
    }
    
    public override func prepare() {
        super.prepare()
        
        guard let collection = collectionView,
            itemCount == nil else { return }
        
        if deleteGestureRecognizer == nil || collection.gestureRecognizers?.contains(deleteGestureRecognizer!) ?? false == false {
            deleteGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanToDelete(gestureRecognizer:)))
            deleteGestureRecognizer?.delegate = self
            deleteGestureRecognizer?.delaysTouchesBegan = true
            collection.addGestureRecognizer(deleteGestureRecognizer!)
        }
        
        let sections = collection.dataSource?.numberOfSections?(in: collection) ?? 0
        guard sections <= 1 else {
            fatalError("This layout support only one section")
        }
        guard sections == 1 else { return }
        itemCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0)
        
    }
    
    // MARK: Updates logic
    
    public override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        for item in updateItems {
            switch item.updateAction {
            case .delete:
                guard let indexPath = item.indexPathBeforeUpdate else { return }
                deletingIndexPaths.append(indexPath)
            default:
                break
            }
        }
    }
    
    public override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        
        deletingIndexPaths.removeAll()
    }
    
    public override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        
        guard deletingIndexPaths.contains(itemIndexPath) == true else { return nil }
        
        var frame = frameForAttribute(at: itemIndexPath)
        
        if currentDeletingIndexPath == itemIndexPath {
            //If the delete is a consequence of an interactive delete
            frame.origin.x = -frame.maxX
        }
        
        let attributes = UICollectionViewLayoutAttributes(forCellWith: itemIndexPath)
        attributes.frame = frame
        attributes.zIndex = itemIndexPath.item
        attributes.transform3D = final3dTransform(forItemOrigin: attributes.frame.origin, andSize: attributes.bounds.size)
        attributes.alpha = 0
        
        return attributes
    }

    // MARK : Layouting Logic
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributesObjects = visibleIndexes(in: rect).compactMap(layoutAttributesForItem)
        return attributesObjects
    }
    
    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let frame = frameForAttribute(at: indexPath)
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frame
        
        if let offset = offsetsForDeletingItems?[indexPath] {
            attributes.frame.origin.x += offset.x
            attributes.frame.origin.y += offset.y
        }
        
        attributes.zIndex = indexPath.item
        attributes.transform3D = final3dTransform(forItemOrigin: attributes.frame.origin, andSize: attributes.bounds.size)
        
        return attributes
    }
    
    // MARK: Invalidation Logic
    
    override public class var invalidationContextClass: AnyClass {
        return LNZSafariLayoutInvalidationContext.self
    }
    
    public override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayout(with: context)
        
        if context.invalidateEverything || context.invalidateDataSourceCounts {
            itemCount = nil
        }
        
        guard let safariContext = context as? LNZSafariLayoutInvalidationContext else { return }
        if safariContext.interactivelyDeleting,
            let deletingIndexPaths = safariContext.interactivelyDeletingIndexPaths {
            if offsetsForDeletingItems == nil {
                offsetsForDeletingItems = [IndexPath: CGPoint]()
            }
            
            deletingIndexPaths.forEach { (indexPath: IndexPath, deltaOffset: CGPoint) in
                let initial: CGPoint = offsetsForDeletingItems?[indexPath] ?? .zero
                let offset = CGPoint(x: deltaOffset.x + initial.x, y: deltaOffset.y + initial.y)
                
                offsetsForDeletingItems?[indexPath] = offset
            }
        } else {
            offsetsForDeletingItems = nil
        }
    }
    
    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    // MARK: - Helper Methods
    
    private func interitemSpacing() -> CGFloat {
        var interitemSpacing = maxInteritemSpacing
        
        if let collection = collectionView,
            let itemCount = itemCount,
            itemCount > 0 {
            interitemSpacing = (collection.bounds.height - sectionInsetTop - sectionInsetBottom)/CGFloat(min(itemCount, 5))
        }
        
        return interitemSpacing
    }
    
    
    private func frameForAttribute(at indexPath: IndexPath) -> CGRect {
        var attributeSize = itemSize
        if let collection = collectionView,
            let collectionDelegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
            let itemSize = collectionDelegate.collectionView?(collection, layout: self, sizeForItemAt: indexPath) {
            attributeSize = itemSize
        }
        
        let interitemSpacing = self.interitemSpacing()
        let y = sectionInsetTop + interitemSpacing * CGFloat(indexPath.item)
        let origin = CGPoint(x: 0, y: y)
        
        return CGRect(origin: origin, size: attributeSize)
    }
    
    func item(forYPosition y: CGFloat) -> Int? {
        guard let itemCount = itemCount,
            itemCount > 0,
            maxInteritemSpacing != 0 else { return nil }
        
        
        let interitemSpacing = self.interitemSpacing()
        
        var i = Int(floor((y - sectionInsetTop)/interitemSpacing))
        if i < 0 { i = 0 }
        if i > itemCount - 1 { i = itemCount - 1 }
        return i
    }
    
    private func visibleIndexes(in rect: CGRect) -> [IndexPath] {
        guard let itemCount = itemCount, itemCount > 0 else { return [] }
        let startingY = rect.origin.y
        let endingY = rect.maxY
        
        guard let startingItem = item(forYPosition: startingY),
            let endingItem = item(forYPosition: endingY),
            startingItem <= endingItem else {
                return []
        }
        
        let indexes = Array(startingItem...endingItem).map {
            IndexPath(item: $0, section: 0)
        }
        return indexes
    }
    
    // MARK: - Gesture Recognizer
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let collection = collectionView,
            let delegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
            let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
        }
        
        let touch = panGesture.location(in: collection)
        let velocity = panGesture.velocity(in: collection)
        
        guard abs(velocity.x) > abs(velocity.y),
            let item = self.item(forYPosition: touch.y) else { return false }
        
        return delegate.collectionView?(collection, layout: self, canDeleteItemAt: IndexPath(item: item, section: 0)) ?? false
    }
    
    func didPanToDelete(gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .possible: break //Good for you, gesture... nothing to do here
        case .began:
            let touch = gestureRecognizer.location(in: collectionView)
            guard let item = self.item(forYPosition: touch.y) else { return }
            
            currentDeletingIndexPath = IndexPath(item: item, section: 0)
        case .changed:
            guard let currentDeletingIndexPath = currentDeletingIndexPath else { return }
            
            var delta = gestureRecognizer.translation(in: collectionView)
            delta.y = 0
            
            let invalidationContext = LNZSafariLayoutInvalidationContext()
            invalidationContext.interactivelyDeleting = true
            invalidationContext.interactivelyDeletingIndexPaths = [(currentDeletingIndexPath, delta)]
            
            invalidateLayout(with: invalidationContext)
            gestureRecognizer.setTranslation(.zero, in: collectionView)
        case .ended:
            guard let collection = collectionView,
                let delegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
                let currentDeletingIndexPath = currentDeletingIndexPath else { fallthrough }
            
            let velocity = gestureRecognizer.velocity(in: collectionView)
            let cumulativeOffset = offsetsForDeletingItems?[currentDeletingIndexPath] ?? .zero
            
            let frame = frameForAttribute(at: currentDeletingIndexPath)
            
            guard cumulativeOffset.x < -frame.width/2.0 || velocity.x < -1000 else { fallthrough }
            delegate.collectionView?(collection, layout: self, didDeleteItemAt: currentDeletingIndexPath)
            self.currentDeletingIndexPath = nil
        case .cancelled, .failed:
            currentDeletingIndexPath = nil
            
            let invalidationContext = LNZSafariLayoutInvalidationContext()
            invalidationContext.interactivelyDeleting = false
            invalidationContext.interactivelyDeletingIndexPaths = nil
            
            invalidateLayout(with: invalidationContext)
        }
    }
}

// MARK: - Animator -
public extension LNZSafariLayout {
    public func animator(forItem indexPath: IndexPath) -> SafariAnimator {
        let animator = SafariAnimator(presentingIndexPath: indexPath) {[weak self] (origin, size, angle) -> CATransform3D in
            guard let `self` = self else { return CATransform3DIdentity }
            return self.final3dTransform(forItemOrigin: origin, andSize: size, enforcingAngle: angle)
        }
        return animator
    }
}
