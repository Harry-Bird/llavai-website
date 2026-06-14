// tests/rent-calc.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeBands, classifyRent, formatEuro } from '../js/rent-calc.mjs';

test('computeBands uses household income when higher', () => {
  const b = computeBands(2900, 4200);
  assert.equal(b.income, 4200);
  assert.equal(Math.round(b.green), 1400); // income / 3
  assert.equal(Math.round(b.amber), 1680); // income / 2.5
});

test('computeBands falls back to salary when household is lower/empty', () => {
  const b = computeBands(3000, 0);
  assert.equal(b.income, 3000);
  assert.equal(Math.round(b.green), 1000);
});

test('computeBands handles zero/garbage income safely', () => {
  assert.equal(computeBands(0, 0).green, 0);
  assert.equal(computeBands('x', null).green, 0);
});

test('classifyRent respects the 3x / 2.5x boundaries', () => {
  const b = computeBands(0, 4200); // green 1400, amber 1680
  assert.equal(classifyRent(1400, b), 'approved'); // <= green
  assert.equal(classifyRent(1401, b), 'risky');
  assert.equal(classifyRent(1680, b), 'risky');    // <= amber
  assert.equal(classifyRent(1681, b), 'out');
  assert.equal(classifyRent(1200, computeBands(0, 0)), 'unknown');
});

test('formatEuro rounds and groups es-ES', () => {
  assert.equal(formatEuro(1399.6), '€1.400');
});
