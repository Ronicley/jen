import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cents, quantity, itemTotal, total } from './shopping.ts';

test('converts Brazilian decimal prices into exact cents', () => {
  assert.equal(cents('18,90'), 1890);
  assert.equal(cents('0,01'), 1);
  assert.equal(cents('5.4'), 540);
  assert.equal(cents('300'), 30000);
  for (const invalid of ['', '0', '-5', '1.000,00', '1,234', 'abc', 'Infinity']) assert.throws(() => cents(invalid));
});
test('requires positive whole quantities and grams', () => {
  assert.equal(quantity('650'), 650);
  for (const invalid of ['0', '-1', '1,5', '', '1e3']) assert.throws(() => quantity(invalid));
});
test('calculates units, weighed goods and package totals', () => {
  assert.equal(itemTotal({ mode: 'unit', price: 549, amount: 3 }), 1647);
  assert.equal(itemTotal({ mode: 'weight', price: 799, amount: 650 }), 519);
  assert.equal(itemTotal({ mode: 'package', price: 1234, amount: 2 }), 2468);
});
test('derives balance from items after edits and removals, including overspend', () => {
  const cart = [{ mode: 'unit', price: 549, amount: 3 }, { mode: 'weight', price: 799, amount: 650 }];
  assert.equal(30000 - total(cart), 27834);
  cart[0].amount = 1;
  assert.equal(30000 - total(cart), 28932);
  assert.equal(30000 - total(cart.slice(1)), 29481);
  assert.equal(100 - total(cart), -968);
  assert.equal(total([]), 0);
});
