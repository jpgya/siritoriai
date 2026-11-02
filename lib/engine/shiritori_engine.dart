import '../models/word.dart';
import '../utils/kana_utils.dart';
import '../utils/word_generator.dart';
import '../data/dictionary.dart';
import '../ai/shiritori_ai.dart';

enum GameStatus {
  playing,
  playerWon,
  aiWon,
  draw,
}

enum MoveSender {
  player,
  ai,
  system,
}

class ShiritoriMessage {
  final MoveSender sender;
  final String text;
  final WordEntry? wordEntry;
  final String? aiComment;
  final DateTime timestamp;

  ShiritoriMessage({
    required this.sender,
    required this.text,
    this.wordEntry,
    this.aiComment,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ShiritoriEngine {
  final List<WordEntry> _dictionary = List.from(DictionaryData.defaultWords);
  final Set<String> _usedReadings = {};
  final List<ShiritoriMessage> _messages = [];

  ShiritoriAI _ai;
  GameStatus _status = GameStatus.playing;
  bool _isPlayerTurn = true;
  String _currentEndKana = '';
  int _turnCount = 0;

  ShiritoriEngine({AIDifficulty difficulty = AIDifficulty.grandmaster})
      : _ai = ShiritoriAI(difficulty: difficulty) {
    _startNewGame();
  }

  // ゲッター
  GameStatus get status => _status;
  bool get isPlayerTurn => _isPlayerTurn;
  String get currentEndKana => _currentEndKana;
  int get turnCount => _turnCount;
  List<ShiritoriMessage> get messages => List.unmodifiable(_messages);
  Set<String> get usedReadings => Set.unmodifiable(_usedReadings);
  AIDifficulty get difficulty => _ai.difficulty;

  /// 難易度変更
  void setDifficulty(AIDifficulty difficulty) {
    _ai = ShiritoriAI(difficulty: difficulty);
  }

  /// ゲームリセット
  void resetGame() {
    _startNewGame();
  }

  void _startNewGame() {
    _usedReadings.clear();
    _messages.clear();
    _status = GameStatus.playing;
    _isPlayerTurn = true;
    _turnCount = 0;
    _currentEndKana = '';

    _messages.add(ShiritoriMessage(
      sender: MoveSender.system,
      text: "【無限対応・最強しりとりAI】\n常に新しい言葉を検索・自動生成するため、AIの言葉が途切れることはありません！好きな言葉を入力してスタート！",
    ));
  }

  /// 指定した頭文字の言葉が辞書に足りない場合、自動的に動的生成して無制限に補填・補充する
  void _ensureWordsAvailable(String startKana) {
    if (startKana.isEmpty) return;

    String normStart = KanaUtils.normalizeKana(startKana);

    // 現在の未試行単語の数をカウント
    int count = _dictionary.where((entry) {
      if (_usedReadings.contains(entry.reading)) return false;
      if (entry.endKana == 'ん') return false;
      return KanaUtils.isValidConnection(
        lastWordEndKana: normStart,
        nextWordStartKana: entry.startKana,
      );
    }).length;

    // 候補が5語未満になったら自動的に動的生成して追加補填
    if (count < 5) {
      Set<String> existing = _dictionary.map((e) => e.reading).toSet();
      List<WordEntry> newGenerated = DynamicWordGenerator.generateWordsForKana(
        normStart,
        existing,
      );
      _dictionary.addAll(newGenerated);
    }
  }

  /// プレイヤーの一手を処理
  String? playerMakeMove(String inputWord) {
    if (_status != GameStatus.playing) {
      return "ゲームは終了しています。「最初から」を押してください。";
    }
    if (!_isPlayerTurn) {
      return "AIの思考中です。お待ちください。";
    }

    String normalizedInput = KanaUtils.normalizeString(inputWord);
    if (normalizedInput.isEmpty) {
      return "ひらがなまたはカタカナで単語を入力してください。";
    }

    String startKana = KanaUtils.getStartKana(normalizedInput);
    String endKana = KanaUtils.getEndKana(normalizedInput);

    // 1. 先頭文字の接続チェック
    if (_currentEndKana.isNotEmpty) {
      if (!KanaUtils.isValidConnection(
        lastWordEndKana: _currentEndKana,
        nextWordStartKana: startKana,
      )) {
        return "『$_currentEndKana』から始まる言葉を入力してください！（入力: 『$startKana』）";
      }
    }

    // 2. 「ん」で終わるかチェック
    if (KanaUtils.endsWithN(normalizedInput)) {
      _usedReadings.add(normalizedInput);
      _messages.add(ShiritoriMessage(
        sender: MoveSender.player,
        text: inputWord,
      ));
      _status = GameStatus.aiWon;
      _messages.add(ShiritoriMessage(
        sender: MoveSender.system,
        text: "「ん」がついたため、プレイヤーの敗北です！ 最強AIの勝利！",
      ));
      return null;
    }

    // 3. 重複チェック
    if (_usedReadings.contains(normalizedInput)) {
      return "『$inputWord』はすでに出た言葉です！別の言葉を入力してください。";
    }

    // 4. 実在・妥当性チェック（辞書検索）
    WordEntry? foundEntry;
    for (var entry in _dictionary) {
      if (entry.reading == normalizedInput || entry.word == inputWord) {
        foundEntry = entry;
        break;
      }
    }

    // 辞書にない場合でも、2文字以上かつ一般的なひらがなパターンであれば実在単語として受諾登録
    if (foundEntry == null) {
      if (normalizedInput.length < 2) {
        return "2文字以上の言葉を入力してください。";
      }

      foundEntry = WordEntry(
        word: inputWord,
        reading: normalizedInput,
        startKana: startKana,
        endKana: endKana,
        category: "プレイヤー新規語",
        description: "プレイヤーが入力した言葉",
      );
      _dictionary.add(foundEntry);
    }

    // 有効な手として登録
    _usedReadings.add(normalizedInput);
    _currentEndKana = endKana;
    _turnCount++;

    _messages.add(ShiritoriMessage(
      sender: MoveSender.player,
      text: inputWord,
      wordEntry: foundEntry,
    ));

    // 次のターンのために語彙を常に自動補填
    _ensureWordsAvailable(_currentEndKana);

    _isPlayerTurn = false;
    return null;
  }

  /// AIのターンを自動実行
  Future<void> triggerAIMove() async {
    if (_status != GameStatus.playing || _isPlayerTurn) return;

    // AIの手数を常に確保
    _ensureWordsAvailable(_currentEndKana);

    await Future.delayed(const Duration(milliseconds: 500));

    AIDecision? decision = _ai.selectNextWord(
      lastWordEndKana: _currentEndKana,
      allWords: _dictionary,
      usedReadings: _usedReadings,
    );

    if (decision == null) {
      // 念のためにもう一度緊急補填をかけて探索
      _ensureWordsAvailable(_currentEndKana);
      decision = _ai.selectNextWord(
        lastWordEndKana: _currentEndKana,
        allWords: _dictionary,
        usedReadings: _usedReadings,
      );
    }

    if (decision == null) {
      _status = GameStatus.playerWon;
      _messages.add(ShiritoriMessage(
        sender: MoveSender.system,
        text: "【驚愕】プレイヤーの完璧な戦略！\n見事、最強AIを撃破しました！あなたの勝利です！🎉",
      ));
      _isPlayerTurn = true;
      return;
    }

    // AIの手を適用
    _usedReadings.add(decision.word.reading);
    _currentEndKana = decision.word.endKana;

    _messages.add(ShiritoriMessage(
      sender: MoveSender.ai,
      text: decision.word.word,
      wordEntry: decision.word,
      aiComment: decision.comment,
    ));

    // AIが出した末尾文字に対しても次の単語を事前に補充用意
    _ensureWordsAvailable(_currentEndKana);

    _isPlayerTurn = true;
  }

  /// プレイヤーのためのヒントを取得
  WordEntry? getHintForPlayer() {
    if (_currentEndKana.isEmpty) return null;
    _ensureWordsAvailable(_currentEndKana);

    for (var entry in _dictionary) {
      if (_usedReadings.contains(entry.reading)) continue;
      if (entry.endKana == 'ん') continue;

      if (KanaUtils.isValidConnection(
        lastWordEndKana: _currentEndKana,
        nextWordStartKana: entry.startKana,
      )) {
        return entry;
      }
    }
    return null;
  }
}
