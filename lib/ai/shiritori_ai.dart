import 'dart:math';
import '../models/word.dart';
import '../utils/kana_utils.dart';

enum AIDifficulty {
  grandmaster, // 最強（ル攻め・完全詰み計算）
  hard,        // 強（高スコア手優先）
  normal,      // 普通（適度にランダム）
}

class AIDecision {
  final WordEntry word;
  final String comment;
  final int estimatedOpponentMoves;
  final bool isWinningMove;

  AIDecision({
    required this.word,
    required this.comment,
    required this.estimatedOpponentMoves,
    required this.isWinningMove,
  });
}

class ShiritoriAI {
  final AIDifficulty difficulty;
  final Random _random = Random();

  ShiritoriAI({this.difficulty = AIDifficulty.grandmaster});

  /// AIの次の一手を決定する
  /// [lastWordEndKana]: 前の単語の末尾文字（ひらがな）
  /// [allWords]: 辞書の全単語
  /// [usedReadings]: 既に使用された単語の読みの集合
  AIDecision? selectNextWord({
    required String lastWordEndKana,
    required List<WordEntry> allWords,
    required Set<String> usedReadings,
  }) {
    // 1. 候補となる未使用単語を検索
    List<WordEntry> candidates = allWords.where((entry) {
      if (usedReadings.contains(entry.reading)) return false;
      if (entry.endKana == 'ん') return false; // 「ん」終わりは回避

      return KanaUtils.isValidConnection(
        lastWordEndKana: lastWordEndKana,
        nextWordStartKana: entry.startKana,
      );
    }).toList();

    if (candidates.isEmpty) {
      return null; // 返せる手がない（降参）
    }

    // 2. 各候補単語のスコア評価
    List<_ScoredWord> scoredCandidates = [];

    for (var candidate in candidates) {
      int opponentMoves = _countValidMovesForOpponent(
        startKana: candidate.endKana,
        allWords: allWords,
        usedReadings: usedReadings,
        currentWord: candidate,
      );

      double score = _evaluateCandidate(
        candidate: candidate,
        opponentMoves: opponentMoves,
        allWords: allWords,
        usedReadings: usedReadings,
      );

      scoredCandidates.add(_ScoredWord(
        word: candidate,
        score: score,
        opponentMoves: opponentMoves,
      ));
    }

    // スコア降順ソート
    scoredCandidates.sort((a, b) => b.score.compareTo(a.score));

    // 難易度に応じた手を選択
    _ScoredWord selected;
    if (difficulty == AIDifficulty.grandmaster) {
      // 最強モード：最高スコアの手を厳密に選ぶ
      selected = scoredCandidates.first;
    } else if (difficulty == AIDifficulty.hard) {
      // 上位3手の中からランダム選択
      int topN = min(3, scoredCandidates.length);
      selected = scoredCandidates[_random.nextInt(topN)];
    } else {
      // 普通モード：上位5手の中からランダム選択
      int topN = min(5, scoredCandidates.length);
      selected = scoredCandidates[_random.nextInt(topN)];
    }

    bool isWinning = selected.opponentMoves == 0;
    String comment = _generateAIComment(
      selected.word,
      selected.opponentMoves,
      isWinning,
    );

    return AIDecision(
      word: selected.word,
      comment: comment,
      estimatedOpponentMoves: selected.opponentMoves,
      isWinningMove: isWinning,
    );
  }

  /// 相手が指定した頭文字から返せる有効な手（「ん」で終わらないもの）の数を算出
  int _countValidMovesForOpponent({
    required String startKana,
    required List<WordEntry> allWords,
    required Set<String> usedReadings,
    required WordEntry currentWord,
  }) {
    Set<String> futureUsed = Set.from(usedReadings)..add(currentWord.reading);

    int count = 0;
    for (var entry in allWords) {
      if (futureUsed.contains(entry.reading)) continue;
      if (entry.endKana == 'ん') continue; // 「ん」で自滅する手は有効な手とみなさない

      if (KanaUtils.isValidConnection(
        lastWordEndKana: startKana,
        nextWordStartKana: entry.startKana,
      )) {
        count++;
      }
    }
    return count;
  }

  /// 候補単語の戦略的スコア計算
  double _evaluateCandidate({
    required WordEntry candidate,
    required int opponentMoves,
    required List<WordEntry> allWords,
    required Set<String> usedReadings,
  }) {
    double score = 0.0;

    // A. 相手の選択肢をゼロにする手（即勝利）
    if (opponentMoves == 0) {
      return 10000.0;
    }

    // B. 相手の選択肢を絞る（Out-Degree反比例スコア）
    score += (100.0 / (opponentMoves + 1));

    // C. 凶悪な攻撃文字（「ル」「ぬ」「む」「ず」「ぷ」など）への誘導ボーナス
    String end = candidate.endKana;
    if (end == 'る') {
      score += 400.0; // 「ル攻め」は最強のハメ手！
    } else if (end == 'ぬ' || end == 'む' || end == 'ず' || end == 'ぷ') {
      score += 250.0;
    } else if (end == 'れ' || end == 'ろ' || end == 'ね') {
      score += 150.0;
    }

    // D. 自分自身の生存安全度（相手が万が一返してきた時に自分が生き残れるか）
    int mySafetyMoves = _estimateMySafety(
      opponentStartKana: end,
      allWords: allWords,
      usedReadings: usedReadings,
      candidate: candidate,
    );
    score += mySafetyMoves * 5.0;

    return score;
  }

  /// 相手が候補の中から返してきた場合に自分が生き残れる手があるか
  int _estimateMySafety({
    required String opponentStartKana,
    required List<WordEntry> allWords,
    required Set<String> usedReadings,
    required WordEntry candidate,
  }) {
    // 簡略化した先読み評価
    Set<String> simulatedUsed = Set.from(usedReadings)..add(candidate.reading);

    // 相手が出しそうな言葉を1つと仮定
    for (var oppEntry in allWords) {
      if (simulatedUsed.contains(oppEntry.reading)) continue;
      if (oppEntry.endKana == 'ん') continue;

      if (KanaUtils.isValidConnection(
        lastWordEndKana: opponentStartKana,
        nextWordStartKana: oppEntry.startKana,
      )) {
        String oppEnd = oppEntry.endKana;
        // AIがさらに返せる言葉の数をカウント
        int myMoves = 0;
        for (var myEntry in allWords) {
          if (simulatedUsed.contains(myEntry.reading) ||
              myEntry.reading == oppEntry.reading) continue;
          if (myEntry.endKana == 'ん') continue;
          if (KanaUtils.isValidConnection(
            lastWordEndKana: oppEnd,
            nextWordStartKana: myEntry.startKana,
          )) {
            myMoves++;
          }
        }
        return myMoves;
      }
    }
    return 1;
  }

  /// AIのセリフ演出生成
  String _generateAIComment(WordEntry word, int opponentMoves, bool isWinning) {
    if (isWinning) {
      return "【詰み発動】『${word.word}』！ あなたが返せる単語はもう存在しません。私の勝ちです！";
    }

    if (word.endKana == 'る') {
      return "【必殺『ル』攻撃】『${word.word}』！ 『${word.endKana}』から始まる言葉、言えますか？（残り候補数: 約$opponentMoves 語）";
    }

    if (opponentMoves <= 2) {
      return "【追い詰め】『${word.word}』！ 相手の残り選択肢は推定 $opponentMoves 語です！ピンチですよ？";
    }

    if (word.description != null && _random.nextDouble() < 0.4) {
      return "『${word.word}』！ 豆知識: ${word.description}";
    }

    List<String> normalComments = [
      "『${word.word}』で勝負！ 次は『${word.endKana}』だよ！",
      "ふふっ、『${word.word}』！ さあ、どう返してくるかな？",
      "『${word.word}』！ 最強AIの頭脳にどこまで喰らいついてこれるかな？",
      "『${word.word}』！ 次の文字は『${word.endKana}』です！",
    ];
    return normalComments[_random.nextInt(normalComments.length)];
  }
}

class _ScoredWord {
  final WordEntry word;
  final double score;
  final int opponentMoves;

  _ScoredWord({
    required this.word,
    required this.score,
    required this.opponentMoves,
  });
}
