export type ReceiptItem = { name: string; quantity: string; unit: string; unitPrice: string; gross: string; discount: string; totalOnly: boolean; reviewed: boolean; source: string; page: number; number?: string; warnings: string[] };
export type ReceiptDraft = { market: string; date: string; key: string; total: string; discount: string; surcharge: string; items: ReceiptItem[]; warnings: string[] };
const fold = (text: string) => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
export const decimalText = (cents: number) => (cents / 100).toFixed(2).replace('.', ',');
export const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
export function validDate(text: string) {
  const value = new Date(`${text}T12:00:00`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text) || !Number.isFinite(value.getTime()) || value.getFullYear() !== Number(text.slice(0, 4)) || value.getMonth() + 1 !== Number(text.slice(5, 7)) || value.getDate() !== Number(text.slice(8, 10))) throw new Error('Informe uma data válida: AAAA-MM-DD.');
  return value.toISOString();
}
function scaled(text: string, digits: number) {
  if (!new RegExp(`^\\d{1,7}([,.]\\d{1,${digits}})?$`).test(text.trim())) throw new Error('Valor decimal inválido. Não use separador de milhar.');
  const [whole, fraction = ''] = text.trim().replace(',', '.').split('.');
  return BigInt(whole) * 10n ** BigInt(digits) + BigInt(fraction.padEnd(digits, '0'));
}
export function receiptMoney(text: string, allowZero = true) {
  const n = Number(scaled(text, 2));
  if (!Number.isSafeInteger(n) || (!allowZero && n < 1)) throw new Error('Informe um valor maior que zero.');
  return n;
}
export const blankItem = (): ReceiptItem => ({ name: '', quantity: '', unit: 'UN', unitPrice: '', gross: '', discount: '0,00', totalOnly: false, reviewed: false, source: '', page: 1, warnings: [] });
export const blankReceipt = (): ReceiptDraft => ({ market: '', date: today(), key: '', total: '', discount: '0,00', surcharge: '0,00', items: [], warnings: [] });
export function fiscalItem(item: ReceiptItem) {
  if (!item.name.trim() || !item.reviewed) throw new Error('Confira e confirme cada produto.');
  const gross = receiptMoney(item.gross, false), discount = receiptMoney(item.discount);
  if (discount > gross) throw new Error('Desconto do item maior que o valor bruto.');
  let price = gross, amount = 1, mode: 'unit' | 'weight' | 'package' = 'package';
  if (!item.totalOnly) {
    const quantity = scaled(item.quantity, 3), unitPrice = scaled(item.unitPrice, 4);
    if (quantity <= 0n || unitPrice <= 0n || !/^(UNID|UND|UN|KG|GR|G|LT|L|ML|PCT|PC|CX|M)$/.test(item.unit)) throw new Error('Confira quantidade, unidade e preço. Ou escolha registrar somente o total.');
    if (item.unit === 'KG' || item.unit === 'G' || item.unit === 'GR') {
      const grams = item.unit === 'KG' ? quantity : quantity / 1000n;
      if ((item.unit !== 'KG' && quantity % 1000n !== 0n) || grams < 1n || grams > 999999n) throw new Error('Peso deve corresponder a gramas inteiras.');
      mode = 'weight'; amount = Number(grams);
      price = Number((unitPrice * (item.unit === 'KG' ? 1n : 1000n) + 50n) / 100n);
    } else if (quantity % 1000n === 0n) { mode = 'unit'; amount = Number(quantity / 1000n); price = Number((unitPrice + 50n) / 100n); }
    else { price = Number((unitPrice + 50n) / 100n); }
  }
  if (amount > 999999 || price < 1 || price > 999999999) throw new Error('Preço ou quantidade fora do limite.');
  return { name: item.name.trim(), mode, price, amount, product_id: null, net_total: gross - discount, fiscal_quantity: item.totalOnly ? '' : item.quantity, fiscal_unit: item.totalOnly ? '' : item.unit, fiscal_price: item.totalOnly ? '' : item.unitPrice, fiscal_discount: discount, fiscal_gross: gross };
}
export function reconcile(draft: ReceiptDraft) {
  validDate(draft.date);
  if (!draft.market.trim() || !draft.items.length) throw new Error('Informe o mercado e pelo menos um produto.');
  if (draft.key && !/^\d{44}$/.test(draft.key)) throw new Error('A chave fiscal deve ter 44 dígitos ou ficar vazia.');
  const items = draft.items.map(fiscalItem), discount = receiptMoney(draft.discount), surcharge = receiptMoney(draft.surcharge), total = receiptMoney(draft.total, false);
  if (items.reduce((sum, item) => sum + item.net_total, 0) - discount + surcharge !== total) throw new Error('A soma dos itens menos desconto geral mais acréscimo precisa conferir exatamente com o total.');
  return { items, discount, surcharge, total };
}
const quantityPattern = /\b(\d{1,6}(?:[,.]\d{1,3})?)\s*(UNID|UND|UN|KG|GR|G|LT|L|ML|PCT|PC|CX|M)\b\s*(?:X|\*)?/i;
function prices(text: string) {
  return [...text.matchAll(/(?<![\d.,/])(?:\d{1,3}(?:\.\d{3})+|\d{1,7})[,.]\d{2,4}(?![\d.,/%])/g)].filter(m => !/^\s*(%|KG|UN|LT|L\b)/i.test(text.slice(m.index! + m[0].length))).map(m => m[0].includes(',') ? m[0].replace(/\./g, '') : m[0]);
}
export function parseReceipt(pages: string[]): ReceiptDraft {
  const draft = blankReceipt(); let foundDate = false, foundTotal = false;
  for (const [page, raw] of pages.entries()) {
    let pending: ReceiptItem | undefined, inProducts = false, ended = false, last: ReceiptItem | undefined;
    const finish = () => {
      if (!pending) return;
      if (!pending.quantity || !pending.unitPrice || !pending.gross) pending.warnings.push('Informações incompletas. Confira no cupom.');
      if (pending.quantity && pending.unitPrice && pending.gross) {
        try { if ((scaled(pending.quantity, 3) * scaled(pending.unitPrice, 4) + 50000n) / 100000n !== scaled(pending.gross, 2)) pending.warnings.push('Quantidade × preço difere do total. Confira arredondamento e desconto.'); } catch { pending.warnings.push('Valor não reconhecido.'); }
      }
      draft.items.push(pending); last = pending; pending = undefined;
    };
    for (const line of raw.split(/\r?\n/).map(l => l.trim()).filter(Boolean)) {
      const lower = fold(line), monetary = prices(line), qty = line.match(quantityPattern), date = line.match(/\b(\d{2})\/(\d{2})\/(\d{4})\b/);
      if (!foundDate && date) { draft.date = `${date[3]}-${date[2]}-${date[1]}`; foundDate = true; }
      const digits = line.replace(/\D/g, ''); if (!draft.key && digits.length === 44) draft.key = digits;
      if (/(descricao|produto)/.test(lower) && /(codigo|vl|valor)/.test(lower)) { finish(); inProducts = true; ended = false; continue; }
      if (/\b(valor\s+(total|a\s+pagar)|total\s+(a\s+pagar|liquido|da\s+compra)|total\s+r\$|total\s*[:=]|^total\s+(r\$\s*)?\d)/.test(lower) && !/subtotal|sub total|desconto|tribut|itens/.test(lower)) {
        finish(); const value = monetary.at(-1);
        if (value) { if (foundTotal && draft.total !== value) draft.warnings.push('Totais diferentes nas fotos. Confira o total final.'); draft.total = value; foundTotal = true; }
        ended = true; inProducts = false; last = undefined; continue;
      }
      if (/subtotal|sub total/.test(lower)) { finish(); last = undefined; continue; }
      if (/desconto|desc\.|acrescimo|taxa de entrega/.test(lower)) {
        const value = monetary.at(-1), isDiscount = /desconto|desc\./.test(lower);
        if (value && isDiscount && !/total|cupom|geral/.test(lower) && !ended && (pending || last)) {
          const item = pending ?? last!; item.discount = value; item.source += `\n${line}`; item.warnings.push('Confira se o desconto é deste item e se o total já o inclui.');
        } else if (value && !/item/.test(lower)) {
          finish(); const field = isDiscount ? 'discount' : 'surcharge';
          if (draft[field] !== '0,00' && draft[field] !== value) draft.warnings.push('Ajustes diferentes nas fotos. Confira.'); draft[field] = value;
        } else draft.warnings.push(`Ajuste não atribuído: ${line}`);
        last = undefined; continue;
      }
      if (/\b(forma\s+de\s+pagamento|dinheiro|troco|credito|debito|pix|tributos|tributacao|consumidor|protocolo|chave\s+de\s+acesso|qtd\.?\s*total\s*de\s*itens)\b/.test(lower)) { finish(); ended = true; inProducts = false; last = undefined; continue; }
      if (ended) continue;
      const numbered = line.match(/^\s*(\d{1,4})\s+(?:\d{4,14}\s+)?(.+)$/), numberedProduct = numbered && /\p{L}/u.test(numbered[2]) && !line.includes('/') && !(qty && line.toUpperCase().startsWith(qty[0].toUpperCase()));
      if (numberedProduct || (inProducts && !pending && /\p{L}/u.test(line) && !qty && monetary.length)) {
        finish(); const body = numberedProduct ? numbered![2] : line;
        pending = { ...blankItem(), name: body.split(quantityPattern)[0].split(/\s+(?:R\$\s*)?\d+[,.]\d{2}\b/)[0].trim(), source: line, page: page + 1, number: numberedProduct ? numbered![1] : undefined }; inProducts = true;
      } else if (!pending) {
        if (inProducts && /\p{L}/u.test(line) && !qty && !monetary.length) pending = { ...blankItem(), name: line, source: line, page: page + 1 };
        else if (!draft.items.length && !draft.market && (line.match(/\p{L}/gu)?.length ?? 0) >= 4 && !/cnpj|cpf|danfe|nfce|nfc-e|documento|fiscal|endereco|inscricao|telefone|cep|rua|avenida/.test(lower) && !line.includes('/') && !monetary.length) draft.market = line;
      } else { pending.source += `\n${line}`; if (!qty && !monetary.length && /\p{L}/u.test(line)) pending.name += ` ${line}`; }
      if (pending) {
        if (qty) { pending.quantity = qty[1]; pending.unit = qty[2].toUpperCase(); }
        if (monetary.length) {
          if (monetary.length === 1 && qty && /[X*]/i.test(qty[0])) pending.unitPrice = monetary[0];
          else { pending.gross = monetary.at(-1)!; if (monetary.length > 1) pending.unitPrice = monetary.at(-2)!; else if (!pending.unitPrice && /^1([,.]0+)?$/.test(pending.quantity)) pending.unitPrice = pending.gross; }
        }
      }
    }
    finish();
  }
  if (!foundDate) draft.warnings.push('Data não identificada. Confira a sugestão de hoje.');
  if (!foundTotal) draft.warnings.push('Total final não identificado.');
  if (pages.length > 1) {
    draft.warnings.push('Confira ordem, sobreposições e produtos cortados entre fotos.');
    for (const item of draft.items) if (draft.items.some(other => other !== item && other.page !== item.page && ((item.number && item.number === other.number) || (fold(item.name) === fold(other.name) && item.gross === other.gross && item.quantity === other.quantity)))) item.warnings.push('Possível repetição entre fotos. Nenhum item foi removido automaticamente.');
  }
  return draft;
}
export function parseLabel(text: string) {
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean), candidates: { price: string; perKg: boolean; isTotal: boolean; context: string }[] = [];
  let grams: string | undefined;
  for (const [index, line] of lines.entries()) {
    const lower = fold(line), priceLabel = /r\$|preco|total|pagar/.test(lower);
    if (/peso/.test(lower) && !priceLabel) {
      const weight = lower.match(/(\d{1,6}(?:[,.]\d{1,3})?)\s*(kg|g)\b/);
      if (weight) { const value = Number(weight[1].replace(',', '.')) * (weight[2] === 'kg' ? 1000 : 1); if (Number.isInteger(value) && value > 0 && value <= 999999) grams = String(value); }
      continue;
    }
    for (const match of line.matchAll(/(?<![\d.,/])\d{1,7}[,.]\d{2}(?![\d.,/%])/g)) {
      if (/^\s*(%|kg\b|g\b)/i.test(line.slice(match.index! + match[0].length)) || receiptMoney(match[0]) < 1) continue;
      const candidate = { price: match[0], perKg: /\/\s*kg\b|por\s+k(g|ilo)\b|preco\s*(por\s*)?kg\b|kg\s*:/.test(lower), isTotal: /total|pagar/.test(lower), context: lines.slice(Math.max(index - 1, 0), index + 2).join(' · ') };
      if (!candidates.some(p => p.price === candidate.price && p.perKg === candidate.perKg && p.isTotal === candidate.isTotal)) candidates.push(candidate);
    }
  }
  const name = lines.find(line => (line.match(/\p{L}/gu)?.length ?? 0) >= 4 && !/r\$|\d+[,.]\d{2}/i.test(line) && !/\b(preco|oferta|promocao|validade|fabricacao|cnpj|codigo|cod|total|peso|liquido|clube|cliente|atacado|varejo|economize|pagar|leve|pague|desconto|de|por)\b/.test(fold(line))) ?? '';
  return { name, candidates, grams };
}
