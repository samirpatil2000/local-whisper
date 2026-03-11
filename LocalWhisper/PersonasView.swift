import SwiftUI

struct PersonasView: View {
    @Bindable var manager: PersonaManager
    @State private var isAddingNew = false
    @State private var editingPersona: Persona?
    @State private var newName = ""
    @State private var newPrompt = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Personas")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if manager.canAdd {
                    Button(action: {
                        newName = ""
                        newPrompt = ""
                        isAddingNew = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if manager.personas.isEmpty && !isAddingNew {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No personas yet")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                    Text("Create custom rewrite styles that appear\nin the floating toolbar.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.personas) { persona in
                            PersonaCard(
                                persona: persona,
                                isEditing: editingPersona?.id == persona.id,
                                onEdit: { editingPersona = persona },
                                onSave: { updated in
                                    manager.update(updated)
                                    editingPersona = nil
                                },
                                onCancel: { editingPersona = nil },
                                onDelete: {
                                    manager.delete(persona)
                                    editingPersona = nil
                                }
                            )
                        }
                        
                        // Inline new persona editor
                        if isAddingNew {
                            PersonaEditor(
                                name: $newName,
                                prompt: $newPrompt,
                                onSave: {
                                    manager.add(name: newName, systemPrompt: newPrompt)
                                    isAddingNew = false
                                },
                                onCancel: { isAddingNew = false }
                            )
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
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

// MARK: - Persona Card

private struct PersonaCard: View {
    let persona: Persona
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (Persona) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    @State private var editName: String = ""
    @State private var editPrompt: String = ""
    
    var body: some View {
        if isEditing {
            PersonaEditor(
                name: $editName,
                prompt: $editPrompt,
                onSave: {
                    var updated = persona
                    updated.name = editName
                    updated.systemPrompt = editPrompt
                    onSave(updated)
                },
                onCancel: onCancel,
                showDelete: true,
                onDelete: onDelete
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .onAppear {
                editName = persona.name
                editPrompt = persona.systemPrompt
            }
        } else {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(persona.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(persona.systemPrompt)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Persona Editor

private struct PersonaEditor: View {
    @Binding var name: String
    @Binding var prompt: String
    let onSave: () -> Void
    let onCancel: () -> Void
    var showDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Persona Name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            
            TextEditor(text: $prompt)
                .font(.system(size: 13))
                .frame(minHeight: 60, maxHeight: 100)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            
            HStack {
                if showDelete {
                    Button("Delete") {
                        onDelete?()
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
