import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.go('/login');
    });
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
              decoration: BoxDecoration(color: AppColors.chalk, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.architecture, size: 38, color: AppColors.navy),
            ),
            const SizedBox(height: 20),
            Text('INDUSTRYHUB', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.white, letterSpacing: 1.4)),
            const SizedBox(height: 9),
            Text('Practical intelligence for Malaysian SMEs', style: TextStyle(color: AppColors.white.withValues(alpha: 0.7))),
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
  final _email = TextEditingController(text: 'owner@kencanaprecision.my');
  final _password = TextEditingController(text: 'password');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) context.go('/home');
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
                    Text('Welcome back.', style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 8),
                    Text('Sign in to keep your operations moving.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.slate)),
                    const SizedBox(height: 28),
                    const SpecDivider(label: 'CREDENTIALS'),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Business email', prefixIcon: Icon(Icons.alternate_email)),
                      validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email address.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (value) => value == null || value.length < 6 ? 'Use at least 6 characters.' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _login, child: const Text('Sign in'))),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go('/signup'), child: const Text('Create a business account'))),
                    const SizedBox(height: 24),
                    Center(child: Text('Demo mode: credentials are accepted locally.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate))),
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

  @override
  void dispose() {
    _business.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Create account',
      showBack: true,
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
                description: 'Start with the basics. You can complete verification and listings after you enter the app.',
              ),
              const SizedBox(height: 24),
              TextFormField(controller: _business, decoration: const InputDecoration(labelText: 'Business name'), validator: _required),
              const SizedBox(height: 14),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Business email'), validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email.'),
              const SizedBox(height: 14),
              TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (value) => value != null && value.length >= 6 ? null : 'Use at least 6 characters.'),
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (_formKey.currentState?.validate() ?? false) context.go('/role-select'); }, child: const Text('Continue'))),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String selected = 'Factory owner';
  final roles = const [
    ('Factory owner', 'Match talent, benchmark prices, and source materials.', Icons.factory_outlined),
    ('Waste supplier', 'List recoverable materials and find verified buyers.', Icons.recycling_outlined),
    ('Buyer', 'Browse materials and send structured deal requests.', Icons.shopping_bag_outlined),
  ];

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
            description: 'This tunes your dashboard. You can still access every module later.',
          ),
          const SizedBox(height: 22),
          ...roles.map((role) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: RadioListTile<String>(
                    value: role.$1,
                    groupValue: selected,
                    onChanged: (value) => setState(() => selected = value!),
                    title: Text(role.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(role.$2)),
                    secondary: Icon(role.$3, color: AppColors.navy),
                    activeColor: AppColors.navy,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              )),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => context.go('/home'), child: const Text('Enter IndustryHub')),
        ],
      ),
    );
  }
}
