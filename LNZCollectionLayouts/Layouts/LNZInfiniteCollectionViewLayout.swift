//
//  LNZInfiniteCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

/**
 This collectionViewLayout will behave as a *LNZSnapToCenterCollectionViewLayout* with the exception that it
 will behave as infinite scrolling. Elements will repeat themselves allowing the user to scroll horizontally
 in any direction. The items in the collection will not really be reordered or duplicated, but the attributes
 for the collection cells will be computed to have a different frame depending on the scroll position.
 The snap to center behavior can be disabled. If the number of elements or the size is too small to avoid the
 same object to appear twice between the visible items, then the layout will behave like a normal
 *LNZSnapToCenterCollectionViewLayout* or a normal UICollectionViewFlowLayout if the snap to center was disabled.
 */
@IBDesignable @objcMembers
open class LNZInfiniteCollectionViewLayout: LNZSnapToCenterCollectionViewLayout {
    //MARK: - Inspectable properties
    
    ///Enable and disable the snap to center behavior inherited by this layout supr class.
    @IBInspectable public var snapToCenter: Bool = true {
        didSet { invalidateLayout() }
    }

    //MARK: - Utility properties

    ///This property signals that the current set of items in the collection can actually be displayed as infinite layout.
    internal var canInfiniteScroll: Bool {
        //To allow infnite scroll the same item cannot be displayed twice in the same visible area, therefore, 
        //we want a content size bug enough to ensure that this will not happen.
        guard let cycleSize = cycleSize else { return false }
        return cycleSize.width > (collectionView?.bounds.size.width ?? 0) * 2.0
    }
    
    //MARK: - Cached properties

    ///This property determines the offset from where we wil start our collection to allow the user to scroll on both sides since the beginning.
    private var cycleStart: CGFloat = 0
    
    ///This property represent the size of each set of items in the data source.
    private var cycleSize: CGSize?
    
    //MARK: - Layout implementation
    //MARK: Preparation

    override open var collectionViewContentSize: CGSize {
        let size = super.collectionViewContentSize
        guard canInfiniteScroll, let cycleSize = cycleSize else { return size }
        
        //Even if the tiles will not be duplicated, the attributes for the cells will be computed so that the frames changes according
        //to the position of the collectin content offset. To allow the user to scroll back and forward "for ever" we need to set the
        //content size of the scrollView to the maximum content size. As exlained [here](https://www.objc.io/issues/3-views/scroll-view/)
        //the contentSize of a scrollView does not change the size of the view itself, but it change the limit of its bounds origin.
        //This means that the size of the scrollView is just a virtual value, and everytime that a pan gesture occurs all the subViews of
        //the scrollView are pinned in the referring system of the view's bounds. If the origin of the view's bounds changes, all the
        //subviews are shifted by the same amount. Therefore scrollView.contentOffset is nothing else than scrollView.bounds.origin.
        //There is no extra memory allocation involved in having a big contentSize. The memory allocation for an empty scrollView with
        //a size of 100x100 and a content size of 100000x100000 will be the same as a normal empty view with size 100x100.
        return CGSize(width: cycleSize.width * 20000, height: size.height)
    }
    
    open override func prepare() {
        super.prepare()
        
        guard let collection = collectionView else { return }
        //Since we want to give the illusion of infinite scrolling the scroll indicator must be disabled as they would not make sense in 
        //terms of ux.
        collection.showsVerticalScrollIndicator = false
        collection.showsHorizontalScrollIndicator = false
        
        let sections = collection.dataSource?.numberOfSections?(in: collection) ?? 0
        guard sections < 2 else {
            fatalError("\(self) is a collection View Layout that just supports one section")
        }
        //we want to reload the item count just if we don't have a cached value. The prepare method will be called at any bounds change 
        //(which means at any change of the scroll postion). We don't want to keep query the data source for values that for sure didn't 
        //change. The invalidate layout methods will take care of clearing this value, if there is a need to refresh the collection.
        if itemCount == nil {
            itemCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0) ?? 0
        }
        
        guard let itemCount = itemCount, cycleSize == nil else { return }
        
        let width = (itemSize.width + interitemSpacing) * CGFloat(itemCount)
        let height = itemSize.height
        
        cycleSize = CGSize(width: width, height: height)
        
        //If the collection cannot be displayed as infinite scrolling because the amount of items is not enough to accomplish this result,
        //the layout must fallback to its parent class behavior.
        guard canInfiniteScroll else {
            if !snapToCenter {
                sectionInsetLeft = minimumSectionInsetLeft
                sectionInsetRight = minimumSectionInsetRight
            }
            return
        }
        
        cycleStart = cycleSize!.width * 10000
        
        //At this point the super already reset the content offset of the collection view to have centered the current in focus.
        //we just have to shift all to go to cycleStart and remove the section inset
        let currentInFocusXOffset = cycleStart + collection.contentOffset.x - sectionInsetLeft
        
        let proposedOffset = CGPoint(x: currentInFocusXOffset, y: collection.contentOffset.y)
        collection.contentOffset = proposedOffset
    }
    
    //MARK: Layouting and attributes generators
    
    ///This method will determine the frame for a cycle at a certain index. Because of the infinite scrolling, we must divide our 
    ///scrollView in cycle. Each cycle is a "virtual" set of items from the collection's data source. The cycle at index 0 would 
    ///be the cycle that goes from cycleStart to cycleStart + cycleSize. the index can be negative where an index of -1 would 
    ///represent the cycle  that goes from cycleStart - cycleSize to cycleStart.
    private func frameForCycle(at index: Int) -> CGRect {
        guard let cycleSize = cycleSize else { return .zero }
        let x = cycleStart + cycleSize.width * CGFloat(index)
        return CGRect(x: x, y: 0, width: cycleSize.width, height: cycleSize.height)
    }
    
    override internal func items(in rect: CGRect) -> [(index:IndexPath, frame: CGRect)] {
        guard canInfiniteScroll else { return super.items(in: rect) }
        guard let cycleSize = cycleSize, cycleSize.width != 0,
            let itemCount = itemCount, itemCount > 0 else { return [] }
        
        //We need to determine which are the cycles currently displayed on the screen. So that we can determine the array of elements 
        //that are currently visible in the rect in parameter.
        let iFirstCycle = Int(floor((rect.origin.x - cycleStart) / cycleSize.width))
        let iLastCycle = Int(floor((rect.maxX - cycleStart) / cycleSize.width))
        
        var indexPaths = [(index:IndexPath, frame: CGRect)]()
        
        var currentX = rect.origin.x
        
        //For each cycle we determine now which are the currently visible items.
        for i in iFirstCycle...iLastCycle {
            let cycleFrame = frameForCycle(at: i)
            
            //TODO: Maybe super can be used
            let relativInitialX = currentX - cycleFrame.origin.x
            let relativeFinalX = min(cycleFrame.maxX, rect.maxX) - cycleFrame.origin.x
            
            let firstIndex = Int(floor(relativInitialX/(itemSize.width + interitemSpacing)))
            let lastIndex = min(Int(floor(relativeFinalX/(itemSize.width + interitemSpacing))), itemCount-1)
            
            for j in firstIndex...lastIndex {
                let x = cycleFrame.origin.x + (itemSize.width + interitemSpacing) * CGFloat(j)
                let y = sectionInsetTop + (headerHeight ?? 0)
                
                indexPaths.append((
                    IndexPath(item: j, section: 0),
                    CGRect(origin: CGPoint(x: x, y: y), size: itemSize)
                ))
            }
            
            currentX = min(cycleFrame.maxX, rect.maxX)
        }
        
        return indexPaths
    }
    
    open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard canInfiniteScroll else { return super.layoutAttributesForElements(in: rect) }
        var attributes = [UICollectionViewLayoutAttributes]()
        
        for item in items(in: collectionView?.bounds ?? rect) {
            let attribute = UICollectionViewLayoutAttributes(forCellWith: item.index)
            attribute.frame = item.frame
            
            attributes.append(attribute)
        }
        
        attributes.append(contentsOf: attributesForHeaderAndFooter())
        return attributes
    }
    
    open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard canInfiniteScroll,
            let cycleSize = cycleSize,
            let collection = collectionView else { return super.layoutAttributesForItem(at: indexPath) }
        
        let currentRect = CGRect(origin: collection.contentOffset, size: collection.bounds.size)
        
        //Since there are many possible frames for the same item we want to be sure that we will return the attribute for the *closest item*
        //in the visible area. The reason is that if this method is called as consequence of a **scrollToItem** mehod, and the user scrolled
        //previously the collection we don't want to show the collectionView to scroll a lot to go back to cycleStart + item origin. Ultimately 
        //the result will be the same, but in terms of UX the user will see a scroll animation more "enjoyable".
        
        let itemsOnScreen = items(in: currentRect)
        var frame: CGRect!
        
        //If the item is visible, we will return the frame for that item
        if let item = itemsOnScreen.first(where: { $0.index == indexPath })  {
            frame = item.frame
        } else {
            
            //If this is not the case, then we will compute which is the visible cycle and which is the closest element with the indexPath in 
            //parameter.
            let iLastCycle = Int(floor((currentRect.maxX - cycleStart) / cycleSize.width))
            let cycleFrame = frameForCycle(at: iLastCycle)
            
            let x = cycleFrame.origin.x + (itemSize.width + interitemSpacing) * CGFloat(indexPath.item)
            let y = sectionInsetTop
            
            frame = CGRect(origin: CGPoint(x: x, y: y), size: itemSize)
        }
        
        let attribute = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attribute.frame = frame
        
        return attribute
    }
    
    open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard snapToCenter else { return proposedContentOffset }
        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
    }

    //MARK: Invalidation

    open override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if context.invalidateEverything || context.invalidateDataSourceCounts || context.contentSizeAdjustment != .zero {
            cycleSize = nil
        }
        
        super.invalidateLayout(with: context)
    }
}
