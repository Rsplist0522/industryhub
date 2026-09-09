import 'package:supabase_flutter/supabase_flutter.dart';

const unverifiedEmailSignInMessage =
    'Please verify your email address before signing in.';

const safeSignupConfirmationMessage =
    'If this is a new email, a confirmation link has been sent. '
    'If you already have an account, please sign in.';

bool hasVerifiedAuthAccess({
  required bool hasSession,
  required String? emailConfirmedAt,
}) => hasSession && emailConfirmedAt != null;

bool hasVerifiedSupabaseSession(SupabaseClient client) => hasVerifiedAuthAccess(
  hasSession: client.auth.currentSession != null,
  emailConfirmedAt: client.auth.currentUser?.emailConfirmedAt,
);

bool isEmailNotConfirmedError(AuthException error) {
  final message = error.message.toLowerCase();
  return message.contains('email not confirmed') ||
      message.contains('email_not_confirmed');
}

bool isExistingAccountSignupError(AuthException error) {
  final message = error.message.toLowerCase();
  return message.contains('already registered') ||
      message.contains('already exists') ||
      message.contains('user_already_exists');
}
