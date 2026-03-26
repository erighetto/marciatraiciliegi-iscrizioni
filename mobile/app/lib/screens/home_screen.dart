import 'package:flutter/material.dart';
import 'package:marcia_mobile/screens/barcode_screen.dart';
import 'package:marcia_mobile/screens/ocr_screen.dart';
import 'package:marcia_mobile/screens/settings_screen.dart';
import 'package:marcia_mobile/models/flow_payload.dart';
import 'package:marcia_mobile/services/auth_service.dart';
import 'package:marcia_mobile/services/settings_service.dart';
import 'package:marcia_mobile/services/sheets_service.dart';
import 'package:marcia_mobile/services/sync_queue_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _sessionRecords = 0;
  String _operatorId = 'Non configurato';
  String _sheetId = 'Non configurato';
  bool _settingsLoaded = false;
  bool _syncing = false;

  final _settings = SettingsService.instance;
  final _syncQueue = SyncQueueService.instance;
  final _auth = AuthService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _trySilentSignIn();
  }

  Future<void> _loadSettings() async {
    final operatorId = await _settings.getOperatorId();
    final sheetId = await _settings.getSheetId();
    if (mounted) {
      setState(() {
        _operatorId = operatorId.trim().isEmpty ? 'Non configurato' : operatorId.trim();
        _sheetId = sheetId.trim().isEmpty ? 'Non configurato' : sheetId.trim();
        _settingsLoaded = true;
      });
    }
  }

  Future<void> _trySilentSignIn() async {
    final ok = await _auth.signInSilently();
    if (ok && mounted) setState(() {});
  }

  Future<void> _signIn() async {
    final ok = await _auth.signIn();
    if (mounted) {
      setState(() {});
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accesso Google non riuscito.')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    if (_syncing || _syncQueue.pendingCount == 0) return;
    setState(() => _syncing = true);
    final sent = await SheetsService.instance.flushQueue(_syncQueue.mutableQueue);
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sent > 0 ? '$sent record inviati a Google Sheets.' : 'Nessun record inviato.')),
      );
    }
  }

  Future<void> _openFlow(String routeName, {Object? arguments}) async {
    final result = await Navigator.of(context).pushNamed(routeName, arguments: arguments);
    if (result is bool && result) {
      setState(() => _sessionRecords += 1);
      // Se autenticato, prova subito il flush
      if (_auth.isSignedIn) await _syncNow();
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).pushNamed(
      SettingsScreen.routeName,
      arguments: SettingsPayload(
        operatorId: _operatorId == 'Non configurato' ? '' : _operatorId,
        sheetId: _sheetId == 'Non configurato' ? '' : _sheetId,
      ),
    );
    if (result is SettingsPayload) {
      await _settings.save(operatorId: result.operatorId, sheetId: result.sheetId);
      if (mounted) {
        setState(() {
          _operatorId = result.operatorId.trim().isEmpty ? 'Non configurato' : result.operatorId.trim();
          _sheetId = result.sheetId.trim().isEmpty ? 'Non configurato' : result.sheetId.trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _syncQueue.pendingCount;
    final isSignedIn = _auth.isSignedIn;
    final userEmail = _auth.currentUser?.email ?? '';

    final statusLabel = isSignedIn
        ? (pendingCount == 0 ? 'Sincronizzato con Sheets' : '$pendingCount record in coda')
        : 'Non autenticato — dati in coda locale';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquisizione Dati'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card stato autenticazione
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                          color: isSignedIn ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    if (isSignedIn) ...[
                      const SizedBox(height: 4),
                      Text(userEmail, style: const TextStyle(fontSize: 13)),
                      if (pendingCount > 0) ...[
                        const SizedBox(height: 8),
                        _syncing
                            ? const LinearProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: _syncNow,
                                icon: const Icon(Icons.sync, size: 18),
                                label: Text('Sincronizza ora ($pendingCount)'),
                              ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    isSignedIn
                        ? TextButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Esci da Google'),
                          )
                        : FilledButton.icon(
                            onPressed: _signIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Accedi con Google'),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card info sessione
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Operatore: $_operatorId'),
                    const SizedBox(height: 4),
                    Text('Foglio: $_sheetId', overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Record sessione: $_sessionRecords'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openFlow(
                BarcodeScreen.routeName,
                arguments: FlowPayload(operatorId: _operatorId == 'Non configurato' ? '' : _operatorId),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Leggi Tessera'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openFlow(
                OcrScreen.routeName,
                arguments: FlowPayload(operatorId: _operatorId == 'Non configurato' ? '' : _operatorId),
              ),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Leggi Anagrafica'),
            ),
            if (!_settingsLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
