import AppKit

/// Stand-in for NSGlassEffectView (macOS 26 only): the same three members the shell uses (`contentView`, `cornerRadius`,
/// `tintColor`) on top of NSVisualEffectView, the material Apple's own candidate window used before Liquid Glass.
@MainActor
class GlassView: NSVisualEffectView {
    private let tintLayerView = NSView()
    var contentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let v = contentView else { return }
            v.frame = bounds
            v.autoresizingMask = [.width, .height]
            addSubview(v)
        }
    }
    var cornerRadius: CGFloat = 0 { didSet { updateMask() } }
    var tintColor: NSColor? { didSet { updateTint() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        tintLayerView.wantsLayer = true
        tintLayerView.frame = bounds
        tintLayerView.autoresizingMask = [.width, .height]
        addSubview(tintLayerView, positioned: .below, relativeTo: nil)
    }

    convenience init() { self.init(frame: .zero) }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func updateTint() {
        tintLayerView.layer?.backgroundColor = tintColor?.cgColor
    }

    private func updateMask() {
        let r = cornerRadius
        guard r > 0 else { maskImage = nil; return }
        let d = r * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        img.resizingMode = .stretch
        maskImage = img
    }
}
