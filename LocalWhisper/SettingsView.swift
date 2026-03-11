import SwiftUI

struct SettingsView: View {
    @AppStorage("fnDictationEnabled") private var fnDictationEnabled = true
    @AppStorage("floatingToolbarEnabled") private var floatingToolbarEnabled = true
    @AppStorage("dictationLanguage") private var dictationLanguage = "en-US"
    
    var historyManager: HistoryManager
    var onFNToggleChanged: ((Bool) -> Void)?
    var onToolbarToggleChanged: ((Bool) -> Void)?
    
    @State private var showClearConfirmation = false
    
    private let supportedLanguages: [(code: String, name: String)] = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("en-AU", "English (Australia)"),
        ("en-IN", "English (India)"),
        ("es-ES", "Spanish"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)"),
        ("hi-IN", "Hindi"),
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                
                // MARK: - Features Section
                
                SectionHeader(title: "FEATURES")
                
                SettingsRow(
                    icon: "keyboard",
                    title: "FN Key Dictation",
                    subtitle: "Hold the FN key anywhere to dictate"
                ) {
                    Toggle("", isOn: $fnDictationEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: fnDictationEnabled) { _, newValue in
                            onFNToggleChanged?(newValue)
                        }
                }
                
                Divider().padding(.leading, 56)
                
                SettingsRow(
                    icon: "text.cursor",
                    title: "Floating Toolbar",
                    subtitle: "Show rewrite options on text selection"
                ) {
                    Toggle("", isOn: $floatingToolbarEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: floatingToolbarEnabled) { _, newValue in
                            onToolbarToggleChanged?(newValue)
                        }
                }
                
                // MARK: - Language Section
                
                SectionHeader(title: "LANGUAGE")
                    .padding(.top, 20)
                
                SettingsRow(
                    icon: "globe",
                    title: "Dictation Language",
                    subtitle: "Language for speech recognition"
                ) {
                    Picker("", selection: $dictationLanguage) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                
                // MARK: - Accessibility Section
                
                SectionHeader(title: "PERMISSIONS")
                    .padding(.top, 20)
                
                SettingsRow(
                    icon: "lock.shield",
                    title: "Accessibility",
                    subtitle: AccessibilityService.isAccessibilityEnabled()
                        ? "Granted — global features active"
                        : "Required for text selection and dictation injection"
                ) {
                    if AccessibilityService.isAccessibilityEnabled() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                    } else {
                        Button("Grant Access") {
                            AccessibilityService.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                // MARK: - Data Section
                
                SectionHeader(title: "DATA")
                    .padding(.top, 20)
                
                SettingsRow(
                    icon: "trash",
                    title: "Clear All History",
                    subtitle: "\(historyManager.entries.count) entries stored locally"
                ) {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                    .disabled(historyManager.entries.isEmpty)
                }
                
                // MARK: - About
                
                VStack(spacing: 4) {
                    Text("Local Whisper")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("On-device. Private. Instant.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Your words never leave your Mac.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Clear All History?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                historyManager.clearAll()
            }
        } message: {
            Text("This will permanently delete all dictation and rewrite history. This cannot be undone.")
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
    }
}

// MARK: - Settings Row

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            trailing()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
