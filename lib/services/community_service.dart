import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fattball/models/community_post_model.dart';

class CommunityServiceException implements Exception {
  const CommunityServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommunityService {
  CommunityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('community_posts');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPosts() =>
      _posts.orderBy('createdAt', descending: true).limit(100).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReplies(String postId) =>
      _posts
          .doc(postId)
          .collection('replies')
          .orderBy('createdAt')
          .limit(100)
          .snapshots();

  Future<String> createPost({
    required String authorUid,
    required String authorName,
    required String authorRole,
    required CommunityPostType type,
    required String title,
    required String body,
    required String governorate,
    String? fieldId,
    String? fieldName,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty ||
        cleanTitle.length > 100 ||
        cleanBody.isEmpty ||
        cleanBody.length > 1500 ||
        governorate.trim().isEmpty ||
        !['customer', 'owner'].contains(authorRole)) {
      throw const CommunityServiceException('تحقق من عنوان المنشور وتفاصيله.');
    }

    final reference = _posts.doc();
    await reference.set({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'type': type == CommunityPostType.lostFound ? 'lost_found' : 'team_search',
      'title': cleanTitle,
      'body': cleanBody,
      'governorate': governorate.trim(),
      'fieldId': fieldId,
      'fieldName': fieldName,
      'imageUrl': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  Future<void> attachImage({
    required String postId,
    required String imageUrl,
  }) {
    if (!imageUrl.startsWith('https://firebasestorage.googleapis.com/')) {
      throw const CommunityServiceException('رابط صورة المنشور غير صالح.');
    }
    return _posts.doc(postId).update({'imageUrl': imageUrl});
  }

  Future<void> reply({
    required String postId,
    required String authorUid,
    required String authorName,
    required String authorRole,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty || cleanBody.length > 500) {
      throw const CommunityServiceException(
        'اكتب رداً لا يتجاوز 500 محرف.',
      );
    }
    await _posts.doc(postId).collection('replies').add({
      'authorUid': authorUid,
      'authorName': authorName,
      'authorRole': authorRole,
      'body': cleanBody,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markFound(String postId) =>
      _posts.doc(postId).update({'status': 'resolved'});
}
