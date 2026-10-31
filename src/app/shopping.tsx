import { useState } from 'react';
import { View, Text, FlatList, Pressable } from 'react-native';
import { Alert } from '@/components/alert';
import { SafeAreaView } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { useStore } from '@/data/store';
import { ActivePurchase } from '@/components/active-purchase';
import { finishTrip, removeItem } from '@/data/database';
import { total, money, itemTotal, amountLabel } from '@/domain/shopping';
import { Action, Card, Note, Empty, ErrorText, s, colors } from '@/components/design';
export default function Shopping() {
  const { trips, items, run, busy } = useStore();
  const [error, setError] = useState('');
  const trip = trips.find(t => !t.finished_at);
  if (!trip) return <SafeAreaView style={[s.safe, { padding: 24 }]}><Empty icon="cart-outline" title="Nenhuma compra aberta" text="Defina seu orçamento para começar." /><Action title="Voltar ao início" onPress={() => router.replace('/')} /></SafeAreaView>;
  const cart = items.filter(i => i.trip_id === trip.id);
  const spent = total(cart), balance = trip.budget - spent;
  function menu(id: number, name: string) {
    Alert.alert(name, 'Escolha uma ação.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Editar item', onPress: () => router.push({ pathname: '/item', params: { id } }) }, { text: 'Apagar item', style: 'destructive', onPress: () => Alert.alert('Apagar produto?', 'O valor voltará ao saldo disponível.', [{ text: 'Cancelar', style: 'cancel' }, { text: 'Apagar', style: 'destructive', onPress: async () => { try { await run(() => removeItem(id)); } catch { setError('Não foi possível apagar o produto. Tente novamente.'); } } }]) }]);
  }
  async function finish() {
    try { await run(() => finishTrip(trip!.id)); router.replace('/history'); }
    catch { setError('Não foi possível finalizar. Tente novamente.'); }
  }
  return <SafeAreaView style={s.safe}>
    <View style={{ padding: 20, gap: 14, maxWidth: 640, width: '100%', alignSelf: 'center' }}>
      <View style={s.row}><Pressable accessibilityRole="button" onPress={() => router.back()} style={{ minHeight: 48, justifyContent: 'center' }}><Text style={{ color: colors.blue, fontFamily: 'InterSemi' }}>‹ Início</Text></Pressable><Note>{trip.market}</Note></View>
      <Card><ActivePurchase /><Note>{balance < 0 ? 'Acima do orçamento' : 'Você ainda pode gastar'}</Note><Text accessibilityLiveRegion="polite" style={[s.amount, balance < 0 && { color: colors.red }]}>{money(Math.abs(balance))}</Text><View style={{ height: 7, backgroundColor: colors.pale, borderRadius: 4, overflow: 'hidden' }}><View style={{ height: 7, width: `${Math.min(100, spent / trip.budget * 100)}%`, backgroundColor: balance < 0 ? colors.red : colors.blue }} /></View><Note>{money(spent)} de {money(trip.budget)}</Note></Card>
      <View style={s.row}><Text style={s.section}>Carrinho · {cart.length}</Text><Pressable onPress={() => router.push('/list')} style={{ minHeight: 48, justifyContent: 'center' }}><Text style={{ color: colors.blue, fontFamily: 'InterSemi' }}>Ver lista</Text></Pressable></View>
    </View>
    <FlatList data={cart} keyExtractor={item => String(item.id)} contentContainerStyle={{ paddingHorizontal: 24, paddingBottom: 20, maxWidth: 640, width: '100%', alignSelf: 'center' }} ListEmptyComponent={<Empty icon="basket-outline" title="Seu carrinho está pronto" text="Adicione o primeiro produto para acompanhar o saldo." />} renderItem={({ item }) => <View style={{ paddingVertical: 18, borderBottomWidth: 1, borderBottomColor: colors.line }}><Pressable disabled={busy} accessibilityRole="button" accessibilityLabel={`Editar ${item.name}`} onLongPress={() => menu(item.id, item.name)} onPress={() => router.push({ pathname: '/item', params: { id: item.id } })} style={{ minHeight: 48 }}><View style={s.row}><Text style={[s.label, { flex: 1 }]}>{item.name}</Text><Text style={s.label}>{money(itemTotal(item))}</Text></View><Note>{amountLabel(item)} · Editar</Note></Pressable><Action secondary title={`Opções de ${item.name}`} icon="ellipsis-horizontal" disabled={busy} onPress={() => menu(item.id, item.name)} /></View>} />
    <View style={{ padding: 20, gap: 8, backgroundColor: 'white', maxWidth: 640, width: '100%', alignSelf: 'center' }}><ErrorText message={error} /><Action title="Fotografar etiqueta" icon="camera-outline" onPress={() => router.push('/scan')} /><Action title="Adicionar manualmente" secondary onPress={() => router.push('/item')} /><Pressable disabled={!cart.length || busy} style={{ minHeight: 48, alignItems: 'center', justifyContent: 'center', opacity: cart.length ? 1 : .4 }} onPress={() => Alert.alert('Finalizar compra?', `Total: ${money(spent)}. A compra será salva no histórico.`, [{ text: 'Continuar comprando', style: 'cancel' }, { text: 'Finalizar', onPress: finish }])}><Text style={s.label}>Finalizar compra</Text></Pressable></View>
  </SafeAreaView>;
}
