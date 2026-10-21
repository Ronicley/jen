import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var store: Store
    @State private var name = ""
    @State private var error = ""
    @State private var editing: ShoppingEntry?
    @State private var editedName = ""
    @State private var deleting: ShoppingEntry?
    var entries: [ShoppingEntry] { store.data.list.filter { !$0.checked } + store.data.list.filter { $0.checked } }
    var body: some View {
        Page {
            Label("Sua lista", systemImage: "checklist").font(.largeTitle.bold())
            Card {
                EntryField(title: "O que falta?", text: $name, icon: "basket")
                PrimaryButton(title: "Adicionar", icon: "plus.circle.fill") {
                    perform { try store.addList(name); name = "" }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            if entries.isEmpty { ContentUnavailableView("Sua lista está vazia", systemImage: "checklist", description: Text("Adicione o que precisa comprar.")) }
            ForEach(entries) { entry in
                Card {
                    HStack(spacing: 16) {
                        Button { perform { try store.toggle(entry) } } label: {
                            Label(entry.name, systemImage: entry.checked ? "checkmark.circle.fill" : "circle")
                                .strikethrough(entry.checked).foregroundStyle(entry.checked ? .secondary : Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityValue(entry.checked ? "Concluído" : "Pendente")
                        Menu {
                            Button { beginEditing(entry) } label: { Label("Editar", systemImage: "pencil") }
                            Button(role: .destructive) { deleting = entry } label: { Label("Apagar", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis.circle").font(.title2).foregroundStyle(Theme.blue).frame(width: 44, height: 44) }
                            .accessibilityLabel("Ações de \(entry.name)")
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 20))
                .contextMenu {
                    Button { beginEditing(entry) } label: { Label("Editar item", systemImage: "pencil") }
                    Button(role: .destructive) { deleting = entry } label: { Label("Apagar item", systemImage: "trash") }
                }
                .accessibilityAction(named: "Editar item") { beginEditing(entry) }
                .accessibilityAction(named: "Apagar item") { deleting = entry }
            }
        }.toolbar(.hidden, for: .navigationBar)
            .alert("Editar item da lista", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Nome do item", text: $editedName)
                Button("Salvar") {
                    guard let entry = editing else { return }
                    perform { try store.rename(entry, name: editedName) }
                    editing = nil
                }.disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancelar", role: .cancel) { editing = nil }
            }
            .confirmationDialog("Apagar item da lista?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Apagar item", role: .destructive) {
                    guard let entry = deleting else { return }
                    perform { try store.delete(entry) }
                    deleting = nil
                }
                Button("Cancelar", role: .cancel) { deleting = nil }
            } message: { Text("\(deleting?.name ?? "") será removido da lista. Esta ação não pode ser desfeita.") }
    }
    private func beginEditing(_ entry: ShoppingEntry) {
        editedName = entry.name
        editing = entry
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); error = "" } catch { self.error = error.localizedDescription }
    }
}
struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Trip?
    @State private var deleting: Trip?
    @State private var importing = false
    @State private var error = ""
    var body: some View {
        Page {
            Label("Histórico", systemImage: "clock.arrow.circlepath").font(.largeTitle.bold())
            PrimaryButton(title: "Importar cupom", icon: "receipt") { importing = true }
            if store.finished.isEmpty {
                ContentUnavailableView("Cada compra conta uma história", systemImage: "receipt", description: Text("Finalize sua primeira compra para ver os gastos e os preços registrados."))
            } else {
                Label("Seus preços", systemImage: "chart.line.uptrend.xyaxis").font(.title3.bold())
                Text("Comparações apenas entre produtos associados por você. Compare embalagens do mesmo tamanho.").font(.footnote).foregroundStyle(.secondary)
                ForEach(store.data.products.filter { !store.records($0).isEmpty }) { product in
                    PriceHistoryCard(product: product)
                }
                if !store.data.products.contains(where: { !store.records($0).isEmpty }) { Text("Associe ou crie um produto ao adicionar itens para começar a comparar preços.").font(.footnote) }
                Label("Compras", systemImage: "receipt").font(.title3.bold())
                ForEach(store.finished) { trip in
                    Card {
                        HStack {
                            Label(shortDate(trip.finishedAt!), systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Menu {
                                Button { editing = trip } label: { Label("Editar compra", systemImage: "pencil") }
                                Button(role: .destructive) { deleting = trip } label: { Label("Apagar compra", systemImage: "trash") }
                            } label: { Image(systemName: "ellipsis.circle").font(.title2).frame(width: 44, height: 44) }
                                .accessibilityLabel("Ações da compra \(trip.market)")
                        }
                        DisclosureGroup {
                            ForEach(store.items(trip)) { item in
                                PurchaseItemRow(trip: trip, item: item, editingFinished: true, compact: true)
                            }
                            if let discount = trip.discount, discount > 0 {
                                HStack { Label("Desconto geral", systemImage: "minus.circle"); Spacer(); Text("−\(money(discount))") }.font(.footnote)
                            }
                            if let surcharge = trip.surcharge, surcharge > 0 {
                                HStack { Label("Acréscimo geral", systemImage: "plus.circle"); Spacer(); Text(money(surcharge)) }.font(.footnote)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(trip.market).bold(); Spacer(); Text(money(store.spent(trip))).bold() }
                                Text("\(shortDate(trip.finishedAt!)) · \(store.items(trip).count) itens").font(.footnote)
                                if let budget = trip.budget { Text("Orçamento: \(money(budget))").font(.footnote).foregroundStyle(.secondary) }
                                if trip.source == "receipt" { Label("Importada de cupom", systemImage: "doc.text.viewfinder").font(.caption).foregroundStyle(Theme.blue) }
                                if trip.adjustment != 0 { Text("Ajustes gerais: \(money(trip.adjustment))").font(.caption) }
                                if let original = trip.receiptTotal, original != store.spent(trip) { Text("Cupom original: \(money(original)) · compra alterada após importação").font(.caption).foregroundStyle(Theme.coral) }
                            }.foregroundStyle(Theme.ink)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 20))
                    .contextMenu {
                        Button { editing = trip } label: { Label("Editar compra", systemImage: "pencil") }
                        Button(role: .destructive) { deleting = trip } label: { Label("Apagar compra", systemImage: "trash") }
                    }
                    .accessibilityAction(named: "Editar compra") { editing = trip }
                    .accessibilityAction(named: "Apagar compra") { deleting = trip }
                }
            }
        }.toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { trip in NavigationStack { EditFinishedTripView(trip: trip) }.environmentObject(store) }
            .sheet(isPresented: $importing) { NavigationStack { ReceiptImportView() }.environmentObject(store) }
            .confirmationDialog("Apagar esta compra?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Apagar compra e seus itens", role: .destructive) {
                    guard let trip = deleting else { return }
                    do { try store.deleteFinishedTrip(trip) } catch { self.error = error.localizedDescription }
                    deleting = nil
                }
                Button("Cancelar", role: .cancel) { deleting = nil }
            } message: {
                Text("A compra \(deleting?.market ?? "") e todos os seus itens serão removidos. Os totais e o histórico de preços serão recalculados. Esta ação não pode ser desfeita.")
            }
            .alert("Não foi possível apagar", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) {
                Button("OK") { error = "" }
            } message: { Text(error) }
    }
}
struct PriceHistoryCard: View {
    @EnvironmentObject var store: Store
    let product: Product
    var body: some View {
        let records = store.records(product)
        Card {
            Text(product.name).font(.headline)
            if let latest = records.first {
                HStack { Text("\(money(latest.price))\(product.mode == .weight ? "/kg" : "")").font(.title3.bold()); Spacer(); Text(product.mode.label).font(.footnote) }
                if let previous = records.first(where: { $0.tripID != latest.tripID }) {
                    let difference = latest.price - previous.price
                    Text(difference == 0 ? "Mesmo preço da compra anterior" : "\(difference > 0 ? "+" : "−")\(money(abs(difference))) em relação à compra anterior")
                        .font(.footnote).foregroundStyle(difference > 0 ? .red : .green)
                } else { Text("Primeiro preço registrado.").font(.footnote).foregroundStyle(.secondary) }
                Divider()
                ForEach(Array(records.prefix(5))) { item in
                    if let trip = store.finished.first(where: { $0.id == item.tripID }) {
                        HStack { Text("\(shortDate(trip.finishedAt!)) · \(trip.market)").font(.footnote); Spacer(); Text(money(item.price)).font(.subheadline.bold()) }
                    }
                }
            }
        }
    }
}
