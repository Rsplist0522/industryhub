import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) context.go('/login');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final profile = state.profile;
    final now = DateTime.now();
    final profileReady = profile.hasRequiredProfileIdentity;
    final hasListings = state.activeListings > 0;
    final actionRoute = !profileReady
        ? '/resource-profile'
        : !hasListings
        ? '/resource-profile'
        : state.savedMatches == 0
        ? '/skill-match'
        : '/fair-price';
    final actionLabel = !profileReady
        ? 'Complete your profile'
        : !hasListings
        ? 'Add your first listing'
        : state.savedMatches == 0
        ? 'Find a training match'
        : 'Run a price check';
    final actionTitle = !profileReady
        ? 'Set up your business identity'
        : !hasListings
        ? 'Publish your first listing'
        : state.savedMatches == 0
        ? 'Build your team capability plan'
        : 'Pressure-test your next quote';
    final actionDescription = !profileReady
        ? 'Add your business name and industry sector before you unlock marketplace and matching features.'
        : !hasListings
        ? 'Publish a supply or demand listing so your business becomes discoverable in the local marketplace.'
        : state.savedMatches == 0
        ? 'Describe a workforce need and save a shortlist of suitable programmes.'
        : 'Use the benchmark-led advisor before you commit to a material price.';

    return AppShell(
      title: 'IndustryHub',
      actions: [
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () =>
                ref.read(appStateProvider.notifier).refreshSupabaseData(),
            icon: const Icon(Icons.refresh_outlined),
          ),
        IconButton(
          tooltip: 'Open account',
          onPressed: () => context.go('/user-profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.logout_outlined),
        ),
        const SizedBox(width: 6),
      ],
      bottomNavigationBar: const _HomeNavigationBar(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appStateProvider.notifier).refreshSupabaseData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Eyebrow(_formatDate(now)),
            const SizedBox(height: 8),
            Text(
              '${_greeting(now)},',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            Text(
              '${profile.businessName}.',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 20),
            MetricStrip(
              metrics: [
                MapEntry('active listings', _twoDigits(state.activeListings)),
                MapEntry(
                  'negotiations in progress',
                  _twoDigits(state.negotiations),
                ),
                MapEntry(
                  'training matches saved',
                  _twoDigits(state.savedMatches),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.north_east,
                        color: AppColors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow(
                            'RECOMMENDED NEXT MOVE',
                            color: AppColors.amber,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            actionTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            actionDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.slate,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => context.push(actionRoute),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text(actionLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            const SpecDivider(label: 'OPERATIONS CONSOLE'),
            const SizedBox(height: 16),
            ModuleCard(
              eyebrow: 'M1 / SKILLMATCH AI',
              title: 'Skill Advisor',
              description:
                  'Turn a hiring or upskilling need into a ranked shortlist of local programmes.',
              icon: Icons.psychology_outlined,
              onTap: () => context.push('/skill-match'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M2 / FAIRPRICE',
              title: 'Price Advisor',
              description:
                  'Pressure-test a proposed price with a transparent, benchmark-led negotiation.',
              icon: Icons.compare_arrows,
              accent: AppColors.amber,
              onTap: () => context.push('/fair-price'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M3 / RESOURCE PROFILES',
              title: 'My Profile & Listings',
              description:
                  'Keep your business profile current, review verification status, and manage the materials you can supply or need.',
              icon: Icons.badge_outlined,
              accent: AppColors.green,
              onTap: () => context.push('/resource-profile'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M4 / MARKETPLACE',
              title: 'ReSource Marketplace',
              description:
                  'Browse nearby industrial materials and move from discovery to a deal request.',
              icon: Icons.storefront_outlined,
              accent: AppColors.rust,
              onTap: () => context.push('/marketplace'),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      state.isLoading
                          ? Icons.sync_outlined
                          : Icons.cloud_done_outlined,
                      color: state.isLoading
                          ? AppColors.amber
                          : AppColors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.isLoading
                            ? 'Refreshing your workspace records from Supabase.'
                            : 'Your profile and listings are connected to your anonymous Supabase workspace. Refresh to check for the latest records.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String _greeting(DateTime date) {
    if (date.hour < 12) return 'Good morning';
    if (date.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1].toUpperCase()} / ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}

class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/marketplace');
        if (index == 2) context.go('/user-profile');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Console',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
