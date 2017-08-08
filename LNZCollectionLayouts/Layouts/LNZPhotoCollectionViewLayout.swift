//
//  LNZPhotoCollectionViewLayout.swift
//  LNZCollectionLayouts
//
//  Created by Giuseppe Lanza on 02/08/2017.
//  Copyright © 2017 Gilt. All rights reserved.
//

import UIKit

@objc public protocol LNZPhotoCollectionViewLayoutDelegate: UICollectionViewDelegate {
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, referenceHeightForHeaderInSection section: Int) -> CGFloat
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, referenceHeightForFooterInSection section: Int) -> CGFloat
    
    /**
     This method is called to determine if an item should be displayed as small square or as full size tile. 
     If this method is not implemented, then the layout will fallback in a random behavior where the occurrences 
     of full size tiles will be randomly determined with a probability of *fullSizePercentage*.
     */
    @objc optional func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, shouldShowFullSizeForItemAt indexPath: IndexPath) -> Bool
    
    @objc func collectionView(_ collectionView: UICollectionView, fullSizeForItemAt indexPath: IndexPath) -> CGSize
}

class LNZPhotoLayoutAttributes: UICollectionViewLayoutAttributes {
    ///The number of squares that this attribute occupies in the photoGrid horizontally
    var horizontalWeight: Int = 1
    
    ///The number of squares that this attribute occupies in the photoGrid vertically
    var verticalWeight: Int = 1
    
    ///The number of squares that this attribute occupies in the photoGrid in total
    var weight: Int {
        return horizontalWeight * verticalWeight
    }
    
    ///The column where the first square is. As first square it is intended the top left square.
    var firstSquareColumn: Int = 0
}

class LNZPhotoSection: Comparable, Equatable, Hashable {
    var origin: CGPoint
    private(set) var size: CGSize = .zero
    
    var frame: CGRect { return CGRect(origin: origin, size: size) }
    
    var invalidatedIndex: Int?
    var invalidatedOrigin: Bool = false
    
    init(withOrigin origin: CGPoint) {
        self.origin = origin
    }
    
    
    
    static func <(lhs: LNZPhotoSection, rhs: LNZPhotoSection) -> Bool {
        return lhs.origin.y < rhs.origin.y
    }
    
    static func ==(lhs: LNZPhotoSection, rhs: LNZPhotoSection) -> Bool {
        return lhs.origin == rhs.origin
    }
    
    var hashValue: Int {
        return "PHOTO_SECTION_\(origin)".hashValue
    }
}

@IBDesignable
open class LNZPhotoCollectionViewLayout: UICollectionViewLayout {
    //MARK: - Inspectable properties

    ///The spacing between consecutive items
    @IBInspectable public var interitemSpacing: CGFloat = 8
    
    ///The space between the items and the top border of the collection view
    @IBInspectable public var sectionInsetTop: CGFloat = 8
    
    ///The space between the items and the bottom border of the collection view
    @IBInspectable public var sectionInsetBottom: CGFloat = 8
    
    ///The space from the left border and the first item of the collection view.
    @IBInspectable public var sectionInsetLeft: CGFloat = 8
    
    ///The space from the right border and the last item of the collection view.
    @IBInspectable public var sectionInsetRight: CGFloat = 8
    
    ///The items are all squares, the width determines the edges size of each square
    @IBInspectable public var itemWidth: CGFloat = 120
    
    @IBInspectable public var fullSizePercentage: CGFloat = 0.8
    //MARK: - Cached properties
    
    private var squareSize: CGSize {
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    private var numberOfColumns: Int?
    
    private var sections = [LNZPhotoSection]()
    
    //MARK: - Layout implementation
    //MARK: Preparation

    override open class var layoutAttributesClass: AnyClass {
        return LNZPhotoLayoutAttributes.self
    }
    
    override open func prepare() {
        super.prepare()
        
        //If we have already computed all the attributes we don't want to do it again, unless something changed.
        //For this "something changed" we will trust our invalidation logic.
        guard let collection = collectionView,
            numberOfColumns == nil else { return }
        
        /*
         W      : collection view width;
         left   : section inset left
         right  : section inset right
         w      : item width
         n      : number of columns
         s      : interitem Spacing
         
         W = left + right + n * w + (n - 1) * s
         n * w + (n - 1) * s = W - left - right
         n * w + n * s = W - left - right + s
         n (w + s) = W - left - right + s
         n = (W - left - right + s)/(w + s)
         */
        numberOfColumns = Int(floor((collection.bounds.width - sectionInsetLeft - sectionInsetRight + interitemSpacing) / (itemWidth + interitemSpacing)))
        
        guard let sections = collection.dataSource?.numberOfSections?(in: collection) else { return }
        
        var lastSection: LNZPhotoSection?
        for i in 0..<sections {
            let lastSectionFrame = lastSection?.frame ?? .zero
            lastSection = layoutSection(section: i, withOrigin: CGPoint(x: lastSectionFrame.maxX, y: lastSectionFrame.maxY))
        }
    }
    
    
    private func layoutSection(section: Int, withOrigin origin: CGPoint) -> LNZPhotoSection? {
        guard let collection = collectionView else { return nil }
        let photoLayoutDelegate = collection.delegate as? LNZPhotoCollectionViewLayoutDelegate
        let headerHeight = photoLayoutDelegate?.collectionView?(collection, layout: self, referenceHeightForHeaderInSection: section) ?? 0
        
        let itemsCount = collection.dataSource?.collectionView(collection, numberOfItemsInSection: section) ?? 0

        var initialIndex = 0

        var sectionObject: LNZPhotoSection!
        if section < sections.count {
            sectionObject = sections[section]
            if sectionObject.invalidatedOrigin {
                sectionObject.origin = origin
            }
            
            if let invalidationFrom = sectionObject.invalidatedIndex {
                //We want to process the items starting from the one that was actually subject to changes.
                initialIndex = invalidationFrom
            } else {
                //the section was not invalidate, so we should not process the items
                initialIndex = itemsCount
            }
        } else {
            sectionObject = LNZPhotoSection(withOrigin: origin)
        }
        
        
        
        for i in initialIndex..<itemsCount {
            let indexPath = IndexPath(item: i, section: section)
            
            let itemRealSize = photoLayoutDelegate?.collectionView(collection, fullSizeForItemAt: indexPath) ?? squareSize
            
            
        }
        
        return sectionObject
    }
}
