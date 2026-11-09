import AppKit
import ShanjieKit

/// The candidate list drawn like Apple Zhuyin's own box: flat 28 pt rows on a menu-material background, the selected row filled with the
/// accent colour, a small number on the left and an optional tag on the right. Replaces the capsule bar; the core is kept in its
/// vertical orientation, so every output is one column of up to nine rows.
@MainActor
final class AppleListView: NSView {
    static let rowH: CGFloat = 28
    static let minWidth: CGFloat = 160
    static let scrollerInset: CGFloat = 15

    var items: [String] = []
    var notes: [String?] = []
    var selected = -1
    var first = 0
    var total = 0
    var numbered = true
    var onClick: ((Int) -> Void)?

    override var isFlipped: Bool { true }

    var needsScroller: Bool { total > items.count }

    static func width(items: [String], notes: [String?], total: Int, numbered: Bool) -> CGFloat {
        var w = minWidth
        for (i, t) in items.enumerated() {
            let tw = (t as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .medium)]).width
            var need = (numbered ? 17 : 10) + tw + 14
            if i < notes.count, let n = notes[i] {
                need += (n as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)]).width + 12
            }
            w = max(w, need)
        }
        return w + (total > items.count ? scrollerInset : 0)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        (dark ? NSColor(white: 1, alpha: 0.10) : NSColor(white: 1, alpha: 0.25)).setFill()
        bounds.fill()
        let rightInset: CGFloat = needsScroller ? Self.scrollerInset : 0
        for i in items.indices {
            let y = CGFloat(i) * Self.rowH
            let rect = NSRect(x: 0, y: y, width: bounds.width - rightInset, height: Self.rowH)
            let isSel = i == selected
            if isSel {
                (NSColor.controlAccentColor.blended(withFraction: 0.13, of: .black) ?? NSColor.controlAccentColor).setFill()
                rect.fill()
            } else {
                NSColor.labelColor.withAlphaComponent(0.10).setFill()
                NSRect(x: 0, y: y + Self.rowH - 0.5, width: rect.width, height: 0.5).fill()
            }
            if numbered {
                let label = (selected < 0 && i == 0) ? "⇥" : "\(i + 1)"
                let color: NSColor = isSel ? .white : NSColor.labelColor.withAlphaComponent(0.4)
                let s = NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: color])
                let sz = s.size()
                s.draw(at: NSPoint(x: 6, y: y + (Self.rowH - sz.height) / 2 + 1))
            }
            let text = items[i]
            let isEmoji = text.unicodeScalars.first.map { $0.properties.isEmojiPresentation } ?? false
            let tf = NSFont.systemFont(ofSize: isEmoji ? 20 : 17, weight: .medium)
            let ts = NSAttributedString(string: text, attributes: [.font: tf, .foregroundColor: isSel ? NSColor.white : NSColor.labelColor])
            let tsz = ts.size()
            ts.draw(at: NSPoint(x: numbered ? 17 : 10, y: y + (Self.rowH - tsz.height) / 2))
            if i < notes.count, let note = notes[i] {
                let gc: NSColor = isSel ? NSColor.white.withAlphaComponent(0.85) : .secondaryLabelColor
                let gs = NSAttributedString(string: note, attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: gc])
                let gsz = gs.size()
                gs.draw(at: NSPoint(x: bounds.width - rightInset - 12 - gsz.width, y: y + (Self.rowH - gsz.height) / 2))
            }
        }
        if needsScroller {
            let h = CGFloat(items.count) * Self.rowH
            let thumbH = max(24, h * CGFloat(items.count) / CGFloat(max(total, 1)))
            let travel = h - thumbH - 8
            let t = total > items.count ? CGFloat(first) / CGFloat(total - items.count) : 0
            let thumb = NSRect(x: bounds.width - 11, y: 4 + travel * min(max(t, 0), 1), width: 7, height: thumbH)
            (dark ? NSColor(white: 0.6, alpha: 0.95) : NSColor(white: 0.74, alpha: 0.95)).setFill()
            NSBezierPath(roundedRect: thumb, xRadius: 3.5, yRadius: 3.5).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let i = Int(p.y / Self.rowH)
        if i >= 0, i < items.count { onClick?(i) }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ApplePanelAdapter: CandidatePanel {
    var onSelect: ((Int) -> Void)?
    private let window: PanelWindow
    private let effect = NSVisualEffectView()
    private let list = AppleListView()
    private var lastLine: NSRect?
    private var hintShown = false

    private let ghostWindow: PanelWindow
    private let ghostLabel = NSTextField(labelWithString: "")

    init() {
        window = PanelWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        let r: CGFloat = 10
        let d = r * 2 + 1
        let mask = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        mask.resizingMode = .stretch
        effect.maskImage = mask
        list.autoresizingMask = [.width, .height]
        effect.addSubview(list)
        window.contentView = effect
        ghostWindow = PanelWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        ghostWindow.isOpaque = false
        ghostWindow.backgroundColor = .clear
        ghostWindow.hasShadow = false
        ghostWindow.ignoresMouseEvents = true
        ghostWindow.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        ghostWindow.hidesOnDeactivate = false
        ghostWindow.isReleasedWhenClosed = false
        ghostLabel.isBezeled = false
        ghostLabel.drawsBackground = false
        ghostLabel.isEditable = false
        ghostLabel.textColor = NSColor.labelColor.withAlphaComponent(0.4)
        ghostWindow.contentView = ghostLabel
        list.onClick = { [weak self] i in self?.onSelect?(i) }
    }

    func show(_ candidates: [String], notes: [String?], selected: Int, columns: Int, first: Int, total: Int, vertical: Int,
              lineRect: NSRect?, appearance: NSAppearance?, glassTint: Double) {
        hideGhost()
        render(candidates, notes: notes, selected: selected, first: first, total: total, numbered: true, lineRect: lineRect, appearance: appearance)
    }

    func showHint(_ text: String, vertical: Int, lineRect: NSRect?, appearance: NSAppearance?, glassTint: Double) {
        hideGhost()
        render([text], notes: [nil], selected: -1, first: 0, total: 1, numbered: false, lineRect: lineRect, appearance: appearance)
    }

    private func render(_ items: [String], notes: [String?], selected: Int, first: Int, total: Int, numbered: Bool,
                        lineRect: NSRect?, appearance: NSAppearance?) {
        if window.appearance?.name != appearance?.name { window.appearance = appearance }
        list.items = items
        list.notes = notes
        list.selected = selected
        list.first = first
        list.total = total
        list.numbered = numbered
        let size = NSSize(width: AppleListView.width(items: items, notes: notes, total: total, numbered: numbered),
                          height: CGFloat(max(items.count, 1)) * AppleListView.rowH)
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let main = NSScreen.main.flatMap { m in screens.firstIndex(of: m) } ?? 0
        let p = PanelPlacement.topLeft(line: lineRect, last: lastLine, size: size, alignOffset: numbered ? 17 : 10,
                                       screens: screens.map { PanelPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) },
                                       main: main)
        if let lineRect { lastLine = lineRect }
        let frame = NSRect(x: p.origin.x, y: p.origin.y - size.height, width: size.width, height: size.height)
        if window.frame != frame { window.setFrame(frame, display: true) }
        list.frame = NSRect(origin: .zero, size: size)
        list.needsDisplay = true
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() {
        window.orderOut(nil)
        hideGhost()
    }

    func setGlassTint(_ glassTint: Double) {}

    // MARK: ghost text

    func showGhost(_ text: String, anchor: GhostAnchor, appearance: NSAppearance?) {
        window.orderOut(nil)
        guard !text.isEmpty else { ghostWindow.orderOut(nil); return }
        if ghostWindow.appearance?.name != appearance?.name { ghostWindow.appearance = appearance }
        let line = anchor.line
        ghostLabel.font = anchor.font.map { NSFont(descriptor: $0.fontDescriptor, size: $0.pointSize) ?? $0 }
            ?? NSFont.systemFont(ofSize: max(12, line.height / 1.2))
        ghostLabel.stringValue = text
        ghostLabel.sizeToFit()
        let lw = ghostLabel.frame.width
        let lh = ghostLabel.frame.height
        let h = max(line.height, lh)
        let frame = NSRect(x: anchor.x, y: line.minY + (line.height - h) / 2, width: lw + 2, height: h)
        ghostLabel.frame = NSRect(x: 0, y: (h - lh) / 2, width: lw, height: lh)
        ghostWindow.setFrame(frame, display: true)
        ghostWindow.contentView = ghostLabel
        if !ghostWindow.isVisible { ghostWindow.orderFrontRegardless() }
    }

    func hideGhost() { ghostWindow.orderOut(nil) }
}
