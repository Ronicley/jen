import { useState } from 'react';
import { router } from 'expo-router';
import { Screen, Heading, Card, Field, Action, Note, ErrorText } from '@/components/design';
import { useStore } from '@/data/store';
import { startTrip } from '@/data/database';
import { cents } from '@/domain/shopping';
export default function NewTrip() {
  const { run, busy } = useStore();
  const [budget, setBudget] = useState('');
  const [market, setMarket] = useState('');
  const [error, setError] = useState('');
  async function save() {
    try { setError(''); const value = cents(budget); await run(() => startTrip(value, market)); router.replace('/shopping'); }
    catch (e) { setError(e instanceof Error ? e.message : 'Não foi possível iniciar a compra.'); }
  }
  return <Screen><Action title="Voltar" secondary onPress={() => router.back()} /><Heading title="Vamos ao mercado?" subtitle="Comece com um limite. O jen cuida das contas." /><Card><Field label="Quanto você quer gastar? (R$)" placeholder="300,00" keyboardType="decimal-pad" value={budget} onChangeText={setBudget} autoFocus /><Field label="Mercado (opcional)" placeholder="Nome do mercado" value={market} onChangeText={setMarket} maxLength={100} /><Note>Você pode ultrapassar o limite. Nós avisamos, sem bloquear sua compra.</Note></Card><ErrorText message={error} /><Action title="Começar compra" onPress={save} disabled={busy} /></Screen>;
}
