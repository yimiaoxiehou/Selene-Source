import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/font_utils.dart';

/// TV/遥控器专用的屏幕键盘按键
class _TvKey {
  final String label;
  final String? value;
  final _TvKeyAction action;
  const _TvKey(this.label, this.action, [this.value]);
}

enum _TvKeyAction { insert, backspace, space, clear, done }

/// TV/遥控器专用屏幕键盘：用方向键移动焦点，OK 键输入，返回键关闭
///
/// 不使用系统 IME，避免 Android TV 上聚焦输入框时系统键盘抢占 D-pad 焦点、
/// 导致遥控器无法在输入框/按钮之间移动且无法退出输入模式的问题。
class TvKeyboard extends StatefulWidget {
  final String initialValue;
  final bool obscure;

  const TvKeyboard({
    super.key,
    required this.initialValue,
    this.obscure = false,
  });

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  late String _text;
  int _row = 0;
  int _col = 0;

  static final List<List<_TvKey>> _rows = [
    for (final s in const [
      '1234567890',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ])
      [for (final c in s.split('')) _TvKey(c, _TvKeyAction.insert, c)],
    [
      const _TvKey('-', _TvKeyAction.insert, '-'),
      const _TvKey('_', _TvKeyAction.insert, '_'),
      const _TvKey('.', _TvKeyAction.insert, '.'),
      const _TvKey('@', _TvKeyAction.insert, '@'),
      const _TvKey(':', _TvKeyAction.insert, ':'),
      const _TvKey('/', _TvKeyAction.insert, '/'),
      const _TvKey('空格', _TvKeyAction.space),
      const _TvKey('⌫', _TvKeyAction.backspace),
      const _TvKey('清空', _TvKeyAction.clear),
      const _TvKey('完成', _TvKeyAction.done),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _text = widget.initialValue;
  }

  void _moveLeft() {
    if (_col > 0) {
      setState(() => _col--);
    }
  }

  void _moveRight() {
    if (_col < _rows[_row].length - 1) {
      setState(() => _col++);
    }
  }

  void _moveUp() {
    if (_row > 0) {
      setState(() {
        _row--;
        if (_col > _rows[_row].length - 1) _col = _rows[_row].length - 1;
      });
    }
  }

  void _moveDown() {
    if (_row < _rows.length - 1) {
      setState(() {
        _row++;
        if (_col > _rows[_row].length - 1) _col = _rows[_row].length - 1;
      });
    }
  }

  void _activate() {
    final k = _rows[_row][_col];
    switch (k.action) {
      case _TvKeyAction.insert:
        setState(() => _text += k.value!);
      case _TvKeyAction.space:
        setState(() => _text += ' ');
      case _TvKeyAction.backspace:
        setState(() {
          if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
        });
      case _TvKeyAction.clear:
        setState(() => _text = '');
      case _TvKeyAction.done:
        Navigator.of(context).pop(_text);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      // 返回键关闭键盘，取消编辑
      Navigator.of(context).pop(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildKey(_TvKey k, bool active) {
    final isDone = k.action == _TvKeyAction.done;
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDone
            ? (active ? const Color(0xFF27ae60) : const Color(0xFF2c3e50))
            : (active ? const Color(0xFF27ae60) : Colors.white.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? const Color(0xFF27ae60) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          k.label,
          style: FontUtils.poppins(
            fontSize: isDone ? 15 : 18,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : (isDone ? Colors.white : const Color(0xFF2c3e50)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display =
        widget.obscure && _text.isNotEmpty ? '•' * _text.length : _text;
    return PopScope(
      // 关闭对话框的返回由下方 Focus 的 onKeyEvent（返回键）统一处理，
      // 避免系统返回既触发路由自动 pop 又触发此处 pop 造成重复 pop。
      canPop: false,
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFf2f5f7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 当前输入内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27ae60), width: 2),
              ),
              child: Text(
                display.isEmpty ? ' ' : display,
                style: FontUtils.poppins(
                  fontSize: 18,
                  color: const Color(0xFF2c3e50),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            // 键盘网格
            Focus(
              autofocus: true,
              onKeyEvent: _onKey,
              child: Column(
                children: [
                  for (int r = 0; r < _rows.length; r++)
                    Row(
                      children: [
                        for (int c = 0; c < _rows[r].length; c++)
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child:
                                  _buildKey(_rows[r][c], r == _row && c == _col),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '方向键移动 · OK 输入 · 返回键关闭',
              style: FontUtils.poppins(
                fontSize: 12,
                color: const Color(0xFF7f8c8d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出 TV 屏幕键盘并编辑文本，返回编辑后的字符串，取消则返回 null
Future<String?> showTvKeyboard(
  BuildContext context,
  String initialValue, {
  bool obscure = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: TvKeyboard(initialValue: initialValue, obscure: obscure),
    ),
  );
}

/// TV/遥控器专用的“输入框”：可聚焦的只读显示，OK 键打开屏幕键盘编辑
///
/// 替代系统 TextFormField，避免在 Android TV 上触发系统 IME 从而锁死 D-pad 导航。
class TvTextField extends StatelessWidget {
  final String label;
  final String value;
  final bool obscure;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const TvTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    this.obscure = false,
  });

  void _open(BuildContext context) async {
    final result = await showTvKeyboard(context, value, obscure: obscure);
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _open(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final display =
              obscure && value.isNotEmpty ? '•' * value.length : value;
          return GestureDetector(
            onTap: () => _open(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused ? const Color(0xFF27ae60) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFF7f8c8d), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      display.isEmpty ? '点击输入$label' : display,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: display.isEmpty
                            ? const Color(0xFFbdc3c7)
                            : const Color(0xFF2c3e50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
