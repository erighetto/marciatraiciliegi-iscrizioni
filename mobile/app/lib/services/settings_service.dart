import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyOperatorId = 'settings_operator_id';
const _keySheetId = 'settings_sheet_id';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Restituisce il valore salvato dall'utente; se non ancora impostato,
  /// usa il default dal .env (GOOGLE_SHEET_ID).
  Future<String> getSheetId() async {
    await init();
    final saved = _prefs!.getString(_keySheetId) ?? '';
    if (saved.isNotEmpty) return saved;
    return dotenv.env['GOOGLE_SHEET_ID'] ?? '';
  }

  Future<String> getOperatorId() async {
    await init();
    return _prefs!.getString(_keyOperatorId) ?? '';
  }

  /// Range foglio tessere dal .env (GOOGLE_SHEET_RANGE_BC).
  String get sheetRangeBC =>
      dotenv.env['GOOGLE_SHEET_RANGE_BC']?.replaceAll("'", '') ?? 'Foglio1!A:J';

  /// Range foglio anagrafiche dal .env (GOOGLE_SHEET_RANGE_OCR).
  String get sheetRangeOCR =>
      dotenv.env['GOOGLE_SHEET_RANGE_OCR']?.replaceAll("'", '') ?? 'Foglio2!A:J';

  /// Client ID OAuth2 dal .env (GOOGLE_CLIENT_ID).
  String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';

  Future<void> setOperatorId(String value) async {
    await init();
    await _prefs!.setString(_keyOperatorId, value);
  }

  Future<void> setSheetId(String value) async {
    await init();
    await _prefs!.setString(_keySheetId, value);
  }

  Future<void> save({required String operatorId, required String sheetId}) async {
    await init();
    await _prefs!.setString(_keyOperatorId, operatorId);
    await _prefs!.setString(_keySheetId, sheetId);
  }
}
