import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class SimpleParticipant {
  final String id; // this is the participant's Firebase uid
  final String name;
  SimpleParticipant({required this.id, required this.name});
}

class GroupProvider extends ChangeNotifier {
  static const _lastGroupKey = 'last_active_group_id';

  String? uid;
  String? activeGroupId;
  String? activeGroupName;
  String? activeJoinCode;
  List<SimpleParticipant> activeParticipants = [];
  bool restoring = true; // true while we check for a previously-active group

  void setUid(String value) {
    uid = value;
    notifyListeners();
  }

  /// Call once at startup: if the device was already in a group last time
  /// the app was open, reconnect to it automatically instead of showing
  /// onboarding again.
  Future<void> tryRestoreLastGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastGroupId = prefs.getString(_lastGroupKey);
    if (lastGroupId != null) {
      _attachToGroup(lastGroupId);
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> _rememberGroup(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastGroupKey, groupId);
  }

  Future<void> createGroup(String groupName, String yourName) async {
    final groupId = await FirestoreService.createGroup(
      groupName: groupName,
      creatorUid: uid!,
      creatorName: yourName,
    );
    await _rememberGroup(groupId);
    _attachToGroup(groupId);
  }

  /// Returns false if the join code doesn't match any group.
  Future<bool> joinGroup(String code, String yourName) async {
    final groupId = await FirestoreService.joinGroup(
      code: code,
      uid: uid!,
      name: yourName,
    );
    if (groupId == null) return false;
    await _rememberGroup(groupId);
    _attachToGroup(groupId);
    return true;
  }

  /// Leaves the currently active group locally (data stays safe in the
  /// cloud) so the device can create or join a different one.
  Future<void> forgetActiveGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastGroupKey);
    activeGroupId = null;
    activeGroupName = null;
    activeJoinCode = null;
    activeParticipants = [];
    notifyListeners();
  }

  /// PERMANENTLY deletes the group for everyone — expenses, settlements,
  /// participants, the works. Cannot be undone.
  Future<void> deleteActiveGroupCompletely() async {
    final groupId = activeGroupId;
    if (groupId == null) return;
    await FirestoreService.deleteGroupCompletely(groupId, activeJoinCode);
    await forgetActiveGroup();
  }

  void _attachToGroup(String groupId) {
    activeGroupId = groupId;

    FirestoreService.groupStream(groupId).listen((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      activeGroupName = data['name'] as String?;
      activeJoinCode = data['joinCode'] as String?;
      notifyListeners();
    });

    FirestoreService.participantsStream(groupId).listen((snap) {
      activeParticipants = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return SimpleParticipant(id: d.id, name: data['name'] as String? ?? '?');
      }).toList();
      notifyListeners();
    });
  }

  String? participantName(String id) {
    try {
      return activeParticipants.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return null;
    }
  }
}
