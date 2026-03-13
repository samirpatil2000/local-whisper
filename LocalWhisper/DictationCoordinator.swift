import Foundation
import Speech
import AVFoundation

/// Coordinates the FN-key-triggered dictation flow:
/// Hold FN → mic activates + pill shows → release FN → transcribe → inject text → log history.
@MainActor
final class DictationCoordinator {
    
    let speechRecognizer: SpeechRecognizer
    let historyManager: HistoryManager
    let pillWindow: DictationPillWindow
    let toastWindow: DictationToastWindow
    
    /// The PID of the app that was focused when dictation started.
    /// Saved before async work so we can inject text back into the right app.
    private var targetAppPID: pid_t?
    private var targetAppName: String?
    
    init(speechRecognizer: SpeechRecognizer, historyManager: HistoryManager) {
        self.speechRecognizer = speechRecognizer
        self.historyManager = historyManager
        self.pillWindow = DictationPillWindow()
        self.toastWindow = DictationToastWindow()
    }
    
    /// Called when FN key is pressed down.
    func beginDictation() {
        // Save the target app BEFORE we do anything
        targetAppPID = AccessibilityService.frontmostAppPID()
        targetAppName = AccessibilityService.frontmostAppName()
        
        pillWindow.showPill()
        speechRecognizer.startGlobalDictation()
    }
    
    /// Called when FN key is released.
    func endDictation() async {
        pillWindow.hidePill()
        defer {
            targetAppPID = nil
            targetAppName = nil
        }

        let transcript = await speechRecognizer.stopGlobalDictation()
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTranscript.isEmpty else { return }

        let historyID = historyManager.logDictation(
            text: trimmedTranscript,
            targetAppName: targetAppName,
            injectionStatus: .failed
        )

        let endPID = AccessibilityService.frontmostAppPID()
        if targetAppPID != endPID {
            historyManager.updateDictationRecord(
                id: historyID,
                injectionStatus: .fallback,
                wasFocusChanged: true,
                targetAppName: targetAppName
            )
            toastWindow.show(message: "App changed. Saved to history.")
            return
        }

        let injectionResult = AccessibilityService.injectText(trimmedTranscript, targetPID: targetAppPID)
        switch injectionResult {
        case .success, .uncertain:
            historyManager.updateDictationRecord(
                id: historyID,
                injectionStatus: .injected,
                wasFocusChanged: false,
                targetAppName: targetAppName
            )
        case .failed(let reason):
            AccessibilityService.copyTextToClipboard(trimmedTranscript)
            historyManager.updateDictationRecord(
                id: historyID,
                injectionStatus: .clipboard_only,
                wasFocusChanged: false,
                targetAppName: targetAppName
            )
            toastWindow.show(message: toastMessage(for: reason))
        }
    }

    private func toastMessage(for reason: InjectionFailureReason) -> String {
        switch reason {
        case .noFocusedEditableElement:
            return "No text field. Saved transcript."
        case .secureTextField:
            return "Secure field detected. Saved transcript."
        case .accessibilityPermissionDenied, .pasteSimulationUnavailable:
            return "Couldn't insert. Copied to clipboard."
        }
    }
}
