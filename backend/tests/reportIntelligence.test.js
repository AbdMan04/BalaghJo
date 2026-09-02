const R = require('../src/services/reportIntelligence');

describe('reportIntelligence', () => {
  describe('tokenize / Arabic normalization', () => {
    test('lowercases English and drops stopwords', () => {
      expect(R.tokenize('A large Pothole in the main street')).toEqual([
        'large',
        'pothole',
        'main',
        'street',
      ]);
    });

    test('unifies Arabic alef/ya/y marbuta variants', () => {
      const tokens = R.tokenize('إصلاح شارع آمن رياضة');
      expect(tokens).toContain('اصلاح');
      expect(tokens).toContain('شارع');
      // آ -> ا, ى -> ي, ة -> ه via normalizeArabic
      expect(tokens).toContain('امن');
      expect(tokens).toContain('رياضه');
    });
  });

  describe('cosine similarity', () => {
    test('is ~1.0 for identical token sets', () => {
      expect(R.cosineSimilarity(['a', 'b'], ['b', 'a'])).toBeCloseTo(1, 10);
    });

    test('is 0 when either side has no terms', () => {
      expect(R.cosineSimilarity([], ['a'])).toBe(0);
      expect(R.cosineSimilarity(['a'], [])).toBe(0);
    });
  });

  describe('haversine distance', () => {
    test('returns ~0 for identical points', () => {
      expect(R.haversineMeters(
        { coordinates: [35.85, 32.55] },
        { coordinates: [35.85, 32.55] }
      )).toBeLessThan(1);
    });

    test('returns Infinity for malformed points', () => {
      expect(R.haversineMeters({ coordinates: [null, 32] }, { coordinates: [35, 32] })).toBe(Infinity);
    });
  });

  describe('location similarity', () => {
    test('is 1 at 0m and decays', () => {
      expect(R.scoreLocationSimilarity(0)).toBe(1);
      expect(R.scoreLocationSimilarity(500)).toBeCloseTo(Math.exp(-1), 5);
      expect(R.scoreLocationSimilarity(5000)).toBeLessThan(0.001);
    });

    test('is 0 for a non-finite distance', () => {
      expect(R.scoreLocationSimilarity(NaN)).toBe(0);
      expect(R.scoreLocationSimilarity(Infinity)).toBe(0);
    });
  });

  describe('scoreDuplicate fusion', () => {
    const mk = (over = {}) => ({
      category: 'pothole',
      title: '',
      description: 'Deep pothole near the school gate',
      location: { coordinates: [35.85, 32.55] },
      ...over,
    });

    test('weights text + location + category agreement', () => {
      const existing = mk();
      const sameText = mk({ location: { coordinates: [35.8505, 32.5505] } }); // ~60m away, same text/category
      const { text, location, category } = R.duplicateSignals(existing, sameText, {
        distanceMeters: R.haversineMeters(existing.location, sameText.location),
      });
      expect(text).toBeCloseTo(1, 5);
      expect(category).toBe(1);
      expect(location).toBeGreaterThan(0.8);
    });

    test('weighs category agreement without blocking cross-category matches', () => {
      const existing = mk();
      // Same text, same spot, but a differently-labeled category: identical
      // wording still ranks as a duplicate (that is the semantic upgrade),
      // just lower than if the category agreed too.
      const otherCategory = mk({ category: 'lighting' });
      const d = R.haversineMeters(existing.location, otherCategory.location);
      const different = R.scoreDuplicate(existing, otherCategory, { distanceMeters: d });
      const same = R.scoreDuplicate(existing, mk(), { distanceMeters: d });
      expect(different).toBeGreaterThanOrEqual(R.DUPLICATE_THRESHOLD);
      expect(different).toBeLessThan(same);
    });
  });

  describe('rankDuplicates', () => {
    test('ranks most-similar first and filters below threshold', () => {
      const candidate = {
        category: 'pothole',
        title: '',
        description: 'Hole in the asphalt near the university',
        location: { coordinates: [35.85, 32.55] },
      };
      const sameSpot = {
        category: 'pothole',
        title: '',
        description: 'Hole in the asphalt near the university',
        location: { coordinates: [35.8502, 32.5502] },
      };
      const farAwayOther = {
        category: 'waste',
        title: '',
        description: 'Trash bins overflowing in the old market',
        location: { coordinates: [35.86, 32.556] },
      };
      const ranked = R.rankDuplicates([farAwayOther, sameSpot], candidate);
      expect(ranked[0].report).toBe(sameSpot);
      expect(ranked).toHaveLength(1);
      expect(ranked[0].distanceMeters).toBeGreaterThan(0);
    });
  });

  describe('scorePriority', () => {
    test('uses a per-category baseline', () => {
      expect(R.scorePriority({ category: 'pothole', description: 'broken road' }).priority)
        .toBe(0.5);
      expect(R.scorePriority({ category: 'waste', description: 'litter' }).priority)
        .toBe(0.35);
    });

    test('boosts on an English urgency term and clamps at 1', () => {
      const { priority, signals } = R.scorePriority({
        category: 'waste',
        description: 'FIRE danger electric wire near a school for children',
      });
      expect(priority).toBe(1); // 0.35 + fire + danger + electric + school + child, clamped
      expect(signals).toEqual(expect.arrayContaining(['fire', 'electric']));
    });

    test('boosts on an Arabic urgency term', () => {
      const { priority, signals } = R.scorePriority({
        category: 'other',
        description: 'حادث سير امام المدرسة',
      });
      expect(priority).toBeGreaterThan(0.25); // baseline + accident + school
      expect(signals).toEqual(expect.arrayContaining(['حادث', 'مدرسة']));
    });

    test('never exceeds the [0, 1] range', () => {
      for (const c of ['pothole', 'waste', 'lighting', 'other']) {
        const { priority } = R.scorePriority({
          category: c,
          description: 'danger fire emergency child accident collapse electric water',
        });
        expect(priority).toBeGreaterThanOrEqual(0);
        expect(priority).toBeLessThanOrEqual(1);
      }
    });

    test('no urgency text stays at the baseline', () => {
      const { priority, signals } = R.scorePriority({
        category: 'pothole',
        description: 'there is a bump',
      });
      expect(priority).toBe(0.5);
      expect(signals).toHaveLength(0);
    });
  });
});