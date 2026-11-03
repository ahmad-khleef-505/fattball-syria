import 'package:fattball/providers/auth_provider.dart';
import 'package:fattball/services/assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  ConsumerState<AssistantChatScreen> createState() =>
      _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  static const _suggestions = [
    'ما هي الملاعب المتاحة في حلب؟',
    'كيف أحجز ملعباً؟',
    'كيف ألغي حجزي؟',
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final message = (suggestion ?? _messageController.text).trim();
    if (message.isEmpty || _isSending) return;

    final previousMessages = _messages
        .where((item) => !item.isError)
        .map(
          (item) => <String, String>{
            'role': item.isUser ? 'user' : 'model',
            'content': item.text,
          },
        )
        .toList();
    final history = previousMessages.length > 8
        ? previousMessages.sublist(previousMessages.length - 8)
        : previousMessages;

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToLatest();

    try {
      final answer = await ref.read(assistantServiceProvider).ask(
            message: message,
            history: history,
          );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: answer)));
    } on AssistantServiceException catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(_ChatMessage(text: error.message, isError: true)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مساعد الملاعب الذكي'),
        actions: [
          IconButton(
            tooltip: 'مسح المحادثة',
            onPressed: _isSending ? null : () => setState(_messages.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildWelcome(colors)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isSending && index == _messages.length) {
                              return const _ThinkingBubble();
                            }
                            return _MessageBubble(message: _messages[index]);
                          },
                        ),
                ),
                if (_messages.isEmpty) _buildSuggestions(),
                _buildComposer(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.sports_soccer,
                size: 46,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'أهلاً بك في ملعبك!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'اسألني عن الملاعب والأسعار وطريقة الحجز. '
              'أعتمد على بيانات الملاعب المنشورة؛ تُعالج رسائلك عبر Gemini، '
              'ولا يطّلع المساعد على حجوزاتك الخاصة.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          label: Text(_suggestions[index]),
          onPressed: _isSending ? null : () => _send(_suggestions[index]),
        ),
      ),
    );
  }

  Widget _buildComposer(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب سؤالك هنا...',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: _isSending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    this.isUser = false,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = message.isError
        ? colors.errorContainer
        : message.isUser
            ? colors.primary
            : colors.surfaceContainerHighest;
    final foreground = message.isError
        ? colors.onErrorContainer
        : message.isUser
            ? colors.onPrimary
            : colors.onSurface;

    return Align(
      alignment: message.isUser
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(color: foreground, height: 1.5),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
