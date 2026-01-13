import SwiftUI
import SwiftData

struct PersonEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PersonModel.name) private var existingPeople: [PersonModel]

    let person: PersonModel?

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedColor = "#8B5CF6"

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, phone
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                contactSection
                colorSection
                previewSection

                if isEditing {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(isEditing ? "Edit Person" : "New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { handleOnAppear() }
        }
    }
}

// MARK: - Toolbar

private extension PersonEditorView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .disabled(!canSave)
        }
    }
}

// MARK: - Form Sections

private extension PersonEditorView {
    var nameSection: some View {
        Section {
            TextField("Name", text: $name)
                .font(.nexusBody)
                .focused($focusedField, equals: .name)

            duplicateNameWarning
        } header: {
            Text("Name")
        }
    }

    @ViewBuilder
    var duplicateNameWarning: some View {
        if isDuplicateName, !trimmedName.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                Text("A person with this name already exists")
                    .font(.nexusCaption)
            }
            .foregroundStyle(.red)
        }
    }

    var contactSection: some View {
        Section {
            emailField
            phoneField
        } header: {
            Text("Contact Info (Optional)")
        }
    }

    var emailField: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 14))
                .foregroundStyle(email.isEmpty ? Color.gray.opacity(0.5) : Color.nexusBlue)
                .frame(width: 20)

            TextField("Email", text: $email)
                .font(.nexusBody)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
        }
    }

    var phoneField: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 14))
                .foregroundStyle(phone.isEmpty ? Color.gray.opacity(0.5) : Color.nexusGreen)
                .frame(width: 20)

            TextField("Phone", text: $phone)
                .font(.nexusBody)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .phone)
        }
    }

    var colorSection: some View {
        Section {
            colorGrid
        } header: {
            Text("Color")
        }
    }

    var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(PersonModel.defaultColors, id: \.self) { colorHex in
                colorButton(colorHex)
            }
        }
        .padding(.vertical, 8)
    }

    func colorButton(_ colorHex: String) -> some View {
        let color = Color(hex: colorHex) ?? .nexusPurple

        return Button {
            withAnimation(.spring(response: 0.2)) {
                selectedColor = colorHex
            }
        } label: {
            colorButtonContent(color: color, isSelected: selectedColor == colorHex)
        }
        .buttonStyle(.plain)
    }

    func colorButtonContent(color: Color, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)

            if isSelected {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    var previewSection: some View {
        Section {
            previewContent
        } header: {
            Text("Preview")
        }
    }

    var previewContent: some View {
        HStack(spacing: 14) {
            previewAvatar
            previewInfo
            Spacer()
        }
        .padding(.vertical, 4)
    }

    var previewAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: selectedColor) ?? .nexusPurple)
                .frame(width: 50, height: 50)

            Text(previewInitials)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    var previewInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name.isEmpty ? "Person Name" : name)
                .font(.nexusHeadline)
                .foregroundStyle(name.isEmpty ? .secondary : .primary)

            previewSubtitle
        }
    }

    @ViewBuilder
    var previewSubtitle: some View {
        if !email.isEmpty {
            Text(email)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        } else if !phone.isEmpty {
            Text(phone)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                deletePerson()
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Person")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Computed Properties

private extension PersonEditorView {
    var isEditing: Bool {
        person != nil
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isDuplicateName: Bool {
        let lowercasedName = trimmedName.lowercased()
        return existingPeople.contains { existingPerson in
            if let person, existingPerson.id == person.id {
                return false
            }
            return existingPerson.name.lowercased() == lowercasedName
        }
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    var previewInitials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

// MARK: - Actions

private extension PersonEditorView {
    func handleOnAppear() {
        if let person {
            name = person.name
            email = person.email ?? ""
            phone = person.phone ?? ""
            selectedColor = person.colorHex
        } else {
            focusedField = .name
            selectedColor = PersonModel.defaultColors.randomElement() ?? "#8B5CF6"
        }
    }

    func save() {
        guard canSave else { return }

        if let person {
            updateExistingPerson(person)
        } else {
            createNewPerson()
        }

        dismiss()
    }

    func updateExistingPerson(_ person: PersonModel) {
        person.name = trimmedName
        person.email = email.isEmpty ? nil : email
        person.phone = phone.isEmpty ? nil : phone
        person.colorHex = selectedColor
    }

    func createNewPerson() {
        let newPerson = PersonModel(
            name: trimmedName,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            colorHex: selectedColor
        )
        modelContext.insert(newPerson)
    }

    func deletePerson() {
        if let person {
            modelContext.delete(person)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PersonEditorView(person: nil)
        .preferredColorScheme(.dark)
}
