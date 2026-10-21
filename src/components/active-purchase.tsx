import { useEffect, useState } from 'react';
import { AccessibilityInfo, Animated, StyleSheet, Text, View } from 'react-native';
import { colors } from './design';

export function ActivePurchase() {
  const [progress] = useState(() => new Animated.Value(0));

  useEffect(() => {
    let mounted = true;
    let preferenceChanged = false;
    const pulse = Animated.loop(Animated.sequence([
      Animated.timing(progress, { toValue: 1, duration: 650, useNativeDriver: true, isInteraction: false }),
      Animated.timing(progress, { toValue: 0, duration: 650, useNativeDriver: true, isInteraction: false }),
    ]));
    const update = (reduceMotion: boolean) => {
      if (!mounted) return;
      pulse.stop();
      progress.setValue(0);
      if (!reduceMotion) pulse.start();
    };
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', value => {
      preferenceChanged = true;
      update(value);
    });
    AccessibilityInfo.isReduceMotionEnabled().then(value => {
      if (!preferenceChanged) update(value);
    }).catch(() => { /* Keep the indicator static if the preference is unavailable. */ });
    return () => { mounted = false; subscription.remove(); pulse.stop(); };
  }, [progress]);

  return <View accessible accessibilityLabel="Compra ativa" style={styles.badge}>
    <View style={styles.indicator}>
      <Animated.View style={[styles.halo, {
        opacity: progress.interpolate({ inputRange: [0, 1], outputRange: [0, 0.25] }),
        transform: [{ scale: progress.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1] }) }],
      }]} />
      <Animated.View style={[styles.dot, {
        transform: [{ scale: progress.interpolate({ inputRange: [0, 1], outputRange: [1, 1.35] }) }],
      }]} />
    </View>
    <Text style={styles.label}>Compra ativa</Text>
  </View>;
}

const styles = StyleSheet.create({
  badge: { flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', gap: 8, backgroundColor: '#E8F5EE', borderRadius: 20, paddingHorizontal: 12, paddingVertical: 7 },
  indicator: { width: 18, height: 18, alignItems: 'center', justifyContent: 'center' },
  halo: { position: 'absolute', width: 18, height: 18, borderRadius: 9, backgroundColor: colors.green },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.green },
  label: { fontFamily: 'InterSemi', fontSize: 12, color: colors.green },
});
