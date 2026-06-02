import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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
                .padding(DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .background(noteBackgroundColor)
            .navigationTitle(note == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                navigationBarLeading
                navigationBarTrailing
                keyboardToolbar
            }
            .sheet(isPresented: $showColorPicker) {
                colorPickerSheet
            }
            .onAppear {
                if note == nil {
                    focusedField = .title
                }
            }
        }
    }
}

// MARK: - Toolbar

private extension NoteEditorView {
    @ToolbarContentBuilder
    var navigationBarLeading: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
    }

    @ToolbarContentBuilder
    var navigationBarTrailing: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    isPinned.toggle()
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(isPinned ? Color.nexusOrange : Color.secondary)
                }
                .accessibilityLabel(isPinned ? "Unpin note" : "Pin note")

                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.nexusRed : Color.secondary)
                }
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button("Save") { saveNote() }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty && content.isEmpty)
            }
        }
    }

    @ToolbarContentBuilder
    var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            GlassEffectContainer(spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    FormatButton(icon: "list.bullet", label: "Bullet list") { insertBulletList() }
                    FormatButton(icon: "list.number", label: "Numbered list") { insertNumberedList() }
                    FormatButton(icon: "checklist", label: "Checklist") { insertChecklist() }
                    FormatButton(icon: "arrow.right.to.line.compact", label: "Indent") { insertIndent() }
                    FormatButton(icon: "text.quote", label: "Quote") { insertQuote() }
                    FormatButton(icon: "minus", label: "Separator") { insertSeparator() }
                }
            }

            Spacer()

            Button {
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
                withAnimation(animation) { showColorPicker = true }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Circle()
                        .fill(selectedColor.map(colorValue(for:)) ?? Color.nexusSurface)
                        .frame(
                            width: DesignSystem.Size.Avatar.sm,
                            height: DesignSystem.Size.Avatar.sm
                        )
                        .overlay { Circle().strokeBorder(Color.nexusBorder, lineWidth: 1) }
                    Image(systemName: "chevron.up")
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.glass)
            .accessibilityLabel(selectedColor.map { "Note color: \($0)" } ?? "Note color: none")
        }
    }
}

// MARK: - Color Picker Sheet

private extension NoteEditorView {
    var colorPickerSheet: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Note Color")
                .font(.nexusHeadline)
                .padding(.top, DesignSystem.Spacing.md)

            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(colors, id: \.self) { color in
                    colorSwatch(color)
                }
                clearColorSwatch
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.bottom, DesignSystem.Spacing.xl)
        .presentationDetents([.height(160)])
        .presentationDragIndicator(.visible)
        .background(Color.nexusSurface)
    }

    func colorSwatch(_ color: String) -> some View {
        Button {
            let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.15)
            withAnimation(animation) {
                selectedColor = selectedColor == color ? nil : color
            }
        } label: {
            Circle()
                .fill(colorValue(for: color))
                .frame(
                    width: DesignSystem.Size.Avatar.sm,
                    height: DesignSystem.Size.Avatar.sm
                )
                .overlay {
                    if selectedColor == color {
                        Circle()
                            .strokeBorder(Color.nexusOnAccent, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(color.capitalized)
        .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
    }

    var clearColorSwatch: some View {
        Button {
            let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.15)
            withAnimation(animation) { selectedColor = nil }
        } label: {
            Circle()
                .fill(Color.nexusSurface)
                .frame(
                    width: DesignSystem.Size.Avatar.sm,
                    height: DesignSystem.Size.Avatar.sm
                )
                .overlay {
                    Image(systemName: "xmark")
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            selectedColor == nil ? Color.nexusOnAccent : Color.nexusBorder,
                            lineWidth: selectedColor == nil ? 2 : 1
                        )
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("No color")
        .accessibilityAddTraits(selectedColor == nil ? .isSelected : [])
    }
}

// MARK: - Background Color

private extension NoteEditorView {
    var noteBackgroundColor: Color {
        guard let colorName = selectedColor else { return .nexusBackground }
        return colorValue(for: colorName).opacity(0.08)
    }

    func colorValue(for name: String) -> Color {
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
           Int(trimmedLine[..<dotIndex]) != nil,
           trimmedLine.dropFirst(trimmedLine.distance(from: trimmedLine.startIndex, to: dotIndex) + 1)
               .trimmingCharacters(in: .whitespaces).isEmpty {
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
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.nexusBody)
                .frame(
                    width: DesignSystem.Size.Button.compact,
                    height: DesignSystem.Size.Button.compact
                )
        }
        .buttonStyle(.glass)
        .accessibilityLabel(label)
    }
}

// MARK: - Preview

#Preview {
    NoteEditorView(note: nil)
}
