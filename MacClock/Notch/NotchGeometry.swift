//
//  NotchGeometry.swift
//  MacClock
//
//  Created by Claude on 2026/2/12.
//

import AppKit

/// Utility for calculating notch-related screen geometry
struct NotchGeometry {

    /// Finds the screen that actually has the notch (safeAreaInsets.top > 0).
    /// Useful for multi-monitor setups where the main screen might be an external display.
    static var screenWithNotch: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }

    /// Whether any connected screen has a notch
    static var hasNotch: Bool {
        return screenWithNotch != nil
    }

    /// The menu bar / notch bar height on the notched screen.
    static var menuBarHeight: CGFloat {
        guard let screen = screenWithNotch ?? NSScreen.main else { return 24 }
        if screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        let computed = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        return max(computed, 24)
    }

    /// Robust calculation of the notch frame.
    /// Ensures a minimum width to prevent panels from overlapping or sticking together.
    static var notchRect: NSRect {
        // Prefer the screen with the notch, otherwise fall back to main
        guard let screen = screenWithNotch ?? NSScreen.main else {
             return NSRect(x: 0, y: 0, width: 200, height: 24)
        }
        
        let screenFrame = screen.frame
        let barHeight = menuBarHeight
        
        // Try to get actual notch geometry from system API
        if screen.safeAreaInsets.top > 0 { // Explicitly check if THIS screen has notch
            if #available(macOS 14.0, *) {
                if let topLeft = screen.auxiliaryTopLeftArea,
                   let topRight = screen.auxiliaryTopRightArea {
                    
                    let notchMinX = topLeft.maxX
                    let notchMaxX = topRight.minX
                    let width = notchMaxX - notchMinX
                    
                    // Safety check: Real notches are usually > 150pt wide.
                    if width > 80 {
                        return NSRect(x: notchMinX, y: screenFrame.maxY - barHeight, width: width, height: barHeight)
                    }
                }
            }
        }
        
        // Fallback: Simulate a centered notch
        let simulatedWidth: CGFloat = 160
        let screenMidX = screenFrame.midX
        let x = screenMidX - (simulatedWidth / 2)
        
        return NSRect(x: x, y: screenFrame.maxY - barHeight, width: simulatedWidth, height: barHeight)
    }

    /// Calculate the frame for the left notch panel (clock side)
    static func leftPanelFrame(panelWidth: CGFloat) -> NSRect {
        let notch = notchRect
        // Position panel ending slightly inside the notch's left edge to prevent gaps
        return NSRect(x: notch.minX - panelWidth + 8, y: notch.minY, width: panelWidth, height: notch.height)
    }

    /// Calculate the frame for the right notch panel (countdown side)
    static func rightPanelFrame(panelWidth: CGFloat) -> NSRect {
        let notch = notchRect
        // Position panel starting slightly inside the notch's right edge to prevent gaps
        return NSRect(x: notch.maxX - 8, y: notch.minY, width: panelWidth, height: notch.height)
    }
}
