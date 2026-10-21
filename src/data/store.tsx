import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { snapshot } from './database';
import { ActivityIndicator, Text, View, Button } from 'react-native';

type Data = Awaited<ReturnType<typeof snapshot>>;
type Store = Data & { busy: boolean; run: (action: () => Promise<unknown>) => Promise<void> };
const Context = createContext<Store | null>(null);
export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [data, setData] = useState<Data>();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const lock = useRef(false);
  const load = useCallback(async () => {
    setError('');
    try { setData(await snapshot()); } catch { setError('Não foi possível abrir seus dados locais. Tente novamente.'); }
  }, []);
  useEffect(() => {
    let mounted = true;
    snapshot().then(value => { if (mounted) setData(value); }).catch(() => {
      if (mounted) setError('Não foi possível abrir seus dados locais. Tente novamente.');
    });
    return () => { mounted = false; };
  }, []);
  const run = async (action: () => Promise<unknown>) => {
    if (lock.current) throw new Error('Aguarde a operação atual terminar.');
    lock.current = true; setBusy(true);
    try { await action(); setData(await snapshot()); }
    finally { lock.current = false; setBusy(false); }
  };
  if (!data) return <View style={{ flex: 1, justifyContent: 'center', padding: 32, gap: 20 }}>
    {error ? <><Text>{error}</Text><Button title="Tentar novamente" onPress={load} /></> : <ActivityIndicator size="large" color="#0077C8" />}
  </View>;
  return <Context.Provider value={{ ...data, busy, run }}>{children}</Context.Provider>;
}
export function useStore() {
  const store = useContext(Context);
  if (!store) throw new Error('StoreProvider não encontrado.');
  return store;
}
