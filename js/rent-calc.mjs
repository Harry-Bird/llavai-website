// js/rent-calc.mjs — pure rental-affordability maths (Spanish 3x income rule).
// No DOM, no side effects. Shared by the browser (rent-calculator.html) and Node unit tests.

// Bands from net monthly income. Agents want income >= 3x rent (green); 2.5x-3x is risky (amber).
// Household income is used when it is higher than the individual salary.
export function computeBands(netSalary, householdIncome) {
  const s = Number(netSalary) || 0;
  const h = Math.max(Number(householdIncome) || 0, s);
  if (h <= 0) return { income: 0, green: 0, amber: 0, scaleMax: 0 };
  return { income: h, green: h / 3, amber: h / 2.5, scaleMax: h / 2 };
}

// Classify a candidate rent against the bands.
export function classifyRent(rent, bands) {
  const r = Number(rent) || 0;
  if (!bands || bands.green <= 0) return 'unknown';
  if (r <= bands.green) return 'approved';
  if (r <= bands.amber) return 'risky';
  return 'out';
}

// Euro formatting with es-ES "." thousands grouping (1.400), rounded to whole euros.
// Manual grouping (not toLocaleString) so Node and every browser render identically.
export function formatEuro(n) {
  const v = Math.round(Number(n) || 0);
  const sign = v < 0 ? '-' : '';
  const digits = String(Math.abs(v)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return '€' + sign + digits;
}
