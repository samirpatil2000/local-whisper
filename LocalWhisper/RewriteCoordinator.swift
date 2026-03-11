import Foundation
import FoundationModels

/// Coordinates the floating rewrite toolbar flow:
/// Detect selection → show toolbar → user picks style → rewrite → replace text → log history.
@MainActor
final class RewriteCoordinator {
    
    let historyManager: HistoryManager
    let personaManager: PersonaManager
    let toolbarWindow: RewriteToolbarWindow
    
    private var currentSelectedText: String?
    private var isProcessing = false
    
    init(historyManager: HistoryManager, personaManager: PersonaManager) {
        self.historyManager = historyManager
        self.personaManager = personaManager
        self.toolbarWindow = RewriteToolbarWindow()
        
        toolbarWindow.onStyleSelected = { [weak self] name, prompt in
            guard let self else { return }
            Task { @MainActor in
                await self.performRewrite(styleName: name, prompt: prompt)
            }
        }
        
        toolbarWindow.onDismiss = { [weak self] in
            self?.currentSelectedText = nil
        }
    }
    
    /// Called when text selection is detected.
    func showToolbar(selectedText: String, bounds: CGRect) {
        currentSelectedText = selectedText
        toolbarWindow.showToolbar(at: bounds, personas: personaManager.personas)
    }
    
    /// Called when selection is cleared.
    func hideToolbar() {
        toolbarWindow.hideToolbar()
        currentSelectedText = nil
    }
    
    /// Performs the rewrite operation.
    private func performRewrite(styleName: String, prompt: String) async {
        guard let selectedText = currentSelectedText, !selectedText.isEmpty else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        
        // Show processing state in toolbar
        if let bounds = AccessibilityService.getSelectionBounds() {
            toolbarWindow.showToolbar(at: bounds, personas: personaManager.personas, isProcessing: true)
        }
        
        let fullPrompt = """
        You are rewriting the following text according to the user's instruction.
        
        INSTRUCTION: \(prompt)
        
        OUTPUT RULES:
        - Return ONLY the rewritten text
        - No explanations, no labels, no preamble
        - Do not wrap in quotes
        - Start directly with the rewritten content
        - Preserve formatting (line breaks, bullet points) where appropriate
        
        TEXT TO REWRITE:
        \(selectedText)
        """
        
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: fullPrompt)
            let result = response.content
            
            // Replace the selected text in-place
            AccessibilityService.replaceSelectedText(result)
            
            // Log to history
            let action: HistoryAction = {
                switch styleName {
                case "Rewrite": return .rewrite
                case "Formal": return .formal
                case "Concise": return .concise
                case "Friendly": return .friendly
                case "Custom": return .custom
                default: return .persona
                }
            }()
            
            historyManager.log(
                originalText: selectedText,
                action: action,
                styleName: styleName,
                resultText: result
            )
        } catch {
            print("[RewriteCoordinator] Rewrite failed: \(error)")
        }
        
        isProcessing = false
        toolbarWindow.hideToolbar()
        currentSelectedText = nil
    }
}
