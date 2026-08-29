import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference get groups => _db.collection('groups');
  static CollectionReference get joinCodes => _db.collection('joinCodes');

  static CollectionReference participants(String groupId) =>
      groups.doc(groupId).collection('participants');

  static CollectionReference expenses(String groupId) =>
      groups.doc(groupId).collection('expenses');

  static CollectionReference settlements(String groupId) =>
      groups.doc(groupId).collection('settlements');

  /// Generates a short, human-shareable join code, e.g. "K3F9QZ".
  static String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 confusion
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Creates a new group, adds the creator as the first participant, and
  /// reserves a join code other people can use to hop in.
  static Future<String> createGroup({
    required String groupName,
    required String creatorUid,
    required String creatorName,
  }) async {
    String code = _generateJoinCode();
    // Extremely unlikely, but make sure the code isn't already taken.
    while ((await joinCodes.doc(code).get()).exists) {
      code = _generateJoinCode();
    }

    final groupRef = groups.doc();
    await groupRef.set({
      'name': groupName,
      'joinCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await joinCodes.doc(code).set({'groupId': groupRef.id});

    await participants(groupRef.id).doc(creatorUid).set({
      'name': creatorName,
      'uid': creatorUid,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return groupRef.id;
  }

  /// Looks up a group by its join code and adds this device as a participant.
  /// Returns the groupId, or null if the code doesn't exist.
  static Future<String?> joinGroup({
    required String code,
    required String uid,
    required String name,
  }) async {
    final codeDoc = await joinCodes.doc(code.toUpperCase().trim()).get();
    if (!codeDoc.exists) return null;
    final groupId = (codeDoc.data() as Map)['groupId'] as String;

    await participants(groupId).doc(uid).set({
      'name': name,
      'uid': uid,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return groupId;
  }

  static Stream<DocumentSnapshot> groupStream(String groupId) =>
      groups.doc(groupId).snapshots();

  static Stream<QuerySnapshot> participantsStream(String groupId) =>
      participants(groupId).orderBy('joinedAt').snapshots();

  static Stream<QuerySnapshot> expensesStream(String groupId) =>
      expenses(groupId).orderBy('timestampMillis', descending: true).snapshots();

  static Stream<QuerySnapshot> settlementsStream(String groupId) =>
      settlements(groupId).orderBy('timestampMillis', descending: true).snapshots();

  static Future<void> addExpense(String groupId, Map<String, dynamic> data) =>
      expenses(groupId).add(data);

  static Future<void> deleteExpense(String groupId, String expenseId) =>
      expenses(groupId).doc(expenseId).delete();

  /// Records that a settle-up transfer was *claimed* as paid by the debtor.
  /// It stays "pending" until the creditor confirms it — only then does it
  /// actually reduce the outstanding balance.
  static Future<void> requestSettlement(
    String groupId, {
    required String fromId,
    required String toId,
    required double amount,
  }) {
    return settlements(groupId).add({
      'fromId': fromId,
      'toId': toId,
      'amount': amount,
      'status': 'pending',
      'timestampMillis': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Creditor confirms they actually received the money.
  static Future<void> confirmSettlement(String groupId, String settlementId) {
    return settlements(groupId).doc(settlementId).update({'status': 'confirmed'});
  }

  /// Creditor disputes/rejects a claimed payment (e.g. wrong amount, never arrived).
  static Future<void> rejectSettlement(String groupId, String settlementId) {
    return settlements(groupId).doc(settlementId).delete();
  }

  /// Permanently deletes a group and everything in it (participants,
  /// expenses, settlements, and its join code). Cannot be undone.
  static Future<void> deleteGroupCompletely(String groupId, String? joinCode) async {
    Future<void> deleteAllDocsIn(CollectionReference col) async {
      final snap = await col.get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await deleteAllDocsIn(participants(groupId));
    await deleteAllDocsIn(expenses(groupId));
    await deleteAllDocsIn(settlements(groupId));

    if (joinCode != null) {
      await joinCodes.doc(joinCode).delete();
    }
    await groups.doc(groupId).delete();
  }
}
