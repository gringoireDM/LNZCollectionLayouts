//
//  LNZSnapToCenterCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

public protocol FocusChangeDelegate: class {
    func focusContainer(_ container: FocusedContaining, willChangeElement inFocus: Int, to newInFocus: Int)
    func focusContainer(_ container: FocusedContaining, didChangeElement inFocus: Int)
}

public protocol FocusedContaining: class {
    var currentInFocus: Int { get }
    
    weak var focusChangeDelegate: FocusChangeDelegate? { get set }
}

/**
 This collection view layout is an horizontal layout that will allow pagination for items smaller than collection.
 The element currently on the center is trackable with delegate pattern through the FocusChangeDelegate protocol.
 
 This collectionView layout handles just one section, of homogeneus elements, therefore just one itemSize is allowed.
 It handles header and footer where the height is specified by the UICollectionViewFlowLayout delegate methods
 collectionView(_: layout: referenceSizeForHeaderInSection) and collectionView(_: layout: referenceSizeForFooterInSection)
 */
@IBDesignable
open class LNZSnapToCenterCollectionViewLayout: UICollectionViewLayout, FocusedContaining {
    //MARK: Inspectable properties
    
    ///The spacing between consecutive items
    @IBInspectable public var interitemSpacing: CGFloat = 8
    
    ///The space between the items and the top border of the collection view
    @IBInspectable public var sectionInsetTop: CGFloat = 8
    
    ///The space between the items and the bottom border of the collection view
    @IBInspectable public var sectionInsetBottom: CGFloat = 8
    
    ///The minimum space from the left border and the first item of the collection view.
    ///The real spacing will be determined in runtime and it will be computed to enforce the first item to be centered.
    @IBInspectable public var minimumSectionInsetLeft: CGFloat = 8
    
    ///The minimum space from the right border and the last item of the collection view.
    ///The real spacing will be determined in runtime and it will be computed to enforce the last item to be centered.
    @IBInspectable public var minimumSectionInsetRight: CGFloat = 8
    
    ///The size for each element in the collection
    @IBInspectable public var itemSize: CGSize = CGSize(width: 100, height: 100)
    
    ///If this property is true, the left and right section spacing will be adapted to enforce the first and last element to be centered.
    ///This property is true by default.
    @IBInspectable public var centerFirstItem: Bool = true
    
    ///This property represents the actual section inset left calculated in order to have the first element of the collection centered.
    internal var sectionInsetLeft: CGFloat = 8
    
    ///This property represents the actual section inset right calculated in order to have the last element of the collection centered.
    internal var sectionInsetRight: CGFloat = 8

    
    ///As in focus element is to be intended the element currently in the center, 
    ///or the closest element to the center of the collection view.
    ///- seeAlso: FocusedContaining
    public internal(set) var currentInFocus: Int = 0 {
        willSet {
            guard newValue != currentInFocus else { return }
            focusChangeDelegate?.focusContainer(self, willChangeElement: currentInFocus, to: newValue)
        }
        didSet {
            guard currentInFocus != oldValue else { return }
            focusChangeDelegate?.focusContainer(self, didChangeElement: currentInFocus)
        }
    }
    
    /**
     This delegate will be called every time the element currently in focus changes.
     - seeAlso: FocusChangeDelegate
     */
    public weak var focusChangeDelegate: FocusChangeDelegate?
    
    //MARK: Cached properties
    internal var itemCount: Int?
    internal var headerHeight: CGFloat?
    internal var footerHeight: CGFloat?
    
    //MARK: - Layout implementation
    
    override open var collectionViewContentSize: CGSize {
        guard let collection = collectionView else { return .zero }
        
        //We can compute the size of the collectionView contentSize property by using the data source methods of the collectionView.dataSource
        //All we need is the number of items in the section.
        
        //We want to query for the itemCount just once. If there is a value of itemCount, the layout ws not invalidated, therefore we should not query 
        //the collectionView as we know that there are no changes.
        if itemCount == nil {
            let sections = collection.dataSource?.numberOfSections?(in: collection) ?? 0
            guard sections < 2 else {
                //This collection view layout can handle just one section.
                fatalError("\(self) is a collection View Layout that just supports one section")
            }

            
            itemCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0) ?? 0
        }
        
        //To compute the height we need to know if there are heders and footers.
        let delegate = collection.delegate as? UICollectionViewDelegateFlowLayout
        
        if headerHeight == nil {
            headerHeight = delegate?.collectionView?(collection, layout: self, referenceSizeForHeaderInSection: 0).height ?? 0
        }
        
        if footerHeight == nil {
            footerHeight = delegate?.collectionView?(collection, layout: self, referenceSizeForFooterInSection: 0).height ?? 0
        }
        //This method is always called right after the prepare method, so at this point sectionInsetLeft + sectionInsetRight is already determined
        let w = sectionInsetLeft + sectionInsetRight - interitemSpacing + (itemSize.width + interitemSpacing) * CGFloat(itemCount ?? 0)
        let h = (headerHeight ?? 0) + sectionInsetTop + sectionInsetBottom + itemSize.height + (footerHeight ?? 0)
        
        return CGSize(width: w, height: h)
    }

    open override func prepareForTransition(from oldLayout: UICollectionViewLayout) {
        //This method will be called when this layout is applied to an existing collectionView with different layout.
        //At this point the layout is still not changed for the collectionView, therefore we can query it to find out which would be the items that 
        //we must display. If the layout is a FocusedContaining, then we want to give focus to the element currently in focus in the old layout.
        //If this is not the case then we will assume that the focused item is the central one in the array of visible elements.
        if let centerLayout = oldLayout as? FocusedContaining {
            currentInFocus = centerLayout.currentInFocus
        } else if let collection = oldLayout.collectionView {
            let visibleIndexes = collection.indexPathsForVisibleItems
            guard !visibleIndexes.isEmpty else { return }
            currentInFocus = collection.indexPathsForVisibleItems[visibleIndexes.count/2].item
        }
        invalidateLayout()
    }
    
    open override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let delta = CGSize(width: newBounds.width - currentCollectionSize.width, height: newBounds.height - currentCollectionSize.height)
        
        let context = UICollectionViewLayoutInvalidationContext()
        context.contentSizeAdjustment = delta
        return context
    }
    
    open override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if context.invalidateEverything || context.invalidateDataSourceCounts || context.contentSizeAdjustment != .zero {
            itemCount = nil
            
            headerHeight = nil
            footerHeight = nil
            
            headerAttributes = nil
            footerAttributes = nil
            
            currentCollectionSize = collectionView?.bounds.size ?? .zero
        }
        super.invalidateLayout(with: context)
    }
    
    ///This property will track changes in the collection view size. The prepare method can be called multiple times even when the collection is scrolling
    ///and there might be operations that in the prepare method we want to perform exclusively if the collection sie is changed.
    internal var currentCollectionSize: CGSize = .zero
    
    open override func prepare() {
        super.prepare()
        
        guard let collection = collectionView else { return }
        collection.decelerationRate = UIScrollViewDecelerationRateFast
        
        sectionInsetLeft = centerFirstItem ? max(minimumSectionInsetLeft, collection.bounds.width/2.0 - itemSize.width/2.0) : minimumSectionInsetLeft
        sectionInsetRight = centerFirstItem ? max(minimumSectionInsetRight, sectionInsetLeft) : minimumSectionInsetRight
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
        guard let itemCount = itemCount else { return [] }
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
        guard let itemCount = itemCount, itemCount > 0 else { return nil }
        var result = [UICollectionViewLayoutAttributes]()
        for item in items(in: rect) {
            let indexPath = item.index
            let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.frame = item.frame
            result.append(attribute)
        }
        
        //move the headers and footers
        
        result.append(contentsOf: attributesForHeaderAndFooter())
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
        //This method is called everytime there is a change in the collection view size or in the collection view offset.
        //The bounds in this case is to be intended as "current visible frame". We want to update the current in focus 
        //just in case of scroll events, and not if the size changes, because in that case we want to preserve the element
        //in the center to be the same.
        if currentCollectionSize == newBounds.size {
            updateCurrentInFocus(in: newBounds)
        }
        return true
    }

}
