import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/font_utils.dart';

/// TV/遥控器专用屏幕键盘的按键模型（公开，供调用方做焦点调度/裁剪）
class TvKey {
  final String label;
  final String? value;
  final TvKeyAction action;
  const TvKey(this.label, this.action, [this.value]);
}

enum TvKeyAction { insert, backspace, space, clear, done }

/// TV/遥控器专用屏幕键盘（纯展示组件）
///
/// 不再内置 Focus 与状态：方向键/OK/返回键统一由上层（登录页的 Focus）驱动，
/// 通过 [row]/[col]/[text] 参数渲染当前焦点与已输入内容。这样可避免 Android TV 上
/// 键盘挂载/ExcludeFocus 时机导致的“焦点拿不到、按键冒泡退出应用”的问题。
///
/// 不使用系统 IME，避免聚焦输入框时系统键盘抢占 D-pad 焦点、导致遥控器无法在
/// 输入框/按钮之间移动且无法退出输入模式。
class TvKeyboard extends StatelessWidget {
  final String text;
  final bool obscure;

  /// 当前焦点行/列（由调用方维护）
  final int row;
  final int col;

  /// 每次输入变化时的实时回调（用于同步回填到对应输入框）
  final ValueChanged<String> onChanged;

  /// 点击“完成”提交编辑
  final ValueChanged<String> onDone;

  /// 点击返回键取消编辑
  final VoidCallback onCancel;

  const TvKeyboard({
    super.key,
    required this.text,
    this.obscure = false,
    required this.row,
    required this.col,
    required this.onChanged,
    required this.onDone,
    required this.onCancel,
  });

  /// 键盘按键布局（最后一行含空格/退格/清空/完成）
  static final List<List<TvKey>> rows = [
    for (final s in const [
      '1234567890',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ])
      [for (final c in s.split('')) TvKey(c, TvKeyAction.insert, c)],
    [
      const TvKey('-', TvKeyAction.insert, '-'),
      const TvKey('_', TvKeyAction.insert, '_'),
      const TvKey('.', TvKeyAction.insert, '.'),
      const TvKey('@', TvKeyAction.insert, '@'),
      const TvKey(':', TvKeyAction.insert, ':'),
      const TvKey('/', TvKeyAction.insert, '/'),
      const TvKey('空格', TvKeyAction.space),
      const TvKey('⌫', TvKeyAction.backspace),
      const TvKey('清空', TvKeyAction.clear),
      const TvKey('完成', TvKeyAction.done),
    ],
  ];

  static int get rowCount => rows.length;
  static int colCount(int r) => rows[r].length;
  static TvKey keyAt(int r, int c) => rows[r][c];

  Widget _buildKey(TvKey k, bool active) {
    final isDone = k.action == TvKeyAction.done;
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
    final display = obscure && text.isNotEmpty ? '•' * text.length : text;
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
          // 键盘网格（焦点由上层 Focus 驱动，这里仅展示）
          Column(
            children: [
              for (int r = 0; r < rows.length; r++)
                Row(
                  children: [
                    for (int c = 0; c < rows[r].length; c++)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _buildKey(rows[r][c], r == row && c == col),
                        ),
                      ),
                  ],
                ),
            ],
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
