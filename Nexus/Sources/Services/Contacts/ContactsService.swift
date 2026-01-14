import Contacts

struct ImportedContact: Identifiable {
    let id = UUID()
    let identifier: String
    let name: String
    let email: String?
    let phone: String?
}

enum ContactsService {
    static func requestAccess() async -> CNAuthorizationStatus {
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)

        if currentStatus == .notDetermined {
            let store = CNContactStore()
            do {
                let granted = try await store.requestAccess(for: .contacts)
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }
        }

        return currentStatus
    }

    static func fetchContacts(excluding existingIds: Set<String>) async throws -> [ImportedContact] {
        let store = CNContactStore()

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [ImportedContact] = []

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        guard !existingIds.contains(contact.identifier) else { return }

                        let name = [contact.givenName, contact.familyName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")

                        guard !name.isEmpty else { return }

                        let email = contact.emailAddresses.first?.value as String?
                        let phone = contact.phoneNumbers.first?.value.stringValue

                        contacts.append(ImportedContact(
                            identifier: contact.identifier,
                            name: name,
                            email: email,
                            phone: phone
                        ))
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return contacts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
