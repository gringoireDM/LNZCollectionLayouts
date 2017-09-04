//
//  LNZSafariTabLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 15/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

internal class LNZSafariLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {
    var interactivelyDeleting: Bool = false
    var interactivelyDeletingIndexPaths: [(indexPath: IndexPath, deltaOffset: CGPoint)]?
}

@IBDesignable
public class LNZSafariLayout: UICollectionViewLayout, UIGestureRecognizerDelegate {
    // MARK: Customization Properties
    ///The spacing between consecutive items
    @IBInspectable public var interitemSpacing: CGFloat = 100
    
    ///The space between the items and the top border of the collection view
    @IBInspectable public var sectionInsetTop: CGFloat = 8
    
    ///The space between the items and the bottom border of the collection view
    @IBInspectable public var sectionInsetBottom: CGFloat = 8
    
    ///The size for each element in the collection
    @IBInspectable public var itemSize: CGSize = CGSize(width: 100, height: 100)
    
    var itemCount: Int?
    
    var deleteGestureRecognizer: UIPanGestureRecognizer?
    
    private var final3dTransform: CATransform3D {
        var transform = CATransform3DIdentity;
        transform.m34 = -1.0/600.0;
        
        let controllers = itemCount ?? 0
        let multiplier: CGFloat = (controllers <= 5 ? CGFloat(controllers) : 5.0) - 1.0
        
        let translateTransform = CATransform3DTranslate(transform, 0.0, 0.0, -120.0)
        let rotateTransform = CATransform3DRotate(transform, -CGFloat.pi/10.0 - CGFloat.pi/10.0 * multiplier/4.0, 1.0, 0.0, 0.0)
        return CATransform3DConcat(translateTransform, rotateTransform)
    }
    
    private var offsetsForDeletingItems: [IndexPath: CGPoint]?
    
    // MARK: Method override
    
    public override var collectionViewContentSize: CGSize {
        guard let itemCount = itemCount,
            let collection = collectionView,
            let lastAttributeFrame = layoutAttributesForItem(at: IndexPath(item: itemCount-1, section: 0))?.frame else { return .zero }
        
        let h = lastAttributeFrame.maxY + sectionInsetBottom
        var size = collection.bounds.size
        size.height = h
        return size
        
    }
    
    override public class var invalidationContextClass: AnyClass {
        return LNZSafariLayoutInvalidationContext.self
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
    
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributesObjects = visibleIndexes(in: rect).flatMap(layoutAttributesForItem)
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
        attributes.transform3D = final3dTransform
        
        return attributes
    }
    
    public override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        var frame = frameForAttribute(at: itemIndexPath)
        
        if currentDeletingIndexPath == itemIndexPath {
            //If the delete is a consequence of an interactive delete
            frame.origin.x = -frame.maxX
        }
        
        let attributes = UICollectionViewLayoutAttributes(forCellWith: itemIndexPath)
        attributes.frame = frame
        attributes.zIndex = itemIndexPath.item
        attributes.transform3D = final3dTransform
        attributes.alpha = 0
        
        return attributes
    }
    
    // MARK: Invalidation Logic
    
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
    
    // MARK: Helper Methods
    
    private func frameForAttribute(at indexPath: IndexPath) -> CGRect {
        var attributeSize = itemSize
        if let collection = collectionView,
            let collectionDelegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
            let itemSize = collectionDelegate.collectionView?(collection, layout: self, sizeForItemAt: indexPath) {
            attributeSize = itemSize
        }
        
        let y = sectionInsetTop + interitemSpacing * CGFloat(indexPath.item)
        let origin = CGPoint(x: 0, y: y)
        
        return CGRect(origin: origin, size: attributeSize)
    }
    
    func item(forYPosition y: CGFloat) -> Int? {
        guard let itemCount = itemCount,
            itemCount > 0,
            interitemSpacing != 0 else { return nil }
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
            startingItem < endingItem else {
                return []
        }
        let indexes = Array(startingItem...endingItem).map {
            IndexPath(item: $0, section: 0)
        }
        return indexes
    }
    
    // MARK: Gesture Recognizer
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let collection = collectionView,
            let delegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
            let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
        }
        
        let touch = panGesture.location(in: collection)
        let velocity = panGesture.velocity(in: collection)
        
        guard fabs(velocity.x) > fabs(velocity.y),
            let item = self.item(forYPosition: touch.y) else { return false }
        
        return delegate.collectionView?(collection, layout: self, canDeleteItemAt: IndexPath(item: item, section: 0)) ?? false
    }
    
    private var currentDeletingIndexPath: IndexPath?
    @objc func didPanToDelete(gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .possible: break //Good for you gesture... nothign to do here
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
            
            
            
            if let collection = collectionView,
                let delegate = collection.delegate as? UICollectionViewDelegateSafariLayout,
                let currentDeletingIndexPath = currentDeletingIndexPath {
                
                let velocity = gestureRecognizer.velocity(in: collectionView)
                let cumulativeOffset = offsetsForDeletingItems?[currentDeletingIndexPath] ?? .zero
                
                let frame = frameForAttribute(at: currentDeletingIndexPath)
                
                if cumulativeOffset.x < -frame.width/2.0 || velocity.x < -500 {
                    delegate.collectionView?(collection, layout: self, didDeleteItemAt: currentDeletingIndexPath)
                } else {
                    fallthrough
                }
                
                self.currentDeletingIndexPath = nil
            } else {
                fallthrough
            }
        case .cancelled, .failed:
            currentDeletingIndexPath = nil
            
            let invalidationContext = LNZSafariLayoutInvalidationContext()
            invalidationContext.interactivelyDeleting = false
            invalidationContext.interactivelyDeletingIndexPaths = nil
            
            invalidateLayout(with: invalidationContext)
        }
    }
}
