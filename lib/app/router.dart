import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_access.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/fair_price/data/fair_price_recommendation_repository.dart';
import '../features/fair_price/presentation/fair_price_screen.dart';
import '../features/fair_price/presentation/saved_recommendations_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/resource_marketplace/data/deal_request_repository.dart';
import '../features/resource_marketplace/presentation/marketplace_screen.dart';
import '../features/resource_profiles/presentation/profile_screen.dart';
import '../features/skill_match/presentation/skill_match_screen.dart';
import '../features/user_profile_screen.dart';

const protectedRoutePaths = <String>{
  '/role-select',
  '/home',
  '/skill-match',
  '/fair-price',
  '/fair-price/recommendations',
  '/resource-profile',
  '/user-profile',
  '/marketplace',
};

String? protectedRouteRedirect({
  required String matchedLocation,
  required bool hasVerifiedSession,
}) {
  if (protectedRoutePaths.contains(matchedLocation) && !hasVerifiedSession) {
    return '/login';
  }
  return null;
}

class AuthStateRefreshNotifier extends ChangeNotifier {
  AuthStateRefreshNotifier() {
    try {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) => notifyListeners(),
      );
    } catch (_) {

    }
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter({Listenable? refreshListenable}) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: refreshListenable,
  redirect: (context, state) {
    var hasVerifiedSession = false;
    try {
      hasVerifiedSession = hasVerifiedSupabaseSession(Supabase.instance.client);
    } catch (_) {

    }
    return protectedRouteRedirect(
      matchedLocation: state.matchedLocation,
      hasVerifiedSession: hasVerifiedSession,
    );
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/auth/confirmed',
      name: 'emailConfirmed',
      builder: (context, state) => const EmailConfirmedScreen(),
    ),
    GoRoute(
      path: '/role-select',
      name: 'roleSelect',
      builder: (context, state) => const RoleSelectScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/skill-match',
      name: 'skillMatch',
      builder: (context, state) => const SkillMatchScreen(),
    ),
    GoRoute(
      path: '/fair-price',
      name: 'fairPrice',
      builder: (context, state) {
        final extra = state.extra;
        return FairPriceScreen(
          initialDeal: extra is DealRequestRecord ? extra : null,
          initialRecommendation: extra is SavedFairPriceRecommendation
              ? extra
              : null,
        );
      },
    ),
    GoRoute(
      path: '/fair-price/recommendations',
      name: 'savedFairPriceRecommendations',
      builder: (context, state) => const SavedRecommendationsScreen(),
    ),
    GoRoute(
      path: '/resource-profile',
      name: 'resourceProfile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/user-profile',
      name: 'userProfile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/marketplace',
      name: 'marketplace',
      builder: (context, state) => const MarketplaceScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  ),
);
