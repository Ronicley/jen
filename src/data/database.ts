import { openDatabaseAsync, type SQLiteDatabase } from 'expo-sqlite';
import type { Item, ItemDraft, ListItem, Product, Trip } from '../domain/shopping';

let connection: Promise<SQLiteDatabase> | undefined;
export function database() {
  return connection ??= openDatabaseAsync('jen.db').then(async db => {
    await db.execAsync(`
      PRAGMA journal_mode = WAL;
      PRAGMA foreign_keys = ON;
      CREATE TABLE IF NOT EXISTS trips (
        id INTEGER PRIMARY KEY, budget INTEGER NOT NULL CHECK(budget > 0), market TEXT NOT NULL,
        created_at TEXT NOT NULL, finished_at TEXT
      );
      CREATE UNIQUE INDEX IF NOT EXISTS one_active_trip ON trips((1)) WHERE finished_at IS NULL;
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, mode TEXT NOT NULL CHECK(mode IN ('unit','weight','package'))
      );
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY, trip_id INTEGER NOT NULL REFERENCES trips(id),
        product_id INTEGER REFERENCES products(id), name TEXT NOT NULL,
        mode TEXT NOT NULL CHECK(mode IN ('unit','weight','package')),
        price INTEGER NOT NULL CHECK(price > 0), amount INTEGER NOT NULL CHECK(amount > 0)
      );
      CREATE INDEX IF NOT EXISTS items_trip ON items(trip_id);
      CREATE TABLE IF NOT EXISTS list_items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, checked INTEGER NOT NULL DEFAULT 0);
      PRAGMA user_version = 1;
    `);
    return db;
  }).catch(error => { connection = undefined; throw error; });
}
export async function snapshot() {
  const db = await database();
  return {
    trips: await db.getAllAsync<Trip>('SELECT * FROM trips ORDER BY id DESC'),
    items: await db.getAllAsync<Item>('SELECT * FROM items ORDER BY id DESC'),
    products: await db.getAllAsync<Product>('SELECT * FROM products ORDER BY name'),
    list: await db.getAllAsync<ListItem>('SELECT * FROM list_items ORDER BY checked, id DESC'),
  };
}
export async function startTrip(budget: number, market: string) {
  const db = await database();
  await db.runAsync('INSERT INTO trips (budget, market, created_at) VALUES (?, ?, ?)', budget, market.trim() || 'Minha compra', new Date().toISOString());
}
export async function saveItem(tripId: number, draft: ItemDraft, id?: number, createProduct = false) {
  const db = await database();
  await db.withTransactionAsync(async () => {
    const trip = await db.getFirstAsync<Trip>('SELECT * FROM trips WHERE id = ? AND finished_at IS NULL', tripId);
    if (!trip) throw new Error('Esta compra já foi finalizada.');
    let productId = draft.product_id;
    if (createProduct) {
      const result = await db.runAsync('INSERT INTO products (name, mode) VALUES (?, ?)', draft.name, draft.mode);
      productId = result.lastInsertRowId;
    }
    if (productId) {
      const product = await db.getFirstAsync<Product>('SELECT * FROM products WHERE id = ?', productId);
      if (!product || product.mode !== draft.mode) throw new Error('Selecione um produto com o mesmo tipo de preço.');
    }
    const values = [productId, draft.name || 'Produto sem nome', draft.mode, draft.price, draft.amount];
    if (id) await db.runAsync('UPDATE items SET product_id=?, name=?, mode=?, price=?, amount=? WHERE id=? AND trip_id=?', ...values, id, tripId);
    else await db.runAsync('INSERT INTO items (product_id, name, mode, price, amount, trip_id) VALUES (?, ?, ?, ?, ?, ?)', ...values, tripId);
  });
}
export async function removeItem(id: number) {
  const db = await database();
  await db.runAsync('DELETE FROM items WHERE id=? AND trip_id IN (SELECT id FROM trips WHERE finished_at IS NULL)', id);
}
export async function finishTrip(id: number) {
  const db = await database();
  await db.runAsync('UPDATE trips SET finished_at=? WHERE id=? AND finished_at IS NULL AND EXISTS (SELECT 1 FROM items WHERE trip_id=?)', new Date().toISOString(), id, id);
}
export async function addListItem(name: string) {
  const db = await database();
  if (!name.trim()) throw new Error('Digite o nome do item.');
  await db.runAsync('INSERT INTO list_items (name) VALUES (?)', name.trim());
}
export async function toggleListItem(id: number) {
  const db = await database();
  await db.runAsync('UPDATE list_items SET checked=1-checked WHERE id=?', id);
}
export async function deleteListItem(id: number) {
  const db = await database();
  await db.runAsync('DELETE FROM list_items WHERE id=?', id);
}
