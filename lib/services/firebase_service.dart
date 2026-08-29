import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  /// Initializes Firebase and signs the device in anonymously so every
  /// participant has a stable identity without any signup flow.
  static Future<String> init() async {
    await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      final credential = await auth.signInAnonymously();
      return credential.user!.uid;
    }
    return auth.currentUser!.uid;
  }

  static String get uid => FirebaseAuth.instance.currentUser!.uid;
}
