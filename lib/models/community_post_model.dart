import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityPostType { lostFound, teamSearch }

class CommunityPostModel {
  const CommunityPostModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.type,
    required this.title,
    required this.body,
    required this.governorate,
    required this.status,
    required this.createdAt,
    this.fieldId,
    this.fieldName,
    this.imageUrl,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final CommunityPostType type;
  final String title;
  final String body;
  final String governorate;
  final String status;
  final DateTime createdAt;
  final String? fieldId;
  final String? fieldName;
  final String? imageUrl;

  factory CommunityPostModel.fromMap(String id, Map<String, dynamic> map) {
    final type = switch (map['type']) {
      'lost_found' => CommunityPostType.lostFound,
      'team_search' => CommunityPostType.teamSearch,
      _ => throw const FormatException('نوع منشور المجتمع غير معروف.'),
    };
    final createdAt = map['createdAt'];
    if (createdAt is! Timestamp) {
      throw const FormatException('تاريخ منشور المجتمع غير صالح.');
    }
    return CommunityPostModel(
      id: id,
      authorUid: map['authorUid'] as String,
      authorName: map['authorName'] as String,
      authorRole: map['authorRole'] as String,
      type: type,
      title: map['title'] as String,
      body: map['body'] as String,
      governorate: map['governorate'] as String,
      status: map['status'] as String,
      createdAt: createdAt.toDate(),
      fieldId: map['fieldId'] as String?,
      fieldName: map['fieldName'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}

class CommunityReplyModel {
  const CommunityReplyModel({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.authorRole,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String authorRole;
  final String body;
  final DateTime createdAt;

  factory CommunityReplyModel.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    if (createdAt is! Timestamp) {
      throw const FormatException('تاريخ الرد غير صالح.');
    }
    return CommunityReplyModel(
      id: id,
      authorUid: map['authorUid'] as String,
      authorName: map['authorName'] as String,
      authorRole: map['authorRole'] as String,
      body: map['body'] as String,
      createdAt: createdAt.toDate(),
    );
  }
}
