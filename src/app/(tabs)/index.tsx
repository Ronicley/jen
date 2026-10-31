import { Text, View } from 'react-native';
import { router } from 'expo-router';
import { Screen, Heading, Card, Action, Note, s, colors, Label } from '@/components/design';
import { useStore } from '@/data/store';
import { ActivePurchase } from '@/components/active-purchase';
import { total, tripTotal, money, date } from '@/domain/shopping';

export default function Home() {
  const { trips, items, list } = useStore();
  const active = trips.find(t => !t.finished_at);
  const finished = trips.filter(t => t.finished_at);
  const now = new Date();
  const monthly = finished.filter(t => { const d = new Date(t.finished_at!); return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear(); });
  const spent = monthly.reduce((sum, trip) => sum + tripTotal(trip, items), 0);
  const remaining = active ? active.budget - total(items.filter(i => i.trip_id === active.id)) : 0;
  return <Screen>
    <View style={s.row}><Text style={{ fontFamily: 'Manrope', fontSize: 34, color: colors.blue, letterSpacing: -2 }}>jen<Text style={{ color: colors.green }}>.</Text></Text><Note>Seu mercado, na conta.</Note></View>
    <Heading title="Compre com tranquilidade." subtitle="Cada item no carrinho. Tudo sob controle." />
    <Card blue>
      {active ? <ActivePurchase /> : null}
      <Text style={{ fontFamily: 'Inter', color: '#E3F2FD' }}>{active ? remaining < 0 ? 'Acima do orçamento' : 'Você ainda pode gastar' : 'Sua próxima compra começa aqui'}</Text>
      <Text style={[s.amount, { color: 'white' }]}>{active ? money(Math.abs(remaining)) : 'No seu ritmo.\nNo seu orçamento.'}</Text>
      <Text style={{ fontFamily: 'Inter', color: 'white', lineHeight: 22 }}>{active ? active.market : 'Defina um limite e acompanhe o saldo enquanto escolhe seus produtos.'}</Text>
      <Action secondary title={active ? 'Continuar compra' : 'Começar uma compra'} icon={active ? 'cart-outline' : 'add'} onPress={() => router.push(active ? '/shopping' : '/new')} />
    </Card>
    <View style={s.row}><Text style={s.section}>Seu mês em números</Text><Note>{now.toLocaleDateString('pt-BR', { month: 'long' })}</Note></View>
    <Card><Label>Total gasto</Label><Text style={s.amount}>{money(spent)}</Text><View style={s.divider} /><View style={s.row}><View><Note>Compras finalizadas</Note><Text style={s.section}>{monthly.length}</Text></View><View><Note>Média por compra</Note><Text style={s.section}>{monthly.length ? money(Math.round(spent / monthly.length)) : '—'}</Text></View></View></Card>
    <Card><Text style={s.section}>Não esqueça de nada</Text><Note>{list.filter(i => !i.checked).length} itens pendentes na sua lista.</Note><Action title="Ver lista de compras" secondary icon="checkbox-outline" onPress={() => router.push('/list')} /></Card>
    {finished.length > 0 ? <><Text style={s.section}>Última compra</Text><Card><View style={s.row}><View><Label>{finished[0].market}</Label><Note>{date(finished[0].finished_at!)}</Note></View><Text style={s.section}>{money(tripTotal(finished[0], items))}</Text></View><Action secondary title="Ver histórico" onPress={() => router.push('/history')} /></Card></> : <Note>Seu histórico começa ao finalizar a primeira compra. Os dados ficam neste aparelho.</Note>}
  </Screen>;
}
