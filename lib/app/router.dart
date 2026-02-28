import 'package:flutter/material.dart';
import 'package:arena/features/home/screens/splash_screen.dart';
import 'package:arena/features/auth/screens/sign_in_screen.dart';
import 'package:arena/features/auth/screens/sign_up_screen.dart';
import 'package:arena/features/auth/screens/verify_email_screen.dart';
import 'package:arena/features/auth/screens/edit_profile_screen.dart';
import 'package:arena/features/auth/screens/forgot_password_screen.dart';
import 'package:arena/features/auth/screens/reset_password_screen.dart';
import 'package:arena/features/hackathons/screens/hackathons_screen.dart';
import 'package:arena/features/notifications/screens/notifications_screen.dart';
import 'package:arena/features/chat/screens/rooms_screen.dart';
import 'package:arena/features/profile/screens/profile_screen.dart';
import 'package:arena/app/shell.dart';

/// Centralised route table for the Arena app.
///
/// Add new routes here — nowhere else. Screens reference route names via the
/// static constants so typos are caught at compile-time.
class AppRouter {
  AppRouter._();

  // Route name constants
  static const splash = '/';
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const verifyEmail = '/verify-email';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const hackathons = '/hackathons';
  static const notifications = '/notifications';
  static const rooms = '/rooms';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  /// Route table consumed by [MaterialApp.routes].
  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        signIn: (_) => const SignInScreen(),
        signUp: (_) => const SignUpScreen(),
        verifyEmail: (_) => const VerifyEmailScreen(),
        home: (_) => const MainShell(),
        profile: (_) => const ProfileScreen(),
        editProfile: (_) => const EditProfileScreen(),
        hackathons: (_) => const HackathonsScreen(),
        notifications: (_) => const NotificationsScreen(),
        rooms: (_) => const RoomsScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        resetPassword: (_) => const ResetPasswordScreen(),
      };
}
