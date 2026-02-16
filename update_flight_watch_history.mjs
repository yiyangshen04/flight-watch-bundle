import fs from 'node:fs/promises';
import path from 'node:path';

const HISTORY_MAX_RUNS = 240;
const LATEST_FILE = 'flight_watch_latest_round.json';
const HISTORY_FILE = 'flight_watch_price_history.json';

function hashText(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    h ^= text.charCodeAt(i);
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
  }
  return (h >>> 0).toString(36);
}

function makePairKey(row) {
  return `${row.departure_date}|${row.return_date}`;
}

function emptyStore() {
  return { version: 1, runs: [], by_pair: {} };
}

function isNum(v) {
  if (v === null || v === undefined || v === '') return false;
  const n = Number(v);
  return Number.isFinite(n);
}

function isPositivePrice(v) {
  return isNum(v) && Number(v) > 0;
}

function isOkStatus(status) {
  return String(status || '').toLowerCase() === 'ok';
}

function collectBadRunIdsFromRaw(raw) {
  const bad = new Set();
  if (!raw || typeof raw !== 'object') return bad;
  const byPair = raw.by_pair && typeof raw.by_pair === 'object' ? raw.by_pair : {};
  for (const entry of Object.values(byPair)) {
    if (!entry || typeof entry !== 'object' || !Array.isArray(entry.samples)) continue;
    for (const sample of entry.samples) {
      if (!sample || typeof sample.run_id !== 'string') continue;
      if (isNum(sample.price) && Number(sample.price) <= 0) {
        bad.add(sample.run_id);
      }
    }
  }
  return bad;
}

function dropBadRuns(store, badRunIds) {
  if (!badRunIds || badRunIds.size === 0) return;
  store.runs = store.runs.filter((r) => !badRunIds.has(r.id));
  Object.keys(store.by_pair).forEach((key) => {
    const entry = store.by_pair[key];
    if (!entry || !Array.isArray(entry.samples)) return;
    entry.samples = entry.samples.filter((s) => !badRunIds.has(s.run_id) && isPositivePrice(s.price));
  });
}

function normalizeStore(raw) {
  const out = emptyStore();
  if (!raw || typeof raw !== 'object') return out;

  if (Array.isArray(raw.runs)) {
    out.runs = raw.runs
      .filter((r) => r && typeof r.id === 'string')
      .map((r) => ({ id: r.id, at: typeof r.at === 'string' ? r.at : '' }));
  }

  const byPair = raw.by_pair && typeof raw.by_pair === 'object' ? raw.by_pair : {};
  for (const [key, entry] of Object.entries(byPair)) {
    if (!entry || typeof entry !== 'object') continue;
    const samples = Array.isArray(entry.samples) ? entry.samples : [];
    out.by_pair[key] = {
      departure_date: typeof entry.departure_date === 'string' ? entry.departure_date : '',
      return_date: typeof entry.return_date === 'string' ? entry.return_date : '',
      samples: samples
        .filter(
          (s) =>
            s &&
            typeof s.run_id === 'string' &&
            isPositivePrice(s.price) &&
            isOkStatus(s.status)
        )
        .map((s) => ({
          run_id: s.run_id,
          at: typeof s.at === 'string' ? s.at : '',
          price: Number(s.price),
          top_flights_item_count: isNum(s.top_flights_item_count) ? Number(s.top_flights_item_count) : null,
          status: typeof s.status === 'string' ? s.status : 'missing'
        }))
    };
  }

  return out;
}

function ensureRun(store, run) {
  const found = store.runs.find((r) => r.id === run.id);
  if (!found) {
    store.runs.push({ id: run.id, at: run.at });
  }
}

function ensureSample(store, row, run, priceField) {
  const key = makePairKey(row);
  if (!store.by_pair[key]) {
    store.by_pair[key] = {
      departure_date: row.departure_date,
      return_date: row.return_date,
      samples: []
    };
  }

  const entry = store.by_pair[key];
  if (!Array.isArray(entry.samples)) entry.samples = [];
  if (entry.samples.some((s) => s.run_id === run.id)) return;

  const rawPrice = row[priceField];
  if (!isPositivePrice(rawPrice)) return;
  if (!isOkStatus(row.status)) return;

  entry.samples.push({
    run_id: run.id,
    at: run.at,
    price: Number(rawPrice),
    top_flights_item_count: isNum(row.top_flights_item_count) ? Number(row.top_flights_item_count) : null,
    status: typeof row.status === 'string' ? row.status : 'missing'
  });
}

function pruneAndSort(store) {
  const usedRuns = new Set();
  Object.values(store.by_pair).forEach((entry) => {
    if (!entry || !Array.isArray(entry.samples)) return;
    entry.samples.forEach((s) => {
      if (s && typeof s.run_id === 'string') usedRuns.add(s.run_id);
    });
  });
  store.runs = store.runs.filter((r) => usedRuns.has(r.id));

  if (store.runs.length > HISTORY_MAX_RUNS) {
    store.runs = store.runs.slice(store.runs.length - HISTORY_MAX_RUNS);
  }

  const allow = {};
  store.runs.forEach((run) => {
    allow[run.id] = true;
  });

  const runOrder = {};
  store.runs.forEach((run, idx) => {
    runOrder[run.id] = idx;
  });

  Object.keys(store.by_pair).forEach((key) => {
    const entry = store.by_pair[key];
    if (!entry || !Array.isArray(entry.samples)) return;
    entry.samples = entry.samples
      .filter((s) => allow[s.run_id])
      .sort((a, b) => {
        const ai = Object.prototype.hasOwnProperty.call(runOrder, a.run_id) ? runOrder[a.run_id] : 0;
        const bi = Object.prototype.hasOwnProperty.call(runOrder, b.run_id) ? runOrder[b.run_id] : 0;
        return ai - bi;
      });
  });
}

async function readJson(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function main() {
  const cwd = process.cwd();
  const latestPath = path.join(cwd, LATEST_FILE);
  const historyPath = path.join(cwd, HISTORY_FILE);

  const latest = await readJson(latestPath);
  if (!latest || !Array.isArray(latest.rows)) {
    throw new Error(`Missing or invalid rows in ${latestPath}`);
  }

  const rows = latest.rows;
  const latestStat = await fs.stat(latestPath);
  const runAtIso = latestStat.mtime.toISOString();
  const runId = `run_${hashText(`${runAtIso}|rows=${rows.length}`)}`;

  const existingRaw = await readJson(historyPath);
  const badRunIds = collectBadRunIdsFromRaw(existingRaw);
  const store = normalizeStore(existingRaw);
  dropBadRuns(store, badRunIds);

  // Bootstrap from baseline/previous/current only once when history file is absent.
  if (store.runs.length === 0) {
    const baselineAt = new Date(latestStat.mtime.getTime() - 6 * 60 * 60 * 1000).toISOString();
    const previousAt = new Date(latestStat.mtime.getTime() - 3 * 60 * 60 * 1000).toISOString();

    const baselineRun = {
      id: `run_${hashText(`${baselineAt}|rows=${rows.length}|bootstrap=baseline`)}`,
      at: baselineAt
    };
    const previousRun = {
      id: `run_${hashText(`${previousAt}|rows=${rows.length}|bootstrap=previous`)}`,
      at: previousAt
    };

    ensureRun(store, baselineRun);
    ensureRun(store, previousRun);

    rows.forEach((row) => {
      ensureSample(store, row, baselineRun, 'baseline_price_usd');
      ensureSample(store, row, previousRun, 'previous_price_usd');
    });
  }

  const currentRun = { id: runId, at: runAtIso };
  const currentHasZero = rows.some((row) => isNum(row.top_min_usd) && Number(row.top_min_usd) <= 0);
  if (!currentHasZero) {
    ensureRun(store, currentRun);
    rows.forEach((row) => {
      ensureSample(store, row, currentRun, 'top_min_usd');
    });
  } else {
    console.warn(`Skipped current run ${runId} because at least one row had non-positive price.`);
  }

  pruneAndSort(store);

  await fs.writeFile(historyPath, `${JSON.stringify(store, null, 2)}\n`, 'utf8');

  console.log(`Updated history: ${historyPath}`);
  console.log(`Runs: ${store.runs.length}, Pairs: ${Object.keys(store.by_pair).length}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
