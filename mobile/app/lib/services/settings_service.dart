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

  Future<String> getOperatorId() async {
    await init();
    return _prefs!.getString(_keyOperatorId) ?? '';
  }

  Future<String> getSheetId() async {
    await init();
    return _prefs!.getString(_keySheetId) ?? '';
  }

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
