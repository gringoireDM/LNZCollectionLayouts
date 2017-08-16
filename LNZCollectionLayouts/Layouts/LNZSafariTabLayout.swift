//
//  LNZSafariTabLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 15/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@IBDesignable
open class LNZSafariTabLayout: UICollectionViewLayout {
    
    ///The minimum spacing between consecutive items
    @IBInspectable public var minimumInteritemSpacing: CGFloat = 100
    
    ///The maximum spacing between consecutive items. If the maximum is less than the minimum, it will be 
    ///capped to the *minimumInteritemSpacing* value.
    @IBInspectable public var maximumInteritemSpacing: CGFloat = 100

    ///The space between the items and the top border of the collection view
    @IBInspectable public var sectionInsetTop: CGFloat = 8
    
    ///The space between the items and the bottom border of the collection view
    @IBInspectable public var sectionInsetBottom: CGFloat = 8
    
    ///The size for each element in the collection
    @IBInspectable public var itemSize: CGSize = CGSize(width: 100, height: 100)
    
    private var final3dTransform: CATransform3D {
        var transform = CATransform3DIdentity;
        transform.m34 = -1.0/600.0;
        
        let controllers = itemCount ?? 0
        let multiplier: CGFloat = (controllers <= 5 ? CGFloat(controllers) : 5.0) - 1.0
        
        let translateTransform = CATransform3DTranslate(transform, 0.0, 0.0, -50.0)
        let rotateTransform = CATransform3DRotate(transform, -CGFloat.pi/30.0 - CGFloat.pi/30.0 * multiplier/4.0, 1.0, 0.0, 0.0)
        return CATransform3DConcat(translateTransform, rotateTransform)
    }
    
    private var itemCount: Int?
    
    private var interitemSpacing: CGFloat {
        return minimumInteritemSpacing
    }
    
    open override var collectionViewContentSize: CGSize {
        guard let itemCount = itemCount,
            let collection = collectionView,
            let lastAttributeFrame = layoutAttributesForItem(at: IndexPath(item: itemCount-1, section: 0))?.frame else { return .zero }
        
        let h = lastAttributeFrame.maxY + sectionInsetBottom
        var size = collection.bounds.size
        size.height = h
        return size
    }
    
    open override func prepare() {
        super.prepare()
        
        guard let collection = collectionView, itemCount == nil else { return }
        
//        var transform = CATransform3DIdentity;
//        transform.m34 = -1.0/600.0;
//        
//        collection.layer.sublayerTransform = transform
        
        itemCount = collection.numberOfItems(inSection: 0)
    }
    
    open override func invalidateLayout() {
        super.invalidateLayout()
        itemCount = nil
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let indexes = visibleIndexes(in: rect)
        var attributesObjects = [UICollectionViewLayoutAttributes]()
        for index in indexes {
            guard let attributes = layoutAttributesForItem(at: index) else { continue }
            attributesObjects.append(attributes)
        }
        return attributesObjects
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let frame = frameForAttribute(at: indexPath)
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frame
        attributes.zIndex = indexPath.item
        attributes.transform3D = final3dTransform
        attributes.center.y -= (attributes.frame.origin.y - frame.origin.y)
        
        return attributes
    }
    
    private func visibleIndexes(in rect: CGRect) -> [IndexPath] {
        guard let itemCount = itemCount, itemCount > 0 else { return [] }
        let startingY = rect.origin.y
        let endingY = rect.maxY
        
        let startingItem = max(item(forYPosition: startingY), 0)
        let endingItem = min(item(forYPosition: endingY), itemCount-1)
        
        guard startingItem < endingItem else { return [] }
        
        var indexes = [IndexPath]()
        for i in startingItem...endingItem {
            indexes.append(IndexPath(item: i, section: 0))
        }
        return indexes
    }
    
    func item(forYPosition y: CGFloat) -> Int {
        return Int(floor((y - sectionInsetTop)/interitemSpacing))
    }
    
    private func frameForAttribute(at indexPath: IndexPath) -> CGRect {
        var attributeSize = itemSize
        if let collection = collectionView,
            let collectionDelegate = collection.delegate as? UICollectionViewDelegateFlowLayout,
            let itemSize = collectionDelegate.collectionView?(collection, layout: self, sizeForItemAt: indexPath) {
            attributeSize = itemSize
        }
        
        let y = sectionInsetTop + interitemSpacing * CGFloat(indexPath.item)
        let origin = CGPoint(x: 0, y: y)
        
        return CGRect(origin: origin, size: attributeSize)
    }
}
