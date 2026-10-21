import Foundation

/// Common Brazilian receipt layouts, not a universal fiscal-document validator.
/// Ambiguous lines remain visible in source text and uncertain items require review.
enum ReceiptParser {
    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
    }
    private static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let ns = text as NSString
        return (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : ns.substring(with: match.range(at: $0)) }
    }
    private static func prices(_ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![0-9.,/])(?:[0-9]{1,3}(?:\.[0-9]{3})+|[0-9]{1,7})[,.][0-9]{2,4}(?![0-9.,/%])"#) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let suffix = ns.substring(from: match.range.location + match.range.length).trimmingCharacters(in: .whitespaces).uppercased()
            if suffix.hasPrefix("%") || suffix.hasPrefix("KG") || suffix.hasPrefix("UN") || suffix.hasPrefix("LT") || suffix.hasPrefix("L ") { return nil }
            let token = ns.substring(with: match.range)
            if let cents = try? ReceiptNumbers.money(token, allowZero: true) { return ReceiptNumbers.text(cents) }
            if (try? ReceiptNumbers.unitPrice(token, multiplier: 1000)) != nil { return token.replacingOccurrences(of: ".", with: ",") }
            return nil
        }
    }
    private static func quantityMatch(_ text: String) -> [String]? {
        captures(#"\b([0-9]{1,6}(?:[,.][0-9]{1,3})?)\s*(UNID|UND|UN|KG|GR|G|LT|L|ML|PCT|PC|CX|M)\b\s*(?:X|\*)?"#, text)
    }
    private static func extractDate(_ text: String) -> Date? {
        guard let parts = captures(#"\b([0-9]{2}/[0-9]{2}/[0-9]{4})(?:\s+([0-9]{2}:[0-9]{2}(?::[0-9]{2})?))?"#, text) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.isLenient = false
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: parts[1])
    }
    static func parse(_ pages: [RecognizedPage]) -> ReceiptDraft {
        var draft = ReceiptDraft()
        draft.pages = pages.map(\.text)
        var foundDate = false
        var foundTotal = false
        var discountRead: Int?
        var surchargeRead: Int?
        var inProducts = false
        var ended = false
        var pending: ReceiptItemDraft?
        var sawItems = false
        var lastWasItem = false

        func finishPending() {
            guard var item = pending else { return }
            if item.quantity.isEmpty { item.warnings.append("Quantidade não identificada.") }
            if item.unitPrice.isEmpty { item.warnings.append("Preço unitário não identificado.") }
            if item.grossTotal.isEmpty { item.warnings.append("Total do item não identificado.") }
            if let amount = ReceiptNumbers.amount(item.quantity),
               let unitPrice = Decimal(string: item.unitPrice.replacingOccurrences(of: ",", with: ".")),
               let gross = try? ReceiptNumbers.money(item.grossTotal) {
                var exact = amount * unitPrice * 100
                var rounded = Decimal()
                NSDecimalRound(&rounded, &exact, 0, .plain)
                if abs(NSDecimalNumber(decimal: rounded).intValue - gross) > 1 {
                    item.warnings.append("Quantidade × preço não corresponde ao total impresso. Confira unidade, desconto e arredondamento.")
                }
            }
            item.warnings = Array(Set(item.warnings)).sorted()
            draft.items.append(item)
            pending = nil
            sawItems = true
        }
        for (pageIndex, page) in pages.enumerated() {
            // Do not combine fragments from different photos as if they were one product.
            finishPending()
            inProducts = false
            ended = false
            for line in page.lines {
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }
                let lower = folded(text)
                if !foundDate, let date = extractDate(text) { draft.date = date; foundDate = true }
                if draft.key.isEmpty {
                    let digits = text.filter(\.isNumber)
                    if digits.count == 44, digits.allSatisfy(\.isASCII) { draft.key = digits }
                }
                let monetary = prices(text)
                let header = (lower.contains("descricao") || lower.contains("produto")) && (lower.contains("codigo") || lower.contains("vl") || lower.contains("valor"))
                if header { finishPending(); inProducts = true; ended = false; lastWasItem = false; continue }
                let totalLabel = captures(#"\b(?:valor\s+(?:total|a\s+pagar)|total\s+(?:a\s+pagar|liquido|da\s+compra)|total\s+r\$|total\s*[:=]|^total\s+(?:r\$\s*)?[0-9])"#, lower) != nil
                let subtotal = lower.contains("subtotal") || lower.contains("sub total")
                let discountLine = lower.contains("desconto") || lower.contains("desc.")
                let surchargeLine = lower.contains("acrescimo") || lower.contains("taxa de entrega")
                if totalLabel && !subtotal && !discountLine && !lower.contains("tribut") && !lower.contains("itens") {
                    finishPending()
                    if let total = monetary.last {
                        if foundTotal && draft.total != total { draft.warnings.append("Foram lidos totais diferentes. Confira o total final pago.") }
                        draft.total = total; foundTotal = true
                    }
                    ended = true; inProducts = false; lastWasItem = false
                    continue
                }
                if subtotal { finishPending(); lastWasItem = false; continue }
                if discountLine || surchargeLine {
                    let value = monetary.last.flatMap { try? ReceiptNumbers.money($0, allowZero: true) }
                    let explicitlyItem = lower.contains("item")
                    let explicitlyGeneral = lower.contains("total") || lower.contains("cupom") || lower.contains("geral")
                    if discountLine && !explicitlyGeneral && !ended && (pending != nil || lastWasItem) {
                        if let value {
                            if pending != nil {
                                pending!.discount = ReceiptNumbers.text(value)
                                pending!.sourceText += "\n" + text
                                pending!.warnings.append("Confira se o desconto pertence a este item e se o total impresso já o inclui.")
                            } else if let index = draft.items.indices.last {
                                draft.items[index].discount = ReceiptNumbers.text(value)
                                draft.items[index].sourceText += "\n" + text
                                draft.items[index].warnings.append("Confira se o desconto pertence a este item e se o total impresso já o inclui.")
                            }
                        }
                    } else if let value, !explicitlyItem {
                        finishPending()
                        if discountLine {
                            if let previous = discountRead, previous != value { draft.warnings.append("Descontos gerais diferentes nas imagens; confira o valor e não desconte duas vezes.") }
                            discountRead = value; draft.discount = ReceiptNumbers.text(value)
                        } else {
                            if let previous = surchargeRead, previous != value { draft.warnings.append("Acréscimos diferentes nas imagens; confira o valor.") }
                            surchargeRead = value; draft.surcharge = ReceiptNumbers.text(value)
                        }
                    } else { draft.warnings.append("Não consegui atribuir este ajuste: \(text)") }
                    lastWasItem = false
                    continue
                }
                let footer = captures(#"\b(?:forma\s+de\s+pagamento|dinheiro|troco|credito|debito|pix|tributos|tributacao|consumidor|protocolo|chave\s+de\s+acesso|qtd\.?\s*total\s*de\s*itens)\b"#, lower) != nil
                if footer { finishPending(); ended = true; inProducts = false; lastWasItem = false; continue }
                if ended { continue }
                // Typical numbered product: 001 7891234567890 LEITE INTEGRAL.
                let numbered = captures(#"^\s*([0-9]{1,4})\s+(?:[0-9]{4,14}\s+)?(.+)$"#, text)
                let qty = quantityMatch(text)
                let numberedProduct = numbered.map { match in
                    match[2].contains(where: \.isLetter) && !text.contains("/") &&
                    !(qty != nil && text.uppercased().hasPrefix(qty![0].uppercased()))
                } ?? false
                if numberedProduct || (inProducts && pending == nil && text.contains(where: \.isLetter) && qty == nil && !monetary.isEmpty) {
                    finishPending()
                    let body = numberedProduct ? numbered![2] : text
                    var name = body
                    if let q = quantityMatch(body), let range = body.range(of: q[0]) { name = String(body[..<range.lowerBound]) }
                    else if let price = captures(#"\s+(?:R\$\s*)?[0-9]+[,.][0-9]{2}\b"#, body), let range = body.range(of: price[0]) { name = String(body[..<range.lowerBound]) }
                    pending = ReceiptItemDraft(name: name.trimmingCharacters(in: .whitespacesAndNewlines), sourceText: text, page: pageIndex + 1,
                                               itemNumber: numberedProduct ? numbered![1] : nil)
                    if line.confidence < 0.75 { pending!.warnings.append("Texto com baixa confiança de leitura.") }
                    inProducts = true
                } else if pending == nil {
                    if inProducts && text.contains(where: \.isLetter) && qty == nil && monetary.isEmpty {
                        pending = ReceiptItemDraft(name: text, sourceText: text, page: pageIndex + 1)
                    } else if !sawItems && draft.market.isEmpty && text.filter(\.isLetter).count >= 4 &&
                                captures(#"\b(?:cnpj|cpf|danfe|nfce|nfc-e|documento|fiscal|endereco|inscricao|telefone|cep|rua|avenida|av\.)\b"#, lower) == nil &&
                                !text.contains("/") && monetary.isEmpty {
                        draft.market = text
                    }
                } else {
                    pending!.sourceText += "\n" + text
                    if qty == nil && monetary.isEmpty && text.contains(where: \.isLetter) {
                        pending!.name += " " + text
                    }
                    if line.confidence < 0.75 { pending!.warnings.append("Texto com baixa confiança de leitura.") }
                }
                if pending != nil {
                    if let qty {
                        pending!.quantity = qty[1]
                        pending!.unit = qty[2].uppercased() == "GR" ? "G" : qty[2].uppercased()
                    }
                    if let total = monetary.last {
                        if monetary.count == 1, let qty, qty[0].uppercased().contains("X") || qty[0].contains("*") {
                            pending!.unitPrice = total
                        } else {
                            pending!.grossTotal = total
                            if monetary.count >= 2 { pending!.unitPrice = monetary[monetary.count - 2] }
                            else if pending!.unitPrice.isEmpty, ReceiptNumbers.amount(pending!.quantity) == 1 { pending!.unitPrice = total }
                        }
                        // Keep pending until the next product/summary: discounts often follow.
                        lastWasItem = true
                    }
                }
            }
            finishPending()
        }
        if !foundDate { draft.warnings.append("Data não identificada: foi sugerida a data de hoje. Confira.") }
        if draft.market.isEmpty { draft.warnings.append("Mercado não identificado.") }
        if !foundTotal { draft.warnings.append("Total final não identificado. Preencha consultando o cupom.") }
        if pages.count > 1 {
            draft.warnings.append("Confira a ordem das fotos, possíveis sobreposições e produtos que ficaram entre duas imagens.")
            for index in draft.items.indices {
                let item = draft.items[index]
                let duplicate = draft.items.enumerated().contains { otherIndex, other in
                    otherIndex != index && other.page != item.page &&
                    ((item.itemNumber != nil && item.itemNumber == other.itemNumber) ||
                     (folded(item.name) == folded(other.name) && item.grossTotal == other.grossTotal && item.quantity == other.quantity))
                }
                if duplicate { draft.items[index].warnings.append("Possível repetição entre fotos. Exclua se for sobreposição; mantenha se for outro produto comprado.") }
            }
        }
        draft.warnings = Array(Set(draft.warnings)).sorted()
        return draft
    }
}
