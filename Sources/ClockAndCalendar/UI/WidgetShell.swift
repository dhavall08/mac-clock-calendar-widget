import SwiftUI

/// Transparent margin the panel keeps around widget content so the hover
/// toolbar, resize grip and neon glow have somewhere to draw.
///
/// `WidgetWindowController` sizes panels from here, so the shell and the window
/// can never disagree about how big the frame should be.
enum WidgetShellMetrics {
    static let insetTop: CGFloat = 42
    static let insetSide: CGFloat = 26
    static let insetBottom: CGFloat = 28

    static func windowSize(for rendered: CGSize) -> CGSize {
        CGSize(width: rendered.width + insetSide * 2,
               height: rendered.height + insetTop + insetBottom)
    }
}

/// Chrome wrapped around every widget: glass background, hover toolbar and the
/// drag-to-resize grip.
///
/// Content is always laid out at the widget's intrinsic `baseSize` and then
/// scaled with `scaleEffect`. That keeps proportions identical at every size —
/// a 3× calendar is the same design, just bigger, with vector-sharp text —
/// instead of a layout that reflows and breaks as it grows.
struct WidgetShell: View {
    @ObservedObject var state: AppState
    let id: UUID
    let onOpenSettings: () -> Void

    @ViewState private var isHovering = false
    @ViewState private var dragStartScale: Double?

    private var chrome: WidgetChrome { state.chrome(for: id) }
    private var base: CGSize { state.baseSize(for: id) }
    private var scale: Double { chrome.scale }
    private var rendered: CGSize { state.renderedSize(for: id) }

    var body: some View {
        widget
            .overlay(alignment: .top) { toolbar }
            .overlay(alignment: .bottomTrailing) { resizeGrip }
            .padding(EdgeInsets(top: WidgetShellMetrics.insetTop,
                                leading: WidgetShellMetrics.insetSide,
                                bottom: WidgetShellMetrics.insetBottom,
                                trailing: WidgetShellMetrics.insetSide))
            .frame(width: WidgetShellMetrics.windowSize(for: rendered).width,
                   height: WidgetShellMetrics.windowSize(for: rendered).height)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .onHover { isHovering = $0 }
    }

    private var widget: some View {
        ZStack(alignment: .topLeading) {
            if chrome.showsBackground {
                GlassBackground(
                    cornerRadius: chrome.cornerRadius * scale,
                    accent: chrome.accent,
                    theme: chrome.theme,
                    opacity: chrome.opacity,
                    showsGlow: chrome.showsGlow,
                    showsShadow: chrome.showsShadow,
                    borderWidth: chrome.borderWidth,
                    borderTint: chrome.borderTint
                )
            }

            if let type = state.type(of: id) {
                type.content(state, id)
                    .frame(width: base.width, height: base.height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: rendered.width, height: rendered.height, alignment: .topLeading)
            }
        }
        .frame(width: rendered.width, height: rendered.height)
        .opacity(chrome.opacity)
    }

    // MARK: Toolbar

    /// Fixed size regardless of widget scale, so it stays clickable when the
    /// calendar is filling half the screen. Sits in the transparent margin
    /// above the widget rather than on top of the month header.
    private var toolbar: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 3)
                .help("Drag anywhere on the widget to move it")

            IconButton(symbol: "slider.horizontal.3", help: "Configure this widget", accent: chrome.accent) {
                onOpenSettings()
            }
            IconButton(symbol: chrome.isLocked ? "lock.fill" : "lock.open",
                       help: chrome.isLocked ? "Unlock" : "Lock in place (ignores clicks)",
                       accent: chrome.accent) {
                state.updateChrome(id, mutate { $0.isLocked.toggle() })
            }
            IconButton(symbol: "eye.slash", help: "Hide widget", accent: chrome.accent) {
                state.updateChrome(id, mutate { $0.isVisible = false })
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.surfaceSunken.opacity(0.94))
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        )
        .offset(y: -20)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
    }

    // MARK: Resize grip

    private var resizeGrip: some View {
        let minScale = state.type(of: id)?.minScale ?? 0.7
        let maxScale = state.maxScale(for: id)

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.surfaceSunken.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(chrome.accent.color())
        }
        .frame(width: 22, height: 22)
        .offset(x: 13, y: 13)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = dragStartScale ?? scale
                    if dragStartScale == nil { dragStartScale = start }
                    // Take the dominant axis so the drag tracks the pointer on a
                    // fixed-aspect widget in both directions.
                    let delta = max(value.translation.width / base.width,
                                    value.translation.height / base.height)
                    let next = min(max(start + delta, minScale), maxScale)
                    state.updateChrome(id, mutate { $0.scale = next })
                }
                .onEnded { _ in dragStartScale = nil }
        )
        .help("Drag to resize")
    }

    // MARK: Helper

    private func mutate(_ block: (inout WidgetChrome) -> Void) -> WidgetChrome {
        var copy = chrome
        block(&copy)
        return copy
    }
}
