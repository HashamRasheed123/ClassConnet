import 'dart:convert';
import 'dart:io';
import '../../models/models.dart';

class QuizImportResult {
  final String? title;
  final String? description;
  final List<QuizQuestionModel> questions;
  final bool requiresManualPaste;
  final String message;

  const QuizImportResult({
    this.title,
    this.description,
    required this.questions,
    this.requiresManualPaste = false,
    required this.message,
  });
}

class QuizImportService {
  /// Ready-to-use prompt an Admin can copy in 1 tap and paste into Google NotebookLM
  /// (or any AI assistant) to export all quiz questions, options, correct answers,
  /// and explanations into a clean format our parser instantly imports.
  static const String notebookLmExportPrompt =
      'Export all MCQ quiz questions, options (A, B, C, D), the correct option, '
      'and explanations from this NotebookLM Quiz as a JSON array in this exact format:\n'
      '[\n'
      '  {\n'
      '    "question": "Question text here?",\n'
      '    "options": ["Option A", "Option B", "Option C", "Option D"],\n'
      '    "correctOptionIndex": 0,\n'
      '    "explanation": "Brief rationale why this answer is correct",\n'
      '    "hint": "Optional hint"\n'
      '  }\n'
      ']';

  /// Attempts to pull quiz questions & answers directly from a shared URL
  /// (such as `https://notebooklm.link.google/ELuWPoJL1iNe`, a JSON endpoint,
  /// or an HTML/Markdown page).
  static Future<QuizImportResult> importFromUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const QuizImportResult(
        questions: [],
        requiresManualPaste: true,
        message: 'Please enter a valid Quiz or NotebookLM URL.',
      );
    }

    final normalizedUrl =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.host.isEmpty) {
      return const QuizImportResult(
        questions: [],
        requiresManualPaste: true,
        message: 'Invalid URL format.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent =
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

    try {
      var currentUri = uri;
      HttpClientResponse? response;
      String finalUrl = normalizedUrl;

      for (int redirectCount = 0; redirectCount < 6; redirectCount++) {
        final request = await client.getUrl(currentUri);
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/json,text/plain;q=0.9,*/*;q=0.8',
        );
        final res = await request.close().timeout(const Duration(seconds: 12));
        response = res;
        if (res.isRedirect ||
            res.statusCode == 301 ||
            res.statusCode == 302 ||
            res.statusCode == 303 ||
            res.statusCode == 307 ||
            res.statusCode == 308) {
          final location = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>();
          if (location == null || location.isEmpty) break;
          currentUri = currentUri.resolve(location);
          finalUrl = currentUri.toString();
          continue;
        }
        break;
      }

      if (response == null) {
        return const QuizImportResult(
          questions: [],
          requiresManualPaste: true,
          message:
              'Could not reach the link. Use Smart Paste below to import the MCQs.',
        );
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 12));

      final pageTitle = _extractHtmlTitle(body);

      // 1. Check if it redirected to Google Sign-In wall
      if (finalUrl.contains('accounts.google.com') ||
          body.contains('accounts.google.com/ServiceLogin') ||
          body.contains('Sign in - Google Accounts')) {
        return QuizImportResult(
          title: pageTitle != null &&
                  !pageTitle.toLowerCase().contains('sign in') &&
                  !pageTitle.toLowerCase().contains('google accounts')
              ? pageTitle
              : 'NotebookLM Practice Quiz',
          description: 'Imported from Google NotebookLM ($normalizedUrl)',
          questions: const [],
          requiresManualPaste: true,
          message:
              'Google NotebookLM links require your Google login session in the browser. '
              'Tap "Open Link in Browser" or "Smart Paste MCQs" below to paste the copied quiz questions or JSON in 1 tap!',
        );
      }

      // 2. Try direct JSON or embedded AF_initDataCallback / script JSON extraction
      final parsedDirect = parseQuizContent(body);
      if (parsedDirect.isNotEmpty) {
        return QuizImportResult(
          title: pageTitle ?? 'NotebookLM Quiz',
          description: 'Pulled from $normalizedUrl',
          questions: parsedDirect,
          requiresManualPaste: false,
          message:
              'Successfully pulled ${parsedDirect.length} MCQ questions from link!',
        );
      }

      // 3. Try stripping HTML tags to plain text and parsing MCQ structure
      final strippedText = _stripHtmlToText(body);
      final parsedFromHtmlText = parseQuizContent(strippedText);
      if (parsedFromHtmlText.isNotEmpty) {
        return QuizImportResult(
          title: pageTitle ?? 'Imported Quiz',
          description: 'Pulled from $normalizedUrl',
          questions: parsedFromHtmlText,
          requiresManualPaste: false,
          message:
              'Successfully extracted ${parsedFromHtmlText.length} MCQs from page!',
        );
      }

      return QuizImportResult(
        title: pageTitle ?? 'NotebookLM Quiz',
        description: 'Source: $normalizedUrl',
        questions: const [],
        requiresManualPaste: true,
        message:
            'Link attached! Because NotebookLM renders quiz cards dynamically inside your signed-in browser session, '
            'open the link and paste the copied quiz text or JSON into the Smart Importer below.',
      );
    } catch (e) {
      return QuizImportResult(
        title: 'NotebookLM Quiz',
        description: 'Source: $normalizedUrl',
        questions: const [],
        requiresManualPaste: true,
        message:
            'Link saved! To pull the questions into the app, paste the copied quiz text or JSON in the Smart Importer below.',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Universal parser that accepts:
  /// - JSON array or object (NotebookLM ExportKit JSON, Gemini JSON, custom JSON)
  /// - Plain text / Markdown copied directly from a NotebookLM quiz, doc, or chat
  static List<QuizQuestionModel> parseQuizContent(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return const [];

    // 1. Try JSON parsing (including fenced ```json ... ``` blocks)
    final fromJson = _tryParseJsonQuestions(trimmed);
    if (fromJson.isNotEmpty) return fromJson;

    // 2. Try parsing plain text / Markdown MCQs
    return _parseTextQuestions(trimmed);
  }

  static List<QuizQuestionModel> _tryParseJsonQuestions(String input) {
    final candidates = <String>[input];

    // Extract ```json ... ``` or ``` ... ``` blocks if present
    final codeFenceRegex =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    for (final match in codeFenceRegex.allMatches(input)) {
      final block = match.group(1)?.trim();
      if (block != null && block.isNotEmpty) {
        candidates.add(block);
      }
    }

    // Also try locating the outermost JSON array `[...]` or object `{...}`
    final firstBracket = input.indexOf('[');
    final lastBracket = input.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      candidates.add(input.substring(firstBracket, lastBracket + 1));
    }
    final firstBrace = input.indexOf('{');
    final lastBrace = input.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      candidates.add(input.substring(firstBrace, lastBrace + 1));
    }

    for (final candidate in candidates) {
      for (final attempt in [candidate, _sanitizeAiJson(candidate)]) {
        try {
          final decoded = jsonDecode(attempt);
          final extracted = _extractQuestionsFromDecodedJson(decoded);
          if (extracted.isNotEmpty) return extracted;
        } catch (_) {
          // Continue to next candidate
        }
      }
    }
    return const [];
  }

  /// Cleans invalid JSON escape sequences and HTML entities commonly produced
  /// when copying JSON out of NotebookLM, Gemini, or Markdown chat windows
  /// (e.g. `\_`, `\*`, `\.`, `\[`, `\]`, `&gt;`, `&lt;`, `&amp;`, smart quotes).
  static String _sanitizeAiJson(String raw) {
    var s = raw
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', r'\"')
        .replaceAll('&#39;', "'");

    // Remove invalid JSON backslash escapes before characters that are NOT valid JSON escapes
    // Valid JSON escapes after `\` are: `"`, `\`, `/`, `b`, `f`, `n`, `r`, `t`, `u`
    s = s.replaceAllMapped(
      RegExp(r'\\(?![/\"\\bfnrtu])'),
      (_) => '',
    );

    // Remove trailing commas before `]` or `}`
    s = s.replaceAll(RegExp(r',\s*([\]\}])'), r'$1');
    return s;
  }

  static List<QuizQuestionModel> _extractQuestionsFromDecodedJson(
      dynamic decoded) {
    final results = <QuizQuestionModel>[];

    if (decoded is List) {
      for (int i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is Map) {
          final q = _mapToQuizQuestion(
              Map<String, dynamic>.from(item), results.length);
          if (q != null) results.add(q);
        }
      }
      if (results.isNotEmpty) return results;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      for (final key in const [
        'questions',
        'quiz',
        'items',
        'mcqs',
        'data',
        'cards'
      ]) {
        final nested = map[key];
        if (nested != null) {
          final sub = _extractQuestionsFromDecodedJson(nested);
          if (sub.isNotEmpty) return sub;
        }
      }
      final single = _mapToQuizQuestion(map, 0);
      if (single != null) return [single];
    }
    return results;
  }

  static QuizQuestionModel? _mapToQuizQuestion(
      Map<String, dynamic> map, int index) {
    final questionText = (map['question'] ??
            map['questionText'] ??
            map['prompt'] ??
            map['title'] ??
            map['stem'] ??
            map['q'])
        ?.toString()
        .trim();
    if (questionText == null || questionText.isEmpty) return null;

    final rawOptions = map['options'] ??
        map['choices'] ??
        map['answers'] ??
        map['answerOptions'] ??
        map['alternatives'];

    final options = <String>[];
    int? detectedCorrectIndex;
    String? detectedExplanation;

    if (rawOptions is List) {
      for (int i = 0; i < rawOptions.length; i++) {
        final opt = rawOptions[i];
        if (opt is String) {
          options.add(_cleanOptionPrefix(opt));
        } else if (opt is Map) {
          final optMap = Map<String, dynamic>.from(opt);
          final text = (optMap['text'] ??
                  optMap['label'] ??
                  optMap['option'] ??
                  optMap['value'] ??
                  optMap['answer'] ??
                  '')
              .toString()
              .trim();
          if (text.isNotEmpty) {
            options.add(_cleanOptionPrefix(text));
            final isCorrect = optMap['isCorrect'] == true ||
                optMap['is_correct'] == true ||
                optMap['correct'] == true;
            if (isCorrect) {
              detectedCorrectIndex = options.length - 1;
              final rationale =
                  optMap['rationale'] ?? optMap['explanation'] ?? optMap['feedback'];
              if (rationale != null &&
                  rationale.toString().trim().isNotEmpty) {
                detectedExplanation = rationale.toString().trim();
              }
            }
          }
        }
      }
    } else {
      // Check keys A, B, C, D or optionA, optionB, etc.
      for (final key in const [
        'A',
        'B',
        'C',
        'D',
        'a',
        'b',
        'c',
        'd',
        'optionA',
        'optionB',
        'optionC',
        'optionD',
        'option_a',
        'option_b',
        'option_c',
        'option_d',
      ]) {
        if (map[key] != null && map[key].toString().trim().isNotEmpty) {
          options.add(map[key].toString().trim());
        }
      }
    }

    if (options.length < 2) return null;

    final rawCorrect = map['correctOptionIndex'] ??
        map['correct_option_index'] ??
        map['correctIndex'] ??
        map['correct_index'] ??
        map['correctAnswer'] ??
        map['correct_answer'] ??
        map['answer'] ??
        map['correct'];

    int correctIdx = detectedCorrectIndex ?? 0;
    if (detectedCorrectIndex == null && rawCorrect != null) {
      correctIdx = _resolveAnswerIndex(rawCorrect, options);
    }

    final explanation = (map['explanation'] ??
            map['rationale'] ??
            map['feedback'] ??
            detectedExplanation)
        ?.toString()
        .trim();
    final hint = map['hint']?.toString().trim();

    return QuizQuestionModel(
      id: map['id']?.toString() ??
          'q_${DateTime.now().microsecondsSinceEpoch}_$index',
      question: _unescapeHtmlAndMarkdown(questionText),
      options: options.map(_unescapeHtmlAndMarkdown).toList(),
      correctOptionIndex: correctIdx.clamp(0, options.length - 1),
      explanation: explanation != null && explanation.isNotEmpty
          ? _unescapeHtmlAndMarkdown(explanation)
          : null,
      hint: hint != null && hint.isNotEmpty
          ? _unescapeHtmlAndMarkdown(hint)
          : null,
    );
  }

  static String _unescapeHtmlAndMarkdown(String input) {
    return input
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(r'\_', '_')
        .replaceAll(r'\*', '*')
        .replaceAll(r'\.', '.');
  }

  static int _resolveAnswerIndex(dynamic rawCorrect, List<String> options) {
    if (rawCorrect is int) {
      if (rawCorrect >= 0 && rawCorrect < options.length) return rawCorrect;
      if (rawCorrect >= 1 && rawCorrect <= options.length) {
        return rawCorrect - 1;
      }
    }
    final str = rawCorrect.toString().trim();
    if (str.isEmpty) return 0;

    final asInt = int.tryParse(str);
    if (asInt != null) {
      if (asInt >= 0 && asInt < options.length) return asInt;
      if (asInt >= 1 && asInt <= options.length) return asInt - 1;
    }

    // Single letter A/B/C/D or "Option B"
    final letterMatch = RegExp(
            r'^(?:option\s*)?([A-Fa-f])(?:[\.\)\:\s]|$)',
            caseSensitive: false)
        .firstMatch(str);
    if (letterMatch != null) {
      final code = letterMatch.group(1)!.toUpperCase().codeUnitAt(0) - 65;
      if (code >= 0 && code < options.length) return code;
    }

    // Exact or substring match against option text
    final cleanedTarget = _cleanOptionPrefix(str).toLowerCase();
    for (int i = 0; i < options.length; i++) {
      final optLower = options[i].toLowerCase();
      if (optLower == cleanedTarget ||
          optLower.contains(cleanedTarget) ||
          cleanedTarget.contains(optLower)) {
        return i;
      }
    }
    return 0;
  }

  static List<QuizQuestionModel> _parseTextQuestions(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final questions = <QuizQuestionModel>[];
    String? currentQuestion;
    List<String> currentOptions = [];
    int? currentCorrectIdx;
    String? currentExplanation;
    String? currentHint;

    void flushCurrent() {
      if (currentQuestion != null &&
          currentQuestion!.trim().isNotEmpty &&
          currentOptions.length >= 2) {
        questions.add(
          QuizQuestionModel(
            id: 'q_${DateTime.now().microsecondsSinceEpoch}_${questions.length}',
            question: currentQuestion!.trim(),
            options: List<String>.from(currentOptions),
            correctOptionIndex:
                (currentCorrectIdx ?? 0).clamp(0, currentOptions.length - 1),
            explanation: currentExplanation?.trim().isNotEmpty == true
                ? currentExplanation!.trim()
                : null,
            hint: currentHint?.trim().isNotEmpty == true
                ? currentHint!.trim()
                : null,
          ),
        );
      }
      currentQuestion = null;
      currentOptions = [];
      currentCorrectIdx = null;
      currentExplanation = null;
      currentHint = null;
    }

    final questionHeaderRegex = RegExp(
      r'^(?:#+\s*)?(?:\*\*)?(?:Q(?:uestion)?\s*\d+|(?:\d+)[\.\)\:])(?:\*\*)?\s+(.+)$',
      caseSensitive: false,
    );
    final optionLineRegex = RegExp(
      r'^\s*(?:[-*•]\s*)?(?:\*\*|\[)?([A-Da-d])(?:\*\*|\])?[\.\)\:\-]\s+(.+)$',
    );
    final checkboxOptionRegex = RegExp(
      r'^\s*[-*•]?\s*\[([xX\s✓✔])\]\s*(?:[A-Da-d][\.\)\:\-]\s*)?(.+)$',
    );
    final answerLineRegex = RegExp(
      r'^\s*(?:\*\*)?(?:Correct\s*Answer|Answer|Correct|Ans|Key)(?:\*\*)?\s*[\:\-]\s*(.+)$',
      caseSensitive: false,
    );
    final explanationLineRegex = RegExp(
      r'^\s*(?:\*\*)?(?:Explanation|Rationale|Reason|Feedback|Why)(?:\*\*)?\s*[\:\-]\s*(.+)$',
      caseSensitive: false,
    );
    final hintLineRegex = RegExp(
      r'^\s*(?:\*\*)?(?:Hint|Tip)(?:\*\*)?\s*[\:\-]\s*(.+)$',
      caseSensitive: false,
    );

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // 1. Check Answer line
      final ansMatch = answerLineRegex.firstMatch(line);
      if (ansMatch != null && currentOptions.isNotEmpty) {
        currentCorrectIdx =
            _resolveAnswerIndex(ansMatch.group(1)!.trim(), currentOptions);
        continue;
      }

      // 2. Check Explanation line
      final expMatch = explanationLineRegex.firstMatch(line);
      if (expMatch != null && currentQuestion != null) {
        final expText = expMatch.group(1)!.trim();
        currentExplanation = currentExplanation == null
            ? expText
            : '$currentExplanation $expText';
        continue;
      }

      // 3. Check Hint line
      final hintMatch = hintLineRegex.firstMatch(line);
      if (hintMatch != null && currentQuestion != null) {
        currentHint = hintMatch.group(1)!.trim();
        continue;
      }

      // 4. Check Checkbox option `[x] Option text`
      final cbMatch = checkboxOptionRegex.firstMatch(line);
      if (cbMatch != null && currentQuestion != null) {
        final marker = cbMatch.group(1)!.trim();
        final optText = _cleanInlineCorrectMarker(cbMatch.group(2)!.trim());
        currentOptions.add(optText.text);
        if (marker.isNotEmpty || optText.isCorrect) {
          currentCorrectIdx = currentOptions.length - 1;
        }
        continue;
      }

      // 5. Check standard A) / B. / C: option line
      final optMatch = optionLineRegex.firstMatch(line);
      if (optMatch != null && currentQuestion != null) {
        final rawOpt = optMatch.group(2)!.trim();
        final cleaned = _cleanInlineCorrectMarker(rawOpt);
        currentOptions.add(cleaned.text);
        if (cleaned.isCorrect) {
          currentCorrectIdx = currentOptions.length - 1;
        }
        continue;
      }

      // 6. Check numbered Question header (`1. What is...` or `Q1: What is...`)
      final qMatch = questionHeaderRegex.firstMatch(line);
      if (qMatch != null) {
        if (currentQuestion != null && currentOptions.length >= 2) {
          flushCurrent();
        }
        currentQuestion = qMatch.group(1)!.replaceAll('**', '').trim();
        continue;
      }

      // 7. Also support unnumbered questions that end with `?` when starting a new block
      if (line.endsWith('?') &&
          (currentQuestion == null || currentOptions.length >= 2)) {
        if (currentQuestion != null && currentOptions.length >= 2) {
          flushCurrent();
        }
        currentQuestion = line.replaceAll('**', '').trim();
        continue;
      }

      // 8. Continuation of question text if options haven't started yet
      if (currentQuestion != null && currentOptions.isEmpty) {
        currentQuestion = '$currentQuestion $line';
      }
    }

    flushCurrent();
    return questions;
  }

  static ({String text, bool isCorrect}) _cleanInlineCorrectMarker(
      String rawOption) {
    var text = rawOption.trim();
    bool isCorrect = false;

    final markers = [
      RegExp(r'\s*\((?:correct|correct answer|right|true)\)\s*$',
          caseSensitive: false),
      RegExp(r'\s*\[(?:correct|correct answer|right|true)\]\s*$',
          caseSensitive: false),
      RegExp(r'\s*[✓✔✅]\s*$'),
      RegExp(r'^\*\s+'),
    ];

    for (final regex in markers) {
      if (regex.hasMatch(text)) {
        isCorrect = true;
        text = text.replaceAll(regex, '').trim();
      }
    }

    if (text.startsWith('**') && text.endsWith('**') && text.length > 4) {
      isCorrect = true;
      text = text.substring(2, text.length - 2).trim();
    }

    return (text: text, isCorrect: isCorrect);
  }

  static String _cleanOptionPrefix(String raw) {
    return raw
        .trim()
        .replaceFirst(
          RegExp(r'^(?:[A-Da-d][\.\)\:\-]\s*)'),
          '',
        )
        .trim();
  }

  static String? _extractHtmlTitle(String html) {
    final ogTitle = RegExp(
      r'''<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogTitle != null && ogTitle.group(1)!.trim().isNotEmpty) {
      return ogTitle.group(1)!.trim();
    }
    final titleTag = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleTag != null && titleTag.group(1)!.trim().isNotEmpty) {
      return titleTag.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return null;
  }

  static String _stripHtmlToText(String html) {
    return html
        .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6]|tr)>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
