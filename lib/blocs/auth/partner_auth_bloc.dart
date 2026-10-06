import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/partner_model.dart';
import '../../data/repositories/partner_auth_repository.dart';
import '../../services/fcm_service.dart';

// ─── STATES ───────────────────────────────────────────────────
abstract class PartnerAuthState {}
class AuthInitial extends PartnerAuthState {}
class AuthLoading extends PartnerAuthState {}
class AuthAuthenticated extends PartnerAuthState {
  final PartnerUser user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends PartnerAuthState {}
class AuthError extends PartnerAuthState {
  final String message;
  AuthError(this.message);
}
// — keeps user on splash with retry option instead of dumping to login
class AuthNetworkError extends PartnerAuthState {
  final String message;
  AuthNetworkError(this.message);
}

// ─── EVENTS ───────────────────────────────────────────────────
abstract class PartnerAuthEvent {}
class AuthCheckRequested extends PartnerAuthEvent {}
class GoogleSignInRequested extends PartnerAuthEvent {}
class LogoutRequested extends PartnerAuthEvent {}

// ─── BLOC ─────────────────────────────────────────────────────
class PartnerAuthBloc extends Bloc<PartnerAuthEvent, PartnerAuthState> {
  final PartnerAuthRepository authRepository;

  PartnerAuthBloc({required this.authRepository}) : super(AuthInitial()) {

    // ─── App Load — validate token with server ────────────
    on<AuthCheckRequested>((event, emit) async {
      try {
        await Future.delayed(const Duration(milliseconds: 1500));

        // validateToken() hits /auth/profile, tries refresh on 401,
        // and falls back to cached user on network errors.
        final user = await authRepository.validateToken();

        if (user != null) {
          await PartnerFCMService.init();
          await PartnerFCMService.initAndSendToken();
          emit(AuthAuthenticated(user));
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        // Emit AuthNetworkError so splash can show a retry button.
        print('❌ Auth check failed: $e');
        emit(AuthNetworkError('Could not verify session: $e'));
      }
    });

    // ─── Google Sign-In ────────────────────────────────────
    on<GoogleSignInRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        print('Starting Google Sign-In for partner...');
        final user = await authRepository.signInWithGoogle();
        await authRepository.saveUserLocally(user);
        await PartnerFCMService.init();
        await PartnerFCMService.initAndSendToken();
        emit(AuthAuthenticated(user));
      } catch (e) {
        print('❌ Google Sign-In Error: $e');
        emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
      }
    });

    // ─── Logout ────────────────────────────────────────────
    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      await PartnerFCMService.clearTokenOnLogout();
      await authRepository.logout();
      emit(AuthUnauthenticated());
    });
  }
}