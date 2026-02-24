import 'package:flutter/material.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  static const routeName = '/ocr';

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _dataNascitaController = TextEditingController();
  bool _ocrModified = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _dataNascitaController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nomeController.text.trim().isEmpty ||
        _cognomeController.text.trim().isEmpty ||
        _dataNascitaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila nome, cognome e data di nascita.')),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leggi Anagrafica')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Fase 4 in corso: OCR manoscritto da integrare. Qui e pronta la schermata di revisione operatore.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nomeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Nome',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cognomeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Cognome',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dataNascitaController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Data di nascita',
              hintText: 'GG/MM/AAAA',
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dato OCR modificato manualmente'),
            value: _ocrModified,
            onChanged: (value) {
              setState(() {
                _ocrModified = value ?? false;
              });
            },
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Conferma e salva'),
          ),
        ],
      ),
    );
  }
}
