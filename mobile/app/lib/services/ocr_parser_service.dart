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
///
/// Ottimizzato per moduli con etichette stampate ("Nome:", "Cognome:", "Data di nascita:")
/// e valori scritti a mano nella stessa riga o nella riga successiva.
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

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      // ---- Data di nascita ----
      if (RegExp(r'nasc|nato|nata', caseSensitive: false).hasMatch(lineLower)) {
        var dateMatch = _datePattern.firstMatch(line);
        // Valore sulla riga successiva se non nella stessa
        if (dateMatch == null && i + 1 < lines.length) {
          dateMatch = _datePattern.firstMatch(lines[i + 1]);
        }
        if (dateMatch != null) {
          dataNascita = _normalizeDate(dateMatch);
        }
        continue;
      }

      // ---- Cognome (controlla prima di "nome" perché "cognome" contiene "nome") ----
      if (RegExp(r'^cognome', caseSensitive: false).hasMatch(lineLower)) {
        final value = _valueAfterColon(line);
        if (value.isNotEmpty) {
          cognome = value;
        } else if (i + 1 < lines.length && _isNameLine(lines[i + 1])) {
          cognome = lines[i + 1].trim();
        }
        continue;
      }

      // ---- Nome ----
      if (RegExp(r'^nome', caseSensitive: false).hasMatch(lineLower)) {
        final value = _valueAfterColon(line);
        if (value.isNotEmpty) {
          nome = value;
        } else if (i + 1 < lines.length && _isNameLine(lines[i + 1])) {
          nome = lines[i + 1].trim();
        }
        continue;
      }
    }

    // Fallback: cerca data ovunque se non estratta con keyword
    if (dataNascita.isEmpty) {
      final dateMatch = _datePattern.firstMatch(rawText);
      if (dateMatch != null) dataNascita = _normalizeDate(dateMatch);
    }

    return OcrAnagraficaResult(
      nome: nome,
      cognome: cognome,
      dataNascita: dataNascita,
    );
  }

  /// Estrae il testo dopo il ":" su una singola riga.
  /// Rimuove i puntini di riempimento tipici dei moduli stampati (es. "Nome: ....... ANDREA").
  static String _valueAfterColon(String line) {
    final idx = line.indexOf(':');
    if (idx == -1) return '';
    return line
        .substring(idx + 1)
        .replaceAll(RegExp(r'\.{2,}'), '') // elimina "......"
        .replaceAll(RegExp(r'\s{2,}'), ' ') // collassa spazi multipli
        .trim();
  }

  /// True se la riga sembra un nome/cognome scritto a mano
  /// (contiene lettere, non è una keyword di form, non è solo una data).
  static bool _isNameLine(String line) {
    return !_datePattern.hasMatch(line) &&
        !RegExp(r'^(?:nome|cognome|nasc|nato|nata|data)', caseSensitive: false)
            .hasMatch(line) &&
        RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(line);
  }

  /// Normalizza la data al formato GG/MM/AAAA.
  /// Anno a 2 cifre: >30 → 1900s, ≤30 → 2000s.
  static String _normalizeDate(RegExpMatch match) {
    final day = match.group(1)!.padLeft(2, '0');
    final month = match.group(2)!.padLeft(2, '0');
    var year = match.group(3)!;
    if (year.length == 2) {
      final y = int.parse(year);
      year = y > 30 ? '19$year' : '20$year';
    }
    return '$day/$month/$year';
  }
}
