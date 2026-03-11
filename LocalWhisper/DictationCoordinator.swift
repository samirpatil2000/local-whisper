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
    
    init(speechRecognizer: SpeechRecognizer, historyManager: HistoryManager) {
        self.speechRecognizer = speechRecognizer
        self.historyManager = historyManager
        self.pillWindow = DictationPillWindow()
    }
    
    /// Called when FN key is pressed down.
    func beginDictation() {
        pillWindow.showPill()
        speechRecognizer.startGlobalDictation()
    }
    
    /// Called when FN key is released.
    func endDictation() async {
        pillWindow.hidePill()
        let transcript = await speechRecognizer.stopGlobalDictation()
        
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Inject the transcribed text into the focused text field
        AccessibilityService.injectText(transcript)
        
        // Log to history
        historyManager.log(
            originalText: "",
            action: .dictation,
            styleName: "Dictation",
            resultText: transcript
        )
    }
}
