import { useState } from 'react';
import { Text } from 'react-native';
import { Alert } from '@/components/alert';
import { router, useLocalSearchParams } from 'expo-router';
import { useStore } from '@/data/store';
import { deleteTrip, editTrip } from '@/data/database';
import { cents, amountLabel, money, itemTotal, tripTotal } from '@/domain/shopping';
import { receiptMoney } from '@/domain/receipt';
import { Action, Card, ErrorText, Field, Heading, Note, Screen, s } from '@/components/design';

export default function TripForm() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { trips, items, run, busy } = useStore(), trip = trips.find(t => t.id === Number(id) && t.finished_at);
  const [market, setMarket] = useState(trip?.market ?? ''), [budget, setBudget] = useState(((trip?.budget ?? 0) / 100).toFixed(2));
  const [date, setDate] = useState(trip?.finished_at?.slice(0, 10) ?? '');
  const [discount, setDiscount] = useState(((trip?.discount ?? 0) / 100).toFixed(2)), [surcharge, setSurcharge] = useState(((trip?.surcharge ?? 0) / 100).toFixed(2));
  const [error, setError] = useState('');
  async function change(action: () => Promise<unknown>, back = false) {
    try { setError(''); await run(action); if (back) router.back(); } catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível salvar.'); }
  }
  if (!trip) return <Screen><Heading title="Compra não encontrada" /><Action title="Voltar" onPress={() => router.back()} /></Screen>;
  return <Screen><Action secondary title="Voltar" onPress={() => router.back()} /><Heading title="Editar compra finalizada" subtitle="A compra continua no histórico. A compra ativa não muda." />
    <Card><Field label="Mercado" value={market} onChangeText={setMarket} maxLength={160} /><Field label="Data (AAAA-MM-DD)" value={date} onChangeText={setDate} maxLength={10} />{!trip.imported ? <Field label="Orçamento (R$)" value={budget} onChangeText={setBudget} keyboardType="decimal-pad" /> : <><Field label="Desconto geral (R$)" value={discount} onChangeText={setDiscount} keyboardType="decimal-pad" /><Field label="Acréscimo geral (R$)" value={surcharge} onChangeText={setSurcharge} keyboardType="decimal-pad" /></>}<Action title="Salvar dados gerais" disabled={busy} onPress={() => change(() => editTrip(trip.id, market, trip.imported ? trip.budget : cents(budget), date, receiptMoney(discount), receiptMoney(surcharge)))} /></Card>
    <Text style={s.section}>Total: {money(tripTotal(trip, items))}</Text><Note>Itens são salvos em seus próprios formulários.</Note>
    {items.filter(item => item.trip_id === trip.id).map(item => <Card key={item.id}><Text style={s.label}>{item.name} · {money(itemTotal(item))}</Text><Note>{amountLabel(item)}</Note><Action secondary title={`Editar ${item.name}`} onPress={() => router.push(trip.imported ? { pathname: '/receipt', params: { id: trip.id } } : { pathname: '/item', params: { id: item.id, tripId: trip.id } })} /></Card>)}
    <Action secondary title={trip.imported ? 'Revisar todos os itens fiscais' : 'Adicionar produto'} onPress={() => router.push(trip.imported ? { pathname: '/receipt', params: { id: trip.id } } : { pathname: '/item', params: { tripId: trip.id } })} />
    <ErrorText message={error} /><Action secondary title="Apagar compra" disabled={busy} onPress={() => Alert.alert('Apagar compra?', 'A compra e seus itens serão removidos. Outras compras, lista e cadastros serão preservados.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Apagar', style: 'destructive', onPress: () => change(() => deleteTrip(trip.id), true) }])} />
  </Screen>;
}
