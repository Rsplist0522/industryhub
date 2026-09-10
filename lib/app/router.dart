import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/fair_price/data/fair_price_recommendation_repository.dart';
import '../features/fair_price/presentation/fair_price_screen.dart';
import '../features/fair_price/presentation/saved_recommendations_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/resource_marketplace/presentation/marketplace_screen.dart';
import '../features/resource_profiles/presentation/profile_screen.dart';
import '../features/skill_match/presentation/skill_match_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    var hasSession = false;
    try {
      hasSession = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      // Supabase may not be initialised yet in isolated widget tests.
    }
    final location = state.matchedLocation;
    final publicRoute = location == '/splash' ||
        location == '/login' ||
        location == '/signup';
    if (!hasSession && !publicRoute) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', name: 'splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', name: 'signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/role-select', name: 'roleSelect', builder: (context, state) => const RoleSelectScreen()),
    GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/skill-match', name: 'skillMatch', builder: (context, state) => const SkillMatchScreen()),
    GoRoute(
      path: '/fair-price',
      name: 'fairPrice',
      builder: (context, state) => FairPriceScreen(
        initialRecommendation: state.extra is SavedFairPriceRecommendation
            ? state.extra as SavedFairPriceRecommendation
            : null,
      ),
    ),
    GoRoute(
      path: '/fair-price/recommendations',
      name: 'fairPriceRecommendations',
      builder: (context, state) => const SavedRecommendationsScreen(),
    ),
    GoRoute(path: '/resource-profile', name: 'resourceProfile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/marketplace', name: 'marketplace', builder: (context, state) => const MarketplaceScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}', style: Theme.of(context).textTheme.bodyLarge),
    ),
  ),
);
