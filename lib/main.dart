import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat message RenderBox',
      home: ChatAppConversationView(),
    );
  }
}

class ChatAppConversationView extends StatefulWidget {
  const ChatAppConversationView({super.key});

  @override
  State<ChatAppConversationView> createState() =>
      _ChatAppConversationViewState();
}

class _ChatAppConversationViewState extends State<ChatAppConversationView> {
  final TextEditingController _controller = TextEditingController();
  final String sentAt = '3 seconds ago';

  @override
  void initState() {
    super.initState();
    _controller.text =
        'Hello?! this is a message! If you read it for long enough, '
        'your brain will grow';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              (_controller.text != '')
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        color: Colors.blue[100]!,
                        padding: const EdgeInsets.all(15),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, widget) {
                            return TimestampedChatMessage(
                              text: _controller.text,
                              sentAt: sentAt,
                              style: const TextStyle(color: Colors.red),
                            );
                          },
                        ),
                      ),
                    )
                  : Container(),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 25),
                child: TextField(
                  controller: _controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimestampedChatMessage extends LeafRenderObjectWidget {
  const TimestampedChatMessage({
    super.key,
    required this.text,
    required this.sentAt,
    this.style,
  });

  final String text;
  final String sentAt;
  final TextStyle? style;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    return TimestampedChatMessageRenderObject(
      text: text,
      sentAt: sentAt,
      textDirection: Directionality.of(context),
      textStyle: effectiveTextStyle!,
      sentAtStyle: effectiveTextStyle.copyWith(color: Colors.grey),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    TimestampedChatMessageRenderObject renderObject,
  ) {
    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }
    renderObject.text = text;
    renderObject.textStyle = effectiveTextStyle!;

    renderObject.sentAt = sentAt;
    renderObject.sentAtStyle = effectiveTextStyle.copyWith(color: Colors.grey);

    renderObject.textDirection = Directionality.of(context);
  }
}

class TimestampedChatMessageRenderObject extends RenderBox {
  TimestampedChatMessageRenderObject({
    required String sentAt,
    required String text,
    required TextStyle sentAtStyle,
    required TextStyle textStyle,
    required TextDirection textDirection,
  }) {
    _text = text;
    _sentAt = sentAt;
    _textStyle = textStyle;
    _sentAtStyle = sentAtStyle;
    _textDirection = textDirection;
    _textPainter = TextPainter(
      text: TextSpan(text: _text, style: _textStyle),
      textDirection: _textDirection,
    );
    _sentAtTextPainter = TextPainter(
      text: TextSpan(text: _sentAt, style: _sentAtStyle),
      textDirection: _textDirection,
    );
  }

  late TextDirection _textDirection;
  late String _text;
  late String _sentAt;
  late TextPainter _textPainter;
  late TextPainter _sentAtTextPainter;
  late TextStyle _sentAtStyle;
  late TextStyle _textStyle;
  late bool _sentAtFitsOnLastLine;
  late double _lineHeight;
  late double _lastMessageLineWidth;
  double _longestLineWidth = 0;
  late double _sentAtLineWidth;
  late int _numMessageLines;

  set sentAt(String val) {
    _sentAt = val;
    _sentAtTextPainter.text = sentAtTextSpan;
    markNeedsLayout();

    markNeedsSemanticsUpdate();
  }

  set sentAtStyle(TextStyle val) {
    _sentAtStyle = val;
    _sentAtTextPainter.text = sentAtTextSpan;
    markNeedsLayout();
  }

  String get text => _text;
  set text(String val) {
    _text = val;
    _textPainter.text = textTextSpan;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle val) {
    _textStyle = val;
    _textPainter.text = textTextSpan;

    markNeedsLayout();
  }

  set textDirection(TextDirection val) {
    if (_textDirection == val) {
      return;
    }
    _textPainter.textDirection = val;
    _sentAtTextPainter.textDirection = val;
    markNeedsSemanticsUpdate();
  }

  TextSpan get textTextSpan => TextSpan(text: _text, style: _textStyle);
  TextSpan get sentAtTextSpan => TextSpan(text: _sentAt, style: _sentAtStyle);

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;

    config.label = '$_text, sent $_sentAt';
    config.textDirection = _textDirection;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText(double.infinity);
    return _longestLineWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final computedSize = _layoutText(width);
    return computedSize.height;
  }

  @override
  void performLayout() {
    final unconstrainedSize = _layoutText(constraints.maxWidth);
    size = constraints.constrain(
      Size(unconstrainedSize.width, unconstrainedSize.height),
    );
  }

  Size _layoutText(double maxWidth) {
    if (_textPainter.text?.toPlainText() == '') {
      return Size.zero;
    }
    assert(
      maxWidth > 0,
      'You must allocate SOME space to layout a TimestampedChatMessageRenderObject. Received a '
      '`maxWidth` value of $maxWidth.',
    );

    _textPainter.layout(maxWidth: maxWidth);
    final textLines = _textPainter.computeLineMetrics();

    _sentAtTextPainter.layout(maxWidth: maxWidth);
    _sentAtLineWidth = _sentAtTextPainter.computeLineMetrics().first.width;

    _longestLineWidth = 0;

    for (final line in textLines) {
      _longestLineWidth = max(_longestLineWidth, line.width);
    }
    _longestLineWidth = max(_longestLineWidth, _sentAtTextPainter.width);

    final sizeOfMessage = Size(_longestLineWidth, _textPainter.height);

    _lastMessageLineWidth = textLines.last.width;
    _lineHeight = textLines.last.height;
    _numMessageLines = textLines.length;

    final lastLineWithDate = _lastMessageLineWidth + (_sentAtLineWidth * 1.08);
    if (textLines.length == 1) {
      _sentAtFitsOnLastLine = lastLineWithDate < maxWidth;
    } else {
      _sentAtFitsOnLastLine =
          lastLineWithDate < min(_longestLineWidth, maxWidth);
    }

    late Size computedSize;
    if (!_sentAtFitsOnLastLine) {
      computedSize = Size(
        sizeOfMessage.width,
        sizeOfMessage.height + _sentAtTextPainter.height,
      );
    } else {
      if (textLines.length == 1) {
        computedSize = Size(
          lastLineWithDate,
          sizeOfMessage.height,
        );
      } else {
        computedSize = Size(
          _longestLineWidth,
          sizeOfMessage.height,
        );
      }
    }
    return computedSize;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_textPainter.text?.toPlainText() == '') {
      return;
    }

    _textPainter.paint(context.canvas, offset);

    late Offset sentAtOffset;
    if (_sentAtFitsOnLastLine) {
      sentAtOffset = Offset(
        offset.dx + (size.width - _sentAtLineWidth),
        offset.dy + (_lineHeight * (_numMessageLines - 1)),
      );
    } else {
      sentAtOffset = Offset(
        offset.dx + (size.width - _sentAtLineWidth),
        offset.dy + _lineHeight * _numMessageLines,
      );
    }

    _sentAtTextPainter.paint(context.canvas, sentAtOffset);
  }
}
