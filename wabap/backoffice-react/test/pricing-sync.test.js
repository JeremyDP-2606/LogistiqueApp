// La copie du calcul de prix du back-office (simulateur) doit rester identique à celle de la Lambda.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { priceCourse, DEFAULT_GRID } from '../src/lib/pricing.js';

const require = createRequire(import.meta.url);
const server = require('../../mobile/amplify/backend/function/deliveryApi/src/lib/pricing.js');

test('mêmes prix que la Lambda pour un échantillon de cas', () => {
  const cases = [];
  for (const size of ['S', 'M', 'L', 'XL']) for (const maxDays of [1, 2, 3]) for (const km of [0.5, 4, 12.3, 37]) {
    cases.push({ km, input: { size, maxDays, options: { deadline: km > 10, weekend: maxDays === 2, night: size === 'L' } } });
  }
  for (const c of cases) {
    assert.deepEqual(priceCourse(DEFAULT_GRID, c.km, c.input, { code: 'P', percent: 5 }), server.priceCourse(server.DEFAULT_GRID, c.km, c.input, { code: 'P', percent: 5 }));
  }
});
