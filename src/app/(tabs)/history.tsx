import { useState } from 'react';
import { Text, View, Pressable } from 'react-native';
import { Alert } from '@/components/alert';
import { router } from 'expo-router';
import { useStore } from '@/data/store';
import { tripTotal, money, date, itemTotal, amountLabel, modeLabel } from '@/domain/shopping';
import { Screen, Heading, Card, Note, Label, Empty, Action, ErrorText, s, colors } from '@/components/design';
import { deleteTrip } from '@/data/database';
export default function History() {
  const { trips, items, products, run, busy } = useStore();
  const [error, setError] = useState('');
  function menu(id: number) {
    Alert.alert('Compra finalizada', 'Escolha uma ação.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Editar compra', onPress: () => router.push({ pathname: '/trip', params: { id } }) }, { text: 'Apagar compra', style: 'destructive', onPress: () => Alert.alert('Apagar compra e seus itens?', 'Outras compras, lista e cadastros serão preservados.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Apagar', style: 'destructive', onPress: async () => { try { await run(() => deleteTrip(id)); } catch { setError('Não foi possível apagar a compra. Tente novamente.'); } } }]) }]);
  }
  const [expanded, setExpanded] = useState<number | null>(null);
  const finished = trips.filter(t => t.finished_at);
  const records = items.filter(i => finished.some(t => t.id === i.trip_id));
  return <Screen><Heading title="Seu histórico" subtitle="Sua memória de preços, sempre por perto." /><Action title="Importar cupom" icon="receipt-outline" onPress={() => router.push('/receipt')} /><ErrorText message={error} />
    {!finished.length ? <Empty icon="receipt-outline" title="Cada compra conta uma história" text="Finalize sua primeira compra para ver os gastos e os preços registrados." /> : <>
    <Text style={s.section}>Preços que você registrou</Text>
    <Note>Comparações apenas entre produtos associados por você. O preço por embalagem só é comparável para o mesmo tamanho.</Note>
    {products.filter(p => records.some(i => i.product_id === p.id)).map(product => {
      const history = records.filter(i => i.product_id === product.id).sort((a, b) => {
        const ta = trips.find(t => t.id === a.trip_id)!.finished_at!;
        const tb = trips.find(t => t.id === b.trip_id)!.finished_at!;
        return tb.localeCompare(ta) || b.id - a.id;
      });
      const latest = history[0];
      const previous = history.find(i => i.trip_id !== latest.trip_id);
      const difference = previous ? latest.price - previous.price : null;
      return <Card key={product.id}><Label>{product.name}</Label><View style={s.row}><Text style={s.section}>{money(latest.price)}{product.mode === 'weight' ? '/kg' : ''}</Text><Note>{modeLabel(product.mode)}</Note></View>{difference !== null ? <Text style={[s.muted, { color: difference > 0 ? colors.red : colors.green }]}>{difference === 0 ? 'Mesmo preço da compra anterior' : `${difference > 0 ? '+' : '−'}${money(Math.abs(difference))} em relação à compra anterior`}</Text> : <Note>Primeiro preço registrado.</Note>}<View style={s.divider} />{history.slice(0, 5).map(item => { const trip = trips.find(t => t.id === item.trip_id)!; return <View key={item.id} style={s.row}><View style={{ flex: 1 }}><Note>{date(trip.finished_at!)} · {trip.market}</Note></View><Label>{money(item.price)}</Label></View>; })}</Card>;
    })}
    {!records.some(i => i.product_id) ? <Note>Ao adicionar produtos, associe ou crie um cadastro para começar a comparar preços.</Note> : null}
    <Text style={s.section}>Compras finalizadas</Text>
    {finished.map(trip => {
      const cart = items.filter(i => i.trip_id === trip.id), spent = tripTotal(trip, items);
      return <Card key={trip.id}><Pressable disabled={busy} accessibilityRole="button" accessibilityState={{ expanded: expanded === trip.id }} onLongPress={() => menu(trip.id)} onPress={() => setExpanded(expanded === trip.id ? null : trip.id)} style={{ gap: 12, minHeight: 48 }}><View style={s.row}><View style={{ flex: 1 }}><Label>{trip.market}</Label><Note>{date(trip.finished_at!)} · {cart.length} itens</Note></View><Text style={s.section}>{money(spent)}</Text></View><Note>{trip.imported ? `Cupom · desconto ${money(trip.discount ?? 0)} · acréscimo ${money(trip.surcharge ?? 0)}` : `Orçamento: ${money(trip.budget)}`} · {expanded === trip.id ? 'Ocultar' : 'Ver itens'}</Note></Pressable><Action secondary title="Opções da compra" icon="ellipsis-horizontal" disabled={busy} onPress={() => menu(trip.id)} />{expanded === trip.id ? <><View style={s.divider} />{cart.map(item => <Pressable key={item.id} accessibilityRole="button" accessibilityLabel={`Editar ${item.name}`} onPress={() => router.push(trip.imported ? { pathname: '/receipt', params: { id: trip.id } } : { pathname: '/item', params: { id: item.id, tripId: trip.id } })} onLongPress={() => router.push({ pathname: '/trip', params: { id: trip.id } })} style={{ gap: 4, minHeight: 48 }}><View style={s.row}><Text style={[s.label, { flex: 1 }]}>{item.name}</Text><Label>{money(itemTotal(item))}</Label></View><Note>{amountLabel(item)}</Note></Pressable>)}</> : null}</Card>;
    })}</>}
  </Screen>;
}
