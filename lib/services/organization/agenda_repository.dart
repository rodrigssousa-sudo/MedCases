import '../entitlement_service.dart';
import '../medcases_feature_authorization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agenda_event.dart';

class AgendaRepository {
  AgendaRepository(
      {FirebaseFirestore? db,
      FirebaseAuth? auth,
      MedCasesFeatureAuthorization? authorization})
      : db = db ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        authorization = authorization ?? MedCasesFeatureAuthorization.instance;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final MedCasesFeatureAuthorization authorization;
  String get uid {
    if (!authorization
        .allows(const FeatureTarget.capability(MedCasesCapability.agenda))) {
      throw StateError('AGENDA_PREMIUM_REQUIRED');
    }
    final value = auth.currentUser?.uid;
    if (value == null) throw StateError('AGENDA_AUTH_REQUIRED');
    return value;
  }

  CollectionReference<Map<String, dynamic>> collection(String owner) =>
      db.collection('users').doc(owner).collection('agenda');
  void assertOwner(String owner) {
    if (uid != owner) throw StateError('AGENDA_OWNER_CHANGED');
  }

  Future<void> save(AgendaEvent event, {required bool create}) async {
    assertOwner(event.userId);
    event.validate();
    final reference = collection(event.userId).doc(event.id);
    await db.runTransaction((tx) async {
      final old = await tx.get(reference);
      assertOwner(event.userId);
      final data = event.toFirestore();
      if (old.exists) {
        if (old.data()?['userId'] != event.userId ||
            old.data()?['id'] != event.id) {
          throw StateError('AGENDA_OWNER_MISMATCH');
        }
        tx.update(reference, data);
      } else {
        if (!create) throw StateError('AGENDA_EVENT_MISSING');
        data['createdAt'] = FieldValue.serverTimestamp();
        tx.set(reference, data);
      }
    });
    assertOwner(event.userId);
  }

  Future<void> delete(AgendaEvent event) async {
    assertOwner(event.userId);
    await collection(event.userId).doc(event.id).delete();
    assertOwner(event.userId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> window(
      String owner, DateTime from, DateTime until) {
    assertOwner(owner);
    return collection(owner)
        .where('startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()))
        .where('startAt', isLessThan: Timestamp.fromDate(until.toUtc()))
        .orderBy('startAt')
        .limit(300)
        .snapshots(includeMetadataChanges: true);
  }

  // Recurrence anchors predate a visible window; a bounded separate query is necessary.
  Stream<QuerySnapshot<Map<String, dynamic>>> recurring(String owner) {
    assertOwner(owner);
    return collection(owner)
        .where('recurrence', whereIn: ['daily', 'weekly', 'monthly'])
        .limit(100)
        .snapshots(includeMetadataChanges: true);
  }
}
