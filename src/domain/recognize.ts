import { requireOptionalNativeModule } from 'expo';

export async function recognize(uri: string): Promise<string> {
  const module = requireOptionalNativeModule<{ recognize: (path: string) => Promise<string> }>('JenOcr');
  if (!module) throw new Error('OCR exige o APK ou um development build; não funciona no Expo Go.');
  return module.recognize(uri);
}
