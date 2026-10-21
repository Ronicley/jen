import Foundation

@main
struct ReceiptChecks {
    static func main() throws {
        func check(_ condition: Bool, _ message: String) {
            guard condition else { fatalError(message) }
        }
        func page(_ text: String) -> RecognizedPage { RecognizedPage(lines: text.split(separator: "\n").map { RecognizedLine(text: String($0)) }) }
        func reject(_ message: String, _ action: () throws -> Void) {
            do { try action(); fatalError(message) } catch {}
        }
        let sample = page("""
        MERCADO EXEMPLO
        CNPJ 12.345.678/0001-99
        Emissão 21/10/2025 10:30:00
        CODIGO DESCRICAO QTD UN VL UNIT VL TOTAL
        001 7891234567890 LEITE INTEGRAL
        3 UN X 5,49 16,47
        002 7899876543210 TOMATE
        0,650 KG X 7,99 5,19
        VALOR TOTAL R$ 21,66
        Dinheiro 30,00
        Troco 8,34
        Tributos aproximados R$ 3,00
        """)
        var draft = ReceiptParser.parse([sample])
        check(draft.market == "MERCADO EXEMPLO", "Mercado")
        check(draft.items.count == 2, "Somente produtos, não pagamentos, troco e tributos")
        check(draft.items[0].name == "LEITE INTEGRAL" && draft.items[0].quantity == "3", "Nome e quantidade")
        check(draft.items[1].unit == "KG" && draft.items[1].quantity == "0,650", "Peso decimal")
        check(draft.total == "21,66" && draft.calculatedTotal == 2166 && draft.difference == 0, "Reconciliação")
        check(draft.items.allSatisfy { $0.problem == nil }, "Leitura simples sem pendências")
        reject("Confirmação obrigatória") { _ = try draft.finishedPurchase() }
        draft.confirmed = true
        let (trip, items) = try draft.finishedPurchase()
        check(trip.budget == nil && trip.finishedAt != nil && trip.source == "receipt", "Compra finalizada sem orçamento")
        check(items[1].amount == 650 && items[1].mode == .weight && items[1].total == 519, "Conversão kg/g e total impresso")
        check(items.allSatisfy { $0.productID == nil }, "Sem associação automática")
        var state = Snapshot()
        let active = Trip(budget: 30000, market: "Compra atual")
        state.trips = [active]
        state.list = [ShoppingEntry(name: "Arroz")]
        try state.importReceipt(draft)
        check(state.trips.count == 2 && state.trips.contains { $0.id == active.id && $0.finishedAt == nil }, "Importação independente da compra ativa")
        check(state.items.count == 2 && state.list.count == 1, "Itens e lista preservados")
        check(state.possibleDuplicate(draft) != nil, "Possível repetição por mercado/data/total")
        reject("Semelhança deve pedir confirmação") { try state.importReceipt(draft) }
        try state.importReceipt(draft, allowSimilar: true)
        check(state.trips.count == 3, "Permite compras semelhantes quando explicitamente confirmado")
        var fiscal = draft
        fiscal.key = String(repeating: "1", count: 44)
        try state.importReceipt(fiscal, allowSimilar: true)
        reject("Mesma chave não pode ser importada duas vezes") { try state.importReceipt(fiscal, allowSimilar: true) }
        let count = state.trips.count
        fiscal.total = "99,99"
        reject("Não salvar total divergente") { try state.importReceipt(fiscal, allowSimilar: true) }
        check(state.trips.count == count, "Falha não altera snapshot")

        let discounted = page("""
        MERCADO B
        20/10/2025
        CODIGO DESCRICAO QTD UN VL UNIT VL TOTAL
        001 123456 ARROZ 2 UN X 10,00 20,00
        Desconto item R$ 2,00
        002 123457 FEIJAO 1 UN X 5,00 5,00
        SUBTOTAL 25,00
        Desconto geral R$ 1,00
        Acrescimo geral R$ 0,50
        TOTAL A PAGAR R$ 22,50
        PIX 22,50
        """)
        var discountDraft = ReceiptParser.parse([discounted])
        check(discountDraft.items.count == 2, "Dois produtos compactos")
        check(discountDraft.items[0].discount == "2,00" && discountDraft.discount == "1,00" && discountDraft.surcharge == "0,50", "Separar descontos por item e gerais")
        check(discountDraft.calculatedTotal == 2250 && discountDraft.difference == 0, "Descontos contados uma vez")
        reject("Desconto ambíguo exige revisão") { discountDraft.confirmed = true; _ = try discountDraft.finishedPurchase() }
        discountDraft.items[0].reviewed = true
        let (discountTrip, discountItems) = try discountDraft.finishedPurchase()
        check(discountItems.reduce(0) { $0 + $1.total } + discountTrip.adjustment == 2250, "Persistir total líquido com ajustes")

        let overlap = ReceiptParser.parse([sample, sample])
        check(overlap.items.count == 4, "Não excluir silenciosamente itens iguais entre fotos")
        check(overlap.items.allSatisfy { !$0.warnings.isEmpty && $0.problem != nil }, "Sobreposição exige revisão individual")
        var lowConfidence = sample
        lowConfidence.lines[4].confidence = 0.4
        check(ReceiptParser.parse([lowConfidence]).items[0].warnings.contains { $0.contains("confiança") }, "Confiança baixa sinalizada")
        let missing = ReceiptParser.parse([page("""
        MERCADO C
        001 12345 PRODUTO SEM PRECO
        TOTAL R$ 10,00
        """)])
        check(missing.items.count == 1 && missing.items[0].problem != nil, "Preço ausente vira pendência, não é inventado")
        check(missing.warnings.contains { $0.contains("Data") }, "Data desconhecida sinalizada")
        let precision = ReceiptParser.parse([page("""
        MERCADO D
        21/10/2025
        001 123456 PRODUTO PESADO
        0,333 KG X 5,999 2,00
        TOTAL 2,00
        """)])
        check(precision.items.first?.unitPrice == "5,999" && precision.items.first?.grossTotal == "2,00", "Preço com três casas preservado")
        let preciseItem = try precision.items[0].cartItem(tripID: UUID())
        check(preciseItem.price == 600 && preciseItem.total == 200 && preciseItem.detail.contains("5,999"), "Preço arredondado para histórico, total fiscal e precisão original preservados")
        let split = ReceiptParser.parse([page("""
        MERCADO E
        001 123456 CAFE
        2 UN X 9,99
        19,98
        TOTAL R$ 19,98
        """)])
        check(split.items[0].unitPrice == "9,99" && split.items[0].grossTotal == "19,98", "Quantidade/preço/total em linhas separadas")
        var totalOnly = ReceiptItemDraft(name: "Produto conferido", grossTotal: "12,34", totalOnly: true)
        check(try totalOnly.cartItem(tripID: UUID()).total == 1234, "Entrada somente por total, sem preço unitário inventado")
        totalOnly.discount = "13,00"
        check(totalOnly.problem != nil, "Desconto não pode superar o item")
        var fractional = ReceiptItemDraft(name: "Suco", quantity: "1,5", unit: "L", unitPrice: "8,00", grossTotal: "12,00")
        check(try fractional.cartItem(tripID: UUID()).detail.contains("1,5 L"), "Unidade fracionada preservada")
        fractional.unit = "KG"; fractional.quantity = "0,0001"
        reject("Peso abaixo da precisão suportada deve ser revisado") { _ = try fractional.cartItem(tripID: UUID()) }
        check(try ReceiptNumbers.money("1.234,56") == 123456, "Milhar fiscal brasileiro")
        check(try ReceiptNumbers.money("1.000") == 100000, "Milhar sem fração")
        check(try ReceiptNumbers.money("12.34") == 1234, "Decimal com ponto")
        reject("Valor negativo") { _ = try ReceiptNumbers.money("-1,00") }
        reject("Casas ambíguas no total") { _ = try ReceiptNumbers.money("1,234") }
        let free = ReceiptItemDraft(name: "Brinde", quantity: "1", unit: "UN", unitPrice: "5,00", grossTotal: "5,00", discount: "5,00")
        check(try free.cartItem(tripID: UUID()).total == 0, "Item integralmente descontado preservado")
        let perGram = ReceiptItemDraft(name: "Peso em gramas", quantity: "650", unit: "G", unitPrice: "0,015", grossTotal: "9,75")
        let gramsItem = try perGram.cartItem(tripID: UUID())
        check(gramsItem.price == 1500 && gramsItem.amount == 650 && gramsItem.total == 975, "Converter preço/g para kg sem arredondar antes da conversão")
        let inconsistent = ReceiptParser.parse([page("""
        MERCADO F
        001 123456 LEITE 33 UN X 5,49 16,47
        TOTAL R$ 16,47
        """)])
        check(inconsistent.items[0].warnings.contains { $0.contains("não corresponde") }, "Inconsistência quantidade/preço/total exige revisão")
        var wrongTotal = draft
        wrongTotal.total = "30,00"
        reject("Divergência impede gravação") { _ = try wrongTotal.finishedPurchase() }
        var noPhotos = ReceiptParser.parse([])
        noPhotos.confirmed = true
        reject("Cupom vazio não pode ser salvo") { _ = try noPhotos.finishedPurchase() }
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONEncoder().encode(state))
        check(decoded.trips.contains { $0.budget == nil && $0.source == "receipt" } && decoded.items[1].printedTotal != nil, "Serialização dos campos fiscais")
        // A real version-1 shape: no receipt fields and a nonoptional budget.
        let legacy = """
        {"version":1,"trips":[{"id":"00000000-0000-0000-0000-000000000001","budget":30000,"market":"Antigo","createdAt":0}],"items":[],"products":[],"list":[]}
        """
        let old = try JSONDecoder().decode(Snapshot.self, from: Data(legacy.utf8))
        check(old.trips[0].budget == 30000 && old.trips[0].source == nil && old.trips[0].adjustment == 0, "Compatibilidade com dados antigos")
        print("OK: cupons, múltiplas fotos, descontos, precisão, totais, duplicidade, atomicidade e dados antigos.")
    }
}
