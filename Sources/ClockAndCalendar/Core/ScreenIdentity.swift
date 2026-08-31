import AppKit

/// A stable, persistable name for a physical display.
///
/// `NSScreenNumber` (a `CGDirectDisplayID`) is recycled by the window server, so
/// it says nothing about *which* monitor came back after a reconnect or a
/// reboot. `CGDisplayCreateUUIDFromDisplayID` is derived from the panel itself
/// and survives both, which is what lets a widget find its way home when an
/// external display is unplugged and plugged in again.
enum ScreenIdentity {

    static func key(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return key(for: CGDirectDisplayID(number.uint32Value))
    }

    static func key(for display: CGDirectDisplayID) -> String {
        if let cf = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, cf) as String
        }
        // Fall back to the EDID numbers. Still tied to the panel rather than to
        // the connection, and only ambiguous between two identical models that
        // both report no serial number.
        return "edid-\(CGDisplayVendorNumber(display))-\(CGDisplayModelNumber(display))-\(CGDisplaySerialNumber(display))"
    }

    /// The attached display with this key, or `nil` when that monitor is away.
    static func screen(for key: String) -> NSScreen? {
        NSScreen.screens.first { Self.key(for: $0) == key }
    }

    /// The attached display a widget's top-left anchor sits on.
    ///
    /// Probes a small square below the anchor rather than the widget's whole
    /// frame: an oversized widget can straddle two displays, and the anchor is
    /// the one part of it that doesn't move when the scale changes.
    static func screen(containing topLeft: CGPoint) -> NSScreen? {
        let probe = CGRect(x: topLeft.x, y: topLeft.y - 40, width: 40, height: 40)
        let best = NSScreen.screens.max { a, b in
            area(a.frame.intersection(probe)) < area(b.frame.intersection(probe))
        }
        guard let best, area(best.frame.intersection(probe)) > 0 else { return nil }
        return best
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull || rect.isEmpty ? 0 : rect.width * rect.height
    }
}
