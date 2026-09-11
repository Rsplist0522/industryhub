import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/auth_access.dart';
import '../../../core/widgets.dart';
import '../../../core/validators.dart';

String _confirmationRedirectUrl() {
  return resolveEmailConfirmationRedirect(
    isWeb: kIsWeb,
    baseUri: Uri.base,
    isMobile:
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS,
    configuredWebRedirect: dotenv.env['AUTH_WEB_REDIRECT_URL'],
  );
}

Future<String> _signedInDestination() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null || !hasVerifiedSupabaseSession(client)) return '/login';
  try {
    final row = await client
        .from('profiles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    final role = (row?['role'] as String?)?.trim() ?? '';
    return role.isEmpty ? '/role-select' : '/home';
  } catch (_) {
    return '/home';
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    var hasVerifiedSession = false;
    try {
      final client = Supabase.instance.client;
      hasVerifiedSession = hasVerifiedSupabaseSession(client);
      if (client.auth.currentSession != null && !hasVerifiedSession) {
        await client.auth.signOut();
      }
    } catch (_) {

    }
    if (!mounted) return;
    if (!hasVerifiedSession) {
      context.go('/login');
      return;
    }
    context.go(await _signedInDestination());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.chalk,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.architecture,
                size: 38,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'INDUSTRYHUB',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Practical intelligence for Malaysian SMEs',
              style: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (response.user?.emailConfirmedAt == null) {
        await client.auth.signOut();
        if (mounted) {
          setState(() => _errorMessage = unverifiedEmailSignInMessage);
        }
        return;
      }
      if (response.session == null) {
        throw const AuthException(
          'Sign-in did not create a session. Please try again.',
        );
      }
      if (mounted) context.go(await _signedInDestination());
    } on AuthException catch (error) {
      if (isEmailNotConfirmedError(error)) {
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {

        }
      }
      if (mounted) {
        setState(
          () => _errorMessage = isEmailNotConfirmedError(error)
              ? unverifiedEmailSignInMessage
              : error.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Sign-in failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('INDUSTRYHUB / ACCESS'),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome back.',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to keep your operations moving.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.slate),
                    ),
                    const SizedBox(height: 28),
                    const SpecDivider(label: 'CREDENTIALS'),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Business email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: validateLoginPassword,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      _AuthError(message: _errorMessage!),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('Create a business account'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Your account is secured by Supabase authentication.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  String? _infoMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _business.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    final businessName = _business.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        emailRedirectTo: _confirmationRedirectUrl(),
        data: {
          'business_name': businessName,
          'sector': 'General manufacturing',
          'role': '',
        },
      );
      if (response.session != null) {
        await client.auth.signOut();
      }
      if (!mounted) return;
      setState(() => _infoMessage = safeSignupConfirmationMessage);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          if (isExistingAccountSignupError(error)) {
            _infoMessage = safeSignupConfirmationMessage;
          } else {
            _errorMessage = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Account creation failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Create account',
      showBack: true,
      fallbackRoute: '/login',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageIntro(
                eyebrow: 'INDUSTRYHUB / ONBOARDING',
                title: 'Set up your workspace.',
                description:
                    'Start with the basics. You can complete verification and listings after you enter the app.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _business,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Business name'),
                validator: (value) =>
                    validateRequiredText(value, label: 'a business name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Business email'),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: validatePassword,
              ),
              const SizedBox(height: 22),
              if (_infoMessage != null) ...[
                _AuthNotice(message: _infoMessage!),
                const SizedBox(height: 14),
              ],
              if (_errorMessage != null) ...[
                _AuthError(message: _errorMessage!),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create account'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/login'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailConfirmedScreen extends StatelessWidget {
  const EmailConfirmedScreen({super.key, this.isVerifiedOverride});

  @visibleForTesting
  final bool? isVerifiedOverride;

  bool get _isVerified {
    if (isVerifiedOverride case final override?) return override;
    try {
      return Supabase.instance.client.auth.currentUser?.emailConfirmedAt !=
          null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _goToSignIn(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {

    }
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _isVerified;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 52,
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isVerified
                            ? 'Email verified successfully.'
                            : 'Email confirmation could not be completed.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isVerified
                            ? 'Your IndustryHub account is now active.'
                            : 'The link may be invalid or expired. Request a new confirmation email, then try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.slate),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _goToSignIn(context),
                          child: Text(
                            isVerified ? 'Sign in' : 'Back to sign in',
                          ),
                        ),
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

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.green, height: 1.35),
    ),
  );
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.rust.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.rust.withValues(alpha: 0.35)),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.rust, height: 1.35),
    ),
  );
}

class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  String selected = 'Factory owner';
  bool _isSaving = false;
  String? _errorMessage;

  final roles = const [
    (
      'Factory owner',
      'Match talent, benchmark prices, and source materials.',
      Icons.factory_outlined,
    ),
    (
      'Waste supplier',
      'List recoverable materials and find verified buyers.',
      Icons.recycling_outlined,
    ),
    (
      'Buyer',
      'Browse materials and send structured deal requests.',
      Icons.shopping_bag_outlined,
    ),
  ];

  Future<void> _saveRole() async {
    if (_isSaving) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || !hasVerifiedSupabaseSession(client)) {
      if (client.auth.currentSession != null) await client.auth.signOut();
      if (mounted) context.go('/login');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await client
          .from('profiles')
          .update({'role': selected})
          .eq('user_id', user.id);
      await ref.read(appStateProvider.notifier).refreshSupabaseData();
      if (mounted) context.go('/home');
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Role could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Choose your role',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PageIntro(
            eyebrow: 'INDUSTRYHUB / ROLE',
            title: 'What are you here to do?',
            description:
                'This records your primary role. You can still access every module later.',
          ),
          const SizedBox(height: 22),
          RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) setState(() => selected = value);
            },
            child: Column(
              children: roles
                  .map(
                    (role) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: RadioListTile<String>(
                          value: role.$1,
                          title: Text(
                            role.$1,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(role.$2),
                          ),
                          secondary: Icon(role.$3, color: AppColors.navy),
                          activeColor: AppColors.navy,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null) ...[
            _AuthError(message: _errorMessage!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _isSaving ? null : _saveRole,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enter IndustryHub'),
          ),
        ],
      ),
    );
  }
}
