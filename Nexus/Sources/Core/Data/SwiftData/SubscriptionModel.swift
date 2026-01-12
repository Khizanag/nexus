import Foundation
import SwiftData

@Model
final class SubscriptionModel {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var currency: String = "GEL"
    var billingCycle: BillingCycle = BillingCycle.monthly
    var category: SubscriptionCategory = SubscriptionCategory.other
    var icon: String = "creditcard.fill"
    var color: String = "blue"
    var startDate: Date = Date()
    var nextDueDate: Date = Date()
    var reminderDaysBefore: Int = 3
    var isActive: Bool = true
    var isPaused: Bool = false
    var notes: String = ""
    var url: String?
    var freeTrialEndDate: Date?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SubscriptionPaymentModel.subscription)
    var payments: [SubscriptionPaymentModel]?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        currency: String = "GEL",
        billingCycle: BillingCycle = .monthly,
        category: SubscriptionCategory = .other,
        icon: String = "creditcard.fill",
        color: String = "blue",
        startDate: Date = .now,
        nextDueDate: Date = .now,
        reminderDaysBefore: Int = 3,
        isActive: Bool = true,
        isPaused: Bool = false,
        notes: String = "",
        url: String? = nil,
        freeTrialEndDate: Date? = nil,
        createdAt: Date = .now,
        payments: [SubscriptionPaymentModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currency = currency
        self.billingCycle = billingCycle
        self.category = category
        self.icon = icon
        self.color = color
        self.startDate = startDate
        self.nextDueDate = nextDueDate
        self.reminderDaysBefore = reminderDaysBefore
        self.isActive = isActive
        self.isPaused = isPaused
        self.notes = notes
        self.url = url
        self.freeTrialEndDate = freeTrialEndDate
        self.createdAt = createdAt
        self.payments = payments
    }

    // MARK: - Computed Properties

    var isInFreeTrial: Bool {
        guard let trialEnd = freeTrialEndDate else { return false }
        return Date() < trialEnd
    }

    var freeTrialDaysLeft: Int? {
        guard let trialEnd = freeTrialEndDate, isInFreeTrial else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: trialEnd).day
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: nextDueDate)).day ?? 0
    }

    var isDueToday: Bool {
        Calendar.current.isDateInToday(nextDueDate)
    }

    var isOverdue: Bool {
        !isPaused && isActive && nextDueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueSoon: Bool {
        daysUntilDue <= reminderDaysBefore && daysUntilDue >= 0
    }

    var monthlyEquivalent: Double {
        switch billingCycle {
        case .weekly: return amount * 4.33
        case .biweekly: return amount * 2.17
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .biannually: return amount / 6
        case .yearly: return amount / 12
        case .custom(let days): return amount * (30.0 / Double(days))
        }
    }

    var yearlyEquivalent: Double {
        monthlyEquivalent * 12
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        if currency == "GEL" { formatter.currencySymbol = "₾" }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    var formattedMonthlyAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        if currency == "GEL" { formatter.currencySymbol = "₾" }
        return formatter.string(from: NSNumber(value: monthlyEquivalent)) ?? "\(currency) \(monthlyEquivalent)"
    }

    var statusText: String {
        if isPaused { return "Paused" }
        if !isActive { return "Cancelled" }
        if isInFreeTrial { return "Free Trial" }
        if isOverdue { return "Overdue" }
        if isDueToday { return "Due Today" }
        if isDueSoon { return "Due Soon" }
        return "Active"
    }

    // MARK: - Methods

    func calculateNextDueDate() -> Date {
        let calendar = Calendar.current
        switch billingCycle {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: nextDueDate) ?? nextDueDate
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: nextDueDate) ?? nextDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: nextDueDate) ?? nextDueDate
        case .biannually:
            return calendar.date(byAdding: .month, value: 6, to: nextDueDate) ?? nextDueDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: nextDueDate) ?? nextDueDate
        }
    }

    func markAsPaid() {
        let payment = SubscriptionPaymentModel(
            amount: amount,
            currency: currency,
            paidDate: Date(),
            subscription: self
        )
        if payments == nil {
            payments = [payment]
        } else {
            payments?.append(payment)
        }
        nextDueDate = calculateNextDueDate()
    }
}

// MARK: - Billing Cycle

enum BillingCycle: Codable, Hashable, CaseIterable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case biannually
    case yearly
    case custom(days: Int)

    static var allCases: [BillingCycle] {
        [.weekly, .biweekly, .monthly, .quarterly, .biannually, .yearly]
    }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 Weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .biannually: "Every 6 Months"
        case .yearly: "Yearly"
        case .custom(let days): "Every \(days) Days"
        }
    }

    var shortName: String {
        switch self {
        case .weekly: "/week"
        case .biweekly: "/2 weeks"
        case .monthly: "/month"
        case .quarterly: "/quarter"
        case .biannually: "/6 months"
        case .yearly: "/year"
        case .custom(let days): "/\(days) days"
        }
    }
}

// MARK: - Subscription Category

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case streaming
    case music
    case software
    case gaming
    case fitness
    case news
    case cloud
    case utilities
    case insurance
    case rent
    case phone
    case internet
    case banking
    case finance
    case education
    case shopping
    case transport
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streaming: "Streaming"
        case .music: "Music"
        case .software: "Software"
        case .gaming: "Gaming"
        case .fitness: "Fitness"
        case .news: "News & Magazines"
        case .cloud: "Cloud Storage"
        case .utilities: "Utilities"
        case .insurance: "Insurance"
        case .rent: "Rent"
        case .phone: "Phone"
        case .internet: "Internet"
        case .banking: "Banking"
        case .finance: "Finance"
        case .education: "Education"
        case .shopping: "Shopping"
        case .transport: "Transport"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .streaming: "play.rectangle.fill"
        case .music: "music.note"
        case .software: "app.badge.fill"
        case .gaming: "gamecontroller.fill"
        case .fitness: "figure.run"
        case .news: "newspaper.fill"
        case .cloud: "cloud.fill"
        case .utilities: "bolt.fill"
        case .insurance: "shield.fill"
        case .rent: "house.fill"
        case .phone: "phone.fill"
        case .internet: "wifi"
        case .banking: "banknote.fill"
        case .finance: "chart.line.uptrend.xyaxis"
        case .education: "graduationcap.fill"
        case .shopping: "bag.fill"
        case .transport: "car.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .streaming: "red"
        case .music: "green"
        case .software: "blue"
        case .gaming: "purple"
        case .fitness: "orange"
        case .news: "gray"
        case .cloud: "cyan"
        case .utilities: "yellow"
        case .insurance: "indigo"
        case .rent: "brown"
        case .phone: "teal"
        case .internet: "mint"
        case .banking: "green"
        case .finance: "blue"
        case .education: "purple"
        case .shopping: "pink"
        case .transport: "orange"
        case .other: "gray"
        }
    }
}

// MARK: - Payment History Model

@Model
final class SubscriptionPaymentModel {
    var id: UUID = UUID()
    var amount: Double = 0
    var currency: String = "GEL"
    var paidDate: Date = Date()
    var subscription: SubscriptionModel?

    init(
        id: UUID = UUID(),
        amount: Double,
        currency: String,
        paidDate: Date = .now,
        subscription: SubscriptionModel? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currency = currency
        self.paidDate = paidDate
        self.subscription = subscription
    }
}

// MARK: - Popular Subscriptions

struct PopularSubscription: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: String
    let category: SubscriptionCategory
    let defaultAmount: Double
    let defaultCurrency: String
    let defaultCycle: BillingCycle
    let url: String?

    static let all: [PopularSubscription] = [
        // Streaming
        PopularSubscription(name: "Netflix", icon: "play.rectangle.fill", color: "red", category: .streaming, defaultAmount: 44.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://netflix.com/account"),
        PopularSubscription(name: "YouTube Premium", icon: "play.rectangle.fill", color: "red", category: .streaming, defaultAmount: 22.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://youtube.com/paid_memberships"),
        PopularSubscription(name: "Disney+", icon: "sparkles.tv.fill", color: "blue", category: .streaming, defaultAmount: 29.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://disneyplus.com/account"),
        PopularSubscription(name: "HBO Max", icon: "play.rectangle.fill", color: "purple", category: .streaming, defaultAmount: 39.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),

        // Music
        PopularSubscription(name: "Spotify", icon: "music.note", color: "green", category: .music, defaultAmount: 14.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://spotify.com/account"),
        PopularSubscription(name: "Apple Music", icon: "music.note", color: "pink", category: .music, defaultAmount: 14.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "SoundCloud Go", icon: "music.note", color: "orange", category: .music, defaultAmount: 12.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),

        // Software
        PopularSubscription(name: "iCloud+", icon: "cloud.fill", color: "blue", category: .cloud, defaultAmount: 2.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Google One", icon: "cloud.fill", color: "blue", category: .cloud, defaultAmount: 5.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://one.google.com"),
        PopularSubscription(name: "Dropbox", icon: "cloud.fill", color: "blue", category: .cloud, defaultAmount: 11.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Microsoft 365", icon: "app.badge.fill", color: "orange", category: .software, defaultAmount: 6.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Adobe Creative Cloud", icon: "app.badge.fill", color: "red", category: .software, defaultAmount: 54.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Notion", icon: "doc.fill", color: "gray", category: .software, defaultAmount: 8.00, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "1Password", icon: "lock.fill", color: "blue", category: .software, defaultAmount: 2.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Claude Pro", icon: "brain", color: "orange", category: .software, defaultAmount: 20.00, defaultCurrency: "USD", defaultCycle: .monthly, url: "https://claude.ai"),
        PopularSubscription(name: "ChatGPT Plus", icon: "brain", color: "green", category: .software, defaultAmount: 20.00, defaultCurrency: "USD", defaultCycle: .monthly, url: "https://chat.openai.com"),
        PopularSubscription(name: "GitHub Copilot", icon: "chevron.left.forwardslash.chevron.right", color: "gray", category: .software, defaultAmount: 10.00, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),

        // Gaming
        PopularSubscription(name: "PlayStation Plus", icon: "gamecontroller.fill", color: "blue", category: .gaming, defaultAmount: 9.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Xbox Game Pass", icon: "gamecontroller.fill", color: "green", category: .gaming, defaultAmount: 14.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Nintendo Online", icon: "gamecontroller.fill", color: "red", category: .gaming, defaultAmount: 3.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),

        // Fitness
        PopularSubscription(name: "Gym Membership", icon: "figure.run", color: "orange", category: .fitness, defaultAmount: 80.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Strava", icon: "figure.run", color: "orange", category: .fitness, defaultAmount: 11.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),

        // Georgian Services
        PopularSubscription(name: "Magti", icon: "phone.fill", color: "red", category: .phone, defaultAmount: 25.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Silknet", icon: "wifi", color: "purple", category: .internet, defaultAmount: 45.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Beeline", icon: "phone.fill", color: "yellow", category: .phone, defaultAmount: 20.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Telasi", icon: "bolt.fill", color: "yellow", category: .utilities, defaultAmount: 0, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "GWP", icon: "drop.fill", color: "blue", category: .utilities, defaultAmount: 0, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),

        // Banking
        PopularSubscription(name: "BoG Solo", icon: "banknote.fill", color: "orange", category: .banking, defaultAmount: 5.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://bog.ge"),
        PopularSubscription(name: "TBC Space", icon: "banknote.fill", color: "blue", category: .banking, defaultAmount: 5.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: "https://tbcbank.ge"),
        PopularSubscription(name: "Credo Premium", icon: "banknote.fill", color: "green", category: .banking, defaultAmount: 3.00, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Liberty Card", icon: "creditcard.fill", color: "red", category: .banking, defaultAmount: 0, defaultCurrency: "GEL", defaultCycle: .yearly, url: nil),

        // Finance & Investment
        PopularSubscription(name: "Trading 212", icon: "chart.line.uptrend.xyaxis", color: "green", category: .finance, defaultAmount: 0, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Revolut Premium", icon: "creditcard.fill", color: "purple", category: .finance, defaultAmount: 7.99, defaultCurrency: "EUR", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Revolut Metal", icon: "creditcard.fill", color: "gray", category: .finance, defaultAmount: 13.99, defaultCurrency: "EUR", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "YNAB", icon: "chart.pie.fill", color: "blue", category: .finance, defaultAmount: 14.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),

        // Education
        PopularSubscription(name: "Coursera Plus", icon: "graduationcap.fill", color: "blue", category: .education, defaultAmount: 59.00, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Udemy", icon: "graduationcap.fill", color: "purple", category: .education, defaultAmount: 0, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Skillshare", icon: "graduationcap.fill", color: "green", category: .education, defaultAmount: 13.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Duolingo Plus", icon: "globe", color: "green", category: .education, defaultAmount: 6.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "MasterClass", icon: "play.circle.fill", color: "red", category: .education, defaultAmount: 10.00, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),

        // Shopping
        PopularSubscription(name: "Amazon Prime", icon: "bag.fill", color: "orange", category: .shopping, defaultAmount: 14.99, defaultCurrency: "USD", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Costco", icon: "cart.fill", color: "red", category: .shopping, defaultAmount: 60.00, defaultCurrency: "USD", defaultCycle: .yearly, url: nil),

        // Transport
        PopularSubscription(name: "Bolt Plus", icon: "car.fill", color: "green", category: .transport, defaultAmount: 4.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Wolt+", icon: "takeoutbag.and.cup.and.straw.fill", color: "blue", category: .transport, defaultAmount: 9.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
        PopularSubscription(name: "Glovo Prime", icon: "box.truck.fill", color: "yellow", category: .transport, defaultAmount: 7.99, defaultCurrency: "GEL", defaultCycle: .monthly, url: nil),
    ]

    static func forCategory(_ category: SubscriptionCategory) -> [PopularSubscription] {
        all.filter { $0.category == category }
    }
}
