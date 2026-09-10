import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industryhub/app/router.dart';
import 'package:industryhub/core/auth_access.dart';
import 'package:industryhub/features/auth/presentation/auth_screens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('verified authentication access', () {
    test('requires both a session and a confirmed email', () {
      const confirmedAt = '2026-09-10T00:00:00Z';

      expect(
        hasVerifiedAuthAccess(hasSession: true, emailConfirmedAt: confirmedAt),
        isTrue,
      );
      expect(
        hasVerifiedAuthAccess(hasSession: true, emailConfirmedAt: null),
        isFalse,
      );
      expect(
        hasVerifiedAuthAccess(hasSession: false, emailConfirmedAt: confirmedAt),
        isFalse,
      );
    });

    test('every protected route redirects an unverified session', () {
      for (final route in protectedRoutePaths) {
        expect(
          protectedRouteRedirect(
            matchedLocation: route,
            hasVerifiedSession: false,
          ),
          '/login',
          reason: '$route must be protected',
        );
      }
    });

    test('confirmation page remains public', () {
      expect(
        protectedRouteRedirect(
          matchedLocation: '/auth/confirmed',
          hasVerifiedSession: false,
        ),
        isNull,
      );
    });

    test('normalizes hidden-account and unverified-email auth errors', () {
      expect(
        isEmailNotConfirmedError(const AuthException('Email not confirmed')),
        isTrue,
      );
      expect(
        isExistingAccountSignupError(
          const AuthException('User already registered'),
        ),
        isTrue,
      );
    });
  });

  group('email confirmation redirect', () {
    test('configured web URL takes priority on Android', () {
      expect(
        resolveEmailConfirmationRedirect(
          isWeb: false,
          baseUri: Uri.parse('file:///'),
          isMobile: true,
          configuredWebRedirect: 'http://localhost:49311/auth/confirmed',
        ),
        'http://localhost:49311/auth/confirmed',
      );
    });

    test('mobile deep link remains the fallback', () {
      expect(
        resolveEmailConfirmationRedirect(
          isWeb: false,
          baseUri: Uri.parse('file:///'),
          isMobile: true,
        ),
        mobileEmailConfirmationDeepLink,
      );
    });

    test('Flutter Web keeps its current-origin confirmation page', () {
      expect(
        resolveEmailConfirmationRedirect(
          isWeb: true,
          baseUri: Uri.parse('http://localhost:49311/signup'),
          isMobile: false,
          configuredWebRedirect: 'https://ignored.example/auth/confirmed',
        ),
        'http://localhost:49311/auth/confirmed',
      );
    });
  });

  testWidgets('email confirmation page explains success and offers sign in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EmailConfirmedScreen(isVerifiedOverride: true)),
    );

    expect(find.text('Email verified successfully.'), findsOneWidget);
    expect(
      find.text('Your IndustryHub account is now active.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
