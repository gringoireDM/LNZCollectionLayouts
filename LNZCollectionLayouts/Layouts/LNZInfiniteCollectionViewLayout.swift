//
//  LNZInfiniteCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 18/07/17.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@IBDesignable
open class LNZInfiniteCollectionViewLayout: LNZSnapToCenterCollectionViewLayout {
    
    override open var collectionViewContentSize: CGSize {
        let size = super.collectionViewContentSize
        guard canInfiniteScroll else { return size }
        return CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height)
    }
    
    internal var canInfiniteScroll: Bool {
        guard let cycleSize = cycleSize else { return false }
        return cycleSize.width > (collectionView?.bounds.size.width ?? 0) * 1.5
    }
    
    private var cycleStart: CGFloat = 0
    
    @IBInspectable public var snapToCenter: Bool = true {
        didSet { invalidateLayout() }
    }
    
    private var cycleSize: CGSize?
    
    open override func prepare() {
        super.prepare()
        
        guard let collection = collectionView else { return }
        collection.showsVerticalScrollIndicator = false
        collection.showsHorizontalScrollIndicator = false
        
        let sections = collection.dataSource?.numberOfSections?(in: collection) ?? 0
        guard sections < 2 else {
            fatalError("\(self) is a collection View Layout that just supports one section")
        }
        if itemCount == nil {
            itemCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: 0) ?? 0
        }
        
        guard cycleSize == nil else { return }
        
        let width = (itemSize.width + interitemSpacing) * CGFloat(itemCount ?? 0)
        let height = itemSize.height
        
        cycleSize = CGSize(width: width, height: height)
        
        guard canInfiniteScroll else {
            if !snapToCenter {
                sectionInsetLeft = minimumSectionInsetLeft
                sectionInsetRight = minimumSectionInsetRight
            }
            return
        }
        
        cycleStart = cycleSize!.width * 10000
        let currentInFocusXOffset = cycleStart + (itemSize.width + interitemSpacing) * CGFloat(currentInFocus) - sectionInsetLeft
        
        let proposedOffset = CGPoint(x: currentInFocusXOffset, y: -collection.contentInset.top)
        collection.contentOffset = proposedOffset
        
    }
    
    open override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        if context.invalidateEverything || context.invalidateDataSourceCounts || context.contentSizeAdjustment != .zero {
            cycleSize = nil
        }
        
        super.invalidateLayout(with: context)
    }
    
    private func framesForCycle(at index: Int) -> CGRect {
        guard let cycleSize = cycleSize else { return .zero }
        let x = cycleStart + cycleSize.width * CGFloat(index)
        return CGRect(x: x, y: 0, width: cycleSize.width, height: cycleSize.height)
    }
    
    override internal func items(in rect: CGRect) -> [(index:IndexPath, frame: CGRect)] {
        guard let cycleSize = cycleSize,
            let itemCount = itemCount, itemCount > 0 else { return [] }
        let iFirstCycle = Int(floor((rect.origin.x - cycleStart) / cycleSize.width))
        let iLastCycle = Int(floor((rect.maxX - cycleStart) / cycleSize.width))
        
        var indexPaths = [(index:IndexPath, frame: CGRect)]()
        
        var currentX = rect.origin.x
        for i in iFirstCycle...iLastCycle {
            let cycleFrame = framesForCycle(at: i)
            
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
        
        for item in items(in: rect) {
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
        
        let itemsOnScreen = items(in: currentRect)
        var frame: CGRect!
        if let item = itemsOnScreen.first(where: { $0.index == indexPath })  {
            frame = item.frame
        } else {
            let iLastCycle = Int(floor((currentRect.maxX - cycleStart) / cycleSize.width))
            let cycleFrame = framesForCycle(at: iLastCycle)
        
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
}
