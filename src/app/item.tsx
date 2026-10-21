import { useState } from 'react';
import { Text, View, Pressable, Alert } from 'react-native';
import { Image } from 'expo-image';
import { router, useLocalSearchParams } from 'expo-router';
import { useStore } from '@/data/store';
import { saveItem, removeItem } from '@/data/database';
import { cents, quantity, itemTotal, total, money, modeLabel, type SaleMode } from '@/domain/shopping';
import { Screen, Heading, Card, Field, Action, Note, Label, ErrorText, s, colors } from '@/components/design';
export default function ItemForm() {
  const { id, photo } = useLocalSearchParams<{ id?: string; photo?: string }>();
  const { trips, items, products, run, busy } = useStore();
  const trip = trips.find(t => !t.finished_at);
  const existing = items.find(i => i.id === Number(id) && i.trip_id === trip?.id);
  const [name, setName] = useState(existing?.name ?? '');
  const [price, setPrice] = useState(existing ? (existing.price / 100).toFixed(2).replace('.', ',') : '');
  const [mode, setMode] = useState<SaleMode>(existing?.mode ?? 'unit');
  const [amount, setAmount] = useState(String(existing?.amount ?? 1));
  const [productId, setProductId] = useState<number | null>(existing?.product_id ?? null);
  const [createProduct, setCreateProduct] = useState(false);
  const [error, setError] = useState('');
  let preview: number | null = null;
  try { preview = itemTotal({ price: cents(price), mode, amount: quantity(amount) }); } catch { /* Incomplete form. */ }
  const cart = items.filter(i => i.trip_id === trip?.id && i.id !== existing?.id);
  async function save() {
    try {
      setError('');
      if (!trip) throw new Error('Inicie uma compra primeiro.');
      if (createProduct && !name.trim()) throw new Error('Informe um nome para salvar no histórico de produtos.');
      const draft = { name: name.trim(), price: cents(price), amount: quantity(amount), mode, product_id: productId };
      if (itemTotal(draft) < 1) throw new Error('O total deve ser de pelo menos R$ 0,01.');
      await run(() => saveItem(trip.id, draft, existing?.id, createProduct));
      router.back();
    } catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível salvar o produto.'); }
  }
  async function remove() {
    try { await run(() => removeItem(existing!.id)); router.back(); } catch { setError('Não foi possível remover o produto.'); }
  }
  const matches = products.filter(p => p.mode === mode && (!name.trim() || p.name.toLocaleLowerCase().includes(name.toLocaleLowerCase()))).slice(0, 6);
  const previous = productId ? items.find(i => i.product_id === productId && trips.some(t => t.id === i.trip_id && t.finished_at)) : null;
  return <Screen><Action title="Cancelar" secondary onPress={() => router.back()} /><Heading title={existing ? 'Editar produto' : 'Confira o produto'} subtitle="Só entra na conta depois da sua confirmação." />
    {photo ? <><Image source={{ uri: photo }} style={{ height: 200, width: '100%', borderRadius: 20 }} contentFit="contain" /><Note>Foto de referência. Nesta versão, preencha o preço e o nome manualmente; o OCR ainda não está integrado.</Note></> : null}
    <Card><Field label="Produto (opcional)" placeholder="Ex.: Café Marca X 500 g" value={name} onChangeText={setName} maxLength={160} /><Label>Como é vendido?</Label><View style={{ gap: 8 }}>{(['unit', 'weight', 'package'] as SaleMode[]).map(value => <Pressable key={value} accessibilityRole="radio" accessibilityState={{ checked: mode === value }} onPress={() => { setMode(value); setAmount(value === 'weight' ? '' : '1'); setProductId(null); setCreateProduct(false); }} style={{ padding: 15, borderRadius: 12, backgroundColor: mode === value ? colors.pale : colors.background, borderWidth: 1, borderColor: mode === value ? colors.blue : colors.line }}><Text style={s.label}>{modeLabel(value)}{mode === value ? ' ✓' : ''}</Text></Pressable>)}</View><Field label={mode === 'weight' ? 'Preço por kg (R$)' : mode === 'package' ? 'Valor total por embalagem (R$)' : 'Preço por unidade (R$)'} keyboardType="decimal-pad" placeholder="0,00" value={price} onChangeText={setPrice} /><Field label={mode === 'weight' ? 'Peso em gramas' : 'Quantidade'} keyboardType="number-pad" value={amount} onChangeText={setAmount} placeholder={mode === 'weight' ? 'Ex.: 650' : '1'} />{mode === 'package' ? <Note>Use o total impresso no adesivo. Sem peso informado, não comparamos o preço por kg.</Note> : null}</Card>
    <Card><Text style={s.section}>Histórico de preços</Text><Note>Associe somente se for a mesma marca e tamanho. Você também pode deixar sem associação.</Note>
      {productId ? <><Label>Selecionado: {products.find(p => p.id === productId)?.name}</Label>{previous ? <Note>Último preço registrado: {money(previous.price)}{mode === 'weight' ? '/kg' : ''}</Note> : null}<Action secondary title="Remover associação" onPress={() => setProductId(null)} /></> : <>{matches.map(p => <Action key={p.id} secondary title={`É este: ${p.name}`} onPress={() => { setProductId(p.id); setCreateProduct(false); setName(p.name); }} />)}<Action secondary title={createProduct ? '✓ Salvar como novo produto' : 'Salvar como novo produto'} onPress={() => setCreateProduct(!createProduct)} /><Note>{createProduct ? 'Use nome, marca e tamanho para identificar este produto.' : 'Sem associação: conta no orçamento, mas não na comparação de preços.'}</Note></>}
    </Card>
    <Card><View style={s.row}><Label>Total do item</Label><Text style={s.section}>{preview === null ? '—' : money(preview)}</Text></View><View style={s.row}><Note>Saldo após confirmar</Note><Label>{preview === null || !trip ? '—' : money(trip.budget - total(cart) - preview)}</Label></View></Card>
    <ErrorText message={error} /><Action title={existing ? 'Salvar alterações' : 'Adicionar ao carrinho'} disabled={busy || !trip} onPress={save} />
    {existing ? <Action secondary title="Remover do carrinho" disabled={busy} onPress={() => Alert.alert('Remover produto?', 'O valor voltará ao saldo disponível.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Remover', style: 'destructive', onPress: remove }])} /> : null}
  </Screen>;
}
