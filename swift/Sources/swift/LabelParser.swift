import Foundation

struct LabelPrice: Identifiable, Sendable {
    var id: Int
    var cents: Int
    var context: String
    var perKg: Bool
    var isTotal: Bool
}
struct LabelReading: Sendable {
    var name: String?
    var prices: [LabelPrice]
    var grams: Int?
    var rawText: String
}

/// Conservative extraction: never treats a package's printed size as weighed quantity.
enum LabelParser {
    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
    static func parse(_ lines: [String]) -> LabelReading {
        let lines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var prices: [LabelPrice] = []
        for (index, line) in lines.enumerated() {
            let normalized = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            // Weight, dates and percentages are not money. A currency marker or price label wins.
            let priceLabel = normalized.contains("r$") || normalized.contains("preco") || normalized.contains("total") || normalized.contains("pagar")
            let weightLabel = normalized.contains("peso") && !priceLabel
            guard !weightLabel else { continue }
            for token in matches(#"(?<![0-9.,/])[0-9]{1,7}[,.][0-9]{2}(?![0-9.,/%])"#, in: line) {
                guard let range = line.range(of: token) else { continue }
                let suffix = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
                if suffix.hasPrefix("%") || suffix.hasPrefix("kg") || suffix.hasPrefix(" g") || suffix == "g" { continue }
                guard let value = try? cents(token) else { continue }
                let perKg = !matches(#"(?:/\s*kg\b|\bpor\s+k(?:g|ilo)\b|\br\$\s*/\s*kg\b|\bpreco\s*(?:por\s*)?kg\b|\bkg\s*:)"#, in: normalized).isEmpty
                let isTotal = normalized.contains("total") || normalized.contains("pagar")
                // Include a neighboring qualifier for human review, without guessing its meaning.
                let context = ([index > 0 ? lines[index - 1] : "", line, index + 1 < lines.count ? lines[index + 1] : ""]).filter { !$0.isEmpty }.joined(separator: " · ")
                if !prices.contains(where: { $0.cents == value && $0.perKg == perKg && $0.isTotal == isTotal }) {
                    prices.append(LabelPrice(id: prices.count, cents: value, context: context, perKg: perKg, isTotal: isTotal))
                }
            }
        }
        let names = lines.filter { line in
            let lower = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let letters = line.filter { $0.isLetter }.count
            guard letters >= 4, !lower.contains("r$"), matches(#"[0-9]+[,.][0-9]{2}"#, in: line).isEmpty else { return false }
            return matches(#"\b(?:preco|oferta|promocao|validade|fabricacao|cnpj|codigo|cod|total|peso|liquido|clube|cliente|atacado|varejo|economize|pagar|leve|pague|desconto|de|por)\b"#, in: lower).isEmpty
        }
        // Recognition is supplied in reading order; first eligible line is only a suggestion.
        let name = names.first.map { first in
            guard names.count > 1, let position = lines.firstIndex(of: first), position + 1 < lines.count,
                  names[1] == lines[position + 1], names[1].count <= 45 else { return first }
            return first + " " + names[1]
        }
        var grams: Int?
        for line in lines {
            let lower = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            guard lower.contains("peso"), !lower.contains("preco"), !lower.contains("r$") else { continue }
            if let weight = matches(#"[0-9]{1,6}(?:[,.][0-9]{1,3})?\s*(?:kg|g)\b"#, in: lower).first {
                let isKg = weight.contains("kg")
                let numeric = weight.replacingOccurrences(of: "kg", with: "").replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                if let value = Double(numeric) {
                    let result = Int((value * (isKg ? 1000 : 1)).rounded())
                    if result > 0 && result <= 999999 { grams = result }
                }
            }
        }
        return LabelReading(name: name, prices: prices, grams: grams, rawText: lines.joined(separator: "\n"))
    }
}
