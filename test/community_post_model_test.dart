import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/community_post_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a lost and found post with optional field and image', () {
    final createdAt = DateTime(2026, 11, 3, 12);
    final post = CommunityPostModel.fromMap('post-id', {
      'authorUid': 'customer-id',
      'authorName': 'لاعب',
      'authorRole': 'customer',
      'type': 'lost_found',
      'title': 'حذاء رياضي',
      'body': 'نسيته قرب المدخل.',
      'governorate': 'حلب',
      'fieldId': 'field-id',
      'fieldName': 'ملعب الشهباء',
      'imageUrl': 'https://firebasestorage.googleapis.com/image',
      'status': 'active',
      'createdAt': Timestamp.fromDate(createdAt),
    });

    expect(post.type, CommunityPostType.lostFound);
    expect(post.fieldName, 'ملعب الشهباء');
    expect(post.createdAt, createdAt);
    expect(post.imageUrl, contains('firebasestorage'));
  });

  test('parses team search and rejects unsupported post types', () {
    final post = CommunityPostModel.fromMap('post-id', {
      'authorUid': 'customer-id',
      'authorName': 'لاعب',
      'authorRole': 'customer',
      'type': 'team_search',
      'title': 'فريق يبحث عن حارس',
      'body': 'نلعب مساء الجمعة.',
      'governorate': 'دمشق',
      'fieldId': null,
      'fieldName': null,
      'imageUrl': null,
      'status': 'active',
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 3)),
    });

    expect(post.type, CommunityPostType.teamSearch);
    expect(post.fieldId, isNull);
    expect(
      () => CommunityPostModel.fromMap(
        'invalid',
        {
          'authorUid': 'customer-id',
          'authorName': 'لاعب',
          'authorRole': 'customer',
          'type': 'unknown',
          'title': 'عنوان',
          'body': 'تفاصيل',
          'governorate': 'دمشق',
          'status': 'active',
          'createdAt': Timestamp.fromDate(DateTime(2026, 11, 3)),
        },
      ),
      throwsFormatException,
    );
  });
}
