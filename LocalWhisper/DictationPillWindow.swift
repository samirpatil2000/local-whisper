import AppKit
import SwiftUI

/// Floating pill window that appears at the bottom center of the screen during dictation.
/// Dark, minimal design with a live waveform animation — iOS dictation style.
final class DictationPillWindow: NSPanel {
    
    private let pillWidth: CGFloat = 160
    private let pillHeight: CGFloat = 44
    private let bottomInset: CGFloat = 24
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = false
        
        // Host SwiftUI content
        let hostingView = NSHostingView(rootView: DictationPillContent())
        hostingView.frame = NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight)
        contentView = hostingView
        
        positionAtBottomCenter()
    }
    
    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - pillWidth / 2
        let y = screenFrame.origin.y + bottomInset
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func showPill() {
        positionAtBottomCenter()
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1
        }
    }
    
    func hidePill() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

// MARK: - SwiftUI Content

private struct DictationPillContent: View {
    var body: some View {
        ZStack {
            // Dark blurred background
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.6))
            
            // Waveform bars
            WaveformView()
        }
        .frame(width: 160, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

private struct WaveformView: View {
    @State private var isAnimating = false
    
    private let barCount = 5
    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 4
    private let maxHeight: CGFloat = 20
    private let minHeight: CGFloat = 4
    
    var body: some View {
        HStack(spacing: spacing) {
            // Left side: mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.trailing, 6)
            
            // Waveform bars
            ForEach(0..<barCount, id: \.self) { i in
                WaveformBar(
                    isAnimating: isAnimating,
                    delay: Double(i) * 0.1,
                    maxHeight: maxHeight,
                    minHeight: minHeight
                )
                .frame(width: barWidth)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct WaveformBar: View {
    let isAnimating: Bool
    let delay: Double
    let maxHeight: CGFloat
    let minHeight: CGFloat
    
    @State private var height: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(0.85))
            .frame(height: height)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(
                    .easeInOut(duration: 0.4 + Double.random(in: 0...0.2))
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    height = CGFloat.random(in: (minHeight + 4)...maxHeight)
                }
            }
    }
}
