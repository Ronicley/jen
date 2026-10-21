import SwiftUI

/// The same actions for manually entered and OCR-confirmed items.
struct PurchaseItemRow: View {
    @EnvironmentObject var store: Store
    let trip: Trip
    let item: CartItem
    var editingFinished = false
    var compact = false
    @State private var editing = false
    @State private var deleting = false
    @State private var error = ""

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.mode.symbol).foregroundStyle(Theme.blue).accessibilityHidden(true)
                Text(item.name).bold()
                Spacer()
                Text(money(item.total)).bold()
            }
            Text(item.detail).font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button { editing = true } label: { details }.buttonStyle(.plain)
                .accessibilityHint("Abre a edição do item")
            Menu {
                Button { editing = true } label: { Label("Editar", systemImage: "pencil") }
                Button(role: .destructive) { deleting = true } label: { Label("Apagar", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle").font(.title2).foregroundStyle(Theme.blue).frame(width: 44, height: 44) }
                .accessibilityLabel("Ações de \(item.name)")
        }
    }
    var body: some View {
        Group {
            if compact { actionsRow.padding(.vertical, 8) }
            else { Card { actionsRow } }
        }.contentShape(Rectangle())
            .contextMenu {
                Button { editing = true } label: { Label("Editar item", systemImage: "pencil") }
                Button(role: .destructive) { deleting = true } label: { Label("Apagar item", systemImage: "trash") }
            }
            .accessibilityAction(named: "Editar item") { editing = true }
            .accessibilityAction(named: "Apagar item") { deleting = true }
            .sheet(isPresented: $editing) {
                NavigationStack {
                    ItemForm(trip: trip, existing: item, editingFinished: editingFinished)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { editing = false } } }
                }.environmentObject(store)
            }
            .confirmationDialog("Apagar \(item.name)?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Apagar item", role: .destructive) {
                    do { try store.remove(item, editingFinished: editingFinished) }
                    catch { self.error = error.localizedDescription }
                }
            } message: { Text("O item será removido e o total da compra será recalculado. Esta ação não pode ser desfeita.") }
            .alert("Não foi possível apagar", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) {
                Button("OK") { error = "" }
            } message: { Text(error) }
    }
}
