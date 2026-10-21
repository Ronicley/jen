import SwiftUI
import UIKit

struct ReceiptPhotoPreview: View {
    let photo: ReceiptPhoto
    @State private var expanded = false
    var body: some View {
        Button { expanded = true } label: {
            VStack {
                Image(uiImage: photo.image).resizable().scaledToFit().frame(maxHeight: 260)
                Label("Ampliar foto", systemImage: "plus.magnifyingglass").font(.caption)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).accessibilityLabel("Ampliar foto do cupom")
            .fullScreenCover(isPresented: $expanded) {
                NavigationStack { ReceiptPhotoViewer(photo: photo) }
            }
    }
}
private struct ReceiptPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ReceiptPhoto
    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image ?? photo.image).resizable().scaledToFit()
                    .frame(width: max(1, geometry.size.width - 24) * zoom).padding(12)
            }
        }.background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button { zoom = max(1, zoom - 0.5) } label: { Label("Reduzir", systemImage: "minus.magnifyingglass").frame(minHeight: 44) }.disabled(zoom <= 1)
                    Spacer()
                    Text("\(Int(zoom * 100))%").monospacedDigit()
                    Spacer()
                    Button { zoom = min(4, zoom + 0.5) } label: { Label("Ampliar", systemImage: "plus.magnifyingglass").frame(minHeight: 44) }.disabled(zoom >= 4)
                }.padding().background(.regularMaterial)
            }
            .navigationTitle("Foto do cupom").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fechar") { dismiss() } } }
            .task { image = UIImage(data: photo.data) }
    }
}
