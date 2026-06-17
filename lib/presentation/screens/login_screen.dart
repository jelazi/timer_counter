import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/services/pocketbase_sync_service.dart';

/// Login screen shown on web before the user authenticates against PocketBase.
///
/// After a successful sign-in the screen starts real-time listeners and runs
/// `smartFirstSync()` so the user immediately sees their data. The parent
/// `AuthGate` switches to `HomeScreen` once `authStateStream` emits `true`.
class LoginScreen extends StatefulWidget {
  final PocketBaseSyncService syncService;

  const LoginScreen({super.key, required this.syncService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final error = await widget.syncService.signIn(email, password);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    // Start listeners and smart-first-sync in background; UI will switch
    // automatically once AuthGate sees the new auth state.
    try {
      await widget.syncService.startListeners();
      await widget.syncService.smartFirstSync();
    } catch (e) {
      debugPrint('[LoginScreen] Post-login sync failed: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.timer_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        tr('app_name'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        autofocus: true,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password is required';
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
