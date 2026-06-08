export 'google_account_service.dart'
    show
        GoogleAccountService,
        GoogleSignInResult,
        authStateProvider,
        googleAccountServiceProvider;

import 'google_account_service.dart';

/// Backward-compatible alias for the unified Google account service.
typedef FirebaseAuthService = GoogleAccountService;

final firebaseAuthServiceProvider = googleAccountServiceProvider;
