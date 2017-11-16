//
//  CarouselCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

/**
 This collectionViewLayout is an LNZInfiniteCollectionViewLayout. It hinerits therefore all the trait of
 infinite collection view and snap to center layout. Infite scroll view and snap to center behaviors are
 disableabe. This layout will configure the items so that the items that are not currenlty on focus will
 appear zoomed out, while the only item at full itemSize will be the one in focus.
 */
@IBDesignable @objcMembers
open class LNZCarouselCollectionViewLayout: LNZInfiniteCollectionViewLayout {
    //MARK: - Inspectable properties
    ///This property wil allow to enable or disable the intinite scrolling behavior. The default value is true.
    @IBInspectable public var isInfiniteScrollEnabled: Bool = true {
        didSet { invalidateLayout() }
    }
    
    ///This property determines how fast each item not in focus will reach the minimum scale factor. The scale
    ///factor of each item depends from the item.center position related to the collection's center, and it 
    /// will be 1 if the element is in the center, and *minimumScaleFactor* if
    ///|item.center - collection.center| >= *scalingOffset*
    @IBInspectable public var scalingOffset: CGFloat = 200
    
    ///The minimum zoom scale factor for items not in focus. The factor used for each item will be proportional 
    ///to the distance of its center to the collection's center.
    @IBInspectable public var minimumScaleFactor: CGFloat = 0.85
    
    //MARK: - Utility properties
    
    override var canInfiniteScroll: Bool { return super.canInfiniteScroll && isInfiniteScrollEnabled }
    
    //MARK: - Layout implementation
    //MARK: Preparation

    open override func prepare() {
        super.prepare()
        //Nothing special here, but it is best practice to override this method anyway
    }
    
    //MARK: Layouting and attributes generators

    private func configureAttributes(for attributes: UICollectionViewLayoutAttributes) {
        guard let collection = collectionView else { return }
        let contentOffset = collection.contentOffset
        let size = collection.bounds.size
        
        let visibleRect = CGRect(x: contentOffset.x, y: contentOffset.y, width: size.width, height: size.height)
        let visibleCenterX = visibleRect.midX
        
        let distanceFromCenter = visibleCenterX - attributes.center.x
        let absDistanceFromCenter = min(abs(distanceFromCenter), scalingOffset)
        let scale = absDistanceFromCenter * (minimumScaleFactor - 1) / scalingOffset + 1
        
        //All the elements that are smaller are not in focus, therefore they should have a smaller zIndex so that if
        //they will overlap accordingly to the perspective in case of a negative value for the *minimumLineSpacing*
        //property.
        attributes.zIndex = Int(scale * 100000)
        attributes.transform3D = CATransform3DScale(CATransform3DIdentity, scale, scale, 1)
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        //Here we rely on super layout implementation, because we know that the parent layout is able to handle the 
        //situation of no infinite scrolling, in case of *canInfiniteScroll* to be false. Since we did override the 
        //*canInfiniteScroll* to consider also the *isInfiniteScrollEnabled* property, we are safe to have the required 
        //behavior from this layout.
        
        //All we have to do at this point is to apply the scale factor to the attributes we already have.
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
