import UIKit

@objc public protocol UICollectionViewDelegateSafariLayout: UICollectionViewDelegate {
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, canDeleteItemAt indexPath: IndexPath) -> Bool
    
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, didDeleteItemAt indexPath: IndexPath)
}
