import Foundation
import SwiftData

// MARK: - House Model

@Model
final class HouseModel {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var city: String = "თბილისი"
    var district: String?
    var apartmentNumber: String?
    var floor: Int?
    var area: Double?
    var icon: String = "house.fill"
    var color: String = "blue"
    var isPrimary: Bool = false
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \UtilityAccountModel.house)
    var utilities: [UtilityAccountModel]?

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        city: String = "თბილისი",
        district: String? = nil,
        apartmentNumber: String? = nil,
        floor: Int? = nil,
        area: Double? = nil,
        icon: String = "house.fill",
        color: String = "blue",
        isPrimary: Bool = false,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.district = district
        self.apartmentNumber = apartmentNumber
        self.floor = floor
        self.area = area
        self.icon = icon
        self.color = color
        self.isPrimary = isPrimary
        self.notes = notes
        self.createdAt = createdAt
    }

    var activeUtilities: [UtilityAccountModel] {
        (utilities ?? []).filter { $0.isActive }
    }

    var totalMonthlyEstimate: Double {
        activeUtilities.reduce(0) { $0 + $1.monthlyAverage }
    }

    var pendingPaymentsCount: Int {
        activeUtilities.filter { $0.hasPendingPayment }.count
    }
}

// MARK: - Utility Account Model

@Model
final class UtilityAccountModel {
    var id: UUID = UUID()
    var type: UtilityType = UtilityType.other
    var provider: String = ""
    var providerIcon: String = "bolt.fill"
    var customerId: String = ""
    var accountNumber: String?
    var meterNumber: String?
    var contractNumber: String?
    var phoneNumber: String?
    var isActive: Bool = true
    var monthlyAverage: Double = 0
    var lastPaymentAmount: Double?
    var lastPaymentDate: Date?
    var nextDueDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()
    var house: HouseModel?

    @Relationship(deleteRule: .cascade, inverse: \UtilityPaymentModel.utility)
    var payments: [UtilityPaymentModel]?

    @Relationship(deleteRule: .cascade, inverse: \UtilityReadingModel.utility)
    var readings: [UtilityReadingModel]?

    init(
        id: UUID = UUID(),
        type: UtilityType,
        provider: String,
        providerIcon: String = "bolt.fill",
        customerId: String,
        accountNumber: String? = nil,
        meterNumber: String? = nil,
        contractNumber: String? = nil,
        phoneNumber: String? = nil,
        isActive: Bool = true,
        monthlyAverage: Double = 0,
        notes: String = "",
        createdAt: Date = .now,
        house: HouseModel? = nil
    ) {
        self.id = id
        self.type = type
        self.provider = provider
        self.providerIcon = providerIcon
        self.customerId = customerId
        self.accountNumber = accountNumber
        self.meterNumber = meterNumber
        self.contractNumber = contractNumber
        self.phoneNumber = phoneNumber
        self.isActive = isActive
        self.monthlyAverage = monthlyAverage
        self.notes = notes
        self.createdAt = createdAt
        self.house = house
    }

    var hasPendingPayment: Bool {
        guard let nextDue = nextDueDate else { return false }
        return nextDue <= Date().addingTimeInterval(7 * 24 * 3600)
    }

    var isOverdue: Bool {
        guard let nextDue = nextDueDate else { return false }
        return nextDue < Date()
    }

    var daysUntilDue: Int? {
        guard let nextDue = nextDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextDue).day
    }

    var lastReading: UtilityReadingModel? {
        readings?.sorted { $0.date > $1.date }.first
    }

    func recordPayment(amount: Double, date: Date = .now, notes: String = "") {
        let payment = UtilityPaymentModel(
            amount: amount,
            date: date,
            notes: notes,
            utility: self
        )

        if payments == nil {
            payments = [payment]
        } else {
            payments?.append(payment)
        }

        lastPaymentAmount = amount
        lastPaymentDate = date

        if let nextDue = nextDueDate {
            self.nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: nextDue)
        }

        updateMonthlyAverage()
    }

    func recordReading(value: Double, date: Date = .now) {
        let reading = UtilityReadingModel(
            value: value,
            date: date,
            utility: self
        )

        if readings == nil {
            readings = [reading]
        } else {
            readings?.append(reading)
        }
    }

    private func updateMonthlyAverage() {
        let recentPayments = (payments ?? [])
            .sorted { $0.date > $1.date }
            .prefix(6)

        if !recentPayments.isEmpty {
            monthlyAverage = recentPayments.reduce(0) { $0 + $1.amount } / Double(recentPayments.count)
        }
    }
}

// MARK: - Utility Type

enum UtilityType: String, Codable, CaseIterable, Identifiable {
    case electricity
    case water
    case gas
    case internet
    case tv
    case phone
    case cleaning
    case security
    case parking
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .electricity: "ელექტროენერგია"
        case .water: "წყალი"
        case .gas: "გაზი"
        case .internet: "ინტერნეტი"
        case .tv: "ტელევიზია"
        case .phone: "ტელეფონი"
        case .cleaning: "დასუფთავება"
        case .security: "დაცვა"
        case .parking: "პარკინგი"
        case .other: "სხვა"
        }
    }

    var displayNameEnglish: String {
        switch self {
        case .electricity: "Electricity"
        case .water: "Water"
        case .gas: "Natural Gas"
        case .internet: "Internet"
        case .tv: "TV"
        case .phone: "Phone"
        case .cleaning: "Cleaning"
        case .security: "Security"
        case .parking: "Parking"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .electricity: "bolt.fill"
        case .water: "drop.fill"
        case .gas: "flame.fill"
        case .internet: "wifi"
        case .tv: "tv.fill"
        case .phone: "phone.fill"
        case .cleaning: "trash.fill"
        case .security: "shield.fill"
        case .parking: "car.fill"
        case .other: "wrench.fill"
        }
    }

    var color: String {
        switch self {
        case .electricity: "yellow"
        case .water: "blue"
        case .gas: "orange"
        case .internet: "purple"
        case .tv: "red"
        case .phone: "green"
        case .cleaning: "brown"
        case .security: "gray"
        case .parking: "cyan"
        case .other: "gray"
        }
    }

    var hasReadings: Bool {
        switch self {
        case .electricity, .water, .gas: true
        default: false
        }
    }
}

// MARK: - Utility Payment Model

@Model
final class UtilityPaymentModel {
    var id: UUID = UUID()
    var amount: Double = 0
    var date: Date = Date()
    var paymentMethod: String?
    var receiptNumber: String?
    var notes: String = ""
    var utility: UtilityAccountModel?

    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = .now,
        paymentMethod: String? = nil,
        receiptNumber: String? = nil,
        notes: String = "",
        utility: UtilityAccountModel? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.receiptNumber = receiptNumber
        self.notes = notes
        self.utility = utility
    }
}

// MARK: - Utility Reading Model

@Model
final class UtilityReadingModel {
    var id: UUID = UUID()
    var value: Double = 0
    var date: Date = Date()
    var photo: Data?
    var notes: String = ""
    var utility: UtilityAccountModel?

    init(
        id: UUID = UUID(),
        value: Double,
        date: Date = .now,
        photo: Data? = nil,
        notes: String = "",
        utility: UtilityAccountModel? = nil
    ) {
        self.id = id
        self.value = value
        self.date = date
        self.photo = photo
        self.notes = notes
        self.utility = utility
    }

    var consumption: Double? {
        guard let utility = utility,
              let readings = utility.readings?.sorted(by: { $0.date < $1.date }),
              let index = readings.firstIndex(where: { $0.id == self.id }),
              index > 0 else { return nil }

        return value - readings[index - 1].value
    }
}

// MARK: - Georgian Utility Providers

struct GeorgianUtilityProvider: Identifiable {
    let id = UUID()
    let name: String
    let nameGeorgian: String
    let type: UtilityType
    let icon: String
    let website: String?
    let phone: String?
    let customerIdFormat: String

    static let all: [GeorgianUtilityProvider] = [
        // Electricity
        GeorgianUtilityProvider(
            name: "Telasi",
            nameGeorgian: "თელასი",
            type: .electricity,
            icon: "bolt.fill",
            website: "https://telasi.ge",
            phone: "0322 77 77 07",
            customerIdFormat: "10-digit customer ID"
        ),
        GeorgianUtilityProvider(
            name: "Energo-Pro Georgia",
            nameGeorgian: "ენერგო-პრო ჯორჯია",
            type: .electricity,
            icon: "bolt.fill",
            website: "https://energo-pro.ge",
            phone: "2 100 100",
            customerIdFormat: "Customer number"
        ),

        // Water
        GeorgianUtilityProvider(
            name: "GWP",
            nameGeorgian: "საქართველოს წყალი და ენერგია",
            type: .water,
            icon: "drop.fill",
            website: "https://gwp.ge",
            phone: "0322 93 11 11",
            customerIdFormat: "10-digit subscriber code"
        ),

        // Gas
        GeorgianUtilityProvider(
            name: "Socar Georgia Gas",
            nameGeorgian: "სოკარ ჯორჯია გაზი",
            type: .gas,
            icon: "flame.fill",
            website: "https://socar.ge",
            phone: "0322 24 44 44",
            customerIdFormat: "Customer ID"
        ),
        GeorgianUtilityProvider(
            name: "KazTransGas Tbilisi",
            nameGeorgian: "ყაზტრანსგაზ თბილისი",
            type: .gas,
            icon: "flame.fill",
            website: nil,
            phone: "0322 94 00 04",
            customerIdFormat: "Subscriber number"
        ),

        // Internet & TV
        GeorgianUtilityProvider(
            name: "Magticom",
            nameGeorgian: "მაგთიკომი",
            type: .internet,
            icon: "wifi",
            website: "https://magticom.ge",
            phone: "*100",
            customerIdFormat: "Phone number or account ID"
        ),
        GeorgianUtilityProvider(
            name: "Silknet",
            nameGeorgian: "სილქნეტი",
            type: .internet,
            icon: "wifi",
            website: "https://silknet.com",
            phone: "100",
            customerIdFormat: "Account number"
        ),
        GeorgianUtilityProvider(
            name: "Beeline",
            nameGeorgian: "ბილაინი",
            type: .internet,
            icon: "wifi",
            website: "https://beeline.ge",
            phone: "*111",
            customerIdFormat: "Phone number"
        ),

        // TV
        GeorgianUtilityProvider(
            name: "Silknet TV",
            nameGeorgian: "სილქნეტი TV",
            type: .tv,
            icon: "tv.fill",
            website: "https://silknet.com",
            phone: "100",
            customerIdFormat: "Account number"
        ),
        GeorgianUtilityProvider(
            name: "Magti TV",
            nameGeorgian: "მაგთი TV",
            type: .tv,
            icon: "tv.fill",
            website: "https://magticom.ge",
            phone: "*100",
            customerIdFormat: "Account ID"
        ),

        // Phone
        GeorgianUtilityProvider(
            name: "Magticom Mobile",
            nameGeorgian: "მაგთიკომი მობაილი",
            type: .phone,
            icon: "phone.fill",
            website: "https://magticom.ge",
            phone: "*100",
            customerIdFormat: "Phone number"
        ),
        GeorgianUtilityProvider(
            name: "Silknet Mobile",
            nameGeorgian: "სილქნეტ მობაილი",
            type: .phone,
            icon: "phone.fill",
            website: "https://silknet.com",
            phone: "100",
            customerIdFormat: "Phone number"
        ),
        GeorgianUtilityProvider(
            name: "Beeline Mobile",
            nameGeorgian: "ბილაინი მობაილი",
            type: .phone,
            icon: "phone.fill",
            website: "https://beeline.ge",
            phone: "*111",
            customerIdFormat: "Phone number"
        ),

        // Cleaning
        GeorgianUtilityProvider(
            name: "Tbilservice Group",
            nameGeorgian: "თბილსერვის ჯგუფი",
            type: .cleaning,
            icon: "trash.fill",
            website: "https://tbilservice.ge",
            phone: "0322 72 22 22",
            customerIdFormat: "Address or customer ID"
        ),

        // Other services
        GeorgianUtilityProvider(
            name: "Condominium / HOA",
            nameGeorgian: "ამხანაგობა",
            type: .other,
            icon: "building.2.fill",
            website: nil,
            phone: nil,
            customerIdFormat: "Apartment number"
        ),
    ]

    static func providers(for type: UtilityType) -> [GeorgianUtilityProvider] {
        all.filter { $0.type == type }
    }
}

// MARK: - Tbilisi Districts

enum TbilisiDistrict: String, CaseIterable, Identifiable {
    case vake = "ვაკე"
    case saburtalo = "საბურთალო"
    case isani = "ისანი"
    case samgori = "სამგორი"
    case didube = "დიდუბე"
    case chughureti = "ჩუღურეთი"
    case krtsanisi = "კრწანისი"
    case mtatsminda = "მთაწმინდა"
    case nadzaladevi = "ნაძალადევი"
    case gldani = "გლდანი"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var displayNameEnglish: String {
        switch self {
        case .vake: "Vake"
        case .saburtalo: "Saburtalo"
        case .isani: "Isani"
        case .samgori: "Samgori"
        case .didube: "Didube"
        case .chughureti: "Chughureti"
        case .krtsanisi: "Krtsanisi"
        case .mtatsminda: "Mtatsminda"
        case .nadzaladevi: "Nadzaladevi"
        case .gldani: "Gldani"
        }
    }
}
