/*
- reportIntelligence — pure scoring logic behind the report feed's AI
  capabilities: semantic duplicate detection and priority ranking.
- Kept free of I/O and framework imports so every branch is unit-testable
  in isolation (same approach as audienceResolver). The controller is the
  only adapter that feeds it real documents.
- Duplicate scoring fuses three signals — text similarity (TF cosine on
  normalized Arabic/English tokens), geographic proximity (exponential
  decay over distance), and category agreement. No external embedding or
  vector store: the civic vocabulary is small, so a token-based model
  stays cheap, offline, and deterministic.
- Priority scoring is a lightweight rule classifier: a per-category
  baseline inflated by an urgency lexicon, clamped to [0, 1].
 */
const LOCAL_WEIGHT = { text: 0.55, location: 0.3, category: 0.15 };
const DUPLICATE_THRESHOLD = 0.45;

// Proximity decay constant (meters). At this distance a location match
// contributes ~37% of its full weight; beyond a few blocks it fades fast.
const LOCATION_DECAY_M = 500;
const DEFAULT_MAX_DUPLICATES = 20;

const CATEGORY_PRIORITY_BASELINE = {
  pothole: 0.5,
  lighting: 0.4,
  waste: 0.35,
  other: 0.25,
};

// Urgency lexicon: (English, transliterated) terms with a severity boost.
// English terms are matched lower-cased; Arabic terms after normalization.
const URGENCY_SIGNALS = [
  { terms: ['danger', 'خطر'], boost: 0.2 },
  { terms: ['accident', 'حادث', 'اصطدام'], boost: 0.25 },
  { terms: ['fire', 'حريق'], boost: 0.3 },
  { terms: ['emergency', 'طوارئ'], boost: 0.3 },
  { terms: ['collaps', 'انهيار', 'انهار', 'سقف'], boost: 0.25 },
  { terms: ['fell', 'سقط'], boost: 0.2 },
  { terms: ['child', 'طفل', 'اطفال', 'أطفال'], boost: 0.2 },
  { terms: ['school', 'مدرسة'], boost: 0.15 },
  { terms: ['hospital', 'مستشفى'], boost: 0.2 },
  { terms: ['electric', 'كهرباء', 'wire', 'أسلاك', 'تماس'], boost: 0.25 },
  { terms: ['manhole', 'فتحة', 'مفتوح'], boost: 0.15 },
  { terms: ['water', 'مياه', 'تسرب', 'ماء'], boost: 0.15 },
  { terms: ['blocked', 'blocking', 'معطل', 'سد'], boost: 0.1 },
  { terms: ['dark', 'ظلام', 'معتم', 'إنارة', 'streetlight'], boost: 0.1 },
];

const ENGLISH_STOPWORDS = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'of', 'in', 'on', 'at', 'to',
  'for', 'with', 'from', 'by', 'is', 'are', 'was', 'be', 'have', 'has',
  'it', 'this', 'that', 'there', 'here', 'my', 'our', 'your', 'near',
  'very', 'big', 'small', 'some', 'any', 'not', 'no',
]);

const ARABIC_STOPWORDS = new Set([
  'في', 'على', 'من', 'عن', 'الى', 'إلى', 'ان', 'أن', 'هذا', 'هذه',
  'هناك', 'عند', 'قبل', 'بعد', 'مع', 'لم', 'له', 'لها', 'فقط', 'كل',
  'جميع', 'ما', 'هو', 'هي', 'او', 'أو', 'و', 'ثم', 'بين', 'حتى',
  'غير', 'كان', 'كون',
]);

// Unify Arabic letter variants and strip short-vowel marks so the same
// word written with different diacritics or alef forms matches in the
// same token bucket ('السّلام' -> 'السلام' -> 'السلام').
function normalizeArabic(text) {
  return text
    .replace(/[\u064B-\u0652\u0640]/g, '') // tashkeel + tatweel
    .replace(/[\u0623\u0625\u0671]/g, '\u0627') // أ إ ٱ -> ا
    .replace(/\u0622/g, '\u0627') // آ -> ا
    .replace(/\u0649/g, '\u064A') // ى -> ي
    .replace(/\u0629/g, '\u0647'); // ة -> ه
}

function tokenize(text) {
  if (!text) return [];
  const normalized = normalizeArabic(String(text).toLowerCase());
  const tokens = normalized.split(/[^0-9\u0600-\u06FFa-z]+/i).filter(Boolean);
  return tokens.filter(
    (t) => t.length > 1 && !ENGLISH_STOPWORDS.has(t) && !ARABIC_STOPWORDS.has(t)
  );
}

function termCounts(tokens) {
  const counts = new Map();
  for (const t of tokens) counts.set(t, (counts.get(t) || 0) + 1);
  return counts;
}

// Cosine similarity over term-frequency vectors. Returns 0 when either
// side has no terms; identical text approaches 1.
function cosineSimilarity(aTokens, bTokens) {
  if (aTokens.length === 0 || bTokens.length === 0) return 0;
  const a = termCounts(aTokens);
  const b = termCounts(bTokens);
  let dot = 0;
  let aNorm = 0;
  let bNorm = 0;
  for (const [term, count] of a) {
    dot += count * (b.get(term) || 0);
    aNorm += count * count;
  }
  for (const [, count] of b) bNorm += count * count;
  const denom = Math.sqrt(aNorm) * Math.sqrt(bNorm);
  return denom === 0 ? 0 : dot / denom;
}

function combinedText(report) {
  return [report.title, report.description].filter(Boolean).join(' ');
}

function scoreTextSimilarity(aText, bText) {
  return cosineSimilarity(tokenize(aText), tokenize(bText));
}

// Exponential proximity decay: 0m -> 1, fades to ~14% at 1km.
function scoreLocationSimilarity(distanceMeters) {
  if (!Number.isFinite(distanceMeters)) return 0;
  return Math.exp(-distanceMeters / LOCATION_DECAY_M);
}

function scoreCategoryAgreement(aCategory, bCategory) {
  return aCategory && aCategory === bCategory ? 1 : 0;
}

// Great-circle distance between two GeoJSON points ({ coordinates: [lng, lat] }).
// Returns Infinity for malformed points so they never count as close.
function haversineMeters(a, b) {
  const [aLng, aLat] = a.coordinates || [];
  const [bLng, bLat] = b.coordinates || [];
  if (![aLng, aLat, bLng, bLat].every(Number.isFinite)) return Infinity;
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const s =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * R * Math.asin(Math.sqrt(s));
}

function duplicateSignals(existing, candidate, { distanceMeters }) {
  return {
    text: scoreTextSimilarity(combinedText(existing), combinedText(candidate)),
    location: scoreLocationSimilarity(distanceMeters),
    category: scoreCategoryAgreement(existing.category, candidate.category),
  };
}

// Weighted duplicate score between an existing report and a candidate,
// in [0, 1]. Weight constants are exported so tests can lock the fusion.
function scoreDuplicate(existing, candidate, { distanceMeters }) {
  const signals = duplicateSignals(existing, candidate, { distanceMeters });
  return (
    signals.text * LOCAL_WEIGHT.text +
    signals.location * LOCAL_WEIGHT.location +
    signals.category * LOCAL_WEIGHT.category
  );
}

// Rank a set of nearby candidate reports against a single candidate,
// keeping only matches at or above DUPLICATE_THRESHOLD, most-similar first.
function rankDuplicates(candidates, candidate, { maxResults = DEFAULT_MAX_DUPLICATES } = {}) {
  const scored = [];
  for (const existing of candidates) {
    const distanceMeters = haversineMeters(existing.location, candidate.location);
    const similarity = scoreDuplicate(existing, candidate, { distanceMeters });
    if (similarity >= DUPLICATE_THRESHOLD) {
      scored.push({
        report: existing,
        similarity,
        distanceMeters: Math.round(distanceMeters),
        signals: duplicateSignals(existing, candidate, { distanceMeters }),
      });
    }
  }
  scored.sort((a, b) => b.similarity - a.similarity || a.distanceMeters - b.distanceMeters);
  return scored.slice(0, maxResults);
}

// Priority classifier: per-category baseline plus urgency-lexicon boosts,
// clamped to [0, 1]. `signals` names the matched terms so an admin UI can
// explain *why* a report was flagged.
function scorePriority({ category, title, description }) {
  const text = normalizeArabic(
    [title, description].filter(Boolean).join(' ').toLowerCase()
  );
  const baseline =
    CATEGORY_PRIORITY_BASELINE[category] ?? CATEGORY_PRIORITY_BASELINE.other;
  let priority = baseline;
  const signals = [];
  for (const { terms, boost } of URGENCY_SIGNALS) {
    const hit = terms.find((t) => text.includes(normalizeArabic(t).toLowerCase()));
    if (hit) {
      priority += boost;
      signals.push(hit);
    }
  }
  return { priority: Math.min(1, Math.max(0, priority)), signals };
}

module.exports = {
  tokenize,
  normalizeArabic,
  cosineSimilarity,
  scoreTextSimilarity,
  scoreLocationSimilarity,
  scoreCategoryAgreement,
  haversineMeters,
  duplicateSignals,
  scoreDuplicate,
  rankDuplicates,
  scorePriority,
  DUPLICATE_THRESHOLD,
  LOCAL_WEIGHT,
};