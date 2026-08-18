import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    return AppShell(
      title: 'IndustryHub',
      actions: [
        IconButton(onPressed: () => context.go('/resource-profile'), icon: const Icon(Icons.account_circle_outlined)),
        const SizedBox(width: 6),
      ],
      bottomNavigationBar: const _HomeNavigationBar(currentIndex: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        children: [
          const Eyebrow('MONDAY / 17 AUG 2026'),
          const SizedBox(height: 8),
          Text('Good morning,\nKencana team.', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 20),
          MetricStrip(metrics: [
            MapEntry('${state.activeListings} active listings', '01'),
            MapEntry('negotiation in progress', '0${state.negotiations}'),
            MapEntry('training matches saved', '0${state.savedMatches}'),
          ]),
          const SizedBox(height: 26),
          const SpecDivider(label: 'OPERATIONS CONSOLE'),
          const SizedBox(height: 16),
          ModuleCard(
            eyebrow: 'M1 / SKILLMATCH AI',
            title: 'Skill Advisor',
            description: 'Turn a hiring or upskilling need into a ranked shortlist of local programmes.',
            icon: Icons.psychology_outlined,
            onTap: () => context.push('/skill-match'),
          ),
          const SizedBox(height: 12),
          ModuleCard(
            eyebrow: 'M2 / FAIRPRICE',
            title: 'Price Advisor',
            description: 'Pressure-test a proposed price with a transparent, benchmark-led negotiation.',
            icon: Icons.compare_arrows,
            accent: AppColors.amber,
            onTap: () => context.push('/fair-price'),
          ),
          const SizedBox(height: 12),
          ModuleCard(
            eyebrow: 'M3 / RESOURCE PROFILES',
            title: 'My Profile & Listings',
            description: 'Keep your business profile verified and manage the materials you can supply or need.',
            icon: Icons.badge_outlined,
            accent: AppColors.green,
            onTap: () => context.push('/resource-profile'),
          ),
          const SizedBox(height: 12),
          ModuleCard(
            eyebrow: 'M4 / MARKETPLACE',
            title: 'ReSource Marketplace',
            description: 'Browse nearby industrial materials and move from discovery to a deal request.',
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
                  const Icon(Icons.shield_outlined, color: AppColors.green),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Your workspace is in demo mode. Connect Firebase and an LLM endpoint when you are ready to move from local prototype data to production services.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        if (index == 2) context.go('/resource-profile');
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Console'),
        NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Market'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
