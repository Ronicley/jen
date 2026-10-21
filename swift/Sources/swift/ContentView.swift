import SwiftUI

enum Theme {
    // Navy and turquoise from jen-logo.png; navy keeps buttons legible.
    static let blue = Color(red: 0.024, green: 0.196, blue: 0.353)
    static let teal = Color(red: 0, green: 0.69, blue: 0.73)
    static let coral = Color(red: 0.80, green: 0.22, blue: 0.17)
    static let pale = Color(red: 0.88, green: 0.96, blue: 0.96)
    static let background = Color(red: 0.95, green: 0.97, blue: 0.97)
    static let ink = Color(red: 0.082, green: 0.145, blue: 0.212)
}
struct Card<Content: View>: View {
    var blue = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .foregroundStyle(blue ? .white : Theme.ink)
            .background(blue ? Theme.blue : .white, in: RoundedRectangle(cornerRadius: 20))
    }
}
struct Page<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BrandHeader()
                content()
            }.frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity)
        }
            .background(Theme.background).scrollDismissesKeyboard(.interactively)
    }
}
struct PrimaryButton: View {
    let title: String
    var icon: String = "arrow.right"
    var secondary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).labelStyle(.titleAndIcon)
                .font(.headline).frame(maxWidth: .infinity).padding(16)
                .foregroundStyle(secondary ? Theme.blue : .white)
                .background(secondary ? Theme.pale : Theme.blue, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }
}
struct EntryField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var icon: String = "pencil"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(Theme.blue)
            TextField(title, text: $text).keyboardType(keyboard).accessibilityLabel(title).padding(15)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.2)))
        }
    }
}
struct ContentView: View {
    @StateObject private var store = Store()
    @State private var tab = 0
    var body: some View {
        Group {
            if let error = store.loadError {
                ContentUnavailableView {
                    Label("Seus dados estão protegidos", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(error) } actions: { Button("Tentar novamente") { store.load() } }
            } else {
                TabView(selection: $tab) {
                    NavigationStack { HomeView(tab: $tab) }.tabItem { Label("Início", systemImage: "house") }.tag(0)
                    NavigationStack { ShoppingListView() }.tabItem { Label("Lista", systemImage: "checklist") }.tag(1)
                    NavigationStack { HistoryView() }.tabItem { Label("Histórico", systemImage: "clock") }.tag(2)
                }
            }
        }.environmentObject(store).tint(Theme.blue).preferredColorScheme(.light)
    }
}
struct HomeView: View {
    @EnvironmentObject var store: Store
    @Binding var tab: Int
    var monthly: [Trip] { store.finished.filter { Calendar.current.isDate($0.finishedAt!, equalTo: Date(), toGranularity: .month) } }
    var body: some View {
        Page {
            Text("Compre com tranquilidade.").font(.largeTitle.bold())
            Card(blue: true) {
                if let trip = store.active {
                    let balance = (trip.budget ?? 0) - store.spent(trip)
                    Label("Compra em andamento", systemImage: "cart")
                    Text(balance < 0 ? "Acima do orçamento" : "Você ainda pode gastar")
                    Text(money(abs(balance))).font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(trip.market)
                    NavigationLink { ShoppingView() } label: { Label("Continuar", systemImage: "cart.fill").font(.headline).padding().frame(maxWidth: .infinity).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14)) }
                } else {
                    Label("Seu orçamento, seu ritmo", systemImage: "basket.fill").font(.headline)
                    Text("Sem surpresa\nno caixa.").font(.largeTitle.bold())
                    NavigationLink { NewTripView() } label: { Label("Nova compra", systemImage: "plus.circle.fill").font(.headline).padding().frame(maxWidth: .infinity).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 14)) }
                }
            }
            Label("Seu mês", systemImage: "chart.bar.fill").font(.title3.bold()).foregroundStyle(Theme.blue)
            Card {
                let spent = monthly.reduce(0) { $0 + store.spent($1) }
                Label("Total gasto", systemImage: "creditcard").font(.subheadline)
                Text(money(spent)).font(.largeTitle.bold()).monospacedDigit()
                Divider()
                HStack { VStack(alignment: .leading) { Text("Compras finalizadas").font(.caption); Text("\(monthly.count)").font(.title2) }; Spacer(); VStack(alignment: .trailing) { Text("Média por compra").font(.caption); Text(monthly.isEmpty ? "—" : money(Int((Double(spent) / Double(monthly.count)).rounded()))).font(.title2) } }
            }
            Card {
                Label("Sua lista", systemImage: "checklist").font(.title3.bold())
                Text("\(store.data.list.filter { !$0.checked }.count) itens pendentes na sua lista.").foregroundStyle(.secondary)
                PrimaryButton(title: "Abrir lista", icon: "checklist", secondary: true) { tab = 1 }
            }
            if let trip = store.finished.first {
                Card {
                    Label("Última compra", systemImage: "receipt").font(.headline)
                    HStack { VStack(alignment: .leading) { Text(trip.market); Text(shortDate(trip.finishedAt!)).font(.caption) }; Spacer(); Text(money(store.spent(trip))).bold() }
                    PrimaryButton(title: "Ver histórico", icon: "clock", secondary: true) { tab = 2 }
                }
            } else { Text("Seu histórico começa ao finalizar a primeira compra. Os dados ficam neste aparelho.").font(.footnote).foregroundStyle(.secondary) }
        }.toolbar(.hidden, for: .navigationBar)
    }
}
struct NewTripView: View {
    @EnvironmentObject var store: Store
    @State private var budget = ""
    @State private var market = ""
    @State private var error = ""
    var body: some View {
        Group {
            if store.active != nil { ShoppingView() }
            else {
                Page {
                    Text("Comece pelo seu limite").font(.largeTitle.bold())
                    Text("Quanto você quer gastar nesta compra?").foregroundStyle(.secondary)
                    Card { EntryField(title: "Orçamento (R$)", text: $budget, keyboard: .decimalPad, icon: "wallet.bifold"); EntryField(title: "Mercado (opcional)", text: $market, icon: "storefront") }
                    if !error.isEmpty { Text(error).foregroundStyle(.red) }
                    PrimaryButton(title: "Começar compra", icon: "cart") {
                        do { try store.start(budget: budget, market: market) } catch { self.error = error.localizedDescription }
                    }
                }.navigationTitle("Nova compra").navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
struct ShoppingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var error = ""
    var body: some View {
        Page {
            if let trip = store.active {
                Text(trip.market).font(.largeTitle.bold())
                Card(blue: true) {
                    Label((trip.budget ?? 0) < store.spent(trip) ? "Acima do orçamento" : "Saldo disponível", systemImage: (trip.budget ?? 0) < store.spent(trip) ? "exclamationmark.triangle.fill" : "wallet.bifold")
                    Text(money((trip.budget ?? 0) - store.spent(trip))).font(.largeTitle.bold()).monospacedDigit()
                    Text("Orçamento: \(money(trip.budget ?? 0)) · Carrinho: \(money(store.spent(trip)))")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .top)], spacing: 12) {
                    NavigationLink { ItemForm(trip: trip, openCameraOnAppear: true) } label: { ActionTile(title: "Ler etiqueta", icon: "camera.viewfinder", prominent: true) }
                    NavigationLink { ItemForm(trip: trip) } label: { ActionTile(title: "Digitar", icon: "square.and.pencil") }
                }.buttonStyle(.plain)
                if store.items(trip).isEmpty { ContentUnavailableView("Seu carrinho está vazio", systemImage: "cart", description: Text("Adicione um produto para acompanhar seu saldo.")) }
                ForEach(store.items(trip)) { item in
                    PurchaseItemRow(trip: trip, item: item)
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                PrimaryButton(title: "Finalizar compra", icon: "checkmark.circle") { confirm = true }.disabled(store.items(trip).isEmpty)
            } else { ContentUnavailableView("Compra finalizada", systemImage: "checkmark.circle") }
        }.navigationTitle("Sua compra").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Finalizar compra? Ela será salva no histórico, onde você poderá editar ou apagar depois.", isPresented: $confirm, titleVisibility: .visible) {
                Button("Finalizar compra") {
                    do { if let trip = store.active { try store.finish(trip); dismiss() } } catch { self.error = error.localizedDescription }
                }
            }
    }
}
