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
///
/// 以回调方式工作（[onChanged]/[onDone]/[onCancel]），由调用方以“覆盖层”而非
/// 对话框路由的形式展示，从而让返回键只关闭键盘、不会因系统返回路由而退出应用。
class TvKeyboard extends StatefulWidget {
  final String initialValue;
  final bool obscure;

  /// 每次输入变化时的实时回调（用于同步回填到对应输入框）
  final ValueChanged<String> onChanged;

  /// 点击“完成”提交编辑
  final ValueChanged<String> onDone;

  /// 点击返回键取消编辑
  final VoidCallback onCancel;

  const TvKeyboard({
    super.key,
    required this.initialValue,
    this.obscure = false,
    required this.onChanged,
    required this.onDone,
    required this.onCancel,
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
    if (_col > 0) setState(() => _col--);
  }

  void _moveRight() {
    if (_col < _rows[_row].length - 1) setState(() => _col++);
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

  void _commit() {
    widget.onChanged(_text);
  }

  void _activate() {
    final k = _rows[_row][_col];
    switch (k.action) {
      case _TvKeyAction.insert:
        setState(() => _text += k.value!);
        _commit();
      case _TvKeyAction.space:
        setState(() => _text += ' ');
        _commit();
      case _TvKeyAction.backspace:
        setState(() {
          if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
        });
        _commit();
      case _TvKeyAction.clear:
        setState(() => _text = '');
        _commit();
      case _TvKeyAction.done:
        widget.onDone(_text);
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
    // 返回键：Android TV 上 BACK 以 KeyEvent(goBack/escape) 形式到达，
    // 必须在此消费并返回 handled，否则会冒泡到 MaterialApp 触发 SystemNavigator.pop 退出应用。
    // 外层登录页的 PopScope(canPop:false) 负责拦截“系统返回路由”通道，双重保险。
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      widget.onCancel();
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
    return Container(
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
    );
  }
}

/// TV/遥控专用的“输入框”：可聚焦的只读显示，OK 键触发 [onTap] 打开屏幕键盘
///
/// 替代系统 TextFormField，避免在 Android TV 上触发系统 IME 从而锁死 D-pad 导航。
class TvTextField extends StatelessWidget {
  final String label;
  final String value;
  final bool obscure;
  final IconData icon;
  final ValueChanged<String> onChanged;

  /// 打开编辑器（由调用方决定如何展示屏幕键盘）
  final VoidCallback onTap;

  const TvTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.onTap,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onTap();
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
            onTap: onTap,
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
