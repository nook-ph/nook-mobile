import 'package:nook/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:nook/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:nook/features/auth/domain/use_cases/check_email_exists_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/delete_account_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/get_current_session_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_apple_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_google_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_in_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/resend_signup_otp_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_out_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/sign_up_with_email_usecase.dart';
import 'package:nook/features/auth/domain/use_cases/verify_signup_otp_usecase.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';

class AuthInjection {
  AuthInjection._();

  static final SupabaseAuthRemoteDataSource _remoteDataSource =
      SupabaseAuthRemoteDataSource();

  static final AuthRepository _authRepository = AuthRepositoryImpl(
    _remoteDataSource,
  );

  static final CheckEmailExistsUseCase _checkEmailExistsUseCase =
      CheckEmailExistsUseCase(_authRepository);

  static final SignUpWithEmailUseCase _signUpWithEmailUseCase =
      SignUpWithEmailUseCase(_authRepository);

  static final SignInWithEmailUseCase _signInWithEmailUseCase =
      SignInWithEmailUseCase(_authRepository);

  static final VerifySignupOtpUseCase _verifySignupOtpUseCase =
      VerifySignupOtpUseCase(_authRepository);

  static final ResendSignupOtpUseCase _resendSignupOtpUseCase =
      ResendSignupOtpUseCase(_authRepository);

  static final SignInWithAppleUsecase _signInWithAppleUsecase =
      SignInWithAppleUsecase(_authRepository);

  static final SignInWithGoogleUseCase _signInWithGoogleUseCase =
      SignInWithGoogleUseCase(_authRepository);

  static final SignOutUseCase _signOutUseCase = SignOutUseCase(_authRepository);

  static final DeleteAccountUseCase _deleteAccountUseCase =
      DeleteAccountUseCase(_authRepository);

  static final GetCurrentSessionUseCase _getCurrentSessionUseCase =
      GetCurrentSessionUseCase(_authRepository);

  static AuthRepository get authRepository => _authRepository;

  static AuthBloc createAuthBloc({required ListsBloc listsBloc}) {
    return AuthBloc(
      checkEmailExistsUseCase: _checkEmailExistsUseCase,
      signUpWithEmailUseCase: _signUpWithEmailUseCase,
      signInWithEmailUseCase: _signInWithEmailUseCase,
      verifySignupOtpUseCase: _verifySignupOtpUseCase,
      resendSignupOtpUseCase: _resendSignupOtpUseCase,
      signInWithAppleUseCase: _signInWithAppleUsecase,
      signInWithGoogleUseCase: _signInWithGoogleUseCase,
      signOutUseCase: _signOutUseCase,
      deleteAccountUseCase: _deleteAccountUseCase,
      getCurrentSessionUseCase: _getCurrentSessionUseCase,
      listsBloc: listsBloc,
    );
  }
}
