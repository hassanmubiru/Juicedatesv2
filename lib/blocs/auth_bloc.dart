import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent {}
class AuthCheckRequested extends AuthEvent {}
class AuthLoggedIn extends AuthEvent {
  final User user;
  AuthLoggedIn(this.user);
}
class AuthLoggedOut extends AuthEvent {}

abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthInProgress extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) {
      final user = _auth.currentUser;
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<AuthLoggedIn>((event, emit) => emit(AuthAuthenticated(event.user)));
    on<AuthLoggedOut>((event, emit) async {
      await _auth.signOut();
      emit(AuthUnauthenticated());
    });
  }
}
