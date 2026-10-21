import Foundation
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published private(set) var data = Snapshot()
    @Published var loadError: String?
    private var loaded = false
    private let file: URL

    init() {
        file = URL.documentsDirectory.appending(path: "jen-swift-v1.json")
        load()
    }
    func load() {
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let decoded = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: file))
                guard decoded.version == 1 else { throw JenError("Versão de dados não suportada.") }
                data = decoded
            }
            loaded = true
            loadError = nil
        } catch { loadError = "Não foi possível abrir seus dados locais: \(error.localizedDescription)" }
    }
    private func commit(_ change: (inout Snapshot) throws -> Void) throws {
        guard loaded else { throw JenError("Reabra seus dados antes de continuar.") }
        var next = data
        try change(&next)
        let encoded = try JSONEncoder().encode(next)
        try encoded.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        data = next
    }
    var active: Trip? { data.trips.first { $0.finishedAt == nil } }
    var finished: [Trip] { data.trips.filter { $0.finishedAt != nil }.sorted { $0.finishedAt! > $1.finishedAt! } }
    func items(_ trip: Trip) -> [CartItem] { data.items.filter { $0.tripID == trip.id } }
    func spent(_ trip: Trip) -> Int { items(trip).reduce(0) { $0 + $1.total } + trip.adjustment }
    func importReceipt(_ draft: ReceiptDraft, allowSimilar: Bool = false) throws {
        try commit { try $0.importReceipt(draft, allowSimilar: allowSimilar) }
    }
    func start(budget: String, market: String) throws {
        let limit = try cents(budget)
        try commit {
            guard !$0.trips.contains(where: { $0.finishedAt == nil }) else { throw JenError("Já existe uma compra em andamento.") }
            let name = market.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.trips.insert(Trip(budget: limit, market: name.isEmpty ? "Minha compra" : name), at: 0)
        }
    }
    func save(_ item: CartItem, createProduct: Bool, editingFinished: Bool = false) throws {
        try commit { state in
            guard state.trips.contains(where: { $0.id == item.tripID && (($0.finishedAt != nil) == editingFinished) }) else { throw JenError("Esta compra não está disponível para edição.") }
            guard item.price > 0, item.amount > 0, item.total > 0 || (item.printedTotal == 0 && item.total == 0) else { throw JenError("O total deve ser de pelo menos R$ 0,01.") }
            var item = item
            item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if createProduct {
                guard !item.name.isEmpty else { throw JenError("Informe um nome para salvar no histórico de produtos.") }
                let product = Product(name: item.name, mode: item.mode)
                state.products.append(product)
                item.productID = product.id
            }
            if let id = item.productID {
                guard state.products.contains(where: { $0.id == id && $0.mode == item.mode }) else { throw JenError("Selecione um produto com o mesmo tipo de preço.") }
            }
            if item.name.isEmpty { item.name = "Produto sem nome" }
            if let index = state.items.firstIndex(where: { $0.id == item.id }) { state.items[index] = item }
            else { state.items.insert(item, at: 0) }
            let adjustment = state.trips.first { $0.id == item.tripID }!.adjustment
            let finalTotal = state.items.filter { $0.tripID == item.tripID }.reduce(0) { $0 + $1.total } + adjustment
            guard !editingFinished || finalTotal > 0 else { throw JenError("Confira os descontos gerais: o total da compra deve ser positivo.") }
        }
    }
    func remove(_ item: CartItem, editingFinished: Bool = false) throws {
        try commit { state in
            guard state.trips.contains(where: { $0.id == item.tripID && (($0.finishedAt != nil) == editingFinished) }) else { throw JenError("Esta compra não está disponível para edição.") }
            if editingFinished && state.items.filter({ $0.tripID == item.tripID }).count <= 1 {
                throw JenError("Uma compra finalizada precisa ter pelo menos um item. Para removê-la inteira, use Apagar compra no histórico.")
            }
            state.items.removeAll { $0.id == item.id && $0.tripID == item.tripID }
            let adjustment = state.trips.first { $0.id == item.tripID }!.adjustment
            let finalTotal = state.items.filter { $0.tripID == item.tripID }.reduce(0) { $0 + $1.total } + adjustment
            guard !editingFinished || finalTotal > 0 else { throw JenError("A exclusão tornaria o total zero ou negativo. Confira primeiro os ajustes gerais da compra.") }
        }
    }
    func updateFinishedTrip(_ trip: Trip, budget: String, market: String, date: Date, discount: String? = nil, surcharge: String? = nil) throws {
        let limit = budget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try cents(budget)
        let reduction = try discount.map(ReceiptNumbers.adjustment)
        let addition = try surcharge.map(ReceiptNumbers.adjustment)
        try commit { state in
            try state.updateFinishedTrip(id: trip.id, budget: limit, market: market, date: date)
            if let index = state.trips.firstIndex(where: { $0.id == trip.id }) {
                if let reduction { state.trips[index].discount = reduction }
                if let addition { state.trips[index].surcharge = addition }
                let total = state.items.filter { $0.tripID == trip.id }.reduce(0) { $0 + $1.total } + state.trips[index].adjustment
                guard total > 0 else { throw JenError("Os ajustes não podem tornar o total da compra zero ou negativo.") }
            }
        }
    }
    func deleteFinishedTrip(_ trip: Trip) throws {
        try commit { try $0.deleteFinishedTrip(id: trip.id) }
    }
    func finish(_ trip: Trip) throws {
        try commit { state in
            guard let index = state.trips.firstIndex(where: { $0.id == trip.id && $0.finishedAt == nil }),
                  state.items.contains(where: { $0.tripID == trip.id }) else { throw JenError("Adicione pelo menos um item antes de finalizar.") }
            state.trips[index].finishedAt = Date()
        }
    }
    func addList(_ name: String) throws {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw JenError("Digite o nome do item.") }
        try commit { $0.list.insert(ShoppingEntry(name: value), at: 0) }
    }
    func toggle(_ entry: ShoppingEntry) throws {
        try commit { state in
            if let index = state.list.firstIndex(where: { $0.id == entry.id }) { state.list[index].checked.toggle() }
        }
    }
    func rename(_ entry: ShoppingEntry, name: String) throws {
        try commit { try $0.renameListItem(id: entry.id, name: name) }
    }
    func delete(_ entry: ShoppingEntry) throws { try commit { $0.list.removeAll { $0.id == entry.id } } }
    func records(_ product: Product) -> [CartItem] {
        data.items.filter { item in item.productID == product.id && finished.contains { $0.id == item.tripID } }
            .sorted { left, right in
                let a = finished.first { $0.id == left.tripID }!.finishedAt!
                let b = finished.first { $0.id == right.tripID }!.finishedAt!
                if a == b { return data.items.firstIndex(where: { $0.id == left.id })! < data.items.firstIndex(where: { $0.id == right.id })! }
                return a > b
            }
    }
}
