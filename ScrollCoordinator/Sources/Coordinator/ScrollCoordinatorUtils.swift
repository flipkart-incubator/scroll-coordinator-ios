//
//  ScrollCoordinatorUtils.swift
//  ScrollCoordinator
//

import Foundation

public class ScrollCoordinatorUtils {
    
    // Method to get the height of the status bar
    static public func getStatusBarHeight() -> CGFloat {
        if UIApplication.shared.isStatusBarHidden {
            return 0
        }
        // statusBarFrame is deprecated in iOS_13 & above. apple suggests to use statusBarManager instead
        if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            let height = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            return height
        } else {
            let statusBarSize = UIApplication.shared.statusBarFrame.size
            let statusBarHeight = min(statusBarSize.width, statusBarSize.height)
            return statusBarHeight
        }
    }
}
