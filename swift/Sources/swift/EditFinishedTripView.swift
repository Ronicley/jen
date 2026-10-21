import SwiftUI

struct EditFinishedTripView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    @State private var market: String
    @State private var budget: String
    @State private var date: Date
    @State private var discount: String
    @State private var surcharge: String
    @State private var error = ""
    @State private var saved = false

    init(trip: Trip) {
        self.trip = trip
        _market = State(initialValue: trip.market)
        _budget = State(initialValue: trip.budget.map(ReceiptNumbers.text) ?? "")
        _date = State(initialValue: trip.finishedAt ?? Date())
        _discount = State(initialValue: ReceiptNumbers.text(trip.discount ?? 0))
        _surcharge = State(initialValue: ReceiptNumbers.text(trip.surcharge ?? 0))
    }
    private var current: Trip? { store.finished.first { $0.id == trip.id } }
    var body: some View {
        Page {
            if let current {
                Label("Editar compra", systemImage: "pencil.circle").font(.title.bold())
                Card {
                    EntryField(title: "Mercado", text: $market, icon: "storefront")
                    EntryField(title: "Orçamento opcional (R$)", text: $budget, keyboard: .decimalPad, icon: "wallet.bifold")
                    if current.source == "receipt" {
                        EntryField(title: "Desconto geral (R$)", text: $discount, keyboard: .decimalPad, icon: "minus.circle")
                        EntryField(title: "Acréscimo geral (R$)", text: $surcharge, keyboard: .decimalPad, icon: "plus.circle")
                    }
                    DatePicker("Data da compra", selection: $date, in: ...Date(), displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "pt_BR"))
                    if !error.isEmpty { Text(error).foregroundStyle(.red) }
                    if saved { Label("Dados da compra salvos", systemImage: "checkmark.circle").foregroundStyle(.green) }
                    PrimaryButton(title: "Salvar", icon: "checkmark.circle.fill") {
                        do {
                            try store.updateFinishedTrip(current, budget: budget, market: market, date: date,
                                                         discount: current.source == "receipt" ? discount : nil,
                                                         surcharge: current.source == "receipt" ? surcharge : nil)
                            error = ""
                            saved = true
                        } catch { self.error = error.localizedDescription }
                    }
                }
                Card {
                    HStack { Text("Total da compra"); Spacer(); Text(money(store.spent(current))).bold() }
                    if let budget = current.budget { HStack { Text("Saldo do orçamento"); Spacer(); Text(money(budget - store.spent(current))).bold() } }
                    if let original = current.receiptTotal { Text("Total original do cupom: \(money(original))").font(.footnote).foregroundStyle(.secondary) }
                }
                Label("Itens", systemImage: "basket").font(.title3.bold())
                Text("Toque em um item para editar ou remover. Alterações nos itens são salvas ao confirmar cada formulário, independentemente dos dados acima.").font(.footnote).foregroundStyle(.secondary)
                ForEach(store.items(current)) { item in
                    PurchaseItemRow(trip: current, item: item, editingFinished: true)
                }
                NavigationLink { ItemForm(trip: current, editingFinished: true) } label: {
                    Label("Adicionar item à compra", systemImage: "plus.circle").font(.headline).frame(maxWidth: .infinity).padding()
                }
            } else { ContentUnavailableView("Compra não encontrada", systemImage: "receipt") }
        }.navigationTitle("Editar compra").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } } }
            .onChange(of: market) { _, _ in saved = false }
            .onChange(of: budget) { _, _ in saved = false }
            .onChange(of: date) { _, _ in saved = false }
            .onChange(of: discount) { _, _ in saved = false }
            .onChange(of: surcharge) { _, _ in saved = false }
    }
}
