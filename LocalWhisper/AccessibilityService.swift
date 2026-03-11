import AppKit
import ApplicationServices

/// System-level accessibility helpers for reading/writing text in any app.
/// Requires Accessibility permission in System Settings → Privacy & Security.
enum AccessibilityService {
    
    // MARK: - Permission Check
    
    static func isAccessibilityEnabled() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions(
            [key: false] as CFDictionary
        )
    }
    
    static func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions(
            [key: true] as CFDictionary
        )
    }
    
    // MARK: - Focused Element
    
    /// Returns the AXUIElement for the currently focused text field (system-wide).
    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        
        return (focusedElement as! AXUIElement)
    }
    
    // MARK: - Read Selected Text
    
    /// Gets the currently selected text from any focused text field.
    static func getSelectedText() -> String? {
        guard let element = focusedElement() else { return nil }
        
        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }
        
        return selectedText as? String
    }
    
    // MARK: - Get Selection Position
    
    /// Gets the screen position of the current text selection for toolbar positioning.
    static func getSelectionBounds() -> CGRect? {
        guard let element = focusedElement() else { return nil }
        
        // Try to get selected text range
        var selectedRange: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else {
            return nil
        }
        
        // Get bounds for the selected text range
        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange!,
            &boundsValue
        ) == .success else {
            return nil
        }
        
        var bounds = CGRect.zero
        if AXValueGetValue(boundsValue as! AXValue, .cgRect, &bounds) {
            return bounds
        }
        return nil
    }
    
    // MARK: - Replace Selected Text
    
    /// Replaces the currently selected text in the focused text field.
    static func replaceSelectedText(_ newText: String) {
        guard let element = focusedElement() else { return }
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
    }
    
    // MARK: - Inject Text
    
    /// Injects text into the focused text field.
    /// Strategy 1: Try AXUIElement direct insertion (no clipboard needed).
    /// Strategy 2: Fall back to clipboard-based Cmd+V paste.
    static func injectText(_ text: String) {
        // Strategy 1: Try direct AX insertion
        if injectViaAccessibility(text) {
            return
        }
        
        // Strategy 2: Clipboard-based paste
        injectViaClipboard(text)
    }
    
    /// Inserts text directly via AXUIElement by setting the value at the cursor position.
    private static func injectViaAccessibility(_ text: String) -> Bool {
        guard let element = focusedElement() else { return false }
        
        // Try to set selected text (replaces selection or inserts at cursor if no selection)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }
    
    /// Injects text by temporarily setting the clipboard and simulating Cmd+V.
    private static func injectViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard
        let savedChangeCount = pasteboard.changeCount
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (NSPasteboard.PasteboardType, Data)? in
            guard let type = item.types.first,
                  let data = item.data(forType: type) else { return nil }
            return (type, data)
        }
        
        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Small delay to ensure clipboard is ready, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulatePaste()
            
            // Restore original clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Only restore if nothing else has touched the clipboard since
                if pasteboard.changeCount == savedChangeCount + 1 {
                    pasteboard.clearContents()
                    if let saved = savedItems {
                        for (type, data) in saved {
                            pasteboard.setData(data, forType: type)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Simulate Paste (Cmd+V)
    
    /// Simulates Cmd+V keystroke to paste from clipboard.
    private static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Key down: V with Command
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 = 'v'
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        
        // Small delay between down and up
        usleep(30_000) // 30ms
        
        // Key up: V with Command
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
