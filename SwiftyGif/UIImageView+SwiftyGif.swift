//
//  UIImageView+SwiftyGif.swift
//

import ImageIO
import UIKit
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


let _gifImageKey = malloc(4)
let _cacheKey = malloc(4)
let _currentImageKey = malloc(4)
let _displayOrderIndexKey = malloc(4)
let _syncFactorKey = malloc(4)
let _haveCacheKey = malloc(4)
let _loopCountKey = malloc(4)
let _displayingKey = malloc(4)
let _isPlayingKey = malloc(4)
let _animationManagerKey = malloc(4)
let _delegateKey = malloc(4)
let _gifScaleKey = malloc(4)

@objc public protocol SwiftyGifDelegate {
    @objc optional func gifDidStart()
    @objc optional func gifDidLoop()
    @objc optional func gifDidStop()
}

public extension UIImageView {
    
    // PRAGMA - Inits
    
    /**
     Convenience initializer. Creates a gif holder (defaulted to infinite loop).
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     */
    public convenience init(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager) {
        self.init()
        setGifImage(gifImage,manager: manager, loopCount: -1);
    }
    
    /**
     Convenience initializer. Creates a gif holder.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     - Parameter loopCount: The number of loops we want for this gif. -1 means infinite.
     */
    public convenience init(gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager, loopCount:Int) {
        self.init()
        setGifImage(gifImage,manager: manager, loopCount: loopCount);
    }
    
    /**
     Set a gif image and a manager to an existing UIImageView. The gif will default to infinite loop.
     WARNING : this overwrite any previous gif.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     */
    public func setGifImage(_ gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager) {
        setGifImage(gifImage, manager: manager, loopCount: -1)
    }
    
    /**
     Set a gif image and a manager to an existing UIImageView.
     WARNING : this overwrite any previous gif.
     - Parameter gifImage: The UIImage containing the gif backing data
     - Parameter manager: The manager to handle the gif display
     - Parameter loopCount: The number of loops we want for this gif. -1 means infinite.
     */
    public func setGifImage(_ gifImage:UIImage, manager:SwiftyGifManager = SwiftyGifManager.defaultManager, loopCount:Int, scale: CGFloat = 2.0) {
        
        self.gifScale = scale
        
        if gifImage.imageCount < 1 {
            self.image = UIImage(data: gifImage.imageData as Data, scale: scale)
            return
        }
        
        self.loopCount = loopCount
        self.gifImage = gifImage
        self.animationManager = manager
        self.syncFactor = 0
        self.displayOrderIndex = 0
        self.cache = NSCache()
        self.haveCache = false
        
        if let gif = self.gifImage {
            
            if let source = gif.imageSource {
                self.currentImage = UIImage(cgImage: CGImageSourceCreateImageAtIndex(source, 0, nil)!, scale: scale, orientation: .up)
                
                if !manager.containsImageView(self) {
                    manager.addImageView(self)
                    startDisplay()
                    startAnimatingGif()
                }
            }
        }
    }

    // PRAGMA - Logic
    
    /**
     Start displaying the gif for this UIImageView.
     */
    fileprivate func startDisplay() {
        self.displaying = true
        updateCache()
    }
    
    /**
     Stop displaying the gif for this UIImageView.
     */
    fileprivate func stopDisplay() {
        self.displaying = false
        updateCache()
        
    }
    
    /**
     Start displaying the gif for this UIImageView.
     */
    @objc public func startAnimatingGif() {
        self.isPlaying = true
    }
    
    /**
     Stop displaying the gif for this UIImageView.
     */
    @objc public func stopAnimatingGif() {
        self.isPlaying = false
    }
    
    /**
     Check if this imageView is currently playing a gif
     - Returns wether the gif is currently playing
     */
    @objc public func isAnimatingGif() -> Bool{
        return self.isPlaying
    }
    
    /**
     Show a specific frame based on a delta from current frame
     - Parameter delta: The delsta from current frame we want
     */
    @objc public func showFrameForIndexDelta(_ delta: Int) {
        
        var nextIndex = self.displayOrderIndex + delta
        
        while nextIndex >= self.gifImage!.framesCount(){
            nextIndex -= self.gifImage!.framesCount()
        }
        
        while nextIndex < 0 {
            nextIndex += self.gifImage!.framesCount()
        }
        
        showFrameAtIndex(nextIndex)
    }
    
    /**
     Show a specific frame
     - Parameter index: The index of frame to show
     */
    @objc public func showFrameAtIndex(_ index: Int) {
        self.displayOrderIndex = index
        updateFrame()
    }
    
    /**
     Update cache for the current imageView.
     */
    @objc public func updateCache() {
        if self.animationManager.hasCache(self) && !self.haveCache {
            prepareCache()
            self.haveCache = true
        }else if !self.animationManager.hasCache(self) && self.haveCache {
            self.cache.removeAllObjects()
            self.haveCache = false
        }
    }
    
    /**
     Update current image displayed. This method is called by the manager.
     */
    @objc public func updateCurrentImage() {
        
        if self.displaying{
            updateFrame()
            updateIndex()
            if loopCount == 0 || !isDisplayedInScreen(self)  || !self.isPlaying {
                stopDisplay()
            }
        }else{
            if(isDisplayedInScreen(self) && loopCount != 0 && self.isPlaying) {
                startDisplay()
            }
            if isDiscarded(self) {
                self.animationManager.deleteImageView(self)
            }
        }
    }
    
    /**
     Force update frame
     */
    fileprivate func updateFrame() {
        if !self.haveCache {
            self.currentImage = self.frameAtIndex(index: self.currentFrameIndex())
        }else{
            if let image = (cache.object(forKey: self.displayOrderIndex as AnyObject) as? UIImage) {
                self.currentImage = image
            }else{
                self.currentImage = self.frameAtIndex(index: self.currentFrameIndex())
            }//prevent case that cache is not ready
        }
    }
    
    /**
     Get current frame index
     */
    @objc public func currentFrameIndex() -> Int{
        return self.displayOrderIndex
    }

    /**
     Get frame at specific index
     */
    @objc public func frameAtIndex(index: Int) -> UIImage {
        return UIImage(cgImage: CGImageSourceCreateImageAtIndex(self.gifImage!.imageSource!,self.gifImage!.displayOrder![index],nil)!, scale: gifScale, orientation: .up)
    }
    
    /**
     Check if the imageView has been discarded and is not in the view hierarchy anymore.
     - Returns : A boolean for weather the imageView was discarded
     */
    @objc public func isDiscarded(_ imageView:UIView?) -> Bool{
        
        if(imageView == nil || imageView!.superview == nil) {
            return true
        }
        return false
    }
    
    /**
     Check if the imageView is displayed.
     - Returns : A boolean for weather the imageView is displayed
     */
    @objc public func isDisplayedInScreen(_ imageView:UIView?) ->Bool{
        if (self.isHidden) {
            return false
        }
        
        let screenRect = UIScreen.main.bounds
        let viewRect = imageView!.convert(self.frame,to:UIApplication.shared.keyWindow)
        
        let intersectionRect = viewRect.intersection(screenRect);
        if (intersectionRect.isEmpty || intersectionRect.isNull) {
            return false
        }
        return (self.window != nil)
    }
    
    /**
     Update loop count and sync factor.
     */
    fileprivate func updateIndex() {
        if let gif = self.gifImage {
            self.syncFactor = (self.syncFactor+1) % gif.displayRefreshFactor!
            if self.syncFactor == 0 {
                self.displayOrderIndex = (self.displayOrderIndex+1) % gif.imageCount!
                
                if displayOrderIndex == 0 {
                    if self.loopCount > 0 {
                        self.loopCount -= 1
                    }
                    self.delegate?.gifDidLoop?()
                }
            }
        }
    }
    
    /**
     Prepare the cache by adding every images of the gif to an NSCache object.
     */
    fileprivate func prepareCache() {
        self.cache.removeAllObjects()
        
        if let gif = self.gifImage {
            for i in 0 ..< gif.displayOrder!.count {
                let image = UIImage(cgImage: CGImageSourceCreateImageAtIndex(gif.imageSource!, gif.displayOrder![i],nil)!)
                self.cache.setObject(image,forKey:i as AnyObject)
            }
        }
    }
    
    // PRAGMA - get / set associated values
    
    @objc public var gifImage: UIImage? {
        get {
            return (objc_getAssociatedObject(self, _gifImageKey!) as! UIImage?)
        }
        set {
            objc_setAssociatedObject(self, _gifImageKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    @objc public var currentImage: UIImage {
        get {
            return (objc_getAssociatedObject(self, _currentImageKey!) as! UIImage)
        }
        set {
            objc_setAssociatedObject(self, _currentImageKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    fileprivate var displayOrderIndex: Int {
        get {
            return (objc_getAssociatedObject(self, _displayOrderIndexKey!) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _displayOrderIndexKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    fileprivate var syncFactor: Int {
        get {
            return (objc_getAssociatedObject(self, _syncFactorKey!) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _syncFactorKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    @objc public var loopCount: Int {
        get {
            return (objc_getAssociatedObject(self, _loopCountKey!) as! Int)
        }
        set {
            objc_setAssociatedObject(self, _loopCountKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    @objc public var gifScale: CGFloat {
        get {
            return (objc_getAssociatedObject(self, _gifScaleKey!) as! CGFloat)
        }
        set {
            objc_setAssociatedObject(self, _gifScaleKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    public var animationManager: SwiftyGifManager {
        get {
            return (objc_getAssociatedObject(self, _animationManagerKey!) as! SwiftyGifManager)
        }
        set {
            objc_setAssociatedObject(self, _animationManagerKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    @objc public var delegate: SwiftyGifDelegate? {
        get {
            return (objc_getAssociatedObject(self, _delegateKey!) as! SwiftyGifDelegate?)
        }
        set {
            objc_setAssociatedObject(self, _delegateKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    fileprivate var haveCache: Bool {
        get {
            return (objc_getAssociatedObject(self, _haveCacheKey!) as! Bool)
        }
        set {
            objc_setAssociatedObject(self, _haveCacheKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    @objc public var displaying: Bool {
        get {
            return (objc_getAssociatedObject(self, _displayingKey!) as! Bool)
        }
        set {
            objc_setAssociatedObject(self, _displayingKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    fileprivate var isPlaying: Bool {
        get {
            return (objc_getAssociatedObject(self, _isPlayingKey!) as! Bool)
        }
        set {
            
            objc_setAssociatedObject(self, _isPlayingKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
            
            if newValue {
                self.delegate?.gifDidStart?()
            } else {
                self.delegate?.gifDidStop?()
            }
        }
    }
    
    fileprivate var cache: NSCache<AnyObject, AnyObject> {
        get {
            return (objc_getAssociatedObject(self, _cacheKey!) as! NSCache)
        }
        set {
            objc_setAssociatedObject(self, _cacheKey!, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN);
        }
    }
}
