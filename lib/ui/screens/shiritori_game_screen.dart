import 'package:flutter/material.dart';
import '../../engine/shiritori_engine.dart';
import '../../ai/shiritori_ai.dart';
import '../../models/word.dart';
import '../theme/app_theme.dart';

class ShiritoriGameScreen extends StatefulWidget {
  const ShiritoriGameScreen({super.key});

  @override
  State<ShiritoriGameScreen> createState() => _ShiritoriGameScreenState();
}

class _ShiritoriGameScreenState extends State<ShiritoriGameScreen> {
  late ShiritoriEngine _engine;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isAiThinking = false;

  @override
  void initState() {
    super.initState();
    _engine = ShiritoriEngine(difficulty: AIDifficulty.grandmaster);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    final error = _engine.playerMakeMove(text);
    _textController.clear();
    _focusNode.requestFocus();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {});
    _scrollToBottom();

    // AIのターン
    if (_engine.status == GameStatus.playing && !_engine.isPlayerTurn) {
      setState(() {
        _isAiThinking = true;
      });

      await _engine.triggerAIMove();

      if (mounted) {
        setState(() {
          _isAiThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _showHint() {
    WordEntry? hint = _engine.getHintForPlayer();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: AppTheme.accentAmber),
            SizedBox(width: 8),
            Text('AIのアドバイス (ヒント)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Text(
                'おすすめ単語: 『${hint.word}』',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCyan,
                ),
              ),
              const SizedBox(height: 8),
              Text('読み: ${hint.reading}'),
              Text('末尾: 『${hint.endKana}』'),
              if (hint.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  '解説: ${hint.description}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                ),
              ],
            ] else ...[
              const Text('ヒントが見つかりませんでした。'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (hint != null)
            ElevatedButton(
              onPressed: () {
                _textController.text = hint.word;
                Navigator.pop(context);
                _focusNode.requestFocus();
              },
              child: const Text('入力に反映'),
            ),
        ],
      ),
    );
  }

  void _showUsedWordsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history, color: AppTheme.primaryCyan),
            const SizedBox(width: 8),
            Text('出た言葉一覧 (${_engine.usedReadings.length}語)'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _engine.usedReadings.isEmpty
              ? const Text('まだ言葉は出ていません。')
              : ListView(
                  shrinkWrap: true,
                  children: _engine.usedReadings
                      .map((reading) => Chip(
                            label: Text(reading),
                            backgroundColor: AppTheme.surfaceDark,
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, color: AppTheme.primaryCyan),
            SizedBox(width: 8),
            Text('しりとり AI'),
          ],
        ),
        actions: [
          PopupMenuButton<AIDifficulty>(
            icon: const Icon(Icons.tune),
            tooltip: 'AI難易度設定',
            onSelected: (difficulty) {
              setState(() {
                _engine.setDifficulty(difficulty);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '難易度を「${_difficultyName(difficulty)}」に変更しました',
                  ),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AIDifficulty.grandmaster,
                child: Text('👑 最強 (Grandmaster) - ル攻め/完全詰み'),
              ),
              const PopupMenuItem(
                value: AIDifficulty.hard,
                child: Text('🔥 強 (Hard)'),
              ),
              const PopupMenuItem(
                value: AIDifficulty.normal,
                child: Text('🌱 普通 (Normal)'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '使用済み単語',
            onPressed: _showUsedWordsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'リセット',
            onPressed: () {
              setState(() {
                _engine.resetGame();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダーステータス
            _buildHeaderStatus(),

            // チャットエリア
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _engine.messages.length + (_isAiThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _engine.messages.length) {
                    return _buildMessageTile(_engine.messages[index]);
                  } else {
                    return _buildAiThinkingTile();
                  }
                },
              ),
            ),

            // ボトム入力エリア
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  String _difficultyName(AIDifficulty difficulty) {
    switch (difficulty) {
      case AIDifficulty.grandmaster:
        return "最強";
      case AIDifficulty.hard:
        return "強";
      case AIDifficulty.normal:
        return "普通";
    }
  }

  Widget _buildHeaderStatus() {
    String endKana = _engine.currentEndKana;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AIモード: ${_difficultyName(_engine.difficulty)}',
                style: const TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ターン数: ${_engine.turnCount} / 使用語数: ${_engine.usedReadings.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: endKana.isEmpty
                    ? [AppTheme.primaryPurple, AppTheme.primaryCyan]
                    : [AppTheme.accentPink, AppTheme.primaryPurple],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  '次の頭文字: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  endKana.isEmpty ? '自由' : endKana,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.yellowAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(ShiritoriMessage msg) {
    if (msg.sender == MoveSender.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
        ),
        child: Text(
          msg.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    bool isPlayer = msg.sender == MoveSender.player;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isPlayer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPlayer) ...[
            const CircleAvatar(
              backgroundColor: AppTheme.primaryCyan,
              child: Icon(Icons.smart_toy, color: Colors.black),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isPlayer
                        ? const LinearGradient(
                            colors: [AppTheme.primaryPurple, Color(0xFF4F46E5)],
                          )
                        : const LinearGradient(
                            colors: [AppTheme.surfaceDark, AppTheme.cardDark],
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isPlayer ? 16 : 4),
                      bottomRight: Radius.circular(isPlayer ? 4 : 16),
                    ),
                    border: isPlayer
                        ? null
                        : Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5)),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isPlayer ? Colors.white : Colors.cyanAccent,
                        ),
                      ),
                      if (msg.wordEntry != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '(${msg.wordEntry!.reading})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPlayer ? Colors.white70 : Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (msg.aiComment != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg.aiComment!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isPlayer) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: AppTheme.accentPink,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiThinkingTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.primaryCyan,
            child: Icon(Icons.smart_toy, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryCyan,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '最強AIが最適な手を計算中...',
                  style: TextStyle(color: AppTheme.primaryCyan, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    bool canInput = _engine.status == GameStatus.playing && !_isAiThinking;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            color: AppTheme.accentAmber,
            tooltip: 'ヒントを貰う',
            onPressed: canInput ? _showHint : null,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: canInput,
              textInputAction: TextInputAction.send,
              onSubmitted: _handleSubmitted,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: canInput
                    ? (_engine.currentEndKana.isEmpty
                        ? '単語を入力...'
                        : '『${_engine.currentEndKana}』から始まる単語...')
                    : 'ゲーム終了',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: AppTheme.cardDark,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryCyan,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: canInput
                ? () => _handleSubmitted(_textController.text)
                : null,
            backgroundColor: canInput ? AppTheme.primaryCyan : Colors.grey,
            child: const Icon(Icons.send, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
