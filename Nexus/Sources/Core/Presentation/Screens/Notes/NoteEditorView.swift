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
    @State private var showColorPicker = false
    @State private var previousContent: String = ""

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
                        .onChange(of: content) { oldValue, newValue in
                            handleContentChange(oldValue: oldValue, newValue: newValue)
                        }
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(noteBackgroundColor)
            .safeAreaInset(edge: .bottom) {
                formattingToolbar
            }
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

    private var noteBackgroundColor: Color {
        guard let colorName = selectedColor else { return .nexusBackground }
        switch colorName {
        case "purple": return .nexusPurple.opacity(0.08)
        case "blue": return .nexusBlue.opacity(0.08)
        case "green": return .nexusGreen.opacity(0.08)
        case "orange": return .nexusOrange.opacity(0.08)
        case "red": return .nexusRed.opacity(0.08)
        case "pink": return .nexusPink.opacity(0.08)
        default: return .nexusBackground
        }
    }

    private var formattingToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            if showColorPicker {
                colorPickerRow
                Divider()
            }

            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        FormatButton(icon: "list.bullet", tooltip: "Bullet List") {
                            insertBulletList()
                        }

                        FormatButton(icon: "list.number", tooltip: "Numbered List") {
                            insertNumberedList()
                        }

                        FormatButton(icon: "checklist", tooltip: "Checklist") {
                            insertChecklist()
                        }

                        Divider()
                            .frame(height: 20)
                            .padding(.horizontal, 8)

                        FormatButton(icon: "arrow.right.to.line.compact", tooltip: "Indent") {
                            insertIndent()
                        }

                        FormatButton(icon: "text.quote", tooltip: "Quote") {
                            insertQuote()
                        }

                        FormatButton(icon: "minus", tooltip: "Separator") {
                            insertSeparator()
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Divider()
                    .frame(height: 24)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showColorPicker.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedColor != nil ? colorValue(for: selectedColor!) : Color.nexusSurface)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.nexusBorder, lineWidth: 1)
                            }

                        Image(systemName: showColorPicker ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44)
            .background(Color.nexusSurface)
        }
    }

    private var colorPickerRow: some View {
        HStack(spacing: 16) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(colorValue(for: color))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if selectedColor == color {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedColor = selectedColor == color ? nil : color
                        }
                    }
            }

            Circle()
                .fill(Color.nexusSurface)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
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
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedColor = nil
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.nexusSurface.opacity(0.8))
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
}

// MARK: - Formatting Actions

private extension NoteEditorView {
    func insertBulletList() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "• "
        } else {
            content += "\n• "
        }
        focusedField = .content
    }

    func insertNumberedList() {
        let lines = content.components(separatedBy: "\n")
        var maxNumber = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let dotIndex = trimmed.firstIndex(of: "."),
               let num = Int(trimmed[..<dotIndex]) {
                maxNumber = max(maxNumber, num)
            }
        }
        let nextNumber = maxNumber + 1

        if content.isEmpty || content.hasSuffix("\n") {
            content += "\(nextNumber). "
        } else {
            content += "\n\(nextNumber). "
        }
        focusedField = .content
    }

    func insertChecklist() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "☐ "
        } else {
            content += "\n☐ "
        }
        focusedField = .content
    }

    func insertIndent() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "    "
        } else {
            content += "\n    "
        }
        focusedField = .content
    }

    func insertQuote() {
        if content.isEmpty || content.hasSuffix("\n") {
            content += "> "
        } else {
            content += "\n> "
        }
        focusedField = .content
    }

    func insertSeparator() {
        if content.isEmpty {
            content = "---\n"
        } else if content.hasSuffix("\n") {
            content += "---\n"
        } else {
            content += "\n---\n"
        }
        focusedField = .content
    }

    func handleContentChange(oldValue: String, newValue: String) {
        guard newValue.count > oldValue.count else { return }
        guard newValue.hasSuffix("\n") else { return }
        guard !oldValue.hasSuffix("\n") else { return }

        let lines = oldValue.components(separatedBy: "\n")
        guard let lastLine = lines.last, !lastLine.isEmpty else { return }

        let trimmedLine = lastLine.trimmingCharacters(in: .whitespaces)

        if trimmedLine == "•" || trimmedLine == "☐" || trimmedLine == "☑" || trimmedLine == ">" {
            content = oldValue.dropLast(lastLine.count).description + "\n"
            return
        }

        if let dotIndex = trimmedLine.firstIndex(of: "."),
           dotIndex != trimmedLine.startIndex,
           let num = Int(trimmedLine[..<dotIndex]),
           trimmedLine.dropFirst(trimmedLine.distance(from: trimmedLine.startIndex, to: dotIndex) + 1).trimmingCharacters(in: .whitespaces).isEmpty {
            content = oldValue.dropLast(lastLine.count).description + "\n"
            return
        }

        if trimmedLine.hasPrefix("• ") {
            content = newValue + "• "
        } else if trimmedLine.hasPrefix("☐ ") {
            content = newValue + "☐ "
        } else if trimmedLine.hasPrefix("☑ ") {
            content = newValue + "☐ "
        } else if trimmedLine.hasPrefix("> ") {
            content = newValue + "> "
        } else if let dotIndex = trimmedLine.firstIndex(of: "."),
                  dotIndex != trimmedLine.startIndex,
                  let num = Int(trimmedLine[..<dotIndex]) {
            let afterDot = trimmedLine.index(after: dotIndex)
            if afterDot < trimmedLine.endIndex, trimmedLine[afterDot] == " " {
                content = newValue + "\(num + 1). "
            }
        }
    }
}

// MARK: - Actions

private extension NoteEditorView {
    func saveNote() {
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

// MARK: - Format Button

private struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.nexusBackground.opacity(0.5))
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NoteEditorView(note: nil)
        .preferredColorScheme(.dark)
}
