const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(process.argv[2] || 'dist');
const ocr = path.join(root, 'ocr');
fs.mkdirSync(ocr, { recursive: true });
for (const name of fs.readdirSync('node_modules/tesseract.js-core').filter(name => name.endsWith('.wasm.js'))) {
  fs.copyFileSync(path.join('node_modules/tesseract.js-core', name), path.join(ocr, name));
}
fs.copyFileSync('node_modules/tesseract.js/dist/worker.min.js', path.join(ocr, 'worker.min.js'));
fs.copyFileSync('node_modules/@tesseract.js-data/por/4.0.0_best_int/por.traineddata.gz', path.join(ocr, 'por.traineddata.gz'));
function files(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? files(file) : [file];
  });
}
const assets = files(root).filter(file => !['sw.js', '_headers'].includes(path.basename(file)));
const hash = crypto.createHash('sha256');
for (const file of assets.sort()) hash.update(path.relative(root, file)).update(fs.readFileSync(file));
const urls = assets.map(file => '/' + path.relative(root, file).split(path.sep).join('/'));
const worker = `const CACHE = ${JSON.stringify('jen-' + hash.digest('hex').slice(0, 16))};
const ASSETS = ${JSON.stringify(urls)};
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS))));
self.addEventListener('activate', event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('jen-') && key !== CACHE).map(key => caches.delete(key))))));
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('/index.html')));
  } else if (ASSETS.includes(new URL(request.url).pathname)) {
    event.respondWith(caches.match(request).then(response => response || fetch(request)));
  }
});
`;
fs.writeFileSync(path.join(root, 'sw.js'), worker);
