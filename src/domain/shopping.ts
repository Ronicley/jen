export type SaleMode = 'unit' | 'weight' | 'package';
export type Trip = { id: number; budget: number; market: string; created_at: string; finished_at: string | null };
export type Product = { id: number; name: string; mode: SaleMode };
export type Item = { id: number; trip_id: number; product_id: number | null; name: string; mode: SaleMode; price: number; amount: number };
export type ListItem = { id: number; name: string; checked: number };
export type ItemDraft = Pick<Item, 'product_id' | 'name' | 'mode' | 'price' | 'amount'>;

// Decimal input is deliberately strict: no ambiguous thousands separators.
export function cents(input: string): number {
  const value = input.trim();
  if (!/^\d{1,7}([,.]\d{1,2})?$/.test(value)) throw new Error('Informe um valor como 18,90, sem separador de milhar.');
  const [whole, fraction = ''] = value.replace(',', '.').split('.');
  const result = Number(whole) * 100 + Number(fraction.padEnd(2, '0'));
  if (result <= 0) throw new Error('O valor precisa ser maior que zero.');
  return result;
}
export function quantity(input: string): number {
  if (!/^\d{1,6}$/.test(input.trim()) || Number(input) < 1) throw new Error('Informe uma quantidade inteira maior que zero.');
  return Number(input);
}
export function itemTotal(item: Pick<Item, 'mode' | 'price' | 'amount'>): number {
  return item.mode === 'weight' ? Math.round(item.price * item.amount / 1000) : item.price * item.amount;
}
export function total(items: Pick<Item, 'mode' | 'price' | 'amount'>[]): number {
  return items.reduce((sum, item) => sum + itemTotal(item), 0);
}
export const money = (value: number) => (value / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
export const date = (value: string) => new Date(value).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' });
export const modeLabel = (mode: SaleMode) => mode === 'weight' ? 'Por kg' : mode === 'package' ? 'Embalagem' : 'Unidade';
export const amountLabel = (item: Item) => item.mode === 'weight' ? `${item.amount} g × ${money(item.price)}/kg` : `${item.amount} ${item.mode === 'package' ? 'emb.' : 'un.'} × ${money(item.price)}`;
