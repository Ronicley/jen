import SwiftUI

struct ReceiptReviewView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var draft: ReceiptDraft
    let photos: [ReceiptPhoto]
    let onSaved: () -> Void
    @State private var editing: ReceiptItemDraft?
    @State private var deleting: ReceiptItemDraft?
    @State private var error = ""
    @State private var duplicate = false
    @State private var leave = false
    @State private var saving = false

    var body: some View {
        Page {
            Label("Revisar cupom", systemImage: "checklist").font(.title.bold())
            Text("Confira os produtos e os valores. Nada foi salvo ainda.").foregroundStyle(.secondary)
            metadata
            if !draft.warnings.isEmpty {
                Card { Label("Confira a leitura", systemImage: "exclamationmark.triangle").bold(); ForEach(draft.warnings, id: \.self) { Text($0).font(.footnote) } }
            }
            Label("\(draft.items.count) produtos", systemImage: "basket").font(.title3.bold())
            if draft.items.isEmpty { Text("Nenhum produto foi identificado com segurança. Consulte o texto reconhecido, adicione os itens ou volte para refazer as fotos.").foregroundStyle(.secondary) }
            ForEach(draft.items) { item in itemRow(item) }
            PrimaryButton(title: "Adicionar item que faltou", icon: "plus.circle", secondary: true) { editing = ReceiptItemDraft() }
            totals
            source
            if let similar = store.data.possibleDuplicate(draft) {
                Label("Já existe uma compra semelhante: \(similar.market), \(money(store.spent(similar))). Confira para não importar duas vezes.", systemImage: "doc.on.doc").font(.footnote).foregroundStyle(Theme.coral)
            }
            Toggle("Conferi os produtos, a data e os valores", isOn: $draft.confirmed)
            if let problem = draft.problem { Label(problem, systemImage: "info.circle").font(.footnote).foregroundStyle(Theme.coral) }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            PrimaryButton(title: "Confirmar e salvar compra", icon: "checkmark.seal.fill") { attemptSave() }.disabled(draft.problem != nil || saving)
        }.navigationTitle("Confirmar compra").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { leave = true } label: { Label("Fotos", systemImage: "chevron.left") } } }
            .sheet(item: $editing) { item in
                NavigationStack {
                    ReceiptItemEditor(item: item, photos: photos) { updated in
                        if let index = draft.items.firstIndex(where: { $0.id == updated.id }) { draft.items[index] = updated }
                        else { draft.items.append(updated) }
                        draft.confirmed = false
                        editing = nil
                    }
                }
            }
            .confirmationDialog("Apagar este item da revisão?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Apagar item", role: .destructive) { draft.items.removeAll { $0.id == deleting?.id }; deleting = nil; draft.confirmed = false }
            } message: { Text("\(deleting?.name ?? "") será removido. Confira se não é um produto legítimo antes de excluir uma possível repetição.") }
            .confirmationDialog("Importar outra compra semelhante?", isPresented: $duplicate, titleVisibility: .visible) {
                Button("Sim, é outra compra") { save(allowSimilar: true) }
            } message: { Text("Há uma compra com o mesmo mercado, dia e total. A compra existente não será substituída.") }
            .confirmationDialog("Voltar para as fotos?", isPresented: $leave, titleVisibility: .visible) {
                Button("Descartar revisão e voltar", role: .destructive) { dismiss() }
            } message: { Text("Suas correções serão descartadas. Você poderá reorganizar as imagens e fazer outra leitura.") }
            .onChange(of: draft.market) { _, _ in draft.confirmed = false }
            .onChange(of: draft.date) { _, _ in draft.confirmed = false }
            .onChange(of: draft.total) { _, _ in draft.confirmed = false }
            .onChange(of: draft.discount) { _, _ in draft.confirmed = false }
            .onChange(of: draft.surcharge) { _, _ in draft.confirmed = false }
            .onChange(of: draft.key) { _, _ in draft.confirmed = false }
    }
    private var metadata: some View {
        Card {
            EntryField(title: "Mercado", text: $draft.market, icon: "storefront")
            DatePicker("Data da compra", selection: $draft.date, in: ...Date(), displayedComponents: [.date]).environment(\.locale, Locale(identifier: "pt_BR"))
            DisclosureGroup("Identificação fiscal (opcional)") {
                EntryField(title: "Chave fiscal de 44 dígitos", text: $draft.key, keyboard: .numberPad, icon: "number")
                Text("Usada somente para detectar uma importação repetida. Não consultamos a SEFAZ.").font(.footnote)
            }
        }
    }
    private func itemRow(_ item: ReceiptItemDraft) -> some View {
        Card {
            HStack {
                Button { editing = item } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.name.isEmpty ? "Produto sem nome" : item.name, systemImage: item.problem == nil ? "checkmark.circle" : "exclamationmark.triangle").bold()
                        Text(item.totalOnly ? "Somente total" : "\(item.quantity) \(item.unit) × R$ \(item.unitPrice)").font(.footnote)
                        Text(item.netTotal.map(money) ?? "Total pendente").bold()
                        if let problem = item.problem { Text(problem).font(.caption).foregroundStyle(Theme.coral) }
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain)
                Menu {
                    Button { editing = item } label: { Label("Revisar item", systemImage: "pencil") }
                    Button(role: .destructive) { deleting = item } label: { Label("Apagar", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Ações de \(item.name)")
            }
        }
    }
    private var totals: some View {
        Card {
            Label("Conferência dos valores", systemImage: "equal.circle").font(.headline)
            HStack { Text("Soma dos itens (líquida)"); Spacer(); Text(draft.items.allSatisfy { $0.netTotal != nil } ? money(draft.items.reduce(0) { $0 + ($1.netTotal ?? 0) }) : "—").bold() }
            EntryField(title: "Desconto geral (R$)", text: $draft.discount, keyboard: .decimalPad, icon: "minus.circle")
            EntryField(title: "Acréscimo geral (R$)", text: $draft.surcharge, keyboard: .decimalPad, icon: "plus.circle")
            Text("Descontos já aplicados em um item não devem ser repetidos aqui. Troco, valor recebido e tributos informativos não são ajustes.").font(.footnote).foregroundStyle(.secondary)
            Divider()
            HStack { Text("Total calculado"); Spacer(); Text(draft.calculatedTotal.map(money) ?? "—").font(.title3.bold()) }
            EntryField(title: "Total final do cupom (R$)", text: $draft.total, keyboard: .decimalPad, icon: "receipt")
            if let difference = draft.difference {
                Label(difference == 0 ? "Valores conferem" : "Diferença: \(money(difference))", systemImage: difference == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(difference == 0 ? .green : Theme.coral)
            }
        }
    }
    private var source: some View {
        Card {
            DisclosureGroup("Consultar fotos e texto original") {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Text("Foto \(index + 1)").font(.headline)
                    ReceiptPhotoPreview(photo: photo)
                    if index < draft.pages.count { Text(draft.pages[index]).font(.caption.monospaced()).textSelection(.enabled) }
                    Divider()
                }
            }
        }
    }
    private func attemptSave() {
        let key = draft.key.filter(\.isNumber)
        if !key.isEmpty && store.data.trips.contains(where: { $0.receiptKey == key }) { error = "Este cupom já foi importado com a mesma chave fiscal."; return }
        if store.data.possibleDuplicate(draft) != nil { duplicate = true } else { save(allowSimilar: false) }
    }
    private func save(allowSimilar: Bool) {
        guard !saving else { return }
        saving = true
        do { try store.importReceipt(draft, allowSimilar: allowSimilar); onSaved() }
        catch { self.error = error.localizedDescription; saving = false }
    }
}

struct ReceiptItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: ReceiptItemDraft
    let photos: [ReceiptPhoto]
    let onSave: (ReceiptItemDraft) -> Void
    @State private var error = ""
    var body: some View {
        Page {
            Card {
                EntryField(title: "Produto", text: $item.name, icon: "tag")
                Toggle("Registrar somente o total do item", isOn: $item.totalOnly)
                if item.totalOnly {
                    Text("Use quando quantidade ou preço unitário não estiverem legíveis. O valor será registrado sem inventar preço por unidade e sem comparação automática de preços.").font(.footnote).foregroundStyle(.secondary)
                } else {
                    EntryField(title: "Quantidade", text: $item.quantity, keyboard: .decimalPad, icon: "number.circle")
                    EntryField(title: "Unidade (UN, KG, G, L…)", text: $item.unit, icon: "scalemass")
                    EntryField(title: "Preço por unidade de venda (R$)", text: $item.unitPrice, keyboard: .decimalPad, icon: "brazilianrealsign.circle")
                }
                EntryField(title: "Total do item antes do desconto (R$)", text: $item.grossTotal, keyboard: .decimalPad, icon: "receipt")
                EntryField(title: "Desconto deste item (R$)", text: $item.discount, keyboard: .decimalPad, icon: "minus.circle")
                Text("Se o total impresso já inclui o desconto, mantenha o desconto aqui em zero. O total cobrado é preservado mesmo com arredondamento.").font(.footnote).foregroundStyle(.secondary)
                HStack { Text("Total cobrado"); Spacer(); Text(item.netTotal.map(money) ?? "—").bold() }
            }
            if !item.warnings.isEmpty {
                Card {
                    ForEach(Array(Set(item.warnings)).sorted(), id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.footnote) }
                    Toggle("Revisei este item e os avisos", isOn: $item.reviewed)
                }
            }
            if !item.sourceText.isEmpty {
                Card {
                    DisclosureGroup("Trecho original · foto \(item.page)") {
                        Text(item.sourceText).font(.caption.monospaced()).textSelection(.enabled)
                        if item.page > 0 && item.page <= photos.count { ReceiptPhotoPreview(photo: photos[item.page - 1]) }
                    }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            PrimaryButton(title: "Confirmar item", icon: "checkmark.circle") {
                do { _ = try item.cartItem(tripID: UUID()); onSave(item) } catch { self.error = error.localizedDescription }
            }
        }.navigationTitle("Revisar produto").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
    }
}
