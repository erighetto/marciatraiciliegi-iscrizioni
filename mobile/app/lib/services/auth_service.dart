import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Client HTTP che inietta il Bearer token di Google Sign-In in ogni request.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Su Android il clientId non va nel costruttore: viene riconosciuto
  // automaticamente tramite SHA-1 + package name registrati su Google Cloud Console.
  // Il clientId dal .env è usato solo se si implementa il flusso server-side.
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'https://www.googleapis.com/auth/spreadsheets',
    ],
  );

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  /// Tenta il login silenzioso (token già salvato) prima di aprire il popup.
  Future<bool> signInSilently() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser != null;
  }

  /// Apre il flusso di login interattivo Google.
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      debugPrint('[AuthService] signIn: utente=${_currentUser?.email}');
      return _currentUser != null;
    } catch (e) {
      debugPrint('[AuthService] signIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Restituisce un http.Client autenticato da usare con il package googleapis.
  Future<http.Client?> getAuthClient() async {
    if (_currentUser == null) {
      debugPrint('[AuthService] getAuthClient: nessun utente loggato');
      return null;
    }
    try {
      final auth = await _currentUser!.authentication;
      if (auth.accessToken == null) {
        debugPrint('[AuthService] getAuthClient: accessToken nullo');
        return null;
      }
      debugPrint('[AuthService] getAuthClient: token OK per ${_currentUser!.email}');
      return _GoogleAuthClient({'Authorization': 'Bearer ${auth.accessToken}'});
    } catch (e) {
      debugPrint('[AuthService] getAuthClient error: $e');
      return null;
    }
  }
}
