import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = process.env.FLIGHT_WATCH_ROOT || path.dirname(fileURLToPath(import.meta.url));
const LATEST_JSON = path.join(ROOT, 'flight_watch_latest_round.json');
const LATEST_CSV = path.join(ROOT, 'flight_watch_latest_round.csv');
const HISTORY_JSON = path.join(ROOT, 'flight_watch_price_history.json');
const HISTORY_UPDATER = path.join(ROOT, 'update_flight_watch_history.mjs');
const OVERLAY_HTML = path.join(ROOT, 'flight_watch_overlay_chart.html');

const TRACK_START_DATE = process.env.TRACK_START_DATE || '2026-02-15';
const START_DATE = process.env.START_DATE || '';
const END_DATE = process.env.END_DATE || '';
const WINDOW_DAYS = Number(process.env.WINDOW_DAYS || '36');
const QUERY_TIMEZONE = process.env.QUERY_TIMEZONE || 'America/Chicago';
const TODAY_OVERRIDE = process.env.TODAY_OVERRIDE || '';
const STAY_DAYS = Number(process.env.STAY_DAYS || '16');
const TARGET_DEP = '2026-03-12';
const TARGET_RET = '2026-03-28';
const MAX_ROWS = Number(process.env.MAX_ROWS || '0');
const REQUEST_DELAY_MS = Number(process.env.REQUEST_DELAY_MS || '350');
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || '25000');
const PER_DATE_MAX_ATTEMPTS = Math.max(3, Number(process.env.PER_DATE_MAX_ATTEMPTS || '6'));
const MISSING_MAX_ATTEMPTS = Math.max(1, Number(process.env.MISSING_MAX_ATTEMPTS || '4'));
const RETRY_BASE_DELAY_MS = Math.max(200, Number(process.env.RETRY_BASE_DELAY_MS || '1200'));
const RETRY_MAX_DELAY_MS = Math.max(RETRY_BASE_DELAY_MS, Number(process.env.RETRY_MAX_DELAY_MS || '30000'));
const RETRY_JITTER_MS = Math.max(0, Number(process.env.RETRY_JITTER_MS || '650'));
const RATE_LIMIT_COOLDOWN_MS = Math.max(2000, Number(process.env.RATE_LIMIT_COOLDOWN_MS || '90000'));
const ROUND_FAIL_RATIO_WARNING = Math.min(
  1,
  Math.max(0, Number(process.env.ROUND_FAIL_RATIO_WARNING || '0.45'))
);

const RPC_URL =
  'https://www.google.com/_/FlightsFrontendUi/data/travel.frontend.flights.FlightsFrontendService/GetShoppingResults?hl=en-US';

// City airports pool tokens used by Google Flights internal request payload.
const CHI = ['/m/01_d4', 4];
const ROM = ['/m/06c62', 5];
const PAR = ['/m/05qtj', 5];

function isoDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function addDays(iso, days) {
  const d = new Date(`${iso}T00:00:00`);
  d.setDate(d.getDate() + days);
  return isoDate(d);
}

function buildDateRange(startIso, endIso) {
  const out = [];
  let cur = new Date(`${startIso}T00:00:00`);
  const end = new Date(`${endIso}T00:00:00`);
  while (cur <= end) {
    out.push(isoDate(cur));
    cur.setDate(cur.getDate() + 1);
  }
  return out;
}

function todayIsoInTz(timeZone) {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return fmt.format(new Date());
}

function maxIsoDate(a, b) {
  return a > b ? a : b;
}

function resolveQueryRange() {
  const todayNow = TODAY_OVERRIDE || todayIsoInTz(QUERY_TIMEZONE);

  // Manual override mode for backfills.
  if (START_DATE || END_DATE) {
    const start = START_DATE || TRACK_START_DATE;
    const end = END_DATE || addDays(start, WINDOW_DAYS - 1);
    return {
      mode: 'manual',
      today_iso: todayNow,
      start_date: start,
      end_date: end
    };
  }

  // Auto mode: slide the query window forward with local day.
  const today = todayNow;
  const start = maxIsoDate(TRACK_START_DATE, today);
  const end = addDays(start, WINDOW_DAYS - 1);
  return {
    mode: 'auto',
    today_iso: today,
    start_date: start,
    end_date: end
  };
}

function median(values) {
  if (!values.length) return null;
  const sorted = values.slice().sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2) return sorted[mid];
  return Number(((sorted[mid - 1] + sorted[mid]) / 2).toFixed(2));
}

function mean(values) {
  if (!values.length) return null;
  return Number((values.reduce((a, b) => a + b, 0) / values.length).toFixed(2));
}

function pairKey(dep, ret) {
  return `${dep}|${ret}`;
}

async function readJson(file) {
  try {
    const raw = await fs.readFile(file, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function toCsv(rows) {
  const headers = [
    'departure_date',
    'return_date',
    'baseline_price_usd',
    'previous_price_usd',
    'top_min_usd',
    'delta_vs_last_round_usd',
    'delta_vs_first_round_usd',
    'top_flights_item_count',
    'status'
  ];

  const lines = [headers.join(',')];
  for (const row of rows) {
    const vals = headers.map((k) => {
      const v = row[k];
      if (v === null || v === undefined) return '';
      return String(v).includes(',') ? `"${String(v).replaceAll('"', '""')}"` : String(v);
    });
    lines.push(vals.join(','));
  }
  return `${lines.join('\n')}\n`;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function jitterMs(maxJitter = RETRY_JITTER_MS) {
  if (!Number.isFinite(maxJitter) || maxJitter <= 0) return 0;
  return Math.floor(Math.random() * (maxJitter + 1));
}

function retryBackoffMs(attempt) {
  const exp = Math.max(0, attempt - 1);
  const base = RETRY_BASE_DELAY_MS * 2 ** exp;
  return Math.min(RETRY_MAX_DELAY_MS, base) + jitterMs();
}

function classifyRetryHint(err, attempt) {
  const code = Number(err?.http_status);
  if (code === 429 || code === 403 || code === 503) {
    return {
      kind: 'rate_limited',
      wait_ms: Math.max(RATE_LIMIT_COOLDOWN_MS, Number(err?.retry_after_ms) || 0) + jitterMs()
    };
  }
  if (err?.name === 'AbortError') {
    return { kind: 'timeout', wait_ms: retryBackoffMs(attempt) };
  }
  return { kind: 'transient', wait_ms: retryBackoffMs(attempt) };
}

function makeSessionToken() {
  const rand = Math.random().toString(36).slice(2, 10);
  return `H${Date.now().toString(36)}${rand}`;
}

function buildInnerRequest(dep, ret) {
  return [
    [null, null, null, makeSessionToken()],
    [
      null,
      null,
      3,
      null,
      [],
      1,
      [1, 0, 0, 0],
      null,
      null,
      null,
      null,
      null,
      null,
      [
        [[[CHI]], [[ROM]], null, 0, null, null, dep, null, null, null, null, null, null, null, 3],
        [[[PAR]], [[CHI]], null, 0, null, null, ret, null, null, null, null, null, null, null, 3]
      ],
      null,
      null,
      null,
      1
    ],
    0,
    0,
    0,
    1
  ];
}

function encodeFormBody(dep, ret) {
  const inner = buildInnerRequest(dep, ret);
  const fReq = JSON.stringify([null, JSON.stringify(inner)]);
  return `f.req=${encodeURIComponent(fReq)}&`;
}

function parseFirstJsonValue(s) {
  let depth = 0;
  let inStr = false;
  let esc = false;
  let end = -1;

  for (let i = 0; i < s.length; i += 1) {
    const ch = s[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === '\\') esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') {
      inStr = true;
      continue;
    }
    if (ch === '[' || ch === '{') depth += 1;
    if (ch === ']' || ch === '}') {
      depth -= 1;
      if (depth === 0) {
        end = i + 1;
        break;
      }
    }
  }

  if (end <= 0) throw new Error('Unable to parse first JSON value from RPC envelope');
  return JSON.parse(s.slice(0, end));
}

function decodeRpcEnvelope(rawText) {
  let s = rawText;

  if (s.startsWith(")]}'")) s = s.slice(4);
  while (s.startsWith('\n')) s = s.slice(1);

  const firstNl = s.indexOf('\n');
  if (firstNl > 0 && /^\d+$/.test(s.slice(0, firstNl))) {
    s = s.slice(firstNl + 1);
  }

  // Some responses contain multiple frames; the main payload frame starts with [["wrb.fr", ...].
  const marker = '[["wrb.fr"';
  const idx = s.indexOf(marker);
  if (idx > 0) {
    s = s.slice(idx);
  }

  const outer = parseFirstJsonValue(s);
  const first = Array.isArray(outer) ? outer[0] : null;
  if (!Array.isArray(first) || first[0] !== 'wrb.fr' || typeof first[2] !== 'string') {
    throw new Error('Missing wrb.fr payload frame');
  }
  return JSON.parse(first[2]);
}

function extractTopFlightsPrices(inner) {
  // Top flights are in inner[2][0], each item has total price at item[1][0][1].
  const items = inner?.[2]?.[0];
  if (!Array.isArray(items)) return [];

  const prices = [];
  for (const item of items) {
    const p = item?.[1]?.[0]?.[1];
    if (Number.isFinite(p) && p > 0) prices.push(p);
  }
  return prices;
}

function finiteNum(v) {
  return Number.isFinite(v) ? v : null;
}

function buildHistoryFirstPriceMap(historyStore) {
  const map = new Map();
  const byPair = historyStore?.by_pair;
  if (!byPair || typeof byPair !== 'object') return map;

  for (const [key, entry] of Object.entries(byPair)) {
    const samples = Array.isArray(entry?.samples) ? entry.samples : [];
    let first = null;
    for (const s of samples) {
      const price = Number(s?.price);
      if (Number.isFinite(price) && price > 0) {
        first = price;
        break;
      }
    }
    if (Number.isFinite(first)) map.set(key, first);
  }
  return map;
}

function knownPrice(row) {
  if (!row) return null;
  return (
    finiteNum(row.top_min_usd) ??
    finiteNum(row.previous_price_usd) ??
    finiteNum(row.baseline_price_usd) ??
    null
  );
}

async function fetchTopFlights(dep, ret) {
  const body = encodeFormBody(dep, ret);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let res;
  try {
    res = await fetch(RPC_URL, {
      method: 'POST',
      headers: {
        'accept-language': 'en-US,en;q=0.9',
        'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
        origin: 'https://www.google.com',
        referer: 'https://www.google.com/travel/flights',
        'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'x-same-domain': '1'
      },
      body,
      signal: controller.signal
    });
  } finally {
    clearTimeout(timer);
  }

  if (!res.ok) {
    const err = new Error(`RPC ${res.status} ${res.statusText}`);
    err.http_status = res.status;
    const retryAfter = Number(res.headers.get('retry-after'));
    if (Number.isFinite(retryAfter) && retryAfter > 0) {
      err.retry_after_ms = retryAfter * 1000;
    }
    throw err;
  }

  const text = await res.text();
  const inner = decodeRpcEnvelope(text);
  const prices = extractTopFlightsPrices(inner);

  if (!prices.length) {
    return { top_min_usd: null, top_flights_item_count: 0, status: 'missing' };
  }

  return {
    top_min_usd: Math.min(...prices),
    top_flights_item_count: prices.length,
    status: 'ok'
  };
}

async function queryPairWithRetries(dep, ret) {
  let sawMissing = false;
  let sawError = false;
  let lastErrorMessage = '';

  for (let attempt = 1; attempt <= PER_DATE_MAX_ATTEMPTS; attempt += 1) {
    try {
      const top = await fetchTopFlights(dep, ret);
      if (top.status === 'ok' && Number.isFinite(top.top_min_usd)) {
        return {
          departure_date: dep,
          return_date: ret,
          top_min_usd: top.top_min_usd,
          top_flights_item_count: top.top_flights_item_count,
          status: 'ok'
        };
      }

      sawMissing = true;
      const missingAttemptLimit = Math.min(PER_DATE_MAX_ATTEMPTS, MISSING_MAX_ATTEMPTS);
      const canRetryMissing = attempt < missingAttemptLimit;
      if (!canRetryMissing) break;

      const sleepMs = retryBackoffMs(attempt);
      console.log(
        `attempt ${attempt} missing for ${dep} -> ${ret}, retry in ${Math.round(sleepMs)}ms`
      );
      await wait(sleepMs);
      continue;
    } catch (err) {
      sawError = true;
      lastErrorMessage = String(err?.message || err);
      if (attempt >= PER_DATE_MAX_ATTEMPTS) break;

      const hint = classifyRetryHint(err, attempt);
      const sleepMs = Number.isFinite(hint.wait_ms) ? hint.wait_ms : retryBackoffMs(attempt);
      console.log(
        `attempt ${attempt} ${hint.kind} for ${dep} -> ${ret}: ${lastErrorMessage}; retry in ${Math.round(
          sleepMs
        )}ms`
      );
      await wait(sleepMs);
    }
  }

  if (lastErrorMessage) {
    console.log(`final failure for ${dep} -> ${ret}: ${lastErrorMessage}`);
  }

  return {
    departure_date: dep,
    return_date: ret,
    top_min_usd: null,
    top_flights_item_count: 0,
    status: sawError && !sawMissing ? 'retry_failed' : sawMissing ? 'missing' : 'retry_failed'
  };
}

function mergeWithPrevious(prevRows, freshRows, firstPriceMap) {
  const prevMap = new Map();
  for (const r of prevRows || []) {
    prevMap.set(pairKey(r.departure_date, r.return_date), r);
  }
  const freshMap = new Map();
  for (const r of freshRows || []) {
    freshMap.set(pairKey(r.departure_date, r.return_date), r);
  }

  const keys = new Set([...prevMap.keys(), ...freshMap.keys()]);
  const merged = [];

  for (const key of keys) {
    const p = prevMap.get(key);
    const r = freshMap.get(key);
    const [depFromKey, retFromKey] = key.split('|');
    const departure = r?.departure_date ?? p?.departure_date ?? depFromKey;
    const ret = r?.return_date ?? p?.return_date ?? retFromKey;

    const prevKnown = knownPrice(p);
    const baseline =
      finiteNum(firstPriceMap?.get(key)) ??
      finiteNum(p?.baseline_price_usd) ??
      prevKnown ??
      finiteNum(r?.top_min_usd) ??
      null;

    let current = null;
    let previous = null;
    let status = 'retry_failed';
    let itemCount = 0;

    if (!r) {
      // Not queried this round (usually aged-out departure dates): keep prior snapshot for chart continuity.
      current = prevKnown;
      previous = prevKnown;
      status = p?.status || 'archived';
      itemCount = Number.isFinite(p?.top_flights_item_count) ? p.top_flights_item_count : 0;
    } else if (r.status === 'ok' && Number.isFinite(r.top_min_usd)) {
      current = r.top_min_usd;
      previous = finiteNum(p?.top_min_usd) ?? prevKnown ?? current;
      status = 'ok';
      itemCount = r.top_flights_item_count;
    } else if (Number.isFinite(prevKnown)) {
      // Query failed this round, but we still keep the last known good price visible in HTML.
      current = prevKnown;
      previous = prevKnown;
      status = 'carry_forward';
      itemCount = Number.isFinite(p?.top_flights_item_count) ? p.top_flights_item_count : 0;
    } else {
      current = null;
      previous = prevKnown;
      status = r.status;
      itemCount = r.top_flights_item_count;
    }

    const deltaLast =
      Number.isFinite(current) && Number.isFinite(previous) ? current - previous : null;
    const deltaFirst =
      Number.isFinite(current) && Number.isFinite(baseline) ? current - baseline : null;

    merged.push({
      departure_date: departure,
      return_date: ret,
      baseline_price_usd: Number.isFinite(baseline) ? baseline : null,
      previous_price_usd: Number.isFinite(previous) ? previous : null,
      top_min_usd: Number.isFinite(current) ? current : null,
      delta_vs_last_round_usd: Number.isFinite(deltaLast) ? deltaLast : null,
      delta_vs_first_round_usd: Number.isFinite(deltaFirst) ? deltaFirst : null,
      top_flights_item_count: itemCount,
      status
    });
  }

  merged.sort((a, b) => pairKey(a.departure_date, a.return_date).localeCompare(pairKey(b.departure_date, b.return_date)));
  return merged;
}

function buildSummary(rows) {
  const okRows = rows.filter((r) => Number.isFinite(r.top_min_usd));
  const vals = okRows.map((r) => r.top_min_usd);
  const sortedOk = okRows.slice().sort((a, b) => a.top_min_usd - b.top_min_usd);

  const summary = {
    row_count: rows.length,
    min: vals.length ? Math.min(...vals) : null,
    median: median(vals),
    mean: mean(vals),
    max: vals.length ? Math.max(...vals) : null
  };

  const target =
    rows.find((r) => r.departure_date === TARGET_DEP && r.return_date === TARGET_RET) || null;

  const cheapest = sortedOk.slice(0, 5);

  let up = 0;
  let down = 0;
  let flat = 0;
  for (const r of rows) {
    const d = r.delta_vs_last_round_usd;
    if (!Number.isFinite(d)) continue;
    if (d > 0) up += 1;
    else if (d < 0) down += 1;
    else flat += 1;
  }

  return {
    summary,
    target,
    cheapest,
    delta_vs_last: { up, down, flat }
  };
}

async function updateOverlayHtmlRows(rows, generatedAtIso) {
  const html = await fs.readFile(OVERLAY_HTML, 'utf8');
  const rowsLiteral = JSON.stringify(rows);
  const safeGeneratedAt = String(generatedAtIso || '').replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  let replaced = html.replace(
    /const rows = \[[\s\S]*?\];\n\n\s+const generatedAtIso = '.*?';\n\s+const targetDate = '2026-03-12';/,
    `const rows = ${rowsLiteral};\n\n    const generatedAtIso = '${safeGeneratedAt}';\n    const targetDate = '2026-03-12';`
  );
  if (replaced === html) {
    replaced = html.replace(
      /const rows = \[[\s\S]*?\];\n\n\s+const targetDate = '2026-03-12';/,
      `const rows = ${rowsLiteral};\n\n    const generatedAtIso = '${safeGeneratedAt}';\n    const targetDate = '2026-03-12';`
    );
  }
  await fs.writeFile(OVERLAY_HTML, replaced, 'utf8');
}

async function run() {
  const existing = await readJson(LATEST_JSON);
  const historyStore = await readJson(HISTORY_JSON);
  const firstPriceMap = buildHistoryFirstPriceMap(historyStore);
  const prevRows = Array.isArray(existing?.rows) ? existing.rows : [];
  const queryRange = resolveQueryRange();
  const departures = buildDateRange(queryRange.start_date, queryRange.end_date);
  const freshRows = [];

  for (const dep of departures) {
    if (MAX_ROWS > 0 && freshRows.length >= MAX_ROWS) break;
    const ret = addDays(dep, STAY_DAYS);
    const row = await queryPairWithRetries(dep, ret);

    freshRows.push(row);
    console.log(
      `${dep} -> ${ret} : ${row.status}${Number.isFinite(row.top_min_usd) ? ` $${row.top_min_usd}` : ''}`
    );

    await wait(REQUEST_DELAY_MS);
  }

  const mergedRows = mergeWithPrevious(prevRows, freshRows, firstPriceMap);
  const ext = buildSummary(mergedRows);
  const failedRows = freshRows.filter((r) => r.status !== 'ok');
  const failRatio = departures.length > 0 ? failedRows.length / departures.length : 0;
  if (failRatio >= ROUND_FAIL_RATIO_WARNING) {
    console.warn(
      `High failure ratio this round: ${failedRows.length}/${departures.length} (${Math.round(
        failRatio * 100
      )}%). This may indicate transient blocking or rate limiting.`
    );
  }

  const out = {
    rows: mergedRows,
    summary: ext.summary,
    target: ext.target,
    cheapest: ext.cheapest,
    delta_vs_last: ext.delta_vs_last,
    query_window: {
      mode: queryRange.mode,
      timezone: QUERY_TIMEZONE,
      today_iso: queryRange.today_iso,
      start_date: queryRange.start_date,
      end_date: queryRange.end_date,
      window_days: WINDOW_DAYS
    },
    generated_at: new Date().toISOString(),
    source: 'http-rpc'
  };

  await fs.writeFile(LATEST_JSON, `${JSON.stringify(out, null, 2)}\n`, 'utf8');
  await fs.writeFile(LATEST_CSV, toCsv(mergedRows), 'utf8');
  await updateOverlayHtmlRows(mergedRows, out.generated_at);

  const { spawn } = await import('node:child_process');
  await new Promise((resolve, reject) => {
    const child = spawn('node', [HISTORY_UPDATER], {
      cwd: ROOT,
      stdio: 'inherit'
    });
    child.on('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`update_flight_watch_history.mjs failed with code ${code}`));
    });
    child.on('error', reject);
  });

  console.log(`Wrote ${LATEST_JSON}`);
  console.log(`Wrote ${LATEST_CSV}`);
  console.log(`Updated ${OVERLAY_HTML}`);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
