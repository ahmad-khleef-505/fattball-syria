import 'dart:async';

import 'package:fattball/models/user_model.dart';
import 'package:fattball/services/admin_service.dart';
import 'package:fattball/services/assistant_service.dart';
import 'package:fattball/services/auth_service.dart';
import 'package:fattball/services/booking_service.dart';
import 'package:fattball/services/community_service.dart';
import 'package:fattball/services/coach_service.dart';
import 'package:fattball/services/firestore_service.dart';
import 'package:fattball/services/notification_service.dart';
import 'package:fattball/services/tournament_service.dart';
import 'package:fattball/services/weather_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService();
});

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final coachServiceProvider = Provider<CoachService>((ref) {
  return CoachService();
});

final assistantServiceProvider = Provider<AssistantService>((ref) {
  return AssistantService();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final tournamentServiceProvider = Provider<TournamentService>((ref) {
  return TournamentService();
});

final weatherServiceProvider = Provider<WeatherService>((ref) {
  final service = WeatherService();
  ref.onDispose(service.dispose);
  return service;
});

final foregroundMessagesProvider = StreamProvider((ref) {
  return ref.watch(notificationServiceProvider).foregroundMessages;
});

final authStateProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authServiceProvider).userStream;
});

final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.role != 'superadmin') return false;
  final firebaseUser = ref.watch(authServiceProvider).currentUser;
  if (firebaseUser == null || firebaseUser.uid != user.uid) return false;

  final token = await firebaseUser.getIdTokenResult();
  return token.claims?['admin'] == true && token.claims?['superadmin'] == true;
});
