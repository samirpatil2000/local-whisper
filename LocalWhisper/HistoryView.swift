import SwiftUI

struct HistoryView: View {
    @Bindable var manager: HistoryManager
    @State private var expandedEntryId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(manager.entries.count) entries")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if manager.entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No history yet")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                    Text("Dictations and rewrites will appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.entries) { entry in
                            HistoryRow(
                                entry: entry,
                                isExpanded: expandedEntryId == entry.id,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if expandedEntryId == entry.id {
                                            expandedEntryId = nil
                                        } else {
                                            expandedEntryId = entry.id
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @State private var copied = false
    
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 0) {
                // Compact row
                HStack(spacing: 10) {
                    // Action badge
                    ActionBadge(action: entry.action)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.resultText)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? nil : 1)
                        
                        Text(entry.formattedTimestamp)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !isExpanded {
                        Text(entry.styleName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .separatorColor).opacity(0.3))
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                
                // Expanded details
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider()
                            .padding(.vertical, 6)
                        
                        if !entry.originalText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ORIGINAL")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(entry.originalText)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary.opacity(0.7))
                                    .textSelection(.enabled)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RESULT")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(entry.resultText)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.system(size: 10))
                                Text(entry.styleName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.resultText, forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copied = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                    Text(copied ? "Copied" : "Copy")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(copied ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Badge

private struct ActionBadge: View {
    let action: HistoryAction
    
    private var icon: String {
        switch action {
        case .dictation: return "mic.fill"
        case .rewrite: return "arrow.triangle.2.circlepath"
        case .formal: return "briefcase"
        case .concise: return "arrow.down.right.and.arrow.up.left"
        case .friendly: return "face.smiling"
        case .custom: return "slider.horizontal.3"
        case .persona: return "person.fill"
        }
    }
    
    private var color: Color {
        switch action {
        case .dictation: return .red
        default: return .accentColor
        }
    }
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .frame(width: 26, height: 26)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
