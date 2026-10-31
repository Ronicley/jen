import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import * as shopping from '../domain/shopping.ts';
import * as receipt from '../domain/receipt.ts';

// Run production operations against SQLite, substituting only the native driver.
async function setup(platform = 'ios') {
  const sqlite = new DatabaseSync(':memory:');
  const db = {
    execAsync: async sql => sqlite.exec(sql),
    runAsync: async (sql, ...values) => { const result = sqlite.prepare(sql).run(...values); return { ...result, lastInsertRowId: Number(result.lastInsertRowid) }; },
    getFirstAsync: async (sql, ...values) => sqlite.prepare(sql).get(...values),
    getAllAsync: async (sql, ...values) => sqlite.prepare(sql).all(...values),
    withExclusiveTransactionAsync: async action => { sqlite.exec('BEGIN'); try { await action(db); sqlite.exec('COMMIT'); } catch (e) { sqlite.exec('ROLLBACK'); throw e; } },
    withTransactionAsync: async action => { sqlite.exec('BEGIN'); try { await action(); sqlite.exec('COMMIT'); } catch (e) { sqlite.exec('ROLLBACK'); throw e; } },
  };
  const source = stripTypeScriptTypes(readFileSync(new URL('./database.ts', import.meta.url), 'utf8')).replace(/^import .*;\s*$/gm, '').replaceAll('export ', '');
  const factory = new Function('openDatabaseAsync', 'validateItem', 'tripTotal', 'reconcile', 'validDate', 'Platform', `${source}; return { snapshot, startTrip, saveItem, removeItem, finishTrip, addListItem, toggleListItem, renameListItem, deleteTrip, editTrip, importReceipt };`);
  return { api: factory(async () => db, shopping.validateItem, shopping.tripTotal, receipt.reconcile, receipt.validDate, { OS: platform }), sqlite };
}
function draft() {
  return { ...receipt.blankReceipt(), market: 'Mercado', date: '2026-10-31', total: '12,00', key: '1'.repeat(44), items: [{ ...receipt.blankItem(), name: 'Suco', quantity: '1,5', unit: 'L', unitPrice: '8,00', gross: '12,00', reviewed: true }] };
}
test('web transaction rolls back a failed receipt edit', async () => {
  const { api, sqlite } = await setup('web');
  try {
    await api.importReceipt(draft(), true);
    const before = await api.snapshot();
    sqlite.exec("CREATE TRIGGER fail_receipt BEFORE INSERT ON item_receipts BEGIN SELECT RAISE(ABORT, 'failure'); END");
    await assert.rejects(api.importReceipt(draft(), true, true, before.trips[0].id), /failure/);
    assert.deepEqual(await api.snapshot(), before);
  } finally { sqlite.close(); }
});
test('atomic fiscal import preserves active purchase, list, precision; blocks duplicates and mismatch', async () => {
  const { api, sqlite } = await setup();
  try {
    await api.startTrip(30000, 'Ativa'); await api.addListItem('Arroz');
    await api.importReceipt(draft(), true);
    const state = await api.snapshot(); assert.equal(state.trips.length, 2); assert.equal(state.list.length, 1);
    assert.equal(state.trips.filter(t => !t.finished_at).length, 1); assert.equal(state.items[0].net_total, 1200); assert.equal(state.items[0].fiscal_quantity, '1,5');
    await assert.rejects(api.importReceipt(draft(), true, true), /já foi importado/);
    await assert.rejects(api.importReceipt({ ...draft(), key: '', total: '12,01' }, true));
    await assert.rejects(api.importReceipt({ ...draft(), key: '' }, true), /semelhante/);
    await assert.rejects(api.importReceipt({ ...draft(), key: '' }, false, true));
    assert.equal((await api.snapshot()).trips.length, 2);
    await api.importReceipt({ ...draft(), key: '' }, true, true); assert.equal((await api.snapshot()).trips.length, 3);
  } finally { sqlite.close(); }
});
test('finished editing, last-item guard, deletion, and list rename preserve other data', async () => {
  const { api, sqlite } = await setup();
  try {
    await api.startTrip(30000, 'Mercado'); const trip = (await api.snapshot()).trips[0];
    const item = { product_id: null, name: 'Leite', mode: 'unit', price: 549, amount: 3 };
    await api.saveItem(trip.id, item, undefined, true); await api.finishTrip(trip.id);
    let state = await api.snapshot(); const first = state.items[0];
    await assert.rejects(api.removeItem(first.id), /pelo menos/);
    await api.saveItem(trip.id, { ...item, price: 599 }, first.id);
    await api.saveItem(trip.id, { ...item, name: 'Outro' }); await api.removeItem(first.id);
    await api.editTrip(trip.id, 'Editado', 40000, '2026-10-30');
    await api.startTrip(10000, 'Ativa'); await api.addListItem('Arroz'); state = await api.snapshot();
    await api.toggleListItem(state.list[0].id); await api.renameListItem(state.list[0].id, 'Feijão');
    await api.deleteTrip(trip.id); state = await api.snapshot();
    assert.equal(state.trips.length, 1); assert.equal(state.trips[0].finished_at, null); assert.equal(state.items.length, 0);
    assert.equal(state.products.length, 1); assert.equal(state.list[0].name, 'Feijão'); assert.equal(state.list[0].checked, 1);
  } finally { sqlite.close(); }
});
test('failed fiscal replacement rolls back and a valid replacement updates totals', async () => {
  const { api, sqlite } = await setup();
  try {
    await api.importReceipt(draft(), true); const trip = (await api.snapshot()).trips[0];
    await assert.rejects(api.importReceipt({ ...draft(), total: '99,00' }, true, false, trip.id));
    assert.equal((await api.snapshot()).items[0].net_total, 1200);
    const changed = draft(); changed.items[0].gross = '15,00'; changed.total = '15,00';
    await api.importReceipt(changed, true, false, trip.id); const state = await api.snapshot();
    assert.equal(state.trips.length, 1); assert.equal(shopping.tripTotal(state.trips[0], state.items), 1500);
    await assert.rejects(api.editTrip(trip.id, 'Mercado', 1200, '2026-10-31', 1600, 0));
    assert.equal(shopping.tripTotal((await api.snapshot()).trips[0], (await api.snapshot()).items), 1500);
  } finally { sqlite.close(); }
});
test('mid-import write failure rolls back purchase and item replacements', async () => {
  const { api, sqlite } = await setup();
  try {
    await api.importReceipt(draft(), true); const before = await api.snapshot(), trip = before.trips[0];
    sqlite.exec("CREATE TRIGGER simulated_disk_error BEFORE INSERT ON item_receipts BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END;");
    await assert.rejects(api.importReceipt(draft(), true, false, trip.id), /simulated write failure/);
    assert.deepEqual(await api.snapshot(), before);
    await assert.rejects(api.importReceipt({ ...draft(), key: '' }, true, true), /simulated write failure/);
    assert.deepEqual(await api.snapshot(), before);
    await assert.rejects(api.saveItem(trip.id, { product_id: null, name: 'Extra', mode: 'unit', price: 100, amount: 1 }), /revisão fiscal/);
    await assert.rejects(api.removeItem(before.items[0].id), /revisão fiscal/);
  } finally { sqlite.close(); }
});
