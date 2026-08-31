import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app/theme.dart';


class SpecDivider extends StatelessWidget {
  const SpecDivider({super.key, this.label});


  final String? label;


  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 2, height: 12, child: VerticalDivider(width: 1, color: AppColors.slate)),
        Expanded(child: Container(height: 1, color: AppColors.line)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: AppTheme.eyebrowStyle),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: AppColors.line)),
        const SizedBox(width: 2, height: 12, child: VerticalDivider(width: 1, color: AppColors.slate)),
      ],
    );
  }
}


class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});


  final String text;
  final Color? color;


  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppTheme.eyebrowStyle.copyWith(color: color));
}


class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});


  final String label;
  final Color color;


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}


class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.navy,
  });


  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Eyebrow(eyebrow, color: accent),
                  Icon(icon, color: accent, size: 24),
                ],
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 7),
              Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.35)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Open module', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.metrics});


  final List<MapEntry<String, String>> metrics;


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        spacing: 22,
        runSpacing: 12,
        children: metrics
            .map(
              (metric) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.key, style: TextStyle(color: AppColors.white.withValues(alpha: 0.65), fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(metric.value, style: AppTheme.dataStyle.copyWith(color: AppColors.white, fontSize: 18)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}


class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.isUser});


  final String text;
  final bool isUser;


  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navy : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: Radius.circular(isUser ? 8 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 8),
          ),
          border: isUser ? null : Border.all(color: AppColors.line),
        ),
        child: Text(text, style: TextStyle(color: isUser ? AppColors.white : AppColors.ink, height: 1.35)),
      ),
    );
  }
}


class PageIntro extends StatelessWidget {
  const PageIntro({super.key, required this.eyebrow, required this.title, required this.description});


  final String eyebrow;
  final String title;
  final String description;


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 7),
        Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.4)),
      ],
    );
  }
}


class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBack = false,
    this.bottomNavigationBar,
    this.fallbackRoute = '/home',
  });


  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottomNavigationBar;
  // Where "back" should land when there is nothing left to pop, e.g. when a
  // screen was reached via context.go() (which clears the navigation stack)
  // rather than context.push(). automaticallyImplyLeading alone can't do
  // this — it only shows a back arrow if canPop() is already true, so a
  // page opened with go() silently loses its back button.
  final String fallbackRoute;


  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideNavigation = constraints.maxWidth >= 700;

        if (useSideNavigation) {
          const navItems = <_NavItem>[
            _NavItem(
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view,
              label: 'Console',
              route: '/home',
            ),
            _NavItem(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront,
              label: 'Market',
              route: '/marketplace',
            ),
            _NavItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
              route: '/resource-profile',
            ),
          ];

          final currentRoute = GoRouterState.of(context).matchedLocation;
          final selectedIndex = navItems.indexWhere(
            (item) => item.route == currentRoute,
          );

          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Go back',
                      onPressed: () => _goBack(context),
                    )
                  : null,
              title: Text(title),
              actions: actions,
            ),
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
                    onDestinationSelected: (index) {
                      if (index < 0 || index >= navItems.length) return;
                      context.go(navItems[index].route);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: navItems
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: SafeArea(child: body)),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Go back',
                    onPressed: () => _goBack(context),
                  )
                : null,
            title: Text(title),
            actions: actions,
          ),
          body: SafeArea(child: body),
          bottomNavigationBar: bottomNavigationBar,
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}


/// Shared bottom navigation for the three main modules. Previously each
/// screen (Marketplace, Home, Profile) built its own NavigationBar with
/// slightly different destinations/ordering; this is the single source of
/// truth so the bottom bar — and by extension the whole shell — looks and
/// behaves the same everywhere.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, required this.currentIndex});


  final int currentIndex;


  static const _destinations = [
    (
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: 'Console',
      route: '/home',
    ),
    (
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      label: 'Market',
      route: '/marketplace',
    ),
    (
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Profile',
      route: '/resource-profile',
    ),
  ];


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        context.go(_destinations[index].route);
      },
      destinations: _destinations
          .map(
            (d) => NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          )
          .toList(),
    );
  }
}
