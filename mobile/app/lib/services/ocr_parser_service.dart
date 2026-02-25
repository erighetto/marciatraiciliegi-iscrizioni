/// Risultato del parsing OCR per anagrafica (nome, cognome, data di nascita).
class OcrAnagraficaResult {
  const OcrAnagraficaResult({
    this.nome = '',
    this.cognome = '',
    this.dataNascita = '',
  });

  final String nome;
  final String cognome;
  final String dataNascita;

  bool get hasAny => nome.isNotEmpty || cognome.isNotEmpty || dataNascita.isNotEmpty;
}

/// Parsing euristico del testo OCR per estrarre nome, cognome e data di nascita.
/// Cerca keyword ("nato il", "cognome:", "nome:") e pattern data GG/MM/AAAA o GG-MM-AAAA.
class OcrParserService {
  static final _datePattern = RegExp(
    r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b',
  );

  static OcrAnagraficaResult parse(String rawText) {
    if (rawText.trim().isEmpty) return const OcrAnagraficaResult();

    final lines = rawText
        .split(RegExp(r'[\n\r]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String nome = '';
    String cognome = '';
    String dataNascita = '';

    // Cerca "nato il" / "nata il" / "data di nascita" / "nascita"
    final lower = rawText.toLowerCase();
    final natoMatch = RegExp(
      r'(?:nato\s+il|nata\s+il|data\s+di\s+nascita|nascita)[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
      caseSensitive: false,
    ).firstMatch(lower);
    if (natoMatch != null) {
      dataNascita = natoMatch.group(1) ?? '';
    }

    // Cerca qualsiasi data nel testo se non ancora trovata
    if (dataNascita.isEmpty) {
      final dateMatch = _datePattern.firstMatch(rawText);
      if (dateMatch != null) {
        dataNascita = dateMatch.group(0) ?? '';
      }
    }

    // Keyword "cognome:" / "nome:"
    final cognomeMatch = RegExp(r'cognome\s*[:\s]+\s*(\S+(?:\s+\S+)*)', caseSensitive: false).firstMatch(lower);
    if (cognomeMatch != null) cognome = cognomeMatch.group(1)?.trim() ?? '';

    final nomeMatch = RegExp(r'nome\s*[:\s]+\s*(\S+(?:\s+\S+)*)', caseSensitive: false).firstMatch(lower);
    if (nomeMatch != null) nome = nomeMatch.group(1)?.trim() ?? '';

    // Euristica: prime due righe non-numeriche spesso sono nome e cognome
    if (nome.isEmpty && cognome.isEmpty && lines.length >= 2) {
      final nonDate = lines.where((l) => !_datePattern.hasMatch(l) && l.length > 1).toList();
      if (nonDate.isNotEmpty) cognome = nonDate.first;
      if (nonDate.length >= 2) nome = nonDate[1];
    } else if (cognome.isEmpty && lines.isNotEmpty && !_datePattern.hasMatch(lines.first)) {
      cognome = lines.first;
    }

    return OcrAnagraficaResult(
      nome: nome,
      cognome: cognome,
      dataNascita: dataNascita,
    );
  }
}
