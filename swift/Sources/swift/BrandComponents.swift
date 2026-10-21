import SwiftUI
import UIKit

@MainActor
private enum BrandAssets {
    // xtool copies this PNG as a loose resource, not an asset catalog.
    // Decode its exact file URL instead of relying on SwiftUI's named-asset lookup.
    static let logo: UIImage? = {
        for bundle in [Bundle.module, Bundle.main] {
            if let url = bundle.url(forResource: "jen-logo", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }()
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let logo = BrandAssets.logo {
                    Image(uiImage: logo).resizable().scaledToFit()
                } else {
                    Image(systemName: "basket.fill").resizable().scaledToFit().foregroundStyle(Theme.blue)
                }
            }.frame(width: 56, height: 56)
                .padding(6).background(.white, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                (Text("jen").foregroundColor(Theme.blue) + Text(".").foregroundColor(Theme.teal))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                Text("Seu mercado, na conta.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .combine).accessibilityLabel("jen. Seu mercado, na conta.")
    }
}

/// Large icon plus short title. Remains readable with Dynamic Type.
struct ActionTile: View {
    let title: String
    let icon: String
    var prominent = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 27, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(prominent ? .white.opacity(0.15) : Theme.pale, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)
            Text(title).font(.headline).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).padding(18)
            .foregroundStyle(prominent ? .white : Theme.blue)
            .background(prominent ? Theme.blue : .white, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
    }
}

extension SaleMode {
    var symbol: String { switch self { case .unit: "cube"; case .weight: "scalemass"; case .package: "shippingbox" } }
}
struct SaleModeSelector: View {
    @Binding var selection: SaleMode
    @ScaledMetric private var minimumWidth = 88.0
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], spacing: 8) {
            ForEach(SaleMode.allCases) { mode in
                Button { selection = mode } label: {
                    VStack(spacing: 8) {
                        Image(systemName: mode.symbol).font(.title2).accessibilityHidden(true)
                        Text(mode.label).font(.caption.bold()).fixedSize(horizontal: false, vertical: true)
                        Image(systemName: selection == mode ? "checkmark.circle.fill" : "circle")
                            .font(.caption).accessibilityHidden(true)
                    }.frame(maxWidth: .infinity, minHeight: 90).padding(8)
                        .foregroundStyle(Theme.blue)
                        .background(selection == mode ? Theme.pale : Theme.background, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selection == mode ? Theme.teal : .clear, lineWidth: 2))
                }.buttonStyle(.plain).accessibilityLabel(mode.label)
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
    }
}
