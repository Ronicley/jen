import { useState } from 'react';
import { View, Text, Pressable } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '@/data/store';
import { addListItem, toggleListItem, deleteListItem } from '@/data/database';
import { Screen, Heading, Card, Field, Action, Empty, ErrorText, Note, s, colors } from '@/components/design';
export default function List() {
  const { list, run, busy } = useStore();
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  async function change(action: () => Promise<unknown>) {
    try { setError(''); await run(action); } catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível atualizar a lista.'); }
  }
  async function add() {
    await change(async () => { await addListItem(name); setName(''); });
  }
  return <Screen><Heading title="Sua lista" subtitle="Um pouco de planejamento. Nada esquecido." /><Card><Field label="O que você precisa comprar?" placeholder="Ex.: Leite — 3 unidades" value={name} onChangeText={setName} maxLength={160} onSubmitEditing={add} returnKeyType="done" /><Action title="Adicionar à lista" icon="add" disabled={busy || !name.trim()} onPress={add} /></Card><ErrorText message={error} /><Note>{list.filter(i => i.checked).length} de {list.length} itens marcados. Marcar não altera o carrinho.</Note>
    {!list.length ? <Empty icon="checkbox-outline" title="Uma lista, menos esquecimentos" text="Adicione os itens antes de sair de casa." /> : <Card>{list.map(item => <View key={item.id} style={s.row}><Pressable disabled={busy} accessibilityRole="checkbox" accessibilityState={{ checked: !!item.checked }} onPress={() => change(() => toggleListItem(item.id))} style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 52 }}><Ionicons name={item.checked ? 'checkbox' : 'square-outline'} size={25} color={item.checked ? colors.green : colors.muted} /><Text style={[s.body, { flex: 1 }, !!item.checked && { textDecorationLine: 'line-through', color: colors.muted }]}>{item.name}</Text></Pressable><Pressable disabled={busy} accessibilityRole="button" accessibilityLabel={`Excluir ${item.name}`} onPress={() => change(() => deleteListItem(item.id))} style={{ minWidth: 48, minHeight: 48, alignItems: 'center', justifyContent: 'center' }}><Ionicons name="close-outline" size={22} color={colors.muted} /></Pressable></View>)}</Card>}
  </Screen>;
}
