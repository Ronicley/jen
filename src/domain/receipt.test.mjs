import { test } from 'node:test';
import assert from 'node:assert/strict';
import { blankItem, parseReceipt, parseLabel, fiscalItem, reconcile, validDate } from './receipt.ts';

export const sample = `MERCADO EXEMPLO
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
Tributos aproximados R$ 3,00`;
export function reviewed() { const draft = parseReceipt([sample]); draft.items.forEach(item => { item.reviewed = true; }); return draft; }
test('receipt port: multiline products, date, exact totals, no payments or taxes', () => {
  const draft = reviewed(), result = reconcile(draft);
  assert.equal(draft.market, 'MERCADO EXEMPLO'); assert.equal(draft.date, '2025-10-21');
  assert.equal(result.total, 2166); assert.equal(result.items.length, 2);
  assert.equal(result.items[1].amount, 650); assert.equal(result.items[1].price, 799); assert.equal(result.items[1].net_total, 519);
});
test('receipt port: item and general discounts counted once', () => {
  const draft = parseReceipt([`MERCADO B
20/10/2025
CODIGO DESCRICAO QTD UN VL UNIT VL TOTAL
001 123456 ARROZ 2 UN X 10,00 20,00
Desconto item R$ 2,00
002 123457 FEIJAO 1 UN X 5,00 5,00
SUBTOTAL 25,00
Desconto geral R$ 1,00
Acrescimo geral R$ 0,50
TOTAL A PAGAR R$ 22,50
PIX 22,50`]);
  assert.throws(() => reconcile(draft)); draft.items.forEach(item => { item.reviewed = true; });
  assert.equal(reconcile(draft).total, 2250); assert.equal(reconcile(draft).items[0].net_total, 1800);
});
test('receipt port: fiscal precision, fractional units, free item and total-only', () => {
  const item = { ...blankItem(), name: 'Produto', quantity: '0,333', unit: 'KG', unitPrice: '5,999', gross: '2,00', reviewed: true };
  assert.equal(fiscalItem(item).price, 600); assert.equal(fiscalItem(item).net_total, 200);
  assert.equal(fiscalItem({ ...item, quantity: '1,5', unit: 'L', unitPrice: '8,00', gross: '12,00' }).fiscal_quantity, '1,5');
  assert.equal(fiscalItem({ ...item, totalOnly: true, discount: '2,00' }).net_total, 0);
  assert.throws(() => fiscalItem({ ...item, quantity: '0,0001' }));
  assert.throws(() => fiscalItem({ ...item, discount: '2,01' }));
});
test('receipt port: overlap retained and warned, missing values never invented', () => {
  const draft = parseReceipt([sample, sample]); assert.equal(draft.items.length, 4);
  assert.ok(draft.items.every(item => item.warnings.some(w => w.includes('repetição'))));
  const missing = parseReceipt(['MERCADO C\n001 12345 PRODUTO SEM PRECO\nTOTAL R$ 10,00']);
  assert.equal(missing.items[0].gross, ''); assert.throws(() => reconcile(missing));
});
test('receipt port: reconciliation and dates reject invalid inputs', () => {
  const draft = reviewed(); draft.total = '21,67'; assert.throws(() => reconcile(draft));
  assert.throws(() => validDate('2026-02-30')); assert.throws(() => validDate('2026-13-01'));
  draft.total = '21,66'; draft.key = '123'; assert.throws(() => reconcile(draft));
});
test('label port: candidates distinct, package size not bought weight, no percent or dates', () => {
  const label = parseLabel('CAFE ESPECIAL 500 g\nR$ 18,90\nClube R$ 16,90\n10,00 %\nValidade 21/10/2025');
  assert.equal(label.candidates.length, 2); assert.equal(label.grams, undefined);
  const weight = parseLabel('TOMATE\nPreço por kg R$ 7,99\nPeso 0,650 kg\nTOTAL R$ 5,19');
  assert.equal(weight.grams, '650'); assert.ok(weight.candidates[0].perKg); assert.ok(weight.candidates[1].isTotal);
});
