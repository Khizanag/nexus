import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteModel.updatedAt, order: .reverse) private var notes: [NoteModel]

    @State private var searchText = ""
    @State private var showNewNote = false
    @State private var selectedNote: NoteModel?

    private var filteredNotes: [NoteModel] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedNotes: [NoteModel] {
        filteredNotes.filter { $0.isPinned }
    }

    private var unpinnedNotes: [NoteModel] {
        filteredNotes.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
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
            .background(Color.nexusBackground)
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewNote) {
                NoteEditorView(note: nil)
            }
            .sheet(item: $selectedNote) { note in
                NoteEditorView(note: note)
            }
        }
    }

    @ViewBuilder
    private func noteSection(title: String?, notes: [NoteModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(notes) { note in
                    NoteCard(note: note)
                        .onTapGesture {
                            selectedNote = note
                        }
                }
            }
        }
    }

    private var emptyState: some View {
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

// MARK: - Note Card

private struct NoteCard: View {
    let note: NoteModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.nexusHeadline)
                .lineLimit(2)

            Text(note.content.isEmpty ? "No content" : note.content)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Spacer(minLength: 0)

            Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.nexusCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(height: 160)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(noteColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    private var noteColor: Color {
        guard let colorName = note.color else { return .nexusSurface }
        switch colorName {
        case "purple": return .nexusPurple.opacity(0.2)
        case "blue": return .nexusBlue.opacity(0.2)
        case "green": return .nexusGreen.opacity(0.2)
        case "orange": return .nexusOrange.opacity(0.2)
        case "red": return .nexusRed.opacity(0.2)
        case "pink": return .nexusPink.opacity(0.2)
        default: return .nexusSurface
        }
    }
}

#Preview {
    NotesView()
        .preferredColorScheme(.dark)
}
