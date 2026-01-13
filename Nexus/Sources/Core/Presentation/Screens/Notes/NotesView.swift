import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteModel.updatedAt, order: .reverse) private var notes: [NoteModel]

    @State private var searchText = ""
    @State private var showNewNote = false
    @State private var selectedNote: NoteModel?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            scrollContent
                .background(Color.nexusBackground)
                .navigationTitle("Notes")
                .searchable(text: $searchText, prompt: "Search notes...")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showNewNote) { NoteEditorView(note: nil) }
                .sheet(item: $selectedNote) { note in NoteEditorView(note: note) }
        }
    }
}

// MARK: - Toolbar

private extension NotesView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNewNote = true } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Main Content

private extension NotesView {
    var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !pinnedNotes.isEmpty {
                    noteSection(title: "Pinned", notes: pinnedNotes)
                }

                if !unpinnedNotes.isEmpty {
                    noteSection(title: pinnedNotes.isEmpty ? nil : "All Notes", notes: unpinnedNotes)
                }

                if filteredNotes.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Sections

private extension NotesView {
    @ViewBuilder
    func noteSection(title: String?, notes: [NoteModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                sectionHeader(title)
            }
            notesGrid(notes)
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.nexusHeadline)
            .foregroundStyle(.secondary)
    }

    func notesGrid(_ notes: [NoteModel]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(notes) { note in
                NoteCard(note: note)
                    .onTapGesture { selectedNote = note }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty ? "No Notes Yet" : "No Results")
                .font(.nexusTitle3)

            Text(searchText.isEmpty ? "Tap + to create your first note" : "Try a different search")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Computed Properties

private extension NotesView {
    var filteredNotes: [NoteModel] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var pinnedNotes: [NoteModel] {
        filteredNotes.filter { $0.isPinned }
    }

    var unpinnedNotes: [NoteModel] {
        filteredNotes.filter { !$0.isPinned }
    }
}

// MARK: - Note Card

private struct NoteCard: View {
    let note: NoteModel

    var body: some View {
        HStack(spacing: 0) {
            accentStripe
            cardContent
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cardBackground }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Note Card Subviews

private extension NoteCard {
    @ViewBuilder
    var accentStripe: some View {
        if note.color != nil {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
        }
    }

    var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader
            cardTitle
            cardPreview
            Spacer(minLength: 0)
            cardDate
        }
        .padding(12)
    }

    var cardHeader: some View {
        HStack {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.nexusOrange)
            }

            Spacer()

            if note.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(Color.nexusRed)
            }
        }
    }

    var cardTitle: some View {
        Text(note.title.isEmpty ? "Untitled" : note.title)
            .font(.nexusHeadline)
            .lineLimit(2)
    }

    var cardPreview: some View {
        Text(note.content.isEmpty ? "No content" : note.content)
            .font(.nexusCaption)
            .foregroundStyle(.secondary)
            .lineLimit(4)
    }

    var cardDate: some View {
        Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
            .font(.nexusCaption2)
            .foregroundStyle(.tertiary)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(noteColor)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
    }
}

// MARK: - Note Card Colors

private extension NoteCard {
    var accentColor: Color {
        guard let colorName = note.color else { return .clear }
        return colorFromName(colorName)
    }

    var noteColor: Color {
        guard let colorName = note.color else { return .nexusSurface }
        return colorFromName(colorName).opacity(0.15)
    }

    var borderColor: Color {
        guard let colorName = note.color else { return .nexusBorder }
        return colorFromName(colorName).opacity(0.3)
    }

    func colorFromName(_ name: String) -> Color {
        switch name {
        case "purple": return .nexusPurple
        case "blue": return .nexusBlue
        case "green": return .nexusGreen
        case "orange": return .nexusOrange
        case "red": return .nexusRed
        case "pink": return .nexusPink
        default: return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    NotesView()
        .preferredColorScheme(.dark)
}
