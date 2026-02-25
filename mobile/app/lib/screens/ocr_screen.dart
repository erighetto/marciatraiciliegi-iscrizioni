import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marcia_mobile/models/acquisition_record.dart';
import 'package:marcia_mobile/models/flow_payload.dart';
import 'package:marcia_mobile/services/ocr_parser_service.dart';
import 'package:marcia_mobile/services/sync_queue_service.dart';

/// Fasi della schermata OCR: acquisizione foto, revisione campi, errore OCR.
enum _OcrPhase { capture, review, error }

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
  String _operatorId = '';

  _OcrPhase _phase = _OcrPhase.capture;
  bool _isLoading = false;
  String _errorMessage = '';

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _dataNascitaController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as FlowPayload?;
    if (args != null && _operatorId.isEmpty) _operatorId = args.operatorId;
  }

  Future<void> _takePhotoAndRecognize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      final rawText = recognizedText.text.trim();

      if (rawText.isEmpty) {
        setState(() {
          _phase = _OcrPhase.error;
          _errorMessage = 'Nessun testo riconosciuto. Riprova con una foto più leggibile.';
          _isLoading = false;
        });
        return;
      }

      final parsed = OcrParserService.parse(rawText);
      _nomeController.text = parsed.nome;
      _cognomeController.text = parsed.cognome;
      _dataNascitaController.text = parsed.dataNascita;
      _ocrModified = false;

      setState(() {
        _phase = _OcrPhase.review;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _OcrPhase.error;
          _errorMessage = 'Errore durante l\'OCR: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _phase = _OcrPhase.capture;
      _errorMessage = '';
      _nomeController.clear();
      _cognomeController.clear();
      _dataNascitaController.clear();
      _ocrModified = false;
    });
  }

  void _manualEntry() {
    setState(() {
      _phase = _OcrPhase.review;
      _errorMessage = '';
      _nomeController.clear();
      _cognomeController.clear();
      _dataNascitaController.clear();
      _ocrModified = false;
    });
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

    final record = AcquisitionRecord(
      type: RecordType.anagrafica,
      operatorId: _operatorId.isEmpty ? 'operatore' : _operatorId,
      payload: {
        'nome': _nomeController.text.trim(),
        'cognome': _cognomeController.text.trim(),
        'dataNascita': _dataNascitaController.text.trim(),
        'ocrModificato': _ocrModified,
        'metodoInserimento': 'ocr',
      },
      timestampIso: DateTime.now().toIso8601String(),
    );
    SyncQueueService.instance.enqueue(record);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analisi OCR in corso...'),
            ],
          ),
        ),
      );
    }

    if (_phase == _OcrPhase.error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ritenta foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _manualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Inserimento manuale'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      );
    }

    if (_phase == _OcrPhase.capture) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Inquadra il documento con nome, cognome e data di nascita, poi scatta la foto.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Icon(Icons.document_scanner, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _takePhotoAndRecognize,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scatta foto'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      );
    }

    // _OcrPhase.review
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisione anagrafica'),
        actions: [
          TextButton(
            onPressed: _retakePhoto,
            child: const Text('Ritenta foto'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Verifica e correggi i campi riconosciuti dall\'OCR.',
            style: TextStyle(fontSize: 14),
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
              setState(() => _ocrModified = value ?? false);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Conferma e salva'),
          ),
        ],
      ),
    );
  }
}
