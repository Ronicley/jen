import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Exercise the exact schema shipped to expo-sqlite against a real SQLite engine.
const source = readFileSync(new URL('./database.ts', import.meta.url), 'utf8');
const schema = source.match(/await db\.execAsync\(`([\s\S]*?)`\);/)[1];
function create(path = ':memory:') { const db = new DatabaseSync(path); db.exec(schema); return db; }
const insertTrip = db => db.prepare('INSERT INTO trips (budget, market, created_at) VALUES (30000, ?, ?)').run('Mercado', '2026-01-01T12:00:00Z');

test('schema is repeatable and allows only one unfinished purchase', () => {
  const db = create();
  try {
    db.exec(schema);
    insertTrip(db);
    assert.throws(() => insertTrip(db));
    db.exec("UPDATE trips SET finished_at='2026-01-01T13:00:00Z'");
    insertTrip(db);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM trips').get().n, 2);
  } finally { db.close(); }
});
test('database rejects orphan items and nonpositive amounts', () => {
  const db = create();
  try {
    const insert = db.prepare("INSERT INTO items (trip_id,name,mode,price,amount) VALUES (?, 'Leite','unit',549,?)");
    assert.throws(() => insert.run(1, 1));
    insertTrip(db);
    assert.throws(() => insert.run(1, 0));
    insert.run(1, 3);
    assert.equal(db.prepare('SELECT price * amount AS total FROM items').get().total, 1647);
  } finally { db.close(); }
});
test('purchase survives database close and reopen', () => {
  const dir = mkdtempSync(join(tmpdir(), 'jen-test-'));
  try {
    let db = create(join(dir, 'jen.db'));
    insertTrip(db); db.close();
    db = create(join(dir, 'jen.db'));
    try { assert.equal(db.prepare('SELECT budget FROM trips WHERE finished_at IS NULL').get().budget, 30000); }
    finally { db.close(); }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('additive upgrade preserves a version 1 purchase, products and list', () => {
  const db = new DatabaseSync(':memory:');
  try {
    const oldSchema = schema.slice(0, schema.indexOf('CREATE TABLE IF NOT EXISTS trip_receipts')) + 'PRAGMA user_version=1;';
    db.exec(oldSchema); insertTrip(db);
    db.exec("INSERT INTO products VALUES (1,'Leite','unit'); INSERT INTO items VALUES (1,1,1,'Leite','unit',549,3); INSERT INTO list_items VALUES (1,'Arroz',1)");
    db.exec(schema);
    assert.equal(db.prepare('PRAGMA user_version').get().user_version, 2);
    assert.equal(db.prepare('SELECT price * amount AS total FROM items').get().total, 1647);
    assert.equal(db.prepare('SELECT name,checked FROM list_items').get().checked, 1);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM products').get().n, 1);
  } finally { db.close(); }
});
