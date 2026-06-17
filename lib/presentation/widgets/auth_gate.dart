import 'package:flutter/material.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../core/utils/platform_utils.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

/// Decides whether to show the login screen or the main app.
///
/// - On desktop/mobile: always renders `HomeScreen` (auto sign-in happens in
///   `main()` from a bundled config / settings override).
/// - On web: renders `LoginScreen` until the user signs in, then switches to
///   `HomeScreen` reactively via `authStateStream`.
///
/// If the `PocketBaseSyncService` is `null` on web (e.g. missing
/// `POCKETBASE_URL` define), shows a setup error instead.
class AuthGate extends StatelessWidget {
  final PocketBaseSyncService? syncService;

  const AuthGate({super.key, this.syncService});

  @override
  Widget build(BuildContext context) {
    // Non-web platforms keep the existing behavior: HomeScreen directly.
    if (!PlatformUtils.isWeb) {
      return const HomeScreen();
    }

    final service = syncService;
    if (service == null) {
      return const _MissingConfigScreen();
    }

    return StreamBuilder<bool>(
      stream: service.authStateStream,
      initialData: service.isSignedIn,
      builder: (context, snapshot) {
        final signedIn = snapshot.data ?? false;
        if (signedIn) return const HomeScreen();
        return LoginScreen(syncService: service);
      },
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              const Text(
                'PocketBase server URL is not configured.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Build the web app with:\n'
                'flutter build web --dart-define=POCKETBASE_URL=https://your-pb.example.com',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
