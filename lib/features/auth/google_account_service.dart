import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/drive/v3.dart' as gdrive;

/// Web client ID from Firebase (required for Google Sign-In + Firebase Auth).
const firebaseWebClientId =
    '817142441074-m8fejjvrd9emj3m9o5i453madgm4lve4.apps.googleusercontent.com';

const googleProfileScopes = [
  'openid',
  'email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

const googleCalendarScopes = [gcal.CalendarApi.calendarReadonlyScope];

const googleDriveScopes = [gdrive.DriveApi.driveReadonlyScope];

/// Single scope list used for every interactive Google sign-in in the app.
const googleSignInScopeHint = [
  ...googleProfileScopes,
  ...googleCalendarScopes,
  ...googleDriveScopes,
];

class GoogleSignInResult {
  const GoogleSignInResult({
    required this.account,
    required this.firebaseUser,
  });

  final GoogleSignInAccount account;
  final User firebaseUser;
}

class GoogleAccountService {
  GoogleAccountService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static Future<void>? _initFuture;
  static GoogleSignInAccount? _sessionAccount;
  static bool _authEventsListening = false;

  GoogleSignInAccount? get sessionAccount => _sessionAccount;

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initialize() async {
    _initFuture ??= GoogleSignIn.instance
        .initialize(serverClientId: firebaseWebClientId)
        .then((_) => _listenToAuthenticationEvents());
    await _initFuture!;
  }

  static void _listenToAuthenticationEvents() {
    if (_authEventsListening) return;
    _authEventsListening = true;
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn(:final user):
          _sessionAccount = user;
        case GoogleSignInAuthenticationEventSignOut():
          _sessionAccount = null;
      }
    });
  }

  Future<GoogleSignInResult> signIn() async {
    await initialize();

    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: googleSignInScopeHint,
    );
    _sessionAccount = account;

    final firebaseUser = await _signInToFirebase(account);
    return GoogleSignInResult(account: account, firebaseUser: firebaseUser);
  }

  Future<User> _signInToFirebase(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const FormatException(
        'Google sign-in did not return an ID token. Check Firebase SHA-1 setup.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) {
      throw const FormatException('Firebase sign-in completed without a user.');
    }
    return user;
  }

  /// Reuses the in-memory Google session when available; otherwise returns null.
  Future<GoogleSignInAccount?> resolveSessionAccount({
    required bool interactive,
  }) async {
    await initialize();

    if (_sessionAccount != null) {
      return _sessionAccount;
    }

    final lightweightFuture =
        GoogleSignIn.instance.attemptLightweightAuthentication();
    if (lightweightFuture != null) {
      final restored = await lightweightFuture;
      if (restored != null) {
        _sessionAccount = restored;
        return restored;
      }
    }

    if (!interactive) return null;

    final result = await signIn();
    return result.account;
  }

  Future<void> signOut() async {
    _sessionAccount = null;
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      await GoogleSignIn.instance.signOut();
    }
  }
}

final googleAccountServiceProvider = Provider<GoogleAccountService>(
  (ref) => GoogleAccountService(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(googleAccountServiceProvider).authStateChanges;
});
