import type { ReactNode } from 'react';
import { ScrollView, View, Text, Pressable, TextInput, StyleSheet, KeyboardAvoidingView, Platform, type TextInputProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
export const colors = { blue: '#0077C8', ink: '#152536', muted: '#5D6D7E', background: '#F4F6F8', line: '#E3E9EF', green: '#147D64', red: '#C43737', pale: '#E8F4FC' };
export function Screen({ children }: { children: ReactNode }) {
  return <SafeAreaView style={s.safe} edges={['top', 'left', 'right']}><KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}><ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={s.page}>{children}</ScrollView></KeyboardAvoidingView></SafeAreaView>;
}
export function Heading({ title, subtitle }: { title: string; subtitle?: string }) { return <View style={{ gap: 6, marginBottom: 8 }}><Text style={s.title}>{title}</Text>{subtitle ? <Text style={s.muted}>{subtitle}</Text> : null}</View>; }
export function Card({ children, blue = false }: { children: ReactNode; blue?: boolean }) { return <View style={[s.card, blue && { backgroundColor: colors.blue }]}>{children}</View>; }
export function Label({ children }: { children: ReactNode }) { return <Text style={s.label}>{children}</Text>; }
export function Body({ children }: { children: ReactNode }) { return <Text style={s.body}>{children}</Text>; }
export function Note({ children }: { children: ReactNode }) { return <Text style={s.muted}>{children}</Text>; }
export function ErrorText({ message }: { message: string }) { return message ? <Text accessibilityRole="alert" style={{ color: colors.red, fontFamily: 'Inter', lineHeight: 22 }}>{message}</Text> : null; }
export function Action({ title, onPress, secondary = false, disabled = false, icon }: { title: string; onPress: () => void; secondary?: boolean; disabled?: boolean; icon?: keyof typeof Ionicons.glyphMap }) {
  return <Pressable accessibilityRole="button" accessibilityState={{ disabled }} disabled={disabled} onPress={onPress} style={({ pressed }) => [s.button, secondary && s.secondary, { opacity: disabled ? .45 : pressed ? .75 : 1 }]}>{icon ? <Ionicons name={icon} size={21} color={secondary ? colors.blue : 'white'} /> : null}<Text style={[s.buttonText, secondary && { color: colors.blue }]}>{title}</Text></Pressable>;
}
export function Field({ label, ...props }: TextInputProps & { label: string }) { return <View style={{ gap: 8 }}><Label>{label}</Label><TextInput accessibilityLabel={label} placeholderTextColor="#728091" {...props} style={[s.input, props.style]} /></View>; }
export function Empty({ icon, title, text }: { icon: keyof typeof Ionicons.glyphMap; title: string; text: string }) {
  return <View style={s.empty}><View style={s.iconBubble}><Ionicons name={icon} size={28} color={colors.blue} /></View><Text style={s.section}>{title}</Text><Text style={[s.muted, { textAlign: 'center' }]}>{text}</Text></View>;
}
export const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  page: { padding: 24, paddingBottom: 40, gap: 20, maxWidth: 640, width: '100%', alignSelf: 'center' },
  title: { fontFamily: 'Manrope', fontSize: 28, color: colors.ink, letterSpacing: -.8 },
  section: { fontFamily: 'Manrope', fontSize: 19, color: colors.ink },
  body: { fontFamily: 'Inter', fontSize: 16, lineHeight: 24, color: colors.ink },
  muted: { fontFamily: 'Inter', fontSize: 14, lineHeight: 21, color: colors.muted },
  label: { fontFamily: 'InterSemi', fontSize: 14, color: colors.ink },
  card: { backgroundColor: 'white', borderRadius: 20, padding: 22, gap: 16, borderWidth: 1, borderColor: '#EDF0F4' },
  button: { minHeight: 54, paddingVertical: 15, paddingHorizontal: 18, backgroundColor: colors.blue, borderRadius: 14, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: 10 },
  secondary: { backgroundColor: colors.pale },
  buttonText: { fontFamily: 'InterSemi', fontSize: 15, color: 'white', textAlign: 'center' },
  input: { minHeight: 54, borderRadius: 12, borderWidth: 1, borderColor: colors.line, paddingHorizontal: 16, paddingVertical: 12, backgroundColor: 'white', color: colors.ink, fontSize: 17, fontFamily: 'Inter' },
  row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  divider: { height: 1, backgroundColor: colors.line },
  amount: { fontFamily: 'Manrope', color: colors.ink, fontSize: 36, fontVariant: ['tabular-nums'], letterSpacing: -1 },
  empty: { paddingVertical: 22, alignItems: 'center', gap: 12 },
  iconBubble: { backgroundColor: colors.pale, width: 60, height: 60, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
