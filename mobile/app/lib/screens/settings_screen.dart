import 'package:flutter/material.dart';

class SettingsPayload {
  const SettingsPayload({required this.operatorId, required this.sheetId});

  final String operatorId;
  final String sheetId;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _operatorController = TextEditingController();
  final _sheetController = TextEditingController();

  @override
  void dispose() {
    _operatorController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as SettingsPayload?;

    if (args != null && _operatorController.text.isEmpty) {
      _operatorController.text = args.operatorId;
      _sheetController.text = args.sheetId;
    }
  }

  void _save() {
    Navigator.of(context).pop(
      SettingsPayload(
        operatorId: _operatorController.text,
        sheetId: _sheetController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _operatorController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Identificativo operatore',
              hintText: 'Nome o codice operatore',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sheetController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'ID o URL Google Sheet',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Salva impostazioni'),
          ),
        ],
      ),
    );
  }
}
