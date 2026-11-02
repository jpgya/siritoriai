class KanaUtils {
  /// カタカナをひひらがなに変換
  static String kataToHira(String input) {
    return input.replaceAllMapped(RegExp(r'[\u30a1-\u30f6]'), (match) {
      return String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60);
    });
  }

  /// 長音や小文字の表記揺れを補正した平仮名文字列を取得
  static String normalizeString(String input) {
    String hira = kataToHira(input.trim());
    // 不要な記号やスペースを除去
    hira = hira.replaceAll(RegExp(r'[^\u3041-\u3096\u30fc]'), '');
    return hira;
  }

  /// 単語の開始文字（ひらがな1文字）を取得
  static String getStartKana(String input) {
    String normalized = normalizeString(input);
    if (normalized.isEmpty) return '';
    
    String first = normalized[0];
    return normalizeKana(first);
  }

  /// 単語の終了文字（ひらがな1文字）を取得
  static String getEndKana(String input) {
    String normalized = normalizeString(input);
    if (normalized.isEmpty) return '';

    // 末尾が長音「ー」の場合、その1つ前の文字を見る
    int idx = normalized.length - 1;
    while (idx >= 0 && normalized[idx] == 'ー') {
      idx--;
    }
    if (idx < 0) return '';

    String last = normalized[idx];
    return normalizeKana(last);
  }

  /// 促音・拗音などの小文字を大文字に正規化（例: ゃ->や, っ->つ）
  static String normalizeKana(String kana) {
    const smallToLarge = {
      'ぁ': 'あ', 'ぃ': 'い', 'ぅ': 'う', 'ぇ': 'え', 'ぉ': 'お',
      'ゃ': 'や', 'ゅ': 'ゆ', 'ょ': 'よ',
      'っ': 'つ', 'ゎ': 'わ',
      'ァ': 'あ', 'ィ': 'い', 'ゥ': 'う', 'ェ': 'え', 'ォ': 'お',
      'ャ': 'や', 'ュ': 'ゆ', 'ョ': 'よ',
      'ッ': 'つ', 'ヮ': 'わ',
    };
    return smallToLarge[kana] ?? kana;
  }

  /// 濁点・半濁点を除去した基本文字を取得（例: が->か, ぱ->は）
  static String stripVoicedSoundMark(String kana) {
    const voicedMap = {
      'が': 'か', 'ぎ': 'き', 'ぐ': 'く', 'げ': 'け', 'ご': 'こ',
      'ざ': 'さ', 'じ': 'し', 'ず': 'す', 'ぜ': 'せ', 'ぞ': 'そ',
      'だ': 'た', 'ぢ': 'ち', 'づ': 'つ', 'で': 'て', 'ど': 'と',
      'ば': 'は', 'び': 'ひ', 'ぶ': 'ふ', 'べ': 'へ', 'ぼ': 'ほ',
      'ぱ': 'は', 'ぴ': 'ひ', 'ぷ': 'ふ', 'ぺ': 'へ', 'ぽ': 'ほ',
      'ヴ': 'う',
    };
    return voicedMap[kana] ?? kana;
  }

  /// 「ん」で終わっているか確認
  static bool endsWithN(String input) {
    String end = getEndKana(input);
    return end == 'ん' || end == 'ン';
  }

  /// しりとりとして繋がっているか検証
  /// [lastWordEndKana]: 前の単語の末尾文字
  /// [nextWordStartKana]: 次の単語の先頭文字
  /// [allowVoicedConversion]: 濁点・半濁点外しを許可するか
  static bool isValidConnection({
    required String lastWordEndKana,
    required String nextWordStartKana,
    bool allowVoicedConversion = true,
  }) {
    String normEnd = normalizeKana(lastWordEndKana);
    String normStart = normalizeKana(nextWordStartKana);

    if (normEnd == normStart) return true;

    if (allowVoicedConversion) {
      if (stripVoicedSoundMark(normEnd) == stripVoicedSoundMark(normStart)) {
        return true;
      }
    }
    return false;
  }
}
