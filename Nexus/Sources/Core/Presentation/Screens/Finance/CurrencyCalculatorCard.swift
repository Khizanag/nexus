import SwiftUI
import SwiftData

struct CurrencyCalculatorCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [CurrencyPreferenceModel]
    @AppStorage("currency") private var preferredCurrency = "USD"

    @State private var isExpanded = false
    @State private var amount = "1000"
    @State private var baseCurrency: Currency?
    @State private var rates: ExchangeRates?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var showAllCurrencies = false
    @State private var isUsingCachedData = false
    @State private var hasInitialized = false

    private let currencyService: CurrencyService
    private let inputHeight: CGFloat = 52

    private var effectiveBaseCurrency: Currency {
        baseCurrency ?? Currency(rawValue: preferredCurrency) ?? .usd
    }

    init(currencyService: CurrencyService = DefaultCurrencyService()) {
        self.currencyService = currencyService
    }

    private var currentPreferences: CurrencyPreferenceModel {
        if let existing = preferences.first {
            return existing
        }
        let new = CurrencyPreferenceModel()
        modelContext.insert(new)
        return new
    }

    private var favoriteCurrencies: [Currency] {
        currentPreferences.favoriteCurrencies
    }

    private var parsedAmount: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var displayedCurrencies: [Currency] {
        let others = Currency.allCases.filter { $0 != effectiveBaseCurrency }
        let favorites = others.filter { favoriteCurrencies.contains($0) }
        let nonFavorites = others.filter { !favoriteCurrencies.contains($0) }

        if showAllCurrencies {
            return favorites + nonFavorites
        } else {
            let combined = favorites + nonFavorites
            return Array(combined.prefix(4))
        }
    }

    private var hasMoreCurrencies: Bool {
        let others = Currency.allCases.filter { $0 != effectiveBaseCurrency }
        return others.count > 4
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            expandedContent
                .frame(height: isExpanded ? nil : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.nexusGreen.opacity(0.3), Color.nexusBorder],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .animation(.spring(response: 0.3), value: showAllCurrencies)
        .task {
            await fetchRates()
        }
    }

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.nexusGreen.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.nexusGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Currency Converter")
                        .font(.nexusHeadline)
                        .foregroundStyle(.primary)
                    if let lastUpdated {
                        HStack(spacing: 4) {
                            Text(timeAgoText(from: lastUpdated))
                            if isUsingCachedData {
                                Text("(offline)")
                                    .foregroundStyle(Color.nexusOrange)
                            }
                        }
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.nexusBorder)
                .padding(.horizontal, 16)

            amountInputSection
            currencyGrid

            if hasMoreCurrencies {
                showMoreButton
            }

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            }
        }
        .padding(.bottom, 16)
    }

    private var amountInputSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(effectiveBaseCurrency.symbol)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.nexusGreen)

                TextField("0", text: $amount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .frame(height: inputHeight)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurfaceSecondary)
            }

            currencyPicker
        }
        .padding(.horizontal, 16)
    }

    private var currencyPicker: some View {
        Menu {
            Section("Favorites") {
                ForEach(favoriteCurrencies) { currency in
                    currencyMenuButton(currency)
                }
            }
            Section("All Currencies") {
                ForEach(Currency.allCases.filter { !favoriteCurrencies.contains($0) }) { currency in
                    currencyMenuButton(currency)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(effectiveBaseCurrency.flag)
                    .font(.system(size: 20))
                Text(effectiveBaseCurrency.rawValue)
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: inputHeight)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurfaceSecondary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func currencyMenuButton(_ currency: Currency) -> some View {
        Button {
            withAnimation {
                baseCurrency = currency
            }
            Task { await fetchRates() }
        } label: {
            HStack {
                Text(currency.flag)
                Text(currency.rawValue)
                Text(currency.name)
                    .foregroundStyle(.secondary)
                if currency == effectiveBaseCurrency {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private var currencyGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(displayedCurrencies) { currency in
                CurrencyResultCard(
                    currency: currency,
                    amount: convertedAmount(to: currency),
                    isFavorite: favoriteCurrencies.contains(currency),
                    onTap: {
                        selectAsBase(currency)
                    },
                    onFavoriteToggle: {
                        toggleFavorite(currency)
                    }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var showMoreButton: some View {
        Button {
            withAnimation {
                showAllCurrencies.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Text(showAllCurrencies ? "Show Less" : "Show All Currencies")
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                Image(systemName: showAllCurrencies ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.nexusGreen)
            .padding(.vertical, 8)
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Updating rates...")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.nexusOrange)
            Text(message)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await fetchRates() }
            }
            .font(.nexusCaption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.nexusGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func convertedAmount(to currency: Currency) -> Double {
        guard let rates else { return 0 }
        return currencyService.convert(
            amount: parsedAmount,
            from: effectiveBaseCurrency,
            to: currency,
            rates: rates
        )
    }

    private func selectAsBase(_ currency: Currency) {
        let convertedValue = convertedAmount(to: currency)
        withAnimation(.spring(response: 0.3)) {
            baseCurrency = currency
            amount = String(format: "%.2f", convertedValue)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await fetchRates() }
    }

    private func toggleFavorite(_ currency: Currency) {
        withAnimation(.spring(response: 0.25)) {
            currentPreferences.toggleFavorite(currency)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func fetchRates() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        isUsingCachedData = false

        let currency = effectiveBaseCurrency

        if let cached = CurrencyCache.getCachedRates(base: currency, context: modelContext), !cached.isStale {
            rates = cached
            lastUpdated = cached.timestamp
            isLoading = false
            return
        }

        do {
            let fetchedRates = try await currencyService.fetchRatesFromAPI(base: currency)
            rates = fetchedRates
            lastUpdated = fetchedRates.timestamp
            CurrencyCache.saveCachedRates(fetchedRates, context: modelContext)
        } catch {
            if let cached = CurrencyCache.getCachedRates(base: currency, context: modelContext) {
                rates = cached
                lastUpdated = cached.timestamp
                isUsingCachedData = true
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't fetch rates"
            }
        }

        isLoading = false
    }

    private func timeAgoText(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Updated just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Updated \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Updated \(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "Updated \(days)d ago"
        }
    }
}

// MARK: - Currency Result Card

private struct CurrencyResultCard: View {
    let currency: Currency
    let amount: Double
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(currency.flag)
                        .font(.system(size: 18))
                    Text(currency.rawValue)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundStyle(isFavorite ? Color.nexusOrange : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(currency.format(amount))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurfaceSecondary)
                    .overlay {
                        if isFavorite {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.nexusOrange.opacity(0.3), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CurrencyCalculatorCard()
        }
        .padding(20)
    }
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
