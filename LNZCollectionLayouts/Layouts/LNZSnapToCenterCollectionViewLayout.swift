//
//  LNZSnapToCenterCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@IBDesignable
open class LNZSnapToCenterCollectionViewLayout: UICollectionViewLayout {
    @IBInspectable public var interitemSpacing: CGFloat = 8
    
    @IBInspectable public var sectionInsetTop: CGFloat = 8
    @IBInspectable public var sectionInsetBottom: CGFloat = 8
    
    @IBInspectable public var minimumSectionInsetLeft: CGFloat = 8
    @IBInspectable public var minimumSectionInsetRight: CGFloat = 8
    
    internal var sectionInsetLeft: CGFloat = 8
    internal var sectionInsetRight: CGFloat = 8

    @IBInspectable public var itemSize: CGSize = CGSize(width: 100, height: 100)

    internal var itemCount: Int = 0
    public var currentInFocus: Int = 0
    
    internal var headerHeight: CGFloat?
    internal var footerHeight: CGFloat?
    
    override open var collectionViewContentSize: CGSize {
        guard let collection = collectionView else { return .zero }
        
        let sections = collection.dataSource?.numberOfSections?(in: collection) ?? 0
        guard sections < 2 else {
            fatalError("\(self) is a collection View Layout that just supports one section")
        }
        
        itemCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0) ?? 0
        
        let delegate = collection.delegate as? UICollectionViewDelegateFlowLayout
        
        headerHeight = delegate?.collectionView?(collection, layout: self, referenceSizeForHeaderInSection: 0).height
        footerHeight = delegate?.collectionView?(collection, layout: self, referenceSizeForFooterInSection: 0).height

        
        let w = sectionInsetLeft + sectionInsetRight - interitemSpacing + (itemSize.width + interitemSpacing) * CGFloat(itemCount)
        let h = (headerHeight ?? 0) + sectionInsetTop + sectionInsetBottom + itemSize.height + (footerHeight ?? 0)
        
        return CGSize(width: w, height: h)
    }

    open override func prepareForTransition(from oldLayout: UICollectionViewLayout) {
        if let centerLayout = oldLayout as? LNZSnapToCenterCollectionViewLayout {
            currentInFocus = centerLayout.currentInFocus
        } else if let collection = oldLayout.collectionView {
            let visibleIndexes = collection.indexPathsForVisibleItems
            guard !visibleIndexes.isEmpty else { return }
            currentInFocus = collection.indexPathsForVisibleItems[visibleIndexes.count/2].item
        }
        invalidateLayout()
    }
    
    open override func prepare() {
        super.prepare()
        
        guard let collection = collectionView else { return }
        collection.decelerationRate = UIScrollViewDecelerationRateFast
        
        sectionInsetLeft = max(minimumSectionInsetLeft, collection.bounds.width/2.0 - itemSize.width/2.0)
        sectionInsetRight = max(minimumSectionInsetRight, sectionInsetLeft)
    }

    internal var headerAttributes: UICollectionViewLayoutAttributes?
    internal var footerAttributes: UICollectionViewLayoutAttributes?
    open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collection = collectionView else { return nil }
        
        var frame: CGRect!
        
        let attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, with: indexPath)
        
        if elementKind == UICollectionElementKindSectionFooter,
            let height = footerHeight,
            height != 0 {
            
            frame = CGRect(x: collection.contentOffset.x, y: collectionViewContentSize.height - height, width: collection.bounds.width, height: height)
            footerAttributes = attributes
        } else if elementKind == UICollectionElementKindSectionHeader,
            let height = headerHeight,
            height != 0 {
            
            frame = CGRect(x: collection.contentOffset.x, y: 0, width: collection.bounds.width, height: height)
            headerAttributes = attributes
        }
        guard frame != nil else { return nil }
        
        attributes.frame = frame
        
        return attributes
    }
    
    internal func items(in rect: CGRect) -> [(index:IndexPath, frame: CGRect)] {
        let firstIndex = max(Int(floor((rect.origin.x - sectionInsetLeft) / (itemSize.width + interitemSpacing))), 0)
        let lastIndex = min(Int(floor((rect.maxX - sectionInsetLeft) / (itemSize.width + interitemSpacing))), itemCount - 1)
        
        var result = [(index:IndexPath, frame: CGRect)]()
        guard firstIndex <= lastIndex else { return result }
        
        for i in firstIndex...lastIndex {
            let indexPath = IndexPath(item: i, section: 0)
            let frame = frameForItem(at: indexPath)
            result.append((indexPath, frame))
        }
        return result
    }

    func frameForItem(at indexPath: IndexPath) -> CGRect {
        let x = sectionInsetLeft + (itemSize.width + interitemSpacing) * CGFloat(indexPath.item)
        let y = (headerHeight ?? 0) + sectionInsetTop
        
        return CGRect(origin: CGPoint(x: x, y: y), size: itemSize)
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard itemCount > 0 else { return nil }
        var result = [UICollectionViewLayoutAttributes]()
        for item in items(in: rect) {
            let indexPath = item.index
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = item.frame
            result.append(attribute)
        }
        
        //move the headers and footers
        
        result.append(contentsOf: attributesForHeaderAndFooter())
        updateCurrentInFocus(in: rect)
        return result
    }
    
    internal func updateCurrentInFocus(in rect: CGRect? = nil) {
        guard let collection = collectionView else { return }
        
        let collectionViewSize = collection.bounds.size
        let proposedRect = rect ?? CGRect(origin: CGPoint(x: collection.contentOffset.x, y: 0), size: collectionViewSize)

        guard let candidate = getAttributeForCenter(in: proposedRect) else { return }
        currentInFocus = candidate.index.item
    }
    
    internal func attributesForHeaderAndFooter() -> [UICollectionViewLayoutAttributes] {
        var result = [UICollectionViewLayoutAttributes]()
        if let header = headerAttributes ?? layoutAttributesForSupplementaryView(ofKind: UICollectionElementKindSectionHeader, at: IndexPath(item: 0, section: 0)) {
            header.frame.origin.x = collectionView?.contentOffset.x ?? 0
            result.append(header)
        }
        
        if let footer = footerAttributes ?? layoutAttributesForSupplementaryView(ofKind: UICollectionElementKindSectionFooter, at: IndexPath(item: 0, section: 0)) {
            footer.frame.origin.x = collectionView?.contentOffset.x ?? 0
            result.append(footer)
        }
        return result
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let frame = frameForItem(at: indexPath)
        
        let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attribute.frame = frame
        
        return attribute
    }
    
    internal func getAttributeForCenter(in rect: CGRect) -> (index: IndexPath, frame: CGRect)? {
        let layoutAttributes = items(in: rect)
        
        var candidateAttributes: (index: IndexPath, frame: CGRect)?
        let proposedContentOffsetCenterX = rect.origin.x + rect.size.width / 2
        
        for attributes in layoutAttributes {
            guard let candidate = candidateAttributes else {
                candidateAttributes = attributes
                continue
            }
            
            if fabs(attributes.frame.midX - proposedContentOffsetCenterX) < fabs(candidate.frame.midX - proposedContentOffsetCenterX) {
                candidateAttributes = attributes
            }
        }
        return candidateAttributes
    }
    
    open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collection = collectionView else { return proposedContentOffset }
        
        let collectionViewSize = collection.bounds.size
        let proposedRect = CGRect(origin: CGPoint(x: proposedContentOffset.x, y: 0), size: collectionViewSize)
        
        guard let candidate = getAttributeForCenter(in: proposedRect) else { return proposedContentOffset }
        
        var newOffsetX = candidate.frame.midX - collection.bounds.size.width / 2
        let offset = newOffsetX - collection.contentOffset.x
        
        if (velocity.x < 0 && offset > 0) || (velocity.x > 0 && offset < 0) {
            let pageWidth = itemSize.width + interitemSpacing
            newOffsetX += velocity.x > 0 ? pageWidth : -pageWidth
        }
        
        currentInFocus = candidate.index.item
        
        return CGPoint(x: newOffsetX, y: proposedContentOffset.y)
    }
    
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

}
