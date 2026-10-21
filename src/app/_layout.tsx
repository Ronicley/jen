import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useFonts } from 'expo-font';
import { Manrope_700Bold } from '@expo-google-fonts/manrope/700Bold';
import { Inter_400Regular } from '@expo-google-fonts/inter/400Regular';
import { Inter_600SemiBold } from '@expo-google-fonts/inter/600SemiBold';
import { ActivityIndicator, View } from 'react-native';
import { StoreProvider } from '@/data/store';

export default function Layout() {
  const [loaded, error] = useFonts({ Manrope: Manrope_700Bold, Inter: Inter_400Regular, InterSemi: Inter_600SemiBold });
  if (!loaded && !error) return <View style={{ flex: 1, justifyContent: 'center' }}><ActivityIndicator /></View>;
  return <StoreProvider><StatusBar style="dark" /><Stack screenOptions={{ headerShown: false }}>
    <Stack.Screen name="(tabs)" /><Stack.Screen name="new" options={{ presentation: 'modal' }} />
    <Stack.Screen name="item" options={{ presentation: 'modal' }} />
  </Stack></StoreProvider>;
}
