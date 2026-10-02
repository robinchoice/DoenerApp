import 'ranking.dart';

typedef Json = Map<String, dynamic>;

DateTime _date(Object? v) => DateTime.parse(v as String);
double? _doubleOrNull(Object? v) => (v as num?)?.toDouble();

// MARK: - Auth

class LoginRequest {
  final String email;
  const LoginRequest({required this.email});

  factory LoginRequest.fromJson(Json j) => LoginRequest(email: j['email'] as String);
  Json toJson() => {'email': email};
}

/// Either [email] + [code] (typed in by the user) or [token] (from the
/// magic link) must be set. [inviteCode] remembers whose invite link brought
/// a new account in.
class VerifyRequest {
  final String? email;
  final String? code;
  final String? token;
  final String? inviteCode;
  const VerifyRequest({this.email, this.code, this.token, this.inviteCode});

  factory VerifyRequest.fromJson(Json j) => VerifyRequest(
        email: j['email'] as String?,
        code: j['code'] as String?,
        token: j['token'] as String?,
        inviteCode: j['inviteCode'] as String?,
      );
  Json toJson() => {'email': email, 'code': code, 'token': token, 'inviteCode': inviteCode};
}

class AuthResponse {
  final String token;
  final UserDto user;
  final bool isNewUser;
  const AuthResponse({required this.token, required this.user, required this.isNewUser});

  factory AuthResponse.fromJson(Json j) => AuthResponse(
        token: j['token'] as String,
        user: UserDto.fromJson(j['user'] as Json),
        isNewUser: j['isNewUser'] as bool,
      );
  Json toJson() => {'token': token, 'user': user.toJson(), 'isNewUser': isNewUser};
}

class UpdateMeRequest {
  final String displayName;
  const UpdateMeRequest({required this.displayName});

  factory UpdateMeRequest.fromJson(Json j) => UpdateMeRequest(displayName: j['displayName'] as String);
  Json toJson() => {'displayName': displayName};
}

// MARK: - User

class UserDto {
  final String id;
  final String displayName;
  const UserDto({required this.id, required this.displayName});

  factory UserDto.fromJson(Json j) => UserDto(id: j['id'] as String, displayName: j['displayName'] as String);
  Json toJson() => {'id': id, 'displayName': displayName};

  @override
  bool operator ==(Object other) => other is UserDto && other.id == id && other.displayName == displayName;
  @override
  int get hashCode => Object.hash(id, displayName);
}

// MARK: - Place

/// [placeId] is the Google Place ID — the only place identifier clients see.
class PlaceDto {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? postalCode;
  final String? city;
  final String? openingHours;
  final double? avgRating;
  final int reviewCount;
  final String? specialNote;

  const PlaceDto({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.postalCode,
    this.city,
    this.openingHours,
    this.avgRating,
    this.reviewCount = 0,
    this.specialNote,
  });

  factory PlaceDto.fromJson(Json j) => PlaceDto(
        placeId: j['placeId'] as String,
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        address: j['address'] as String?,
        postalCode: j['postalCode'] as String?,
        city: j['city'] as String?,
        openingHours: j['openingHours'] as String?,
        avgRating: _doubleOrNull(j['avgRating']),
        reviewCount: j['reviewCount'] as int? ?? 0,
        specialNote: j['specialNote'] as String?,
      );

  Json toJson() => {
        'placeId': placeId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'postalCode': postalCode,
        'city': city,
        'openingHours': openingHours,
        'avgRating': avgRating,
        'reviewCount': reviewCount,
        'specialNote': specialNote,
      };
}

class PlaceSummaryDto {
  final int reviewCount;
  final double? avgRating;
  final double? avgSauceRating;
  final double? avgFleischRating;
  final double? avgBrotRating;
  final String? topDimension;
  final String summaryText;

  const PlaceSummaryDto({
    required this.reviewCount,
    this.avgRating,
    this.avgSauceRating,
    this.avgFleischRating,
    this.avgBrotRating,
    this.topDimension,
    required this.summaryText,
  });

  factory PlaceSummaryDto.fromJson(Json j) => PlaceSummaryDto(
        reviewCount: j['reviewCount'] as int,
        avgRating: _doubleOrNull(j['avgRating']),
        avgSauceRating: _doubleOrNull(j['avgSauceRating']),
        avgFleischRating: _doubleOrNull(j['avgFleischRating']),
        avgBrotRating: _doubleOrNull(j['avgBrotRating']),
        topDimension: j['topDimension'] as String?,
        summaryText: j['summaryText'] as String,
      );

  Json toJson() => {
        'reviewCount': reviewCount,
        'avgRating': avgRating,
        'avgSauceRating': avgSauceRating,
        'avgFleischRating': avgFleischRating,
        'avgBrotRating': avgBrotRating,
        'topDimension': topDimension,
        'summaryText': summaryText,
      };
}

// MARK: - Review

class ReviewDto {
  final String id;
  final String userId;
  final String userName;
  final String placeId;
  final String placeName;
  final int rating;
  final int? sauceRating;
  final int? fleischRating;
  final int? brotRating;
  final String? text;
  final String? specialNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReviewDto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.placeId,
    required this.placeName,
    required this.rating,
    this.sauceRating,
    this.fleischRating,
    this.brotRating,
    this.text,
    this.specialNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReviewDto.fromJson(Json j) => ReviewDto(
        id: j['id'] as String,
        userId: j['userId'] as String,
        userName: j['userName'] as String,
        placeId: j['placeId'] as String,
        placeName: j['placeName'] as String,
        rating: j['rating'] as int,
        sauceRating: j['sauceRating'] as int?,
        fleischRating: j['fleischRating'] as int?,
        brotRating: j['brotRating'] as int?,
        text: j['text'] as String?,
        specialNote: j['specialNote'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
      );

  Json toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'placeId': placeId,
        'placeName': placeName,
        'rating': rating,
        'sauceRating': sauceRating,
        'fleischRating': fleischRating,
        'brotRating': brotRating,
        'text': text,
        'specialNote': specialNote,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// One review per user and place — PUT replaces the previous one.
class UpsertReviewRequest {
  final int rating;
  final int? sauceRating;
  final int? fleischRating;
  final int? brotRating;
  final String? text;
  final String? specialNote;

  const UpsertReviewRequest({
    required this.rating,
    this.sauceRating,
    this.fleischRating,
    this.brotRating,
    this.text,
    this.specialNote,
  });

  factory UpsertReviewRequest.fromJson(Json j) => UpsertReviewRequest(
        rating: j['rating'] as int,
        sauceRating: j['sauceRating'] as int?,
        fleischRating: j['fleischRating'] as int?,
        brotRating: j['brotRating'] as int?,
        text: j['text'] as String?,
        specialNote: j['specialNote'] as String?,
      );

  Json toJson() => {
        'rating': rating,
        'sauceRating': sauceRating,
        'fleischRating': fleischRating,
        'brotRating': brotRating,
        'text': text,
        'specialNote': specialNote,
      };
}

// MARK: - Visit

class VisitDto {
  final String id;
  final String userId;
  final String userName;
  final String placeId;
  final String placeName;
  final DateTime visitedAt;
  final String? foodType;

  const VisitDto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.placeId,
    required this.placeName,
    required this.visitedAt,
    this.foodType,
  });

  factory VisitDto.fromJson(Json j) => VisitDto(
        id: j['id'] as String,
        userId: j['userId'] as String,
        userName: j['userName'] as String,
        placeId: j['placeId'] as String,
        placeName: j['placeName'] as String,
        visitedAt: _date(j['visitedAt']),
        foodType: j['foodType'] as String?,
      );

  Json toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'placeId': placeId,
        'placeName': placeName,
        'visitedAt': visitedAt.toUtc().toIso8601String(),
        'foodType': foodType,
      };
}

/// [id] is generated on the client so offline retries are idempotent.
class CreateVisitRequest {
  final String id;
  final DateTime visitedAt;
  final String? foodType;

  const CreateVisitRequest({required this.id, required this.visitedAt, this.foodType});

  factory CreateVisitRequest.fromJson(Json j) => CreateVisitRequest(
        id: j['id'] as String,
        visitedAt: _date(j['visitedAt']),
        foodType: j['foodType'] as String?,
      );

  Json toJson() => {
        'id': id,
        'visitedAt': visitedAt.toUtc().toIso8601String(),
        'foodType': foodType,
      };
}

// MARK: - Feed

enum FeedItemType { visit, review }

/// Check-ins come from friends only; reviews from friends and from everyone
/// around — [fromFriend] tells them apart.
class FeedItem {
  final String id;
  final FeedItemType type;
  final UserDto user;
  final PlaceDto place;
  final DateTime timestamp;
  final bool fromFriend;
  final int? rating;
  final String? text;
  final String? foodType;

  const FeedItem({
    required this.id,
    required this.type,
    required this.user,
    required this.place,
    required this.timestamp,
    required this.fromFriend,
    this.rating,
    this.text,
    this.foodType,
  });

  factory FeedItem.fromJson(Json j) => FeedItem(
        id: j['id'] as String,
        type: FeedItemType.values.byName(j['type'] as String),
        user: UserDto.fromJson(j['user'] as Json),
        place: PlaceDto.fromJson(j['place'] as Json),
        timestamp: _date(j['timestamp']),
        fromFriend: j['fromFriend'] as bool,
        rating: j['rating'] as int?,
        text: j['text'] as String?,
        foodType: j['foodType'] as String?,
      );

  Json toJson() => {
        'id': id,
        'type': type.name,
        'user': user.toJson(),
        'place': place.toJson(),
        'timestamp': timestamp.toUtc().toIso8601String(),
        'fromFriend': fromFriend,
        'rating': rating,
        'text': text,
        'foodType': foodType,
      };
}

class FeedPage {
  final List<FeedItem> items;
  final String? cursor;
  final bool hasMore;

  const FeedPage({required this.items, this.cursor, required this.hasMore});

  factory FeedPage.fromJson(Json j) => FeedPage(
        items: (j['items'] as List).map((e) => FeedItem.fromJson(e as Json)).toList(),
        cursor: j['cursor'] as String?,
        hasMore: j['hasMore'] as bool,
      );

  Json toJson() => {'items': items.map((e) => e.toJson()).toList(), 'cursor': cursor, 'hasMore': hasMore};
}

class LiveStatusDto {
  final UserDto user;
  final String placeId;
  final String placeName;
  final String? foodType;
  final DateTime until;

  const LiveStatusDto({
    required this.user,
    required this.placeId,
    required this.placeName,
    this.foodType,
    required this.until,
  });

  factory LiveStatusDto.fromJson(Json j) => LiveStatusDto(
        user: UserDto.fromJson(j['user'] as Json),
        placeId: j['placeId'] as String,
        placeName: j['placeName'] as String,
        foodType: j['foodType'] as String?,
        until: _date(j['until']),
      );

  Json toJson() => {
        'user': user.toJson(),
        'placeId': placeId,
        'placeName': placeName,
        'foodType': foodType,
        'until': until.toUtc().toIso8601String(),
      };
}

// MARK: - Ranking

/// A friend's rating of a ranked place, in the ranked dimension.
class FriendRatingDto {
  final UserDto user;
  final int rating;
  const FriendRatingDto({required this.user, required this.rating});

  factory FriendRatingDto.fromJson(Json j) =>
      FriendRatingDto(user: UserDto.fromJson(j['user'] as Json), rating: j['rating'] as int);
  Json toJson() => {'user': user.toJson(), 'rating': rating};
}

/// [average] and [count] are the real numbers; the order comes from [weightedRating].
class RankingEntryDto {
  final PlaceDto place;
  final double average;
  final int count;
  final List<FriendRatingDto> friends;

  const RankingEntryDto({required this.place, required this.average, required this.count, this.friends = const []});

  factory RankingEntryDto.fromJson(Json j) => RankingEntryDto(
        place: PlaceDto.fromJson(j['place'] as Json),
        average: (j['average'] as num).toDouble(),
        count: j['count'] as int,
        friends: (j['friends'] as List).map((e) => FriendRatingDto.fromJson(e as Json)).toList(),
      );

  Json toJson() => {
        'place': place.toJson(),
        'average': average,
        'count': count,
        'friends': friends.map((e) => e.toJson()).toList(),
      };
}

/// Places of one [city] (as in their address), best first. [city] is null
/// when no place near the requested position is known.
class RankingDto {
  final String? city;
  final RatingDimension by;
  final List<RankingEntryDto> entries;

  const RankingDto({this.city, required this.by, required this.entries});

  factory RankingDto.fromJson(Json j) => RankingDto(
        city: j['city'] as String?,
        by: RatingDimension.values.byName(j['by'] as String),
        entries: (j['entries'] as List).map((e) => RankingEntryDto.fromJson(e as Json)).toList(),
      );

  Json toJson() => {'city': city, 'by': by.name, 'entries': entries.map((e) => e.toJson()).toList()};
}

// MARK: - Friends

enum FriendshipStatus { pending, accepted }

enum FriendshipDirection { incoming, outgoing }

class FriendshipDto {
  final String id;
  final UserDto user;
  final FriendshipStatus status;
  final FriendshipDirection direction;
  final DateTime createdAt;

  const FriendshipDto({
    required this.id,
    required this.user,
    required this.status,
    required this.direction,
    required this.createdAt,
  });

  factory FriendshipDto.fromJson(Json j) => FriendshipDto(
        id: j['id'] as String,
        user: UserDto.fromJson(j['user'] as Json),
        status: FriendshipStatus.values.byName(j['status'] as String),
        direction: FriendshipDirection.values.byName(j['direction'] as String),
        createdAt: _date(j['createdAt']),
      );

  Json toJson() => {
        'id': id,
        'user': user.toJson(),
        'status': status.name,
        'direction': direction.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

class FriendRequestBody {
  final String userId;
  const FriendRequestBody({required this.userId});

  factory FriendRequestBody.fromJson(Json j) => FriendRequestBody(userId: j['userId'] as String);
  Json toJson() => {'userId': userId};
}

/// Personal invite link — whoever opens it and signs in becomes a friend.
class InviteDto {
  final String code;
  final String url;
  const InviteDto({required this.code, required this.url});

  factory InviteDto.fromJson(Json j) => InviteDto(code: j['code'] as String, url: j['url'] as String);
  Json toJson() => {'code': code, 'url': url};
}

// MARK: - Feedback & shop reports

class FeedbackRequest {
  final String message;
  final String? screenshotBase64;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;

  const FeedbackRequest({
    required this.message,
    this.screenshotBase64,
    this.appVersion,
    this.buildNumber,
    this.platform,
  });

  factory FeedbackRequest.fromJson(Json j) => FeedbackRequest(
        message: j['message'] as String,
        screenshotBase64: j['screenshotBase64'] as String?,
        appVersion: j['appVersion'] as String?,
        buildNumber: j['buildNumber'] as String?,
        platform: j['platform'] as String?,
      );

  Json toJson() => {
        'message': message,
        'screenshotBase64': screenshotBase64,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'platform': platform,
      };
}

class ShopReportRequest {
  final String name;
  final String? hint;
  final double? latitude;
  final double? longitude;
  final String? note;

  const ShopReportRequest({required this.name, this.hint, this.latitude, this.longitude, this.note});

  factory ShopReportRequest.fromJson(Json j) => ShopReportRequest(
        name: j['name'] as String,
        hint: j['hint'] as String?,
        latitude: _doubleOrNull(j['latitude']),
        longitude: _doubleOrNull(j['longitude']),
        note: j['note'] as String?,
      );

  Json toJson() => {'name': name, 'hint': hint, 'latitude': latitude, 'longitude': longitude, 'note': note};
}
