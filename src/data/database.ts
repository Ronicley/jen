import { openDatabaseAsync, type SQLiteDatabase } from 'expo-sqlite';
import { Platform } from 'react-native';
import type { Item, ItemDraft, ListItem, Product, Trip } from '../domain/shopping';
import { validateItem, tripTotal } from '../domain/shopping';
import { reconcile, validDate, type ReceiptDraft } from '../domain/receipt';

let connection: Promise<SQLiteDatabase> | undefined;
async function transaction(db: SQLiteDatabase, action: (db: SQLiteDatabase) => Promise<void>) {
  if (Platform.OS === 'web') await db.withTransactionAsync(() => action(db));
  else await db.withExclusiveTransactionAsync(action);
}
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
      CREATE TABLE IF NOT EXISTS trip_receipts (
        trip_id INTEGER PRIMARY KEY REFERENCES trips(id), receipt_key TEXT UNIQUE,
        discount INTEGER NOT NULL CHECK(discount >= 0), surcharge INTEGER NOT NULL CHECK(surcharge >= 0)
      );
      CREATE TABLE IF NOT EXISTS item_receipts (
        item_id INTEGER PRIMARY KEY REFERENCES items(id), net_total INTEGER NOT NULL CHECK(net_total >= 0),
        fiscal_quantity TEXT NOT NULL, fiscal_unit TEXT NOT NULL, fiscal_price TEXT NOT NULL,
        fiscal_discount INTEGER NOT NULL CHECK(fiscal_discount >= 0), fiscal_gross INTEGER NOT NULL CHECK(fiscal_gross > 0)
      );
      PRAGMA user_version = 2;
    `);
    return db;
  }).catch(error => { connection = undefined; throw error; });
}
export async function snapshot() {
  const db = await database();
  return {
    trips: await db.getAllAsync<Trip>('SELECT t.*, r.receipt_key, r.discount, r.surcharge, r.trip_id IS NOT NULL AS imported FROM trips t LEFT JOIN trip_receipts r ON r.trip_id=t.id ORDER BY COALESCE(finished_at, created_at) DESC, t.id DESC'),
    items: await db.getAllAsync<Item>('SELECT i.*, r.net_total, r.fiscal_quantity, r.fiscal_unit, r.fiscal_price, r.fiscal_discount, r.fiscal_gross FROM items i LEFT JOIN item_receipts r ON r.item_id=i.id ORDER BY i.id DESC'),
    products: await db.getAllAsync<Product>('SELECT * FROM products ORDER BY name'),
    list: await db.getAllAsync<ListItem>('SELECT * FROM list_items ORDER BY checked, id DESC'),
  };
}
export async function startTrip(budget: number, market: string) {
  if (!Number.isSafeInteger(budget) || budget < 1 || budget > 999999999) throw new Error('Orçamento inválido.');
  const db = await database();
  await db.runAsync('INSERT INTO trips (budget, market, created_at) VALUES (?, ?, ?)', budget, market.trim() || 'Minha compra', new Date().toISOString());
}
export async function saveItem(tripId: number, draft: ItemDraft, id?: number, createProduct = false) {
  validateItem(draft);
  const db = await database();
  await transaction(db, async db => {
    const trip = await db.getFirstAsync<Trip>('SELECT * FROM trips WHERE id = ?', tripId);
    if (!trip) throw new Error('Compra não encontrada.');
    if (await db.getFirstAsync('SELECT trip_id FROM trip_receipts WHERE trip_id=?', tripId)) throw new Error('Use a revisão fiscal para editar esta compra.');
    if (id && !await db.getFirstAsync('SELECT id FROM items WHERE id=? AND trip_id=?', id, tripId)) throw new Error('Produto não encontrado.');
    if (id && await db.getFirstAsync('SELECT item_id FROM item_receipts WHERE item_id=?', id)) throw new Error('Use a revisão fiscal para editar este item.');
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
  await transaction(db, async db => {
    const item = await db.getFirstAsync<Item>('SELECT * FROM items WHERE id=?', id);
    if (!item) throw new Error('Produto não encontrado.');
    if (await db.getFirstAsync('SELECT trip_id FROM trip_receipts WHERE trip_id=?', item.trip_id)) throw new Error('Use a revisão fiscal para editar esta compra.');
    const trip = await db.getFirstAsync<Trip>('SELECT * FROM trips WHERE id=?', item.trip_id);
    const count = await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM items WHERE trip_id=?', item.trip_id);
    if (trip?.finished_at && count!.n <= 1) throw new Error('Uma compra finalizada precisa manter pelo menos um produto.');
    await db.runAsync('DELETE FROM item_receipts WHERE item_id=?', id);
    await db.runAsync('DELETE FROM items WHERE id=?', id);
  });
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
export async function renameListItem(id: number, name: string) {
  if (!name.trim()) throw new Error('Digite o nome do item.');
  await (await database()).runAsync('UPDATE list_items SET name=? WHERE id=?', name.trim(), id);
}
export async function editTrip(id: number, market: string, budget: number, date: string, discount = 0, surcharge = 0) {
  const timestamp = validDate(date);
  if (!market.trim() || !Number.isSafeInteger(budget) || budget < 1 || !Number.isSafeInteger(discount) || discount < 0 || !Number.isSafeInteger(surcharge) || surcharge < 0) throw new Error('Confira mercado, orçamento e ajustes.');
  const db = await database();
  await transaction(db, async db => {
    const trip = await db.getFirstAsync<Trip>('SELECT * FROM trips WHERE id=? AND finished_at IS NOT NULL', id);
    if (!trip) throw new Error('Compra finalizada não encontrada.');
    await db.runAsync('UPDATE trips SET market=?, budget=?, created_at=?, finished_at=? WHERE id=?', market.trim(), budget, timestamp, timestamp, id);
    if (await db.getFirstAsync('SELECT trip_id FROM trip_receipts WHERE trip_id=?', id)) {
      const rows = await db.getAllAsync<Item>('SELECT i.*, r.net_total FROM items i LEFT JOIN item_receipts r ON r.item_id=i.id WHERE trip_id=?', id);
      if (tripTotal({ ...trip, discount, surcharge }, rows) <= 0) throw new Error('Total final precisa ser maior que zero.');
      await db.runAsync('UPDATE trip_receipts SET discount=?, surcharge=? WHERE trip_id=?', discount, surcharge, id);
    }
  });
}
export async function deleteTrip(id: number) {
  const db = await database();
  await transaction(db, async db => {
    if (!await db.getFirstAsync('SELECT id FROM trips WHERE id=? AND finished_at IS NOT NULL', id)) throw new Error('Compra finalizada não encontrada.');
    await db.runAsync('DELETE FROM item_receipts WHERE item_id IN (SELECT id FROM items WHERE trip_id=?)', id);
    await db.runAsync('DELETE FROM items WHERE trip_id=?', id);
    await db.runAsync('DELETE FROM trip_receipts WHERE trip_id=?', id);
    await db.runAsync('DELETE FROM trips WHERE id=?', id);
  });
}
export async function importReceipt(draft: ReceiptDraft, confirmed: boolean, allowSimilar = false, editId?: number) {
  if (!confirmed) throw new Error('Confirme a conferência do cupom.');
  const values = reconcile(draft), timestamp = validDate(draft.date), db = await database();
  await transaction(db, async db => {
    if (editId && !await db.getFirstAsync('SELECT id FROM trips WHERE id=? AND finished_at IS NOT NULL', editId)) throw new Error('Compra não encontrada.');
    if (draft.key && await db.getFirstAsync('SELECT trip_id FROM trip_receipts WHERE receipt_key=? AND trip_id != ?', draft.key, editId ?? -1)) throw new Error('Este cupom já foi importado.');
    const similar = await db.getAllAsync<Trip>('SELECT t.*, r.discount, r.surcharge FROM trips t LEFT JOIN trip_receipts r ON r.trip_id=t.id WHERE lower(trim(market))=lower(trim(?)) AND finished_at IS NOT NULL AND substr(finished_at,1,10)=? AND t.id != ?', draft.market, timestamp.slice(0, 10), editId ?? -1);
    for (const trip of similar) {
      const rows = await db.getAllAsync<Item>('SELECT i.*, r.net_total FROM items i LEFT JOIN item_receipts r ON r.item_id=i.id WHERE trip_id=?', trip.id);
      if (!allowSimilar && tripTotal(trip, rows) === values.total) throw new Error('Compra semelhante encontrada. Confirme que é outro cupom legítimo.');
    }
    let tripId = editId;
    if (tripId) {
      await db.runAsync('DELETE FROM item_receipts WHERE item_id IN (SELECT id FROM items WHERE trip_id=?)', tripId);
      await db.runAsync('DELETE FROM items WHERE trip_id=?', tripId);
      await db.runAsync('DELETE FROM trip_receipts WHERE trip_id=?', tripId);
      await db.runAsync('UPDATE trips SET market=?, created_at=?, finished_at=? WHERE id=?', draft.market.trim(), timestamp, timestamp, tripId);
    } else tripId = (await db.runAsync('INSERT INTO trips (budget,market,created_at,finished_at) VALUES (?,?,?,?)', values.total, draft.market.trim(), timestamp, timestamp)).lastInsertRowId;
    await db.runAsync('INSERT INTO trip_receipts (trip_id,receipt_key,discount,surcharge) VALUES (?,?,?,?)', tripId, draft.key || null, values.discount, values.surcharge);
    for (const item of values.items) {
      const result = await db.runAsync('INSERT INTO items (trip_id,name,mode,price,amount) VALUES (?,?,?,?,?)', tripId, item.name, item.mode, item.price, item.amount);
      await db.runAsync('INSERT INTO item_receipts (item_id,net_total,fiscal_quantity,fiscal_unit,fiscal_price,fiscal_discount,fiscal_gross) VALUES (?,?,?,?,?,?,?)', result.lastInsertRowId, item.net_total, item.fiscal_quantity, item.fiscal_unit, item.fiscal_price, item.fiscal_discount, item.fiscal_gross);
    }
  });
}
