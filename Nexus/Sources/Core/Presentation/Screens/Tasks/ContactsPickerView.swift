import SwiftUI

struct ContactsPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let existingContactIds: Set<String>
    let onSelect: ([ImportedContact]) -> Void

    @State private var contacts: [ImportedContact] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Select Contacts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .searchable(text: $searchText, prompt: "Search contacts")
                .task { await loadContacts() }
        }
    }
}

// MARK: - Toolbar

private extension ContactsPickerView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Add") { addSelectedContacts() }
                .fontWeight(.semibold)
                .disabled(selectedIds.isEmpty)
        }
    }
}

// MARK: - Content

private extension ContactsPickerView {
    @ViewBuilder
    var content: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if contacts.isEmpty {
            emptyView
        } else {
            contactsList
        }
    }

    var loadingView: some View {
        ProgressView("Loading contacts...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Unable to Load Contacts")
                .font(.nexusHeadline)

            Text(message)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await loadContacts() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("All Contacts Imported")
                .font(.nexusHeadline)

            Text("All your contacts have already been added to your people list.")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    var contactsList: some View {
        List {
            selectionHeader

            ForEach(filteredContacts) { contact in
                contactRow(contact)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Contact Row

private extension ContactsPickerView {
    var selectionHeader: some View {
        Section {
            HStack {
                Text("\(selectedIds.count) selected")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if selectedIds.isEmpty {
                    Button("Select All") { selectAll() }
                        .font(.nexusSubheadline)
                } else {
                    Button("Deselect All") { deselectAll() }
                        .font(.nexusSubheadline)
                }
            }
        }
    }

    func contactRow(_ contact: ImportedContact) -> some View {
        HStack(spacing: 12) {
            contactAvatar(contact)
            contactInfo(contact)
            Spacer()
            selectionIndicator(contact)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(contact)
        }
    }

    func contactAvatar(_ contact: ImportedContact) -> some View {
        Text(initials(for: contact.name))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.nexusBlue))
    }

    func contactInfo(_ contact: ImportedContact) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(contact.name)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if let email = contact.email, !email.isEmpty {
                Text(email)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            } else if let phone = contact.phone, !phone.isEmpty {
                Text(phone)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func selectionIndicator(_ contact: ImportedContact) -> some View {
        if selectedIds.contains(contact.id) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.nexusGreen)
        } else {
            Circle()
                .strokeBorder(Color.nexusBorder, lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Computed Properties

private extension ContactsPickerView {
    var filteredContacts: [ImportedContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            contact.email?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.phone?.contains(searchText) == true
        }
    }
}

// MARK: - Actions

private extension ContactsPickerView {
    func loadContacts() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedContacts = try await ContactsService.fetchContacts(excluding: existingContactIds)
            await MainActor.run {
                contacts = fetchedContacts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func toggleSelection(_ contact: ImportedContact) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedIds.contains(contact.id) {
                selectedIds.remove(contact.id)
            } else {
                selectedIds.insert(contact.id)
            }
        }
    }

    func selectAll() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedIds = Set(filteredContacts.map { $0.id })
        }
    }

    func deselectAll() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedIds.removeAll()
        }
    }

    func addSelectedContacts() {
        let selected = contacts.filter { selectedIds.contains($0.id) }
        onSelect(selected)
        dismiss()
    }
}

// MARK: - Helpers

private extension ContactsPickerView {
    func initials(for name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

// MARK: - Preview

#Preview {
    ContactsPickerView(existingContactIds: []) { contacts in
        print("Selected: \(contacts.count)")
    }
    .preferredColorScheme(.dark)
}
