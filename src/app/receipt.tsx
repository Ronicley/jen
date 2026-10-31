import { useEffect, useRef, useState } from 'react';
import { Linking, Modal, ScrollView, Text, View } from 'react-native';
import { Alert } from '@/components/alert';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router, useLocalSearchParams } from 'expo-router';
import { useStore } from '@/data/store';
import { importReceipt } from '@/data/database';
import { blankItem, blankReceipt, decimalText, fiscalItem, parseReceipt, receiptMoney, reconcile, type ReceiptDraft, type ReceiptItem } from '@/domain/receipt';
import { recognize } from '@/domain/recognize';
import { money, tripTotal } from '@/domain/shopping';
import { Action, Card, ErrorText, Field, Heading, Label, Note, Screen, s } from '@/components/design';

export default function Receipt() {
  const { id } = useLocalSearchParams<{ id?: string }>(), { trips, items, busy, run } = useStore();
  const trip = trips.find(t => t.id === Number(id) && t.finished_at && t.imported);
  const [draft, setDraft] = useState<ReceiptDraft>(() => trip ? {
    ...blankReceipt(), market: trip.market, date: trip.finished_at!.slice(0, 10), key: trip.receipt_key ?? '', total: decimalText(tripTotal(trip, items)), discount: decimalText(trip.discount ?? 0), surcharge: decimalText(trip.surcharge ?? 0),
    items: items.filter(i => i.trip_id === trip.id).map(item => ({ ...blankItem(), name: item.name, quantity: item.fiscal_quantity ?? String(item.amount), unit: item.fiscal_unit || 'UN', unitPrice: item.fiscal_price ?? decimalText(item.price), gross: decimalText(item.fiscal_gross ?? item.price * item.amount), discount: decimalText(item.fiscal_discount ?? 0), totalOnly: !item.fiscal_quantity, reviewed: true })),
  } : blankReceipt());
  const [photos, setPhotos] = useState<string[]>([]), [raw, setRaw] = useState<string[]>([]), [preview, setPreview] = useState<string>();
  const [reading, setReading] = useState(false), [picking, setPicking] = useState(false), [reviewing, setReviewing] = useState(!!trip);
  const [error, setError] = useState(''), [confirmed, setConfirmed] = useState(false), [allowSimilar, setAllowSimilar] = useState(false);
  const generation = useRef(0), mounted = useRef(true), pickingLock = useRef(false);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  function update(values: Partial<ReceiptDraft>) { setDraft(current => ({ ...current, ...values })); setConfirmed(false); setAllowSimilar(false); }
  function updateItem(index: number, values: Partial<ReceiptItem>) {
    update({ items: draft.items.map((item, i) => i === index ? { ...item, ...values, reviewed: false } : item) });
  }
  async function pick(camera: boolean) {
    if (pickingLock.current || photos.length >= 10) return;
    pickingLock.current = true; setPicking(true); setError('');
    try {
      if (camera) {
        const permission = await ImagePicker.requestCameraPermissionsAsync();
        if (!permission.granted) { if (!permission.canAskAgain) Alert.alert('Câmera bloqueada', 'Permita a câmera nas configurações ou escolha fotos da galeria.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Configurações', onPress: () => { Linking.openSettings().catch(() => setError('Abra as configurações do Android manualmente.')); } }]); throw new Error('Câmera não permitida. Você pode escolher fotos da galeria.'); }
      }
      const result = camera ? await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 1 }) : await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsMultipleSelection: true, selectionLimit: 10 - photos.length, orderedSelection: true, quality: 1 });
      if (mounted.current && !result.canceled) { setPhotos(current => [...current, ...result.assets.map(asset => asset.uri)].slice(0, 10)); setRaw([]); setReviewing(false); }
    } catch (e) { if (mounted.current) setError(e instanceof Error ? e.message : 'Não foi possível abrir as imagens. Tente novamente.'); }
    finally { pickingLock.current = false; if (mounted.current) setPicking(false); }
  }
  async function read() {
    if (reading) return;
    const token = ++generation.current; setReading(true); setError('');
    try {
      const pages: string[] = [];
      for (const photo of photos) {
        const text = await recognize(photo);
        if (token !== generation.current || !mounted.current) return;
        if (!text.trim()) throw new Error(`Nenhum texto reconhecido na foto ${pages.length + 1}. Refaça a foto ou use a revisão manual.`);
        pages.push(text);
      }
      if (token === generation.current) { setRaw(pages); setDraft(parseReceipt(pages)); setReviewing(true); setConfirmed(false); setAllowSimilar(false); }
    } catch (e) { if (token === generation.current && mounted.current) setError(e instanceof Error ? e.message : 'Falha na leitura. Tente novamente ou revise manualmente.'); }
    finally { if (token === generation.current && mounted.current) setReading(false); }
  }
  function move(index: number, offset: number) {
    const next = [...photos]; [next[index], next[index + offset]] = [next[index + offset], next[index]]; setPhotos(next); setRaw([]);
  }
  async function save() {
    try { setError(''); await run(() => importReceipt(draft, confirmed, allowSimilar, trip?.id)); router.back(); }
    catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível salvar. Nenhuma compra foi importada.'); }
  }
  let validation = '';
  try { reconcile(draft); } catch (e) { validation = e instanceof Error ? e.message : 'Revise os valores.'; }
  let subtotal = 0;
  try { subtotal = draft.items.reduce((sum, item) => sum + receiptMoney(item.gross) - receiptMoney(item.discount), 0) - receiptMoney(draft.discount) + receiptMoney(draft.surcharge); } catch { /* Incomplete form. */ }
  return <Screen><Action secondary title={reading ? 'Cancelar leitura' : 'Cancelar e voltar'} disabled={busy} onPress={() => { generation.current++; router.back(); }} />
    <Heading title={trip ? 'Revisar compra fiscal' : 'Importar cupom'} subtitle="Confira o cupom antes de salvar. A compra ativa não será alterada." />
    <Note>OCR local. Fotos ficam no cache temporário; fotos e texto bruto não entram no histórico. Cupons cancelados, devoluções e valores negativos não são suportados.</Note>
    {!trip ? <><Action secondary title="Fotografar cupom" icon="camera-outline" disabled={reading || picking || photos.length >= 10} onPress={() => pick(true)} /><Action secondary title="Escolher fotos da galeria" icon="images-outline" disabled={reading || picking || photos.length >= 10} onPress={() => pick(false)} /><Note>{photos.length}/10 fotos. Ordene os trechos do começo ao fim, sem repetir produtos.</Note></> : null}
    {photos.map((uri, index) => <Card key={`${index}-${uri}`}><Label>Foto {index + 1}</Label><Image source={{ uri }} contentFit="contain" style={{ width: '100%', height: 180 }} /><Action secondary title={`Ampliar foto ${index + 1}`} onPress={() => setPreview(uri)} />{!reviewing ? <><View style={s.row}><View style={{ flex: 1 }}><Action secondary title="Antes" disabled={reading || index === 0} onPress={() => move(index, -1)} /></View><View style={{ flex: 1 }}><Action secondary title="Depois" disabled={reading || index === photos.length - 1} onPress={() => move(index, 1)} /></View></View><Action secondary title={`Remover foto ${index + 1}`} disabled={reading} onPress={() => setPhotos(current => current.filter((_, i) => i !== index))} /></> : null}</Card>)}
    {!reviewing && !trip ? <><Action title={reading ? 'Lendo no aparelho…' : 'Ler e revisar'} disabled={reading || picking || !photos.length} onPress={read} /><Action secondary title="Revisar manualmente" disabled={reading || picking} onPress={() => setReviewing(true)} /></> : null}
    {reviewing ? <>
      {!trip ? <Action secondary title="Voltar às fotos" disabled={busy} onPress={() => Alert.alert('Voltar às fotos?', 'Uma nova leitura substituirá a revisão atual.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Voltar', onPress: () => setReviewing(false) }])} /> : null}
      {draft.warnings.map((warning, index) => <Note key={index}>{warning}</Note>)}
      <Card><Field label="Mercado" value={draft.market} onChangeText={market => update({ market })} maxLength={160} /><Field label="Data (AAAA-MM-DD)" value={draft.date} onChangeText={date => update({ date })} maxLength={10} /><Field label="Chave fiscal (opcional, 44 dígitos)" value={draft.key} onChangeText={key => update({ key })} keyboardType="number-pad" maxLength={44} /></Card>
      <Text style={s.section}>Produtos · {draft.items.length}</Text><Note>Valores são sugestões. Revise cada item, inclusive repetições entre fotos. Desconto do item já está no valor líquido; não o repita no desconto geral.</Note>
      {draft.items.map((item, index) => <Card key={index}>
        <Label>Produto {index + 1} · foto {item.page}</Label>{item.source ? <Text selectable style={s.muted}>{item.source}</Text> : null}{item.warnings.map((warning, i) => <Note key={i}>{warning}</Note>)}
        <Field label="Nome do produto" value={item.name} onChangeText={name => updateItem(index, { name })} maxLength={160} />
        <Action secondary title={item.totalOnly ? '✓ Registrar somente o total do item' : 'Registrar somente o total do item'} onPress={() => updateItem(index, { totalOnly: !item.totalOnly })} />
        {!item.totalOnly ? <><Field label="Quantidade original" value={item.quantity} onChangeText={quantity => updateItem(index, { quantity })} keyboardType="decimal-pad" /><Field label="Unidade (UN, KG, G, L, LT, ML, PCT, PC, CX, M)" value={item.unit} onChangeText={unit => updateItem(index, { unit: unit.toUpperCase().trim() })} autoCapitalize="characters" /><Field label="Preço unitário original (até 4 decimais)" value={item.unitPrice} onChangeText={unitPrice => updateItem(index, { unitPrice })} keyboardType="decimal-pad" /></> : <Note>Sem inventar quantidade ou preço unitário.</Note>}
        <Field label="Valor bruto do item (R$)" value={item.gross} onChangeText={gross => updateItem(index, { gross })} keyboardType="decimal-pad" /><Field label="Desconto do item (R$)" value={item.discount} onChangeText={discount => updateItem(index, { discount })} keyboardType="decimal-pad" />
        <Action secondary title={item.reviewed ? '✓ Produto conferido' : 'Confirmar conferência deste produto'} onPress={() => { try { fiscalItem({ ...item, reviewed: true }); update({ items: draft.items.map((value, i) => i === index ? { ...value, reviewed: !value.reviewed } : value) }); setError(''); } catch (e) { setError(e instanceof Error ? e.message : 'Confira os dados.'); } }} />
        <Action secondary title={`Apagar produto ${index + 1}`} onPress={() => Alert.alert('Apagar produto da revisão?', 'A compra só será alterada quando você salvar.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Apagar', style: 'destructive', onPress: () => update({ items: draft.items.filter((_, i) => i !== index) }) }])} />
      </Card>)}
      <Action secondary title="Adicionar produto não reconhecido" onPress={() => update({ items: [...draft.items, blankItem()] })} />
      <Card><Field label="Desconto geral (R$)" value={draft.discount} onChangeText={discount => update({ discount })} keyboardType="decimal-pad" /><Field label="Acréscimo geral (R$)" value={draft.surcharge} onChangeText={surcharge => update({ surcharge })} keyboardType="decimal-pad" /><Field label="Total final pago (R$)" value={draft.total} onChangeText={total => update({ total })} keyboardType="decimal-pad" /><Label>Soma calculada: {money(subtotal)}</Label><ErrorText message={validation} /></Card>
      <Action secondary title={allowSimilar ? '✓ Confirmo que não é uma compra repetida' : 'Confirmar outra compra legítima, se houver uma semelhante'} onPress={() => setAllowSimilar(!allowSimilar)} />
      <Action secondary title={confirmed ? '✓ Conferi todos os itens e o total' : 'Confirmar conferência de todos os itens e total'} disabled={!!validation} onPress={() => setConfirmed(!confirmed)} />
      <Action title={busy ? 'Salvando…' : trip ? 'Salvar revisão fiscal' : 'Salvar compra no histórico'} disabled={busy || !!validation || !confirmed} onPress={save} />
    </> : null}
    {raw.map((text, index) => <Card key={index}><Label>Texto original · foto {index + 1}</Label><Text selectable style={s.muted}>{text}</Text></Card>)}
    <ErrorText message={error} />
    <Modal visible={!!preview} onRequestClose={() => setPreview(undefined)}><Screen><Action title="Fechar foto" onPress={() => setPreview(undefined)} /><ScrollView horizontal maximumZoomScale={5}><Image source={{ uri: preview }} contentFit="contain" style={{ width: 1400, height: 2000 }} /></ScrollView></Screen></Modal>
  </Screen>;
}
