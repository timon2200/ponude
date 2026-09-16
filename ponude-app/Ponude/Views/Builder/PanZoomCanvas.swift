import SwiftUI
import AppKit

/// A Canva-style canvas for the A4 preview: pinch to zoom (anchored at the
/// cursor), two-finger scroll or left-drag to pan, ⌘+scroll to zoom, and
/// double-click to refit the page.
///
/// Event handling lives in AppKit (`NSView` gets `magnify` and `scrollWheel`
/// for free); rendering stays in SwiftUI via the scale/offset bindings.
struct PanZoomCanvas: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGPoint
    var minScale: CGFloat = 0.15
    var maxScale: CGFloat = 5
    var onReset: () -> Void

    func makeNSView(context: Context) -> PanZoomNSView {
        let view = PanZoomNSView()
        view.onPan = { [self] dx, dy in pan(dx: dx, dy: dy) }
        view.onMagnify = { [self] factor, anchor in zoom(by: factor, at: anchor) }
        view.onReset = onReset
        return view
    }

    func updateNSView(_ nsView: PanZoomNSView, context: Context) {
        nsView.onReset = onReset
    }

    private func pan(dx: CGFloat, dy: CGFloat) {
        offset = CGPoint(x: offset.x + dx, y: offset.y + dy)
    }

    /// Zooms around the cursor: the content point under the cursor stays put.
    private func zoom(by factor: CGFloat, at anchor: CGPoint) {
        let newScale = min(max(scale * factor, minScale), maxScale)
        guard newScale != scale else { return }
        let contentPoint = CGPoint(x: (anchor.x - offset.x) / scale,
                                   y: (anchor.y - offset.y) / scale)
        offset = CGPoint(x: anchor.x - contentPoint.x * newScale,
                         y: anchor.y - contentPoint.y * newScale)
        scale = newScale
    }
}

/// Plain NSView that forwards trackpad/mouse gestures to the canvas.
final class PanZoomNSView: NSView {
    var onPan: ((CGFloat, CGFloat) -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    var onReset: (() -> Void)?

    private var dragStart: CGPoint?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { NSCursor.openHand.set() }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) {
            onMagnify?(1 + event.scrollingDeltaY * 0.01, point)
        } else {
            // Natural scrolling: content follows the fingers.
            onPan?(event.scrollingDeltaX, event.scrollingDeltaY)
        }
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(1 + event.magnification, convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onReset?()
            return
        }
        dragStart = convert(event.locationInWindow, from: nil)
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        onPan?(point.x - start.x, point.y - start.y)
        dragStart = point
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        NSCursor.openHand.set()
    }
}
