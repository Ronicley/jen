import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct ReceiptPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
    @MainActor
    init(_ image: UIImage) throws {
        let maxSide: CGFloat = 2400
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        // Drawing also normalizes camera/HEIC orientation before OCR.
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.9) else { throw JenError("Não consegui abrir esta imagem.") }
        self.data = data
        let thumbnailScale = min(1, 480 / max(size.width, size.height))
        let thumbnailSize = CGSize(width: size.width * thumbnailScale, height: size.height * thumbnailScale)
        self.image = UIGraphicsImageRenderer(size: thumbnailSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
}
struct ReceiptImportView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [ReceiptPhoto] = []
    @State private var selection: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var cameraPhoto: UIImage?
    @State private var busy = false
    @State private var progress = ""
    @State private var error = ""
    @State private var draft = ReceiptDraft()
    @State private var reviewing = false
    @State private var cancel = false
    @State private var readingTask: Task<Void, Never>?
    private let limit = 10

    var body: some View {
        Page {
            Label("Importar cupom", systemImage: "receipt").font(.title.bold())
            Text("Fotografe uma compra já feita. Em cupons longos, use várias fotos, em ordem, com os produtos e o total legíveis.").foregroundStyle(.secondary)
            Label("Leitura neste iPhone · sem enviar fotos", systemImage: "lock.shield").font(.footnote).foregroundStyle(Theme.blue)
            if busy { ProgressView(progress).frame(maxWidth: .infinity) }
            captureActions.disabled(busy || photos.count >= limit)
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                Card {
                    HStack {
                        Text("Foto \(index + 1)").bold()
                        Spacer()
                        Button { photos.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityLabel("Mover foto para cima")
                        Button { photos.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }.disabled(index == photos.count - 1).accessibilityLabel("Mover foto para baixo")
                        Button(role: .destructive) { photos.removeAll { $0.id == photo.id } } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Remover foto \(index + 1)")
                    }
                    Image(uiImage: photo.image).resizable().scaledToFit().frame(maxHeight: 260).frame(maxWidth: .infinity)
                }.disabled(busy)
            }
            Text("\(photos.count)/\(limit) fotos. Para refazer, remova uma imagem e fotografe novamente. Evite cortar um produto entre fotos; repetições serão sinalizadas para revisão.").font(.footnote).foregroundStyle(.secondary)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            PrimaryButton(title: "Ler e revisar", icon: "text.viewfinder") { recognize() }.disabled(photos.isEmpty || busy)
        }.navigationTitle("Cupom fiscal").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { if photos.isEmpty && !busy { dismiss() } else { cancel = true } } } }
            .interactiveDismissDisabled(!photos.isEmpty || busy)
            .sheet(isPresented: $camera) { CameraPicker(photo: $cameraPhoto).ignoresSafeArea() }
            .onChange(of: cameraPhoto) { _, image in
                guard let image else { return }
                do { if photos.count < limit { photos.append(try ReceiptPhoto(image)) } } catch { self.error = error.localizedDescription }
                cameraPhoto = nil
            }
            .onChange(of: selection) { _, items in loadPhotos(items) }
            .navigationDestination(isPresented: $reviewing) {
                ReceiptReviewView(draft: draft, photos: photos) { dismiss() }
                    .environmentObject(store)
            }
            .confirmationDialog("Descartar esta importação?", isPresented: $cancel, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { readingTask?.cancel(); dismiss() }
            } message: { Text("Nada foi salvo no histórico. As fotos e os dados em revisão serão descartados.") }
    }
    private var captureActions: some View {
        HStack(spacing: 12) {
            Button { requestCamera() } label: { ActionTile(title: "Fotografar", icon: "camera", prominent: true) }.buttonStyle(.plain)
            PhotosPicker(selection: $selection, maxSelectionCount: max(1, limit - photos.count), selectionBehavior: .ordered, matching: .images) {
                ActionTile(title: "Galeria", icon: "photo.on.rectangle")
            }.buttonStyle(.plain)
        }
    }
    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "Câmera indisponível. Selecione uma imagem da galeria."; return }
        Task { @MainActor in
            if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
            else { error = "Permita o acesso à câmera em Ajustes > jen ou use a galeria." }
        }
    }
    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        busy = true
        error = ""
        progress = "Abrindo imagens…"
        readingTask = Task { @MainActor in
            defer { busy = false; selection = [] }
            do {
                var loaded: [ReceiptPhoto] = []
                for item in items {
                    try Task.checkCancellation()
                    guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw JenError("Uma imagem não pôde ser aberta. Tente selecioná-la novamente.") }
                    loaded.append(try ReceiptPhoto(image))
                }
                try Task.checkCancellation()
                photos.append(contentsOf: loaded.prefix(limit - photos.count))
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
    private func recognize() {
        busy = true
        error = ""
        let images = photos.map(\.data)
        readingTask = Task { @MainActor in
            defer { busy = false }
            do {
                var pages: [RecognizedPage] = []
                for (index, data) in images.enumerated() {
                    try Task.checkCancellation()
                    progress = "Lendo foto \(index + 1) de \(images.count)…"
                    let page = try await TextRecognizer.recognize(data)
                    try Task.checkCancellation()
                    pages.append(page)
                }
                let recognizedPages = pages
                draft = await Task.detached(priority: .userInitiated) { ReceiptParser.parse(recognizedPages) }.value
                try Task.checkCancellation()
                reviewing = true
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
    }
}
