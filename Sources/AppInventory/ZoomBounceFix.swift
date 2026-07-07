import SwiftUI
import AppKit
import ObjectiveC

/// Fixes the title-bar double-click zoom bounce on macOS 26: the system
/// delivers the double-click twice — once through the new Gestures pipeline
/// (which zooms) and once via the delayed legacy mouseUp re-send (which zooms
/// again, toggling straight back). This installs a window-delegate interceptor
/// that vetoes the duplicate delivery and makes zoom fill the visible screen,
/// forwarding every other delegate call to SwiftUI's original delegate.
struct ZoomBounceFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window,
                  !(window.delegate is ZoomDelegateInterceptor) else { return }
            let interceptor = ZoomDelegateInterceptor(wrapping: window.delegate)
            // window.delegate is a weak reference; tie the interceptor's
            // lifetime to the window so it isn't deallocated immediately.
            objc_setAssociatedObject(window, &ZoomDelegateInterceptor.associationKey,
                                     interceptor, .OBJC_ASSOCIATION_RETAIN)
            window.delegate = interceptor
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class ZoomDelegateInterceptor: NSObject, NSWindowDelegate {
    static var associationKey: UInt8 = 0

    // Strong: NSWindow.delegate doesn't retain, and the original must outlive us.
    private let original: NSWindowDelegate?

    init(wrapping original: NSWindowDelegate?) {
        self.original = original
    }

    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame: NSRect) -> NSRect {
        defaultFrame   // zoom to the full visible screen area
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // The duplicate double-click delivery is identifiable by the
        // delayed-event re-send frame in its call stack; veto just that one.
        // Verified via frame-change instrumentation on macOS 26.0; if the OS
        // bug is fixed, this check never triggers and zoom behaves normally.
        !Thread.callStackSymbols.contains { $0.contains("SortAndSendDelayedEvents") }
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if original?.responds(to: aSelector) == true { return original }
        return super.forwardingTarget(for: aSelector)
    }
}
