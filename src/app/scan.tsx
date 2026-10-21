import { useRef, useState } from 'react';
import { View, Text, Linking } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Action, Heading, Note, ErrorText, s } from '@/components/design';
export default function Scan() {
  const [permission, requestPermission] = useCameraPermissions();
  const camera = useRef<CameraView>(null);
  const lock = useRef(false);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [torch, setTorch] = useState(false);
  const [error, setError] = useState('');
  async function capture() {
    if (!ready || lock.current) return;
    lock.current = true; setBusy(true); setError('');
    try {
      const photo = await camera.current?.takePictureAsync({ quality: .7 });
      if (!photo) throw new Error('capture');
      router.replace({ pathname: '/item', params: { photo: photo.uri } });
    } catch { setError('Não foi possível fotografar. Tente novamente ou digite o preço.'); }
    finally { setBusy(false); lock.current = false; }
  }
  return <SafeAreaView style={[s.safe, { padding: 24, gap: 16 }]}>
    <Action title="Voltar" secondary onPress={() => router.back()} />
    <Heading title="Fotografe a etiqueta" subtitle="Enquadre o nome e o preço do produto." />
    <Note>Captura de referência: o preenchimento ainda é manual. Leitura automática em uma próxima etapa.</Note>
    {permission?.granted ? <View style={{ flex: 1, minHeight: 180, overflow: 'hidden', borderRadius: 24 }}><CameraView ref={camera} style={{ flex: 1 }} facing="back" enableTorch={torch} onCameraReady={() => setReady(true)} onMountError={() => { setReady(false); setError('Câmera indisponível. Você pode adicionar o preço manualmente.'); }} /><View pointerEvents="none" style={{ position: 'absolute', top: '30%', bottom: '30%', left: 24, right: 24, borderWidth: 2, borderColor: 'white', borderRadius: 16 }} /></View> : <View style={{ flex: 1, justifyContent: 'center', gap: 20 }}><Text style={s.body}>Permita o uso da câmera para fotografar etiquetas. Nenhuma imagem é enviada a um servidor.</Text><Action title={permission?.canAskAgain === false ? 'Abrir configurações' : 'Permitir câmera'} onPress={async () => { try { if (permission?.canAskAgain === false) await Linking.openSettings(); else await requestPermission(); } catch { setError('Não foi possível solicitar acesso à câmera.'); } }} /></View>}
    <ErrorText message={error} />
    {permission?.granted ? <><Action secondary title={torch ? 'Desligar lanterna' : 'Ligar lanterna'} onPress={() => setTorch(!torch)} /><Action title={busy ? 'Capturando…' : 'Capturar etiqueta'} icon="camera-outline" disabled={!ready || busy} onPress={capture} /></> : null}
    <Action title="Digitar sem foto" secondary disabled={busy} onPress={() => router.replace('/item')} />
  </SafeAreaView>;
}
