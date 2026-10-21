import Foundation

@main
struct DomainChecks {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        func rejects(_ value: String, using parse: (String) throws -> Int) {
            do { _ = try parse(value); fatalError("Deveria rejeitar: \(value)") } catch {}
        }
        let a = try cents("18,90")
        let b = try cents(" 1.5 ")
        let c = try cents("0,01")
        check(a == 1890 && b == 150 && c == 1, "Conversão de centavos")
        for value in ["0", "-1", "1.234,56", "1,234", "abc", "", "100000000", "١"] { rejects(value, using: cents) }
        let q = try quantity(" 650 ")
        check(q == 650, "Quantidade inteira")
        for value in ["0", "1.5", "-1", "1000000", ""] { rejects(value, using: quantity) }
        let trip = Trip(budget: 20000, market: "Mercado")
        let weighted = CartItem(tripID: trip.id, name: "Banana", mode: .weight, price: 999, amount: 650)
        let unit = CartItem(tripID: trip.id, name: "Leite", mode: .unit, price: 599, amount: 3)
        let package = CartItem(tripID: trip.id, name: "Queijo", mode: .package, price: 1890, amount: 2)
        let rounded = CartItem(tripID: trip.id, name: "Peso", mode: .weight, price: 1, amount: 500)
        check(weighted.total == 649, "Preço por kg arredondado")
        check(unit.total == 1797, "Preço por unidade")
        check(package.total == 3780, "Preço por embalagem")
        check(rounded.total == 1, "Arredondamento de meio centavo")
        var state = Snapshot()
        state.trips = [trip]
        state.items = [weighted, unit, package]
        state.list = [ShoppingEntry(name: "Arroz")]
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(state))
        check(decoded.items.reduce(0) { $0 + $1.total } == 6226, "Persistência e total do carrinho")
        check(decoded.trips[0].id == trip.id && !decoded.list[0].checked, "Identidade e lista persistidas")
        let shelf = LabelParser.parse(["CAFE MARCA X 500G", "R$ 18,90"])
        check(shelf.name == "CAFE MARCA X 500G" && shelf.prices.first?.cents == 1890, "Nome e preço da etiqueta")
        check(shelf.grams == nil, "Tamanho da embalagem não vira peso comprado")
        let promotion = LabelParser.parse(["ARROZ TIPO 1", "Preço normal R$ 29,90", "Clube R$ 24,90"])
        check(promotion.prices.count == 2, "Preços promocionais precisam de escolha")
        let weighed = LabelParser.parse(["TOMATE", "Preço por kg R$ 7,99", "Peso líquido 0,650 kg", "Total R$ 5,19"])
        check(weighed.grams == 650, "Peso explícito da etiqueta")
        check(weighed.prices.count == 2, "Peso decimal não pode virar preço")
        check(weighed.prices[0].perKg && weighed.prices[1].isTotal, "Separar kg e total para não multiplicar duas vezes")
        let noise = LabelParser.parse(["Validade 21/10/2026", "Desconto 10,00%", "Peso 0,500 kg", "7891234567890"])
        check(noise.prices.isEmpty, "Datas, percentuais, peso e código não são preço")
        let gramWeight = LabelParser.parse(["Peso 650 g", "R$ 9.99"])
        check(gramWeight.grams == 650 && gramWeight.prices.first?.cents == 999, "Peso em gramas e decimal com ponto")
        check(LabelParser.parse([]).prices.isEmpty, "OCR vazio")
        let finishedDate = Date(timeIntervalSince1970: 1700000000)
        let finishedTrip = Trip(budget: 10000, market: "Mercado antigo", finishedAt: finishedDate)
        let product = Product(name: "Leite", mode: .unit)
        let historicalItem = CartItem(tripID: finishedTrip.id, productID: product.id, name: "Leite", mode: .unit, price: 599, amount: 2)
        state.trips.append(finishedTrip)
        state.products.append(product)
        state.items.append(historicalItem)
        try state.updateFinishedTrip(id: finishedTrip.id, budget: 15000, market: "  Mercado novo  ", date: finishedDate)
        let updated = state.trips.first { $0.id == finishedTrip.id }!
        check(updated.market == "Mercado novo" && updated.budget == 15000 && updated.finishedAt == finishedDate, "Editar metadados sem reabrir compra")
        check(state.items.contains { $0.id == historicalItem.id }, "Editar compra preserva itens")
        do {
            try state.updateFinishedTrip(id: trip.id, budget: 100, market: "Inválido", date: finishedDate)
            fatalError("Não deveria editar uma compra ativa pelo histórico")
        } catch {}
        do {
            try state.updateFinishedTrip(id: finishedTrip.id, budget: 0, market: "Inválido", date: finishedDate)
            fatalError("Não deveria aceitar orçamento zero")
        } catch {}
        do {
            try state.updateFinishedTrip(id: finishedTrip.id, budget: 100, market: "Inválido", date: Date().addingTimeInterval(86400))
            fatalError("Não deveria aceitar data futura")
        } catch {}
        try state.deleteFinishedTrip(id: finishedTrip.id)
        check(!state.trips.contains { $0.id == finishedTrip.id } && !state.items.contains { $0.tripID == finishedTrip.id }, "Apagar compra e seus itens")
        check(state.trips.contains { $0.id == trip.id } && state.items.contains { $0.tripID == trip.id }, "Não apagar outras compras")
        check(state.products.contains { $0.id == product.id } && state.list.count == 1, "Preservar cadastros e lista")
        do {
            try state.deleteFinishedTrip(id: trip.id)
            fatalError("Não deveria apagar compra ativa pelo histórico")
        } catch {}
        let restored = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(state))
        check(!restored.items.contains { $0.tripID == finishedTrip.id }, "Exclusão persiste na serialização")
        let entryID = state.list[0].id
        state.list[0].checked = true
        try state.renameListItem(id: entryID, name: "  Arroz integral  ")
        check(state.list[0].name == "Arroz integral" && state.list[0].checked && state.list[0].id == entryID, "Renomear preserva identidade e marcação")
        do {
            try state.renameListItem(id: entryID, name: "  ")
            fatalError("Não deve aceitar nome vazio")
        } catch {}
        do {
            try state.renameListItem(id: UUID(), name: "Ausente")
            fatalError("Não deve recriar item excluído")
        } catch {}
        let renamed = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(state))
        check(renamed.list[0].name == "Arroz integral" && renamed.list[0].checked, "Edição da lista persiste")
        print("OK: domínio, persistência, OCR, histórico e edição de itens da lista.")
    }
}
