//
//  SnapBehaviour.swift
//  ScrollCoordinator
//

import Foundation

//Enum which gives the direction in which the view would snap(disappear)
public enum SnapDirection {
    case TOP
    case BOTTOM
}

//Enum specifying the states of the view possible during the snapping behaviour
enum SnapState {
    case EXPANDED
    case EXPANDING
    case CONTRACTED
    case CONTRACTING
}

//Informs the delegate when we update ScrollView insets in case it wants to anything in such a case
public protocol SnapDelegate: class {
    func snapDidUpdateView()
}

//Behaviour which allows a view to gradually disappear/appear with the ScrollMovements
public class SnapBehaviour: Behaviour {
    public var needsPostGestureInfo: Bool = false
    
    //Defines the direction in which the view wants to snap
    let snapDirection: SnapDirection
    
    //The view which needs the SnapBehaviour
    let view: UIView
    
    //Properties which control the SnapBehaviour
    var snapDistance: CGFloat = 0
    var startingVerticalPosition: CGFloat = 0
    var currentSnapState = SnapState.EXPANDED
    
    //Defines whether the we need the "fade away" effect during snapping
    let isFadeEnabled: Bool
    
    //Needed in case we have pull to refresh
    let refreshControl: UIRefreshControl?
    
    //For handling changing StatusBarHeight
    var oldStatusBarHeight: CGFloat?
    var newStatusBarHeight: CGFloat?
    
    //For delegating snap updates
    weak var snapDelegate: SnapDelegate?
    
    public init(snapDirection: SnapDirection, view: UIView, isFadeEnabled: Bool = false, refreshControl: UIRefreshControl?, snapDelegate: SnapDelegate?) {
        self.snapDirection = snapDirection
        self.view = view
        self.isFadeEnabled = isFadeEnabled
        self.refreshControl = refreshControl
        self.snapDelegate = snapDelegate
        oldStatusBarHeight = getStatusBarHeight()
        NotificationCenter.default.addObserver(self, selector: #selector(SnapBehaviour.statusBarHeightDidChange), name: NSNotification.Name.UIApplicationDidChangeStatusBarFrame, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func statusBarHeightDidChange() {
        newStatusBarHeight = getStatusBarHeight()
        if let newHeight = newStatusBarHeight, let oldHeight = oldStatusBarHeight, snapDirection == .BOTTOM {
            startingVerticalPosition = startingVerticalPosition + oldHeight - newHeight
        }
        
        oldStatusBarHeight = newStatusBarHeight
        
        if currentSnapState != .EXPANDED {
            snapExpand()
            applyAlpha()
        }
    }
    
    func getStatusBarHeight() -> CGFloat {
        if UIApplication.shared.isStatusBarHidden {
            return 0
        }
        
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        let statusBarHeight = min(statusBarSize.width, statusBarSize.height)
        return statusBarHeight
    }
    
    
    //We expand the views when the vc is about to appear
    public func vcWillAppear() {
        self.snapDistance = view.bounds.height
        self.startingVerticalPosition = view.frame.origin.y
        if currentSnapState != .EXPANDED {
            snapExpand()
            applyAlpha()
        }
    }
    
    //We expand the views when the vc is about to disappear
    public func vcWillDisappear() {
        if currentSnapState != .EXPANDED {
            snapExpand()
            applyAlpha()
        }
    }
    
    public func vcDidSubLayoutViews(){
        viewDidUpdate()
    }
    
    public func handleGestureFromDependantScroll(gestureInfo: PanGestureInformation, scrollTranslationInfo: ScrollTranslationInformation) {
            handleOngoingGesture(gestureInfo: gestureInfo, scrollTranslationInfo: scrollTranslationInfo)
    }
    
    //We fully expand/contract the views when the gesture has ended
    public func gestureDidFinish(gestureInfo: PanGestureInformation, scrollView: UIScrollView) {
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            if self?.currentSnapState == .CONTRACTING {
                self?.snapContract()
            } else if self?.currentSnapState == .EXPANDING {
                self?.snapExpand()
            }
            self?.applyAlpha()
            }, completion: { [weak self] (finished: Bool) in
                self?.viewDidUpdate()
        })
    }
    
    public func getDependantScrollView() -> UIScrollView? {
        return nil
    }
    
    public func scrollDidTranslateAfterGesture(scrollTranslationInfo: ScrollTranslationInformation) {

    }
    
    
    
    //We gradually expand/contract the views while the gesture is going on
    func handleOngoingGesture(gestureInfo: PanGestureInformation, scrollTranslationInfo: ScrollTranslationInformation) {
        // Ignore duplicate scroll events or events in which there is no vertical scroll
        if(gestureInfo.verticalDelta == 0 || scrollTranslationInfo.verticalDelta == 0) {
            return
        }
        
        // if refreshing we dont need to handle the gesture
        if let isRefreshing = refreshControl?.isRefreshing, isRefreshing {
            return
        }
        
        let scrollView = scrollTranslationInfo.scrollView
        
        //Return if we detect bottom bouncing effect
        let insets = getContentInsets(scrollView: scrollView)
        let scrollFrame = UIEdgeInsetsInsetRect(scrollView.bounds, insets)
        let scrollableAmount: CGFloat = scrollView.contentSize.height - scrollFrame.height
        if scrollableAmount < 3 * snapDistance && currentSnapState == .EXPANDED {
            return
        }
        
        if gestureInfo.verticalDirection == .down {
            //We are scrolling in the bottom direction, so need to expand the views
            if currentSnapState != .EXPANDED {
                incrementalExpand(deltaOffset: gestureInfo.verticalDelta)
            }
        } else {
            //We are scrolling in the upward direction, so need to contract the view
            if currentSnapState != .CONTRACTED {
                incrementalContract(deltaOffset: gestureInfo.verticalDelta)
            }
        }
        applyAlpha()
        viewDidUpdate()
    }
    
    //Fully contract the view when the user lifts his finger ie ends the gesture
    func snapContract() {
        currentSnapState = .CONTRACTED
        if snapDirection == .TOP {
            self.view.frame.origin.y = self.startingVerticalPosition - self.snapDistance
        } else {
            self.view.frame.origin.y = self.startingVerticalPosition + self.snapDistance
        }
    }
    
    //Gradually contract the view as the user is scrolling
    func incrementalContract(deltaOffset: CGFloat) {
        currentSnapState = .CONTRACTING
        if snapDirection == .TOP {
            view.frame.origin.y = max(view.frame.origin.y - deltaOffset, startingVerticalPosition - snapDistance)
        } else {
            view.frame.origin.y = min(view.frame.origin.y + deltaOffset, startingVerticalPosition + snapDistance)
        }
    }
    
    //Fully expand the view when the user lifts his finger ie ends the gesture
    func snapExpand() {
        currentSnapState = .EXPANDED
        self.view.frame.origin.y = self.startingVerticalPosition
    }
    
    //Gradually expand the view as the user is scrolling
    func incrementalExpand(deltaOffset: CGFloat) {
        currentSnapState = .EXPANDING
        if snapDirection == .TOP {
            view.frame.origin.y = min(view.frame.origin.y + deltaOffset, startingVerticalPosition)
        } else {
            view.frame.origin.y = max(view.frame.origin.y - deltaOffset, startingVerticalPosition)
        }
    }
    
    //Reset parameters when a new gesture starts
    public func gestureDidStart(scrollView: UIScrollView) {
    }
    
    //Applying alpha to gradually make a view transparent as it is being snapped
    func applyAlpha() {
        //Need this only if fade is enabled
        guard isFadeEnabled else {
            return
        }
        let snappedAmount: CGFloat = abs(view.frame.origin.y - startingVerticalPosition)
        let snapRatio: CGFloat = snappedAmount/snapDistance
        var alpha: CGFloat = 1.0 - snapRatio
        alpha = CGFloat(min(max(Float.ulpOfOne, Float(alpha)), 1.0))
        
        
        for subView in view.subviews {
            //First index hack needed as it is the background view and we dont want to alter that
            if subView != view.subviews[0], Float(subView.alpha) >= Float.ulpOfOne {
                subView.alpha = alpha
                hideViewIfNeeded(subView, alpha)
            }
        }
    }
    
    private func viewDidUpdate() {
        snapDelegate?.snapDidUpdateView()
    }
    
    /*
     Need these due to iOS 11 compatibility issues
     */
    fileprivate func hideViewIfNeeded(_ view: UIView, _ alpha: CGFloat) {
        // quick fix as alpha of navigation items gets reset to 1.0 when frame of navigation bar is altered in iOS 11
        if #available(iOS 11.0, *) {
            if alpha < 0.25 {
                view.isHidden = true
            } else {
                view.isHidden = false
            }
        }
    }
    
    func getContentInsets(scrollView: UIScrollView) -> UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return scrollView.adjustedContentInset
        } else {
            return scrollView.contentInset
        }
    }
}
