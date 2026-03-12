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
                    Button("New") {
                        newName = ""
                        newPrompt = ""
                        isAddingNew = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if manager.personas.isEmpty && !isAddingNew {
                Spacer()
                VStack(spacing: 8) {
                    Text("No personas yet")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "#8E8E93"))
                    Text("Tap + to create a custom rewrite style.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.personas) { persona in
                            PersonaCard(
                                persona: persona,
                                onEdit: { editingPersona = persona },
                                onDelete: { manager.delete(persona) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F2F2F7"))
        .sheet(isPresented: $isAddingNew) {
            PersonaEditor(
                name: $newName,
                prompt: $newPrompt,
                onSave: {
                    manager.add(name: newName, systemPrompt: newPrompt)
                    isAddingNew = false
                },
                onCancel: { isAddingNew = false }
            )
        }
        .sheet(item: $editingPersona) { persona in
            PersonaEditor(
                name: Binding(
                    get: { persona.name },
                    set: { editingPersona?.name = $0 }
                ),
                prompt: Binding(
                    get: { persona.systemPrompt },
                    set: { editingPersona?.systemPrompt = $0 }
                ),
                onSave: {
                    if let p = editingPersona {
                        manager.update(p)
                    }
                    editingPersona = nil
                },
                onCancel: { editingPersona = nil }
            )
        }
    }
}

// MARK: - Persona Card

private struct PersonaCard: View {
    let persona: Persona
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(persona.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#1C1C1E"))
                
                Text(persona.systemPrompt)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#8E8E93"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isHovering {
                Button(action: onDelete) {
                    Text("Delete")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isHovering ? Color(hex: "#F9F9F9") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Persona Editor

private struct PersonaEditor: View {
    @Binding var name: String
    @Binding var prompt: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var isAppearing = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.bottom, 8)
                    .overlay(
                        Rectangle().fill(Color(hex: "#E5E5EA")).frame(height: 0.5),
                        alignment: .bottom
                    )
                
                ZStack(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Describe how this persona rewrites text…")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#8E8E93"))
                            .padding(.top, 4)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $prompt)
                        .font(.system(size: 13))
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .overlay(
                    Rectangle().fill(Color(hex: "#E5E5EA")).frame(height: 0.5),
                    alignment: .bottom
                )
            }
            .padding(20)
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#8E8E93"))
                .padding(.trailing, 16)
                
                Button(action: onSave) {
                    Text("Save")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 36)
                        .background(
                            (name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ?
                            Color.accentColor.opacity(0.5) : Color.accentColor
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 360)
        .background(Color.white)
        .scaleEffect(isAppearing ? 1.0 : 0.95)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
    }
}
