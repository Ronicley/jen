import { createWorker } from 'tesseract.js';

export async function recognize(uri: string): Promise<string> {
  const worker = await createWorker('por', 1, __DEV__ ? {} : {
    workerPath: '/ocr/worker.min.js',
    corePath: '/ocr',
    langPath: '/ocr',
    workerBlobURL: false,
  });
  try {
    const result = await worker.recognize(uri);
    return result.data.text;
  } finally {
    await worker.terminate();
  }
}
