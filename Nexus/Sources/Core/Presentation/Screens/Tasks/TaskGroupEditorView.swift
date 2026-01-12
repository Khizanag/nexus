import SwiftUI
import SwiftData

struct TaskGroupEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskGroupModel.order) private var existingGroups: [TaskGroupModel]

    let group: TaskGroupModel?

    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "#8B5CF6"

    private var isEditing: Bool { group != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                        .font(.nexusBody)
                } header: {
                    Text("Name")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(TaskGroupModel.defaultIcons, id: \.self) { icon in
                            iconButton(icon)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(TaskGroupModel.defaultColors, id: \.self) { color in
                            colorButton(color)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                // Preview
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill((Color(hex: selectedColor) ?? .nexusPurple).opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: selectedIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: selectedColor) ?? .nexusPurple)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Project Name" : name)
                                .font(.nexusHeadline)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)

                            Text("0 tasks")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Preview")
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteGroup()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Project")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let group {
                    name = group.name
                    selectedIcon = group.icon
                    selectedColor = group.colorHex
                }
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.2)) {
                selectedIcon = icon
            }
        } label: {
            ZStack {
                Circle()
                    .fill(selectedIcon == icon
                        ? (Color(hex: selectedColor) ?? .nexusPurple).opacity(0.2)
                        : Color.nexusSurface
                    )
                    .frame(width: 48, height: 48)

                if selectedIcon == icon {
                    Circle()
                        .strokeBorder(Color(hex: selectedColor) ?? .nexusPurple, lineWidth: 2)
                        .frame(width: 48, height: 48)
                }

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedIcon == icon
                        ? (Color(hex: selectedColor) ?? .nexusPurple)
                        : .secondary
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func colorButton(_ colorHex: String) -> some View {
        let color = Color(hex: colorHex) ?? .nexusPurple

        return Button {
            withAnimation(.spring(response: 0.2)) {
                selectedColor = colorHex
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)

                if selectedColor == colorHex {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let group {
            group.name = trimmedName
            group.icon = selectedIcon
            group.colorHex = selectedColor
        } else {
            let newGroup = TaskGroupModel(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor,
                order: existingGroups.count
            )
            modelContext.insert(newGroup)
        }

        dismiss()
    }

    private func deleteGroup() {
        if let group {
            modelContext.delete(group)
        }
        dismiss()
    }
}

#Preview {
    TaskGroupEditorView(group: nil)
        .preferredColorScheme(.dark)
}
