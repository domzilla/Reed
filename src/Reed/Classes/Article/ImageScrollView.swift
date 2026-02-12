//
//  ImageScrollView.swift
//  Beauty
//
//  Created by Nguyen Cong Huy on 1/19/16.
//  Copyright © 2016 Nguyen Cong Huy. All rights reserved.
//

import UIKit

@objc
protocol ImageScrollViewDelegate: UIScrollViewDelegate {
    func imageScrollViewDidGestureSwipeUp(imageScrollView: ImageScrollView)
    func imageScrollViewDidGestureSwipeDown(imageScrollView: ImageScrollView)
}

class ImageScrollView: UIScrollView {
    @objc
    enum ScaleMode: Int {
        case aspectFill
        case aspectFit
        case widthFill
        case heightFill
    }

    @objc
    enum Offset: Int {
        case beginning
        case center
    }

    static let kZoomInFactorFromMinWhenDoubleTap: CGFloat = 2

    @objc open var imageContentMode: ScaleMode = .widthFill
    @objc open var initialOffset: Offset = .beginning

    @objc private(set) var zoomView: UIImageView?

    @objc open weak var imageScrollViewDelegate: ImageScrollViewDelegate?

    var imageSize: CGSize = .zero
    private var pointToCenterAfterResize: CGPoint = .zero
    private var scaleToRestoreAfterResize: CGFloat = 1.0
    var maxScaleFromMinScale: CGFloat = 3.0

    var zoomedFrame: CGRect {
        self.zoomView?.frame ?? CGRect.zero
    }

    override open var frame: CGRect {
        willSet {
            if
                self.frame.equalTo(newValue) == false, newValue.equalTo(CGRect.zero) == false,
                self.imageSize.equalTo(CGSize.zero) == false
            {
                self.prepareToResize()
            }
        }

        didSet {
            if
                self.frame.equalTo(oldValue) == false, self.frame.equalTo(CGRect.zero) == false,
                self.imageSize.equalTo(CGSize.zero) == false
            {
                self.recoverFromResizing()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.initialize()
    }

    private func initialize() {
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        bouncesZoom = true
        decelerationRate = UIScrollView.DecelerationRate.fast
        delegate = self
    }

    @objc
    func adjustFrameToCenter() {
        guard let unwrappedZoomView = zoomView else {
            return
        }

        var frameToCenter = unwrappedZoomView.frame

        // center horizontally
        if frameToCenter.size.width < bounds.width {
            frameToCenter.origin.x = (bounds.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        // center vertically
        if frameToCenter.size.height < bounds.height {
            frameToCenter.origin.y = (bounds.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        unwrappedZoomView.frame = frameToCenter
    }

    private func prepareToResize() {
        let boundsCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        self.pointToCenterAfterResize = convert(boundsCenter, to: self.zoomView)

        self.scaleToRestoreAfterResize = zoomScale

        // If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
        // allowable scale when the scale is restored.
        if self.scaleToRestoreAfterResize <= minimumZoomScale + CGFloat(Float.ulpOfOne) {
            self.scaleToRestoreAfterResize = 0
        }
    }

    private func recoverFromResizing() {
        self.setMaxMinZoomScalesForCurrentBounds()

        // restore zoom scale, first making sure it is within the allowable range.
        let maxZoomScale = max(minimumZoomScale, scaleToRestoreAfterResize)
        zoomScale = min(maximumZoomScale, maxZoomScale)

        // restore center point, first making sure it is within the allowable range.

        // convert our desired center point back to our own coordinate space
        let boundsCenter = convert(pointToCenterAfterResize, to: zoomView)

        // calculate the content offset that would yield that center point
        var offset = CGPoint(x: boundsCenter.x - bounds.size.width / 2.0, y: boundsCenter.y - bounds.size.height / 2.0)

        // restore offset, adjusted to be within the allowable range
        let maxOffset = self.maximumContentOffset()
        let minOffset = self.minimumContentOffset()

        var realMaxOffset = min(maxOffset.x, offset.x)
        offset.x = max(minOffset.x, realMaxOffset)

        realMaxOffset = min(maxOffset.y, offset.y)
        offset.y = max(minOffset.y, realMaxOffset)

        contentOffset = offset
    }

    private func maximumContentOffset() -> CGPoint {
        CGPoint(x: contentSize.width - bounds.width, y: contentSize.height - bounds.height)
    }

    private func minimumContentOffset() -> CGPoint {
        CGPoint.zero
    }

    // MARK: - Set up

    open func setup() {
        var topSupperView = superview

        while topSupperView?.superview != nil {
            topSupperView = topSupperView?.superview
        }

        // Make sure views have already layout with precise frame
        topSupperView?.layoutIfNeeded()
    }

    // MARK: - Display image

    @objc
    open func display(image: UIImage) {
        if let zoomView {
            zoomView.removeFromSuperview()
        }

        zoomView = UIImageView(image: image)
        zoomView!.isUserInteractionEnabled = true
        addSubview(zoomView!)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestureRecognizer(_:)))
        tapGesture.numberOfTapsRequired = 2
        zoomView!.addGestureRecognizer(tapGesture)

        let downSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeUpGestureRecognizer(_:)))
        downSwipeGesture.direction = .down
        zoomView!.addGestureRecognizer(downSwipeGesture)

        let upSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeDownGestureRecognizer(_:)))
        upSwipeGesture.direction = .up
        zoomView!.addGestureRecognizer(upSwipeGesture)

        self.configureImageForSize(image.size)
        self.adjustFrameToCenter()
    }

    private func configureImageForSize(_ size: CGSize) {
        self.imageSize = size
        contentSize = self.imageSize
        self.setMaxMinZoomScalesForCurrentBounds()
        zoomScale = minimumZoomScale

        switch self.initialOffset {
        case .beginning:
            contentOffset = CGPoint.zero
        case .center:
            let xOffset = contentSize.width < bounds.width ? 0 : (contentSize.width - bounds.width) / 2
            let yOffset = contentSize.height < bounds.height ? 0 : (contentSize.height - bounds.height) / 2

            switch self.imageContentMode {
            case .aspectFit:
                contentOffset = CGPoint.zero
            case .aspectFill:
                contentOffset = CGPoint(x: xOffset, y: yOffset)
            case .heightFill:
                contentOffset = CGPoint(x: xOffset, y: 0)
            case .widthFill:
                contentOffset = CGPoint(x: 0, y: yOffset)
            }
        }
    }

    private func setMaxMinZoomScalesForCurrentBounds() {
        // calculate min/max zoomscale
        let xScale = bounds.width / self.imageSize.width // the scale needed to perfectly fit the image width-wise
        let yScale = bounds.height / self.imageSize.height // the scale needed to perfectly fit the image height-wise

        var minScale: CGFloat = 1

        switch self.imageContentMode {
        case .aspectFill:
            minScale = max(xScale, yScale)
        case .aspectFit:
            minScale = min(xScale, yScale)
        case .widthFill:
            minScale = xScale
        case .heightFill:
            minScale = yScale
        }

        let maxScale = self.maxScaleFromMinScale * minScale

        // don't let minScale exceed maxScale. (If the image is smaller than the screen, we don't want to force it to be
        // zoomed.)
        if minScale > maxScale {
            minScale = maxScale
        }

        maximumZoomScale = maxScale
        minimumZoomScale =
            minScale // * 0.999 // the multiply factor to prevent user cannot scroll page while they use this control in
        // UIPageViewController
    }

    // MARK: - Gesture

    @objc
    func doubleTapGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        // zoom out if it bigger than middle scale point. Else, zoom in
        if zoomScale >= maximumZoomScale / 2.0 {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let center = gestureRecognizer.location(in: gestureRecognizer.view)
            let zoomRect = self.zoomRectForScale(
                ImageScrollView.kZoomInFactorFromMinWhenDoubleTap * minimumZoomScale,
                center: center
            )
            zoom(to: zoomRect, animated: true)
        }
    }

    @objc
    func swipeUpGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            self.imageScrollViewDelegate?.imageScrollViewDidGestureSwipeUp(imageScrollView: self)
        }
    }

    @objc
    func swipeDownGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            self.imageScrollViewDelegate?.imageScrollViewDidGestureSwipeDown(imageScrollView: self)
        }
    }

    private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero

        // the zoom rect is in the content view's coordinates.
        // at a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
        // as the zoom scale decreases, so more content is visible, the size of the rect grows.
        zoomRect.size.height = self.frame.size.height / scale
        zoomRect.size.width = self.frame.size.width / scale

        // choose an origin so as to get the right center.
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)

        return zoomRect
    }

    open func refresh() {
        if let image = zoomView?.image {
            self.display(image: image)
        }
    }

    open func resize() {
        self.configureImageForSize(self.imageSize)
    }
}

extension ImageScrollView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        self.imageScrollViewDelegate?.scrollViewWillEndDragging?(
            scrollView,
            withVelocity: velocity,
            targetContentOffset: targetContentOffset
        )
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.imageScrollViewDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewWillBeginDecelerating?(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        self.imageScrollViewDelegate?.scrollViewWillBeginZooming?(scrollView, with: view)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.imageScrollViewDelegate?.scrollViewDidEndZooming?(scrollView, with: view, atScale: scale)
    }

    func scrollViewShouldScrollToTop(_: UIScrollView) -> Bool {
        false
    }

    @available(iOS 11.0, *)
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        self.imageScrollViewDelegate?.scrollViewDidChangeAdjustedContentInset?(scrollView)
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        self.zoomView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.adjustFrameToCenter()
        self.imageScrollViewDelegate?.scrollViewDidZoom?(scrollView)
    }
}
