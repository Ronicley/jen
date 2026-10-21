import Foundation

struct RecognizedLine: Sendable {
    var text: String
    var confidence: Float = 1
}
struct RecognizedPage: Sendable {
    var lines: [RecognizedLine]
    var text: String { lines.map(\.text).joined(separator: "\n") }
}

/// Decimal arithmetic is used for fiscal inputs; item totals remain integer cents.
enum ReceiptNumbers {
    static func amount(_ input: String) -> Decimal? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{1,6}(?:[,.][0-9]{1,3})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: text.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }
    static func money(_ input: String, allowZero: Bool = false) throws -> Int {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^(?:[0-9]{1,7}|[0-9]{1,3}(?:\.[0-9]{3})+)(?:,[0-9]{1,2})?$|^[0-9]{1,7}\.[0-9]{1,2}$"#, options: .regularExpression) != nil else {
            throw JenError("Informe um valor monetário como 18,90.")
        }
        let groupedInteger = text.range(of: #"^[0-9]{1,3}(?:\.[0-9]{3})+$"#, options: .regularExpression) != nil
        let normalized = text.contains(",") || groupedInteger ? text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : text
        guard let value = Decimal(string: normalized), value >= 0, value <= 9999999.99 else { throw JenError("Valor fora do limite permitido.") }
        let result = NSDecimalNumber(decimal: value * 100).intValue
        guard allowZero || result > 0 else { throw JenError("O valor precisa ser maior que zero.") }
        return result
    }
    static func unitPrice(_ input: String, multiplier: Int = 1) throws -> Int {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{1,7}(?:[,.][0-9]{1,4})?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: text.replacingOccurrences(of: ",", with: ".")), value > 0, value <= 9999999.99 else {
            throw JenError("Confira o preço unitário (até quatro casas decimais).")
        }
        var scaled = value * 100 * Decimal(multiplier)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded >= 1 else { throw JenError("O preço unitário precisa ser de pelo menos um centavo.") }
        return NSDecimalNumber(decimal: rounded).intValue
    }
    static func adjustment(_ input: String) throws -> Int {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : try money(input, allowZero: true)
    }
    static func text(_ cents: Int) -> String {
        "\(cents / 100),\(String(format: "%02d", cents % 100))"
    }
}

struct ReceiptItemDraft: Identifiable, Sendable {
    var id = UUID()
    var name = ""
    var quantity = ""
    var unit = "UN"
    var unitPrice = ""
    var grossTotal = ""
    var discount = ""
    var totalOnly = false
    var sourceText = ""
    var page = 1
    var itemNumber: String?
    var warnings: [String] = []
    var reviewed = false

    var netTotal: Int? {
        guard let gross = try? ReceiptNumbers.money(grossTotal), let reduction = try? ReceiptNumbers.adjustment(discount), reduction <= gross else { return nil }
        return gross - reduction
    }
    var problem: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Informe o nome do produto." }
        guard let netTotal, netTotal >= 0 else { return "Confira o total e o desconto do item." }
        if !totalOnly {
            guard ReceiptNumbers.amount(quantity) != nil else { return "Confira a quantidade." }
            guard (try? ReceiptNumbers.unitPrice(unitPrice, multiplier: unit.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) == "G" ? 1000 : 1)) != nil else { return "Confira o preço unitário." }
            guard !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Informe a unidade de venda." }
        }
        if !warnings.isEmpty && !reviewed { return "Revise os avisos deste item." }
        return nil
    }
    func cartItem(tripID: UUID) throws -> CartItem {
        if let problem { throw JenError(problem) }
        guard let net = netTotal else { throw JenError("Total do item inválido.") }
        let normalizedUnit = unit.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var mode = SaleMode.package
        var count = 1
        var price = try ReceiptNumbers.money(grossTotal)
        var detail = "Total conferido no cupom (sem preço unitário)"
        if !totalOnly, let value = ReceiptNumbers.amount(quantity) {
            price = try ReceiptNumbers.unitPrice(unitPrice, multiplier: normalizedUnit == "G" ? 1000 : 1)
            detail = "\(quantity) \(normalizedUnit) × R$ \(unitPrice)"
            if normalizedUnit == "KG" || normalizedUnit == "G" {
                let grams = NSDecimalNumber(decimal: value * (normalizedUnit == "KG" ? 1000 : 1))
                guard grams.decimalValue == Decimal(grams.intValue), grams.intValue > 0, grams.intValue <= 999999 else {
                    throw JenError("O peso precisa corresponder a gramas inteiras, até 999999 g.")
                }
                mode = .weight
                count = grams.intValue
            } else if ["UN", "UND", "UNID", "PC", "PCT", "CX"].contains(normalizedUnit), value == Decimal(NSDecimalNumber(decimal: value).intValue) {
                count = NSDecimalNumber(decimal: value).intValue
                mode = ["PCT", "CX"].contains(normalizedUnit) ? .package : .unit
            }
        }
        let reduction = try ReceiptNumbers.adjustment(discount)
        if reduction > 0 { detail += " · desconto \(money(reduction))" }
        return CartItem(tripID: tripID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), mode: mode, price: price, amount: count,
                        printedTotal: net, receiptDetail: detail, receiptDiscount: reduction)
    }
}
struct ReceiptDraft: Sendable {
    var market = ""
    var date = Date()
    var items: [ReceiptItemDraft] = []
    var total = ""
    var discount = ""
    var surcharge = ""
    var key = ""
    var warnings: [String] = []
    var pages: [String] = []
    var confirmed = false

    var calculatedTotal: Int? {
        guard items.allSatisfy({ $0.netTotal != nil }),
              let reduction = try? ReceiptNumbers.adjustment(discount), let addition = try? ReceiptNumbers.adjustment(surcharge) else { return nil }
        return items.reduce(0) { $0 + ($1.netTotal ?? 0) } - reduction + addition
    }
    var difference: Int? {
        guard let calculatedTotal, let target = try? ReceiptNumbers.money(total) else { return nil }
        return target - calculatedTotal
    }
    var problem: String? {
        if market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Informe o mercado." }
        if date > Date() { return "A data não pode estar no futuro." }
        if items.isEmpty { return "Adicione pelo menos um produto." }
        if let item = items.first(where: { $0.problem != nil }) { return "\(item.name.isEmpty ? "Produto" : item.name): \(item.problem!)" }
        guard (try? ReceiptNumbers.money(total)) != nil else { return "Confira o total final do cupom." }
        guard let difference else { return "Confira os descontos e acréscimos." }
        if difference != 0 { return "Resolva a diferença de \(money(abs(difference))) antes de salvar." }
        if !confirmed { return "Confirme que revisou os produtos e os valores." }
        return nil
    }
    func finishedPurchase() throws -> (Trip, [CartItem]) {
        if let problem { throw JenError(problem) }
        let id = UUID()
        let receiptKey = key.filter(\.isNumber)
        if !receiptKey.isEmpty && (receiptKey.count != 44 || !receiptKey.allSatisfy({ $0.isASCII })) {
            throw JenError("A chave fiscal deve conter 44 dígitos, ou ficar vazia.")
        }
        let trip = Trip(id: id, budget: nil, market: market.trimmingCharacters(in: .whitespacesAndNewlines), finishedAt: date, source: "receipt",
                        receiptKey: receiptKey.isEmpty ? nil : receiptKey, receiptTotal: try ReceiptNumbers.money(total),
                        discount: try ReceiptNumbers.adjustment(discount), surcharge: try ReceiptNumbers.adjustment(surcharge))
        return (trip, try items.map { try $0.cartItem(tripID: id) })
    }
}

extension Snapshot {
    func possibleDuplicate(_ draft: ReceiptDraft) -> Trip? {
        let key = draft.key.filter(\.isNumber)
        let total = try? ReceiptNumbers.money(draft.total)
        return trips.first { trip in
            if !key.isEmpty, trip.receiptKey == key { return true }
            let spent = items.filter { $0.tripID == trip.id }.reduce(0) { $0 + $1.total } + trip.adjustment
            return trip.finishedAt.map { Calendar.current.isDate($0, inSameDayAs: draft.date) } == true &&
                trip.market.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == draft.market.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) && spent == total
        }
    }
    mutating func importReceipt(_ draft: ReceiptDraft, allowSimilar: Bool = false) throws {
        let (trip, cart) = try draft.finishedPurchase()
        if let key = trip.receiptKey, trips.contains(where: { $0.receiptKey == key }) {
            throw JenError("Este cupom já foi importado (mesma chave fiscal).")
        }
        if !allowSimilar && possibleDuplicate(draft) != nil { throw JenError("Já existe uma compra semelhante. Confirme antes de importar novamente.") }
        trips.insert(trip, at: 0)
        items.insert(contentsOf: cart, at: 0)
    }
}
