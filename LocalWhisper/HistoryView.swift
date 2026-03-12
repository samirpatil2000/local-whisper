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
                HistoryEmptyState()
            } else {
                HistoryListView(manager: manager, expandedEntryId: $expandedEntryId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F2F2F7"))
    }
}

// MARK: - Subviews

private struct HistoryEmptyState: View {
    var body: some View {
        Spacer()
        VStack(spacing: 8) {
            Text("No history yet")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "#8E8E93"))
            Text("Dictations and rewrites will appear here.")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#8E8E93"))
        }
        Spacer()
    }
}

private struct HistoryListView: View {
    @Bindable var manager: HistoryManager
    @Binding var expandedEntryId: UUID?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(manager.entries) { (entry: HistoryEntry) in
                    entryRow(for: entry)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    @ViewBuilder
    private func entryRow(for entry: HistoryEntry) -> some View {
        let isLast = entry.id == manager.entries.last?.id
        
        VStack(spacing: 0) {
            HistoryRow(
                entry: entry,
                isExpanded: expandedEntryId == entry.id,
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedEntryId == entry.id {
                            expandedEntryId = nil
                        } else {
                            expandedEntryId = entry.id
                        }
                    }
                }
            )
            
            if !isLast {
                Rectangle()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(height: 0.5)
                    .padding(.leading, 52)
            }
        }
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
                HStack(spacing: 16) {
                    ActionBadge(action: entry.action)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.resultText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#1C1C1E"))
                            .lineLimit(1)
                        
                        Text(entry.formattedTimestamp)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                
                // Expanded details
                if isExpanded {
                    ExpandedDetails(entry: entry, copied: $copied)
                }
            }
            .background(Color.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Expanded Details

private struct ExpandedDetails: View {
    let entry: HistoryEntry
    @Binding var copied: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color(hex: "#E5E5EA"))
                .frame(height: 0.5)
            
            if !entry.originalText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ORIGINAL")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#8E8E93"))
                    Text(entry.originalText)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#1C1C1E"))
                        .textSelection(.enabled)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("RESULT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#8E8E93"))
                Text(entry.resultText)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#1C1C1E"))
                    .textSelection(.enabled)
            }
            
            HStack {
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.resultText, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(copied ? .green : .accentColor)
                }
                .buttonStyle(.plain)
            }
            
            Rectangle()
                .fill(Color(hex: "#E5E5EA"))
                .frame(height: 0.5)
        }
        .padding(.horizontal, 52)
        .padding(.bottom, 12)
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
        case .dictation: return Color(hex: "#FF3B30")
        default: return .accentColor
        }
    }
    
    private var bgColor: Color {
        switch action {
        case .dictation: return Color(hex: "#FFF0EE")
        default: return Color(hex: "#EEF4FF")
        }
    }
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(color)
            .frame(width: 36, height: 36)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
