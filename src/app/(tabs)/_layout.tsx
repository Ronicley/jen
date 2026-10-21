import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { colors } from '@/components/design';
export default function Layout() {
  return <Tabs screenOptions={{ headerShown: false, tabBarActiveTintColor: colors.blue, tabBarInactiveTintColor: colors.muted, tabBarStyle: { borderTopColor: colors.line, backgroundColor: 'white' }, tabBarLabelStyle: { fontFamily: 'InterSemi', fontSize: 12 } }}>
    <Tabs.Screen name="index" options={{ title: 'Início', tabBarIcon: ({ focused, size }) => <Ionicons name="home-outline" color={focused ? colors.blue : colors.muted} size={size} /> }} />
    <Tabs.Screen name="list" options={{ title: 'Lista', tabBarIcon: ({ focused, size }) => <Ionicons name="checkbox-outline" color={focused ? colors.blue : colors.muted} size={size} /> }} />
    <Tabs.Screen name="history" options={{ title: 'Histórico', tabBarIcon: ({ focused, size }) => <Ionicons name="receipt-outline" color={focused ? colors.blue : colors.muted} size={size} /> }} />
  </Tabs>;
}
