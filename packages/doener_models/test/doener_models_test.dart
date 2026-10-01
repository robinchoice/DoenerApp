import 'package:doener_models/doener_models.dart';
import 'package:test/test.dart';

VisitDto _visit(String placeId, DateTime at) => VisitDto(
      id: '$placeId-${at.microsecondsSinceEpoch}',
      userId: 'u',
      userName: 'U',
      placeId: placeId,
      placeName: placeId,
      visitedAt: at,
    );

void main() {
  group('StampTier', () {
    test('picks highest reached tier', () {
      expect(StampTier.forStamps(0), StampTier.doenerneuling);
      expect(StampTier.forStamps(4), StampTier.doenerneuling);
      expect(StampTier.forStamps(5), StampTier.doenerfreund);
      expect(StampTier.forStamps(99), StampTier.doenermeister);
      expect(StampTier.forStamps(500), StampTier.doenerlegende);
      expect(StampTier.doenerlegende.nextTier, isNull);
    });
  });

  group('ProfileStats', () {
    test('counts places, cities and achievements', () {
      final base = DateTime(2026, 5, 1, 12);
      final visits = [
        for (var i = 0; i < 5; i++) _visit('a', base.add(Duration(days: i))),
        for (var i = 0; i < 4; i++) _visit('berlin$i', base),
        _visit('berlin4', DateTime(2026, 5, 2, 23)),
      ];
      final stats = ProfileStats.compute(
        visits: visits,
        reviewCount: 1,
        cityOf: (id) => id.startsWith('berlin') ? 'Berlin' : 'Freiburg',
      );
      expect(stats.totalVisits, 10);
      expect(stats.uniquePlaces, 6);
      expect(stats.maxVisitsToSamePlace, 5);
      expect(stats.uniquePlacesByCity, {'Freiburg': 1, 'Berlin': 5});
      expect(stats.stampTier, StampTier.doenerfreund);
      expect(stats.stampsToNextTier, 5);
      expect(stats.stampProgress, closeTo(0.5, 1e-9));
      expect(
        stats.unlockedAchievements(friendsCount: 5),
        {
          AchievementType.firstBite,
          AchievementType.critic,
          AchievementType.regular,
          AchievementType.berlinTour,
          AchievementType.nightOwl,
          AchievementType.socialButterfly,
        },
      );
    });

    test('empty stats unlock nothing', () {
      const stats = ProfileStats();
      expect(stats.unlockedAchievements(friendsCount: 0), isEmpty);
      expect(stats.stampProgress, 0);
    });
  });

  group('Validation', () {
    test('email', () {
      expect(Validation.isValidEmail(' Robin@Example.org '), isTrue);
      expect(Validation.normalizeEmail(' Robin@Example.org '), 'robin@example.org');
      expect(Validation.isValidEmail('no-at-sign'), isFalse);
      expect(Validation.isValidEmail('a@b'), isFalse);
    });

    test('display name and ratings', () {
      expect(Validation.displayNameError(' R '), isNotNull);
      expect(Validation.displayNameError('Robin'), isNull);
      expect(Validation.isGeneratedName(' Döner-Fan-4821 '), isTrue);
      expect(Validation.isGeneratedName('Döner-Fan-Robin'), isFalse);
      expect(Validation.displayNameError('Döner-Fan-4821'), isNotNull, reason: 'the placeholder is not a chosen name');
      expect(Validation.isValidRating(null), isTrue);
      expect(Validation.isValidRating(0), isFalse);
      expect(Validation.isValidRating(5), isTrue);
      expect(Validation.clean('  '), isNull);
    });
  });

  test('DTO JSON roundtrip', () {
    final item = FeedItem(
      id: '1',
      type: FeedItemType.review,
      user: const UserDto(id: 'u', displayName: 'Robin'),
      place: const PlaceDto(placeId: 'p', name: 'Laden', latitude: 48, longitude: 7.8, avgRating: 4),
      timestamp: DateTime.utc(2026, 9, 1, 12, 0, 0, 123, 456),
      rating: 5,
    );
    final page = FeedPage.fromJson(FeedPage(items: [item], cursor: 'c', hasMore: true).toJson());
    expect(page.items.single.timestamp, item.timestamp);
    expect(page.items.single.place.avgRating, 4.0);
    expect(page.items.single.type, FeedItemType.review);
  });
}
