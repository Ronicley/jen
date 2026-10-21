import { useState } from 'react';
import { Text, View, Pressable } from 'react-native';
import { useStore } from '@/data/store';
import { total, money, date, itemTotal, amountLabel, modeLabel } from '@/domain/shopping';
import { Screen, Heading, Card, Note, Label, Empty, s, colors } from '@/components/design';
export default function History() {
  const { trips, items, products } = useStore();
  const [expanded, setExpanded] = useState<number | null>(null);
  const finished = trips.filter(t => t.finished_at);
  const records = items.filter(i => finished.some(t => t.id === i.trip_id));
  return <Screen><Heading title="Seu histórico" subtitle="Sua memória de preços, sempre por perto." />
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
      const cart = items.filter(i => i.trip_id === trip.id), spent = total(cart);
      return <Card key={trip.id}><Pressable accessibilityRole="button" accessibilityState={{ expanded: expanded === trip.id }} onPress={() => setExpanded(expanded === trip.id ? null : trip.id)} style={{ gap: 12, minHeight: 48 }}><View style={s.row}><View style={{ flex: 1 }}><Label>{trip.market}</Label><Note>{date(trip.finished_at!)} · {cart.length} itens</Note></View><Text style={s.section}>{money(spent)}</Text></View><Note>Orçamento: {money(trip.budget)} · {expanded === trip.id ? 'Ocultar' : 'Ver itens'}</Note></Pressable>{expanded === trip.id ? <><View style={s.divider} />{cart.map(item => <View key={item.id} style={{ gap: 4 }}><View style={s.row}><Text style={[s.label, { flex: 1 }]}>{item.name}</Text><Label>{money(itemTotal(item))}</Label></View><Note>{amountLabel(item)}</Note></View>)}</> : null}</Card>;
    })}</>}
  </Screen>;
}
