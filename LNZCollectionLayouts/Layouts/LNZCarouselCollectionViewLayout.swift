//
//  CarouselCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@IBDesignable
open class LNZCarouselCollectionViewLayout: LNZInfiniteCollectionViewLayout {
    @IBInspectable public var isInfiniteScrollEnabled: Bool = true {
        didSet { invalidateLayout() }
    }
    
    @IBInspectable public var scalingOffset: CGFloat = 200
    @IBInspectable public var minimumScaleFactor: CGFloat = 0.85
    
    override var canInfiniteScroll: Bool { return super.canInfiniteScroll && isInfiniteScrollEnabled }
    
    open override func prepare() {
        super.prepare()
        
    }
    
    private func configureAttributes(for attributes: UICollectionViewLayoutAttributes) {
        guard let collection = collectionView else { return }
        let contentOffset = collection.contentOffset
        let size = collection.bounds.size
        
        let visibleRect = CGRect(x: contentOffset.x, y: contentOffset.y, width: size.width, height: size.height)
        let visibleCenterX = visibleRect.midX
        
        let distanceFromCenter = visibleCenterX - attributes.center.x
        let absDistanceFromCenter = min(abs(distanceFromCenter), scalingOffset)
        let scale = absDistanceFromCenter * (minimumScaleFactor - 1) / scalingOffset + 1
        
        //All the elemnts that are smaller are not infocus, therefore they should have a smaller zIndex so that if
        //they will overlap accordingly to the perspective in case of a negative value for the *minimumLineSpacing*
        //property.
        attributes.zIndex = Int(scale * 100000)
        attributes.transform3D = CATransform3DScale(CATransform3DIdentity, scale, scale, 1)
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        for attribute in attributes where attribute.representedElementCategory == .cell {
            configureAttributes(for: attribute)
        }
        return attributes
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attribute = super.layoutAttributesForItem(at: indexPath) else { return nil }
        configureAttributes(for: attribute)
        return attribute
    }
}
