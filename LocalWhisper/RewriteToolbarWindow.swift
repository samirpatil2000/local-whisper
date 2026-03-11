import AppKit
import SwiftUI

/// Floating toolbar that appears above selected text with rewrite options.
/// Pill-shaped buttons in a single row with blur background, max height 36pt.
final class RewriteToolbarWindow: NSPanel {
    
    var onStyleSelected: ((String, String) -> Void)?  // (styleName, prompt)
    var onDismiss: (() -> Void)?
    
    private var hostingView: NSHostingView<RewriteToolbarContent>?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 36),
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
    }
    
    func showToolbar(at selectionBounds: CGRect, personas: [Persona], isProcessing: Bool = false) {
        let content = RewriteToolbarContent(
            personas: personas,
            isProcessing: isProcessing,
            onSelect: { [weak self] name, prompt in
                self?.onStyleSelected?(name, prompt)
            }
        )
        
        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 36)
        
        // Size to fit content
        let fittingSize = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height)
        
        contentView = hosting
        hostingView = hosting
        
        // Position above the selection
        positionAboveSelection(selectionBounds, toolbarSize: fittingSize)
        
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            animator().alphaValue = 1
        }
        
        installDismissMonitors()
    }
    
    func hideToolbar() {
        removeDismissMonitors()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
    
    private func positionAboveSelection(_ bounds: CGRect, toolbarSize: NSSize) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // AX coordinates are top-left origin; convert to bottom-left for NSWindow
        let flippedY = screenFrame.height - bounds.origin.y
        
        // Position above the selection with 8pt gap
        var x = bounds.origin.x + (bounds.width / 2) - (toolbarSize.width / 2)
        var y = flippedY + 8
        
        // Clamp to screen bounds
        x = max(screenFrame.origin.x + 8, min(x, screenFrame.maxX - toolbarSize.width - 8))
        y = max(screenFrame.origin.y + 8, min(y, screenFrame.maxY - toolbarSize.height - 8))
        
        setFrame(NSRect(x: x, y: y, width: toolbarSize.width, height: toolbarSize.height), display: true)
    }
    
    private func installDismissMonitors() {
        removeDismissMonitors()
        
        // Click outside to dismiss
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hideToolbar()
                self?.onDismiss?()
            }
        }
        
        // Escape to dismiss
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.hideToolbar()
                    self?.onDismiss?()
                }
            }
        }
    }
    
    private func removeDismissMonitors() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

// MARK: - SwiftUI Toolbar Content

private struct RewriteToolbarContent: View {
    let personas: [Persona]
    let isProcessing: Bool
    let onSelect: (String, String) -> Void
    
    @State private var showCustomField = false
    @State private var customInstruction = ""
    
    private let defaultStyles: [(name: String, prompt: String)] = [
        ("Rewrite", "Rewrite this text to be cleaner and more polished while preserving the original meaning."),
        ("Formal", "Rewrite this text in a formal, professional business tone. Avoid contractions. Use precise language."),
        ("Concise", "Compress this text to the absolute minimum words needed. Remove all redundancy and fluff."),
        ("Friendly", "Rewrite this text in a warm, casual, and friendly tone. Use natural contractions and conversational language."),
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .padding(.horizontal, 8)
                
                Text("Rewriting…")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.7))
            } else if showCustomField {
                // Custom instruction inline field
                HStack(spacing: 4) {
                    TextField("Instruction…", text: $customInstruction)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .default))
                        .foregroundColor(.white)
                        .frame(width: 180)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                        .onSubmit {
                            if !customInstruction.isEmpty {
                                onSelect("Custom", customInstruction)
                                showCustomField = false
                                customInstruction = ""
                            }
                        }
                    
                    Button("Cancel") {
                        showCustomField = false
                        customInstruction = ""
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .buttonStyle(.plain)
                }
            } else {
                // Default style pills
                ForEach(defaultStyles, id: \.name) { style in
                    ToolbarPill(title: style.name) {
                        onSelect(style.name, style.prompt)
                    }
                }
                
                // Custom button
                ToolbarPill(title: "Custom") {
                    showCustomField = true
                }
                
                // Persona pills (up to 3 more for max 8 total)
                let personaSlots = min(personas.count, 3)
                if personaSlots > 0 {
                    Divider()
                        .frame(height: 16)
                        .background(Color.white.opacity(0.2))
                    
                    ForEach(personas.prefix(personaSlots)) { persona in
                        ToolbarPill(title: persona.name) {
                            onSelect(persona.name, persona.systemPrompt)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.5))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .fixedSize()
    }
}

private struct ToolbarPill: View {
    let title: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isHovered ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
