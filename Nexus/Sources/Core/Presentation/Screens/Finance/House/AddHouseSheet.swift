import SwiftUI
import SwiftData
import CoreLocation

struct AddHouseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var city = "თბილისი"
    @State private var district: TbilisiDistrict?
    @State private var apartmentNumber = ""
    @State private var floor = ""
    @State private var area = ""
    @State private var isPrimary = false
    @State private var icon = "house.fill"
    @State private var color = "blue"
    @State private var notes = ""
    @State private var isLoadingLocation = false

    private let locationService = DefaultLocationService.shared

    private let icons = [
        "house.fill",
        "building.2.fill",
        "building.fill",
        "house.lodge.fill",
        "house.and.flag.fill"
    ]

    private let colors = ["blue", "green", "purple", "orange", "pink", "cyan", "indigo"]

    var body: some View {
        NavigationStack {
            Form {
                Section("ძირითადი ინფორმაცია") {
                    TextField("სახელი (მაგ: ჩემი ბინა)", text: $name)

                    TextField("მისამართი", text: $address)

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("მიმდინარე მდებარეობა")
                        }
                        .foregroundStyle(Color.nexusTeal)
                    }
                    .disabled(isLoadingLocation)

                    Picker("ქალაქი", selection: $city) {
                        Text("თბილისი").tag("თბილისი")
                        Text("ბათუმი").tag("ბათუმი")
                        Text("ქუთაისი").tag("ქუთაისი")
                    }

                    if city == "თბილისი" {
                        Picker("უბანი", selection: $district) {
                            Text("აირჩიეთ").tag(nil as TbilisiDistrict?)
                            ForEach(TbilisiDistrict.allCases) { dist in
                                Text(dist.displayName).tag(dist as TbilisiDistrict?)
                            }
                        }
                    }
                }

                Section("დამატებითი") {
                    TextField("ბინის ნომერი", text: $apartmentNumber)
                        .keyboardType(.numberPad)

                    TextField("სართული", text: $floor)
                        .keyboardType(.numberPad)

                    TextField("ფართი (მ²)", text: $area)
                        .keyboardType(.decimalPad)
                }

                Section("გარეგნობა") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .foregroundStyle(icon == iconName ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(icon == iconName ? Color.nexusPurple : Color.nexusSurface)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { colorName in
                                Button {
                                    color = colorName
                                } label: {
                                    Circle()
                                        .fill(Color.named(colorName))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if color == colorName {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                Section {
                    Toggle("მთავარი სახლი", isOn: $isPrimary)
                }

                Section {
                    TextField("შენიშვნები", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        addHouse()
                    } label: {
                        HStack {
                            Spacer()
                            Text("სახლის დამატება")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
            .navigationTitle("ახალი სახლი")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
            }
        }
    }

    private func addHouse() {
        let house = HouseModel(
            name: name,
            address: address,
            city: city,
            district: district?.displayName,
            apartmentNumber: apartmentNumber.isEmpty ? nil : apartmentNumber,
            floor: Int(floor),
            area: Double(area),
            icon: icon,
            color: color,
            isPrimary: isPrimary,
            notes: notes
        )

        modelContext.insert(house)
        try? modelContext.save()
        dismiss()
    }

    private func useCurrentLocation() async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        do {
            let location = try await locationService.getCurrentLocation()
            let addressString = try await locationService.reverseGeocode(location)
            address = addressString
        } catch {
            print("Failed to get location: \(error)")
        }
    }
}

// MARK: - Edit House Sheet

struct EditHouseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var house: HouseModel

    @State private var district: TbilisiDistrict?
    @State private var isLoadingLocation = false

    private let locationService = DefaultLocationService.shared

    private let icons = [
        "house.fill",
        "building.2.fill",
        "building.fill",
        "house.lodge.fill",
        "house.and.flag.fill"
    ]

    private let colors = ["blue", "green", "purple", "orange", "pink", "cyan", "indigo"]

    var body: some View {
        NavigationStack {
            Form {
                Section("ძირითადი ინფორმაცია") {
                    TextField("სახელი", text: $house.name)
                    TextField("მისამართი", text: $house.address)

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("მიმდინარე მდებარეობა")
                        }
                        .foregroundStyle(Color.nexusTeal)
                    }
                    .disabled(isLoadingLocation)

                    Picker("ქალაქი", selection: $house.city) {
                        Text("თბილისი").tag("თბილისი")
                        Text("ბათუმი").tag("ბათუმი")
                        Text("ქუთაისი").tag("ქუთაისი")
                    }
                }

                Section("დამატებითი") {
                    TextField("ბინის ნომერი", text: Binding(
                        get: { house.apartmentNumber ?? "" },
                        set: { house.apartmentNumber = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("სართული", value: $house.floor, format: .number)
                        .keyboardType(.numberPad)

                    TextField("ფართი (მ²)", value: $house.area, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section("გარეგნობა") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { iconName in
                                Button {
                                    house.icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .foregroundStyle(house.icon == iconName ? .white : .primary)
                                        .frame(width: 50, height: 50)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(house.icon == iconName ? Color.nexusPurple : Color.nexusSurface)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { colorName in
                                Button {
                                    house.color = colorName
                                } label: {
                                    Circle()
                                        .fill(Color.named(colorName))
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if house.color == colorName {
                                                Circle()
                                                    .strokeBorder(.white, lineWidth: 3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                Section {
                    Toggle("მთავარი სახლი", isOn: $house.isPrimary)
                }

                Section {
                    TextField("შენიშვნები", text: $house.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("რედაქტირება")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("შენახვა") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func useCurrentLocation() async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        do {
            let location = try await locationService.getCurrentLocation()
            let addressString = try await locationService.reverseGeocode(location)
            house.address = addressString
        } catch {
            print("Failed to get location: \(error)")
        }
    }
}

