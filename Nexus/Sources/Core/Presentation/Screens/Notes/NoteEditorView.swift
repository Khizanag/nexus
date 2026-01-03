import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let note: NoteModel?

    @State private var title: String
    @State private var content: String
    @State private var isPinned: Bool
    @State private var isFavorite: Bool
    @State private var selectedColor: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case title, content
    }

    private let colors = ["purple", "blue", "green", "orange", "red", "pink"]

    init(note: NoteModel?) {
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
        _isPinned = State(initialValue: note?.isPinned ?? false)
        _isFavorite = State(initialValue: note?.isFavorite ?? false)
        _selectedColor = State(initialValue: note?.color)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $title)
                        .font(.nexusTitle2)
                        .focused($focusedField, equals: .title)

                    Divider()

                    TextEditor(text: $content)
                        .font(.nexusBody)
                        .frame(minHeight: 300)
                        .scrollContentBackground(.hidden)
                        .focused($focusedField, equals: .content)

                    colorPicker
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(note == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            isPinned.toggle()
                        } label: {
                            Image(systemName: isPinned ? "pin.fill" : "pin")
                                .foregroundStyle(isPinned ? Color.nexusOrange : Color.secondary)
                        }

                        Button {
                            isFavorite.toggle()
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(isFavorite ? Color.nexusRed : Color.secondary)
                        }

                        Button("Save") {
                            saveNote()
                        }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty && content.isEmpty)
                    }
                }
            }
            .onAppear {
                if note == nil {
                    focusedField = .title
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(colorValue(for: color))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                            }
                        }
                        .onTapGesture {
                            selectedColor = selectedColor == color ? nil : color
                        }
                }

                Circle()
                    .fill(Color.nexusSurface)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if selectedColor == nil {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        } else {
                            Circle()
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                    }
                    .onTapGesture {
                        selectedColor = nil
                    }
            }
        }
    }

    private func colorValue(for name: String) -> Color {
        switch name {
        case "purple": .nexusPurple
        case "blue": .nexusBlue
        case "green": .nexusGreen
        case "orange": .nexusOrange
        case "red": .nexusRed
        case "pink": .nexusPink
        default: .nexusSurface
        }
    }

    private func saveNote() {
        if let existingNote = note {
            existingNote.title = title
            existingNote.content = content
            existingNote.isPinned = isPinned
            existingNote.isFavorite = isFavorite
            existingNote.color = selectedColor
            existingNote.updatedAt = .now
        } else {
            let newNote = NoteModel(
                title: title,
                content: content,
                isPinned: isPinned,
                isFavorite: isFavorite,
                color: selectedColor
            )
            modelContext.insert(newNote)
        }

        dismiss()
    }
}

#Preview {
    NoteEditorView(note: nil)
        .preferredColorScheme(.dark)
}
