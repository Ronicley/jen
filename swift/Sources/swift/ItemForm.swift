import SwiftUI
import UIKit
import AVFoundation

struct ItemForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    let existing: CartItem?
    let editingFinished: Bool
    let openCameraOnAppear: Bool
    @State private var didOpenCamera = false
    @State private var name: String
    @State private var price: String
    @State private var amount: String
    @State private var printedTotal: String
    @State private var mode: SaleMode
    @State private var productID: UUID?
    @State private var createProduct = false
    @State private var error = ""
    @State private var photo: UIImage?
    @State private var camera = false
    @State private var confirmRemove = false
    @State private var reading: LabelReading?
    @State private var scanning = false
    @State private var scanID = UUID()
    @State private var scanMessage = ""

    init(trip: Trip, existing: CartItem? = nil, editingFinished: Bool = false, openCameraOnAppear: Bool = false) {
        self.trip = trip
        self.existing = existing
        self.editingFinished = editingFinished
        self.openCameraOnAppear = openCameraOnAppear
        _name = State(initialValue: existing?.name ?? "")
        _price = State(initialValue: existing.map { String(format: "%.2f", Double($0.price) / 100).replacingOccurrences(of: ".", with: ",") } ?? "")
        _amount = State(initialValue: existing.map { String($0.amount) } ?? "1")
        _printedTotal = State(initialValue: existing?.printedTotal.map(ReceiptNumbers.text) ?? "")
        _mode = State(initialValue: existing?.mode ?? .unit)
        _productID = State(initialValue: existing?.productID)
    }
    private func draft() throws -> CartItem {
        var item = CartItem(id: existing?.id ?? UUID(), tripID: trip.id, productID: productID, name: name, mode: mode, price: try cents(price), amount: try quantity(amount))
        if existing?.printedTotal != nil {
            item.printedTotal = try ReceiptNumbers.money(printedTotal, allowZero: true)
            if item.price == existing?.price && item.amount == existing?.amount && item.mode == existing?.mode && item.printedTotal == existing?.printedTotal {
                item.receiptDetail = existing?.receiptDetail
                item.receiptDiscount = existing?.receiptDiscount
            }
        }
        return item
    }
    var matches: [Product] {
        Array(store.data.products.filter { $0.mode == mode && (name.isEmpty || $0.name.localizedCaseInsensitiveContains(name)) }.sorted { $0.name < $1.name }.prefix(6))
    }
    var body: some View {
        Page {
            Label("Confira o produto", systemImage: "tag").font(.title.bold())
            Text("Só entra na conta depois da sua confirmação.").foregroundStyle(.secondary)
            if let photo { Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 20)) }
            PrimaryButton(title: photo == nil ? "Ler etiqueta" : "Nova foto", icon: "camera.viewfinder", secondary: true) { requestCamera() }.disabled(scanning)
            Text("A leitura acontece neste iPhone, sem enviar a foto. Confira os dados sugeridos antes de adicionar ao carrinho.").font(.footnote).foregroundStyle(.secondary)
            if scanning { ProgressView("Lendo nome e preços da etiqueta…").accessibilityLabel("Lendo etiqueta") }
            if !scanMessage.isEmpty { Text(scanMessage).font(.footnote).foregroundStyle(Theme.blue) }
            if let reading {
                Card {
                    Label("Etiqueta lida", systemImage: "text.viewfinder").font(.title3.bold())
                    if let suggestion = reading.name {
                        Text("Nome sugerido: \(suggestion)")
                        Button { name = suggestion; productID = nil; createProduct = false } label: { Label("Usar nome", systemImage: "checkmark.circle") }.frame(minHeight: 44)
                    }
                    if reading.prices.count > 1 {
                        Text("Encontrei mais de um preço. Escolha o que vale para sua compra; confira condições de clube, quantidade e promoção.").font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(reading.prices) { candidate in
                        Button { applyPrice(candidate, reading: reading) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Usar \(money(candidate.cents))\(candidate.perKg ? "/kg" : candidate.isTotal ? " (total)" : "")").bold()
                                Text(candidate.context).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                        }
                    }
                    if let grams = reading.grams { Text("Peso identificado: \(grams) g. Só é aplicado quando você escolhe um preço por kg.").font(.footnote) }
                    DisclosureGroup("Ver todo o texto reconhecido") { Text(reading.rawText).font(.footnote).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
            Card {
                EntryField(title: "Produto (opcional)", text: $name, icon: "tag")
                Text("Como é vendido?").font(.subheadline.bold())
                SaleModeSelector(selection: Binding(get: { mode }, set: { value in
                    mode = value; amount = value == .weight ? "" : "1"; productID = nil; createProduct = false
                }))
                EntryField(title: mode == .weight ? "Preço por kg (R$)" : mode == .package ? "Total por embalagem (R$)" : "Preço por unidade (R$)", text: $price, keyboard: .decimalPad, icon: "brazilianrealsign.circle")
                EntryField(title: mode == .weight ? "Peso em gramas" : "Quantidade", text: $amount, keyboard: .numberPad, icon: mode == .weight ? "scalemass" : "number.circle")
                if mode == .package { Text("Use o total impresso no adesivo. Sem peso informado, não comparamos o preço por kg.").font(.footnote).foregroundStyle(.secondary) }
                if existing?.printedTotal != nil {
                    EntryField(title: "Total cobrado deste item (R$)", text: $printedTotal, keyboard: .decimalPad, icon: "receipt")
                    Text("Item importado: este total, já com desconto, é o que conta na compra. Ao alterar quantidade ou preço, atualize também o total cobrado.").font(.footnote).foregroundStyle(.secondary)
                    if let detail = existing?.receiptDetail { Text("No cupom: \(detail)").font(.footnote) }
                }
            }
            Card {
                Label("Histórico de preços", systemImage: "chart.line.uptrend.xyaxis").font(.title3.bold())
                Text("Associe somente se for a mesma marca e tamanho.").font(.footnote).foregroundStyle(.secondary)
                if let id = productID, let product = store.data.products.first(where: { $0.id == id }) {
                    Text("Selecionado: \(product.name)").bold()
                    if let previous = store.records(product).first { Text("Último preço: \(money(previous.price))\(mode == .weight ? "/kg" : "")").font(.footnote) }
                    Button { productID = nil } label: { Label("Desvincular", systemImage: "link.badge.plus") }.frame(minHeight: 44)
                } else {
                    ForEach(matches) { product in
                        Button("É este: \(product.name)") { productID = product.id; name = product.name; createProduct = false }.padding(.vertical, 6)
                    }
                    Toggle("Salvar como novo produto", isOn: $createProduct)
                    Text(createProduct ? "Use nome, marca e tamanho para identificar este produto." : "Sem associação: conta no orçamento, mas não na comparação de preços.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Card {
                let preview = try? draft()
                HStack { Text("Total do item"); Spacer(); Text(preview.map { money($0.total) } ?? "—").bold() }
                let other = store.items(trip).filter { $0.id != existing?.id }.reduce(0) { $0 + $1.total }
                if let budget = trip.budget {
                    HStack { Text("Saldo após confirmar"); Spacer(); Text(preview.map { money(budget - other - $0.total - trip.adjustment) } ?? "—").bold() }
                } else {
                    HStack { Text("Compra após confirmar"); Spacer(); Text(preview.map { money(other + $0.total + trip.adjustment) } ?? "—").bold() }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
            PrimaryButton(title: existing == nil ? "Adicionar" : "Salvar", icon: existing == nil ? "cart.badge.plus" : "checkmark.circle.fill") {
                do { try store.save(draft(), createProduct: createProduct, editingFinished: editingFinished); dismiss() } catch { self.error = error.localizedDescription }
            }.disabled(scanning)
            if existing != nil { Button(role: .destructive) { confirmRemove = true } label: { Label("Apagar item", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44) }.tint(Theme.coral) }
        }.navigationTitle(existing == nil ? "Adicionar produto" : "Editar produto").navigationBarTitleDisplayMode(.inline)
            .task {
                if openCameraOnAppear && !didOpenCamera {
                    didOpenCamera = true
                    requestCamera()
                }
            }
            .sheet(isPresented: $camera) { CameraPicker(photo: $photo).ignoresSafeArea() }
            .onChange(of: photo) { _, image in
                guard let image else { return }
                readLabel(image)
            }
            .onDisappear { scanID = UUID() }
            .confirmationDialog("Remover produto? O valor voltará ao saldo disponível.", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remover", role: .destructive) {
                    do { if let existing { try store.remove(existing, editingFinished: editingFinished); dismiss() } } catch { self.error = error.localizedDescription }
                }
            }
    }
    private func applyPrice(_ candidate: LabelPrice, reading: LabelReading) {
        price = String(format: "%.2f", Double(candidate.cents) / 100).replacingOccurrences(of: ".", with: ",")
        productID = nil
        createProduct = false
        if candidate.isTotal {
            mode = .package
            amount = "1"
        } else if candidate.perKg {
            mode = .weight
            amount = reading.grams.map(String.init) ?? ""
        } else {
            mode = .unit
            amount = "1"
        }
        scanMessage = "Preço sugerido aplicado. Confira nome, preço e \(mode == .weight ? "peso" : "quantidade") antes de confirmar."
    }
    private func readLabel(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { error = "Não foi possível preparar a foto para leitura."; return }
        let id = UUID()
        scanID = id
        scanning = true
        reading = nil
        error = ""
        scanMessage = ""
        Task { @MainActor in
            do {
                let result = try await LabelRecognizer.recognize(data)
                guard scanID == id else { return }
                reading = result
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let suggestion = result.name { name = suggestion }
                if result.prices.count == 1, price.isEmpty, let candidate = result.prices.first {
                    applyPrice(candidate, reading: result)
                } else if result.prices.isEmpty {
                    scanMessage = "Li o texto, mas não identifiquei um preço com segurança. Confira o texto abaixo ou tente outra foto."
                } else {
                    scanMessage = "Etiqueta lida. Escolha o preço abaixo para preencher o formulário."
                }
                scanning = false
            } catch {
                guard scanID == id else { return }
                scanning = false
                self.error = "Não foi possível ler a etiqueta: \(error.localizedDescription)"
            }
        }
    }
    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "Câmera indisponível. Digite os dados manualmente."; return }
        Task { @MainActor in
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { camera = true }
            else { error = "Permita o acesso à câmera em Ajustes > jen. Você também pode digitar sem foto." }
        }
    }
}
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var photo: UIImage?
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.photo = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
