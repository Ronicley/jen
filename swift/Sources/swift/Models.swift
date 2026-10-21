import Foundation

enum SaleMode: String, Codable, CaseIterable, Identifiable {
    case unit, weight, package
    var id: String { rawValue }
    var label: String { switch self { case .unit: "Unidade"; case .weight: "Por kg"; case .package: "Embalagem" } }
}
struct Trip: Identifiable, Codable {
    var id = UUID()
    var budget: Int?
    var market: String
    var createdAt = Date()
    var finishedAt: Date?
    var source: String?
    var receiptKey: String?
    var receiptTotal: Int?
    var discount: Int?
    var surcharge: Int?
    var adjustment: Int { (surcharge ?? 0) - (discount ?? 0) }
}
struct Product: Identifiable, Codable {
    var id = UUID()
    var name: String
    var mode: SaleMode
}
struct CartItem: Identifiable, Codable {
    var id = UUID()
    var tripID: UUID
    var productID: UUID?
    var name: String
    var mode: SaleMode
    var price: Int
    var amount: Int
    // Optional fields keep version-1 JSON readable without a destructive migration.
    var printedTotal: Int?
    var receiptDetail: String?
    var receiptDiscount: Int?
    var total: Int { printedTotal ?? (mode == .weight ? (price * amount + 500) / 1000 : price * amount) }
    var detail: String { receiptDetail ?? (mode == .weight ? "\(amount) g × \(money(price))/kg" : "\(amount) \(mode == .package ? "emb." : "un.") × \(money(price))") }
}
struct ShoppingEntry: Identifiable, Codable {
    var id = UUID()
    var name: String
    var checked = false
}
struct Snapshot: Codable {
    var version = 1
    var trips: [Trip] = []
    var products: [Product] = []
    var items: [CartItem] = []
    var list: [ShoppingEntry] = []

    mutating func renameListItem(id: UUID, name: String) throws {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw JenError("Digite o nome do item.") }
        guard let index = list.firstIndex(where: { $0.id == id }) else { throw JenError("Este item não está mais na lista.") }
        list[index].name = value
    }

    mutating func updateFinishedTrip(id: UUID, budget: Int?, market: String, date: Date) throws {
        guard let index = trips.firstIndex(where: { $0.id == id && $0.finishedAt != nil }) else {
            throw JenError("Compra finalizada não encontrada.")
        }
        guard budget == nil || budget! > 0 else { throw JenError("O orçamento precisa ser maior que zero.") }
        guard date <= Date() else { throw JenError("A data da compra não pode estar no futuro.") }
        let name = market.trimmingCharacters(in: .whitespacesAndNewlines)
        trips[index].budget = budget
        trips[index].market = name.isEmpty ? "Minha compra" : name
        trips[index].finishedAt = date
    }

    mutating func deleteFinishedTrip(id: UUID) throws {
        guard trips.contains(where: { $0.id == id && $0.finishedAt != nil }) else {
            throw JenError("Compra finalizada não encontrada.")
        }
        items.removeAll { $0.tripID == id }
        trips.removeAll { $0.id == id }
        // Keep product identities: other purchases can reference the same products.
    }
}
struct JenError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
func cents(_ input: String) throws -> Int {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.range(of: #"^[0-9]{1,7}([,.][0-9]{1,2})?$"#, options: .regularExpression) != nil else {
        throw JenError("Informe um valor como 18,90, sem separador de milhar.")
    }
    let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ".")
    let fraction = parts.count > 1 ? String(parts[1]) : ""
    let result = Int(parts[0])! * 100 + (Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
    guard result > 0 else { throw JenError("O valor precisa ser maior que zero.") }
    return result
}
func quantity(_ input: String) throws -> Int {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.range(of: #"^[0-9]{1,6}$"#, options: .regularExpression) != nil,
          let result = Int(value), result > 0 else { throw JenError("Informe uma quantidade inteira maior que zero.") }
    return result
}
func money(_ cents: Int) -> String {
    (Double(cents) / 100).formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
}
func shortDate(_ date: Date) -> String {
    date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
}
