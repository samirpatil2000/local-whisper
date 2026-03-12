import SwiftUI
import Speech
import AVFoundation
import FoundationModels

// MARK: - App Entry Point

@main
struct LocalWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainAppView(
                personaManager: appDelegate.personaManager,
                historyManager: appDelegate.historyManager,
                onFNToggleChanged: { [weak appDelegate] enabled in
                    appDelegate?.setFNDictationEnabled(enabled)
                },
                onToolbarToggleChanged: { [weak appDelegate] enabled in
                    appDelegate?.setFloatingToolbarEnabled(enabled)
                }
            )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 600, height: 680)
    }
}

// MARK: - Main App View (Three-Tab Layout)

struct MainAppView: View {
    let personaManager: PersonaManager
    let historyManager: HistoryManager
    var onFNToggleChanged: ((Bool) -> Void)?
    var onToolbarToggleChanged: ((Bool) -> Void)?
    
    @State private var selectedTab: AppTab = .personas
    @Namespace private var animation
    
    enum AppTab: String, CaseIterable {
        case personas = "Personas"
        case history = "History"
        case settings = "Settings"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 32) {
                Spacer()
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tabIcon(tab),
                        isSelected: selectedTab == tab,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer()
            }
            .frame(height: 52)
            .background(Color.white)
            
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 0.5)
            
            // Tab content
            Group {
                switch selectedTab {
                case .personas:
                    PersonasView(manager: personaManager)
                case .history:
                    HistoryView(manager: historyManager)
                case .settings:
                    SettingsView(
                        historyManager: historyManager,
                        onFNToggleChanged: onFNToggleChanged,
                        onToolbarToggleChanged: onToolbarToggleChanged
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(Color(hex: "#F2F2F7"))
    }
    
    private func tabIcon(_ tab: AppTab) -> String {
        switch tab {
        case .personas: return "person.2"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .accentColor : Color(hex: "#8E8E93"))
            .frame(width: 64)
            .contentShape(Rectangle())
            .overlay(
                VStack {
                    Spacer()
                    if isSelected {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "TabUnderline", in: namespace)
                    }
                }
                .padding(.bottom, -8) // aligns perfectly to the bottom edge of the 52pt height
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Corrections Dictionary

struct CorrectionEntry: Codable, Identifiable {
    var id = UUID()
    var spoken: String
    var corrected: String
}

@MainActor
final class CorrectionsDictionary: ObservableObject {
    @Published var entries: [CorrectionEntry] = [] {
        didSet {
            save()
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "LocalWhisper.Corrections"),
           let decoded = try? JSONDecoder().decode([CorrectionEntry].self, from: data) {
            self.entries = decoded
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "LocalWhisper.Corrections")
        }
    }
    
    func add(spoken: String, corrected: String) {
        let trimmedSpoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCorrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSpoken.isEmpty, !trimmedCorrected.isEmpty else { return }
        entries.append(CorrectionEntry(spoken: trimmedSpoken, corrected: trimmedCorrected))
    }
    
    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }
    
    /// Layer 1: Instant find-and-replace on transcript (case-insensitive)
    func apply(to text: String) -> String {
        var result = text
        for entry in entries {
            result = result.replacingOccurrences(
                of: "(?i)\\b\(NSRegularExpression.escapedPattern(for: entry.spoken))\\b",
                with: entry.corrected,
                options: .regularExpression
            )
        }
        return result
    }
    
    /// Layer 2: Formatted context block for the AI Prompt
    func contextBlock() -> String {
        guard !entries.isEmpty else { return "" }
        var block = "\nPERSONAL DICTIONARY (always apply these corrections):\n"
        for entry in entries {
            block += "- \"\(entry.spoken)\" → \"\(entry.corrected)\"\n"
        }
        return block
    }
}

// MARK: - Speech Recognizer

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    
    var corrections: CorrectionsDictionary?
    
    /// Text accumulated from previous recognition sessions within
    /// the same recording. Each time Apple's recognizer times out
    /// (~60s), we save what we have here and restart seamlessly.
    private var accumulatedTranscript: String = ""
    
    /// The partial text from the current recognition session only.
    private var currentSessionText: String = ""
    
    /// Whether the user intentionally stopped recording (vs. auto-restart).
    private var userRequestedStop: Bool = false
    
    /// Continuation used to await the final recognition result when stopping global dictation.
    private var stopContinuation: CheckedContinuation<Void, Never>?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    init() {
        let locale = UserDefaults.standard.string(forKey: "dictationLanguage") ?? "en-US"
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        speechRecognizer?.supportsOnDeviceRecognition = true
    }
    
    /// The full transcript is accumulated + current session, with corrections applied.
    private var fullTranscript: String {
        let combined: String
        if accumulatedTranscript.isEmpty {
            combined = currentSessionText
        } else if currentSessionText.isEmpty {
            combined = accumulatedTranscript
        } else {
            combined = accumulatedTranscript + " " + currentSessionText
        }
        return corrections?.apply(to: combined) ?? combined
    }
    
    // MARK: - Global Dictation (Push-to-Talk)
    
    /// Start dictation for global FN key use (no UI transcript updates).
    func startGlobalDictation() {
        Task {
            await startRecordingInternal(updateTranscriptLive: false)
        }
    }
    
    /// Stop global dictation and return the final transcript.
    /// Waits for the speech recognizer to deliver its final result before returning.
    func stopGlobalDictation() async -> String {
        userRequestedStop = true
        
        // Stop the audio engine and signal end-of-audio, but DON'T cancel the task yet.
        // Let the recognizer finish processing the buffered audio.
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        // Wait for the recognition task to deliver its final result.
        // The callback in startRecognitionTask will resume this continuation.
        await withCheckedContinuation { continuation in
            self.stopContinuation = continuation
            
            // Safety timeout — if the recognizer doesn't respond in 2 seconds, proceed anyway.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let cont = self.stopContinuation {
                    self.stopContinuation = nil
                    self.commitCurrentSession()
                    cont.resume()
                }
            }
        }
        
        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        return fullTranscript
    }
    
    // MARK: - Standard Recording
    
    func toggleRecording() {
        if isRecording {
            userRequestedStop = true
            stopAudioAndRecognition()
            isRecording = false
            transcript = fullTranscript
        } else {
            Task {
                await startRecordingInternal(updateTranscriptLive: true)
            }
        }
    }
    
    private func startRecordingInternal(updateTranscriptLive: Bool) async {
        // Guard against double-start
        if isRecording {
            return
        }
        
        // Fully clean up any prior session first
        forceCleanup()
        
        errorMessage = nil
        transcript = ""
        accumulatedTranscript = ""
        currentSessionText = ""
        userRequestedStop = false
        
        // Request speech recognition authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            errorMessage = "Speech recognition not authorized. Enable it in System Settings → Privacy & Security → Speech Recognition."
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "On-device speech recognition is not available on this device."
            return
        }
        
        // Start audio engine — always remove any stale tap first
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return
        }
        
        startRecognitionTask(updateTranscriptLive: updateTranscriptLive)
    }
    
    /// Starts (or restarts) just the recognition task.
    private func startRecognitionTask(updateTranscriptLive: Bool) {
        guard let speechRecognizer = speechRecognizer else { return }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        currentSessionText = ""
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    self.currentSessionText = result.bestTranscription.formattedString
                    
                    if updateTranscriptLive {
                        self.transcript = self.fullTranscript
                    }
                    
                    if result.isFinal {
                        self.commitCurrentSession()
                        // If we're waiting for the final result (global dictation stop), resume.
                        if let cont = self.stopContinuation {
                            self.stopContinuation = nil
                            cont.resume()
                        }
                    }
                }
                
                if let error = error {
                    self.commitCurrentSession()
                    
                    // If we're waiting for the final result, resume on error too.
                    if let cont = self.stopContinuation {
                        self.stopContinuation = nil
                        cont.resume()
                        return
                    }
                    
                    let nsError = error as NSError
                    let isCancellation = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                    
                    if !isCancellation && !self.userRequestedStop {
                        self.startRecognitionTask(updateTranscriptLive: updateTranscriptLive)
                    }
                }
            }
        }
        
        // Reconnect the audio tap to feed this new request
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
    }
    
    /// Saves current session text into the accumulated transcript.
    private func commitCurrentSession() {
        if !currentSessionText.isEmpty {
            if accumulatedTranscript.isEmpty {
                accumulatedTranscript = currentSessionText
            } else {
                accumulatedTranscript += " " + currentSessionText
            }
            currentSessionText = ""
        }
    }
    
    /// Stops the audio engine and cancels recognition.
    private func stopAudioAndRecognition() {
        forceCleanup()
        commitCurrentSession()
    }
    
    /// Hard cleanup of all audio and recognition resources.
    private func forceCleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

// MARK: - Rewrite Engine

@MainActor
final class RewriteEngine: ObservableObject {
    @Published var rewrittenText: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String? = nil
    
    var corrections: CorrectionsDictionary?
    
    func rewrite(text: String, prompt: String) async -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        isProcessing = true
        errorMessage = nil
        
        let fullPrompt = """
        You are rewriting the following text according to the user's instruction.
        \(corrections?.contextBlock() ?? "")
        INSTRUCTION: \(prompt)
        
        OUTPUT RULES:
        - Return ONLY the rewritten text
        - No explanations, no labels, no preamble
        - Do not wrap in quotes
        - Start directly with the rewritten content
        
        TEXT:
        \(text)
        """
        
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: fullPrompt)
            let result = response.content
            rewrittenText = result
            isProcessing = false
            return result
        } catch {
            errorMessage = "Rewrite failed: \(error.localizedDescription)"
            isProcessing = false
            return nil
        }
    }
}
