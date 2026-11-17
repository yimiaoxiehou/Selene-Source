part of '../player_screen.dart';

/// 带 hover 效果的返回按钮（PC 端专用）
class _HoverBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color iconColor;

  const _HoverBackButton({
    required this.onTap,
    required this.iconColor,
  });

  @override
  State<_HoverBackButton> createState() => _HoverBackButtonState();
}

class _HoverBackButtonState extends State<_HoverBackButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: _isHovering
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.5),
                )
              : null,
          child: Icon(
            Icons.arrow_back,
            color: widget.iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的选集卡片（PC 端专用）
class _EpisodeCardWithHover extends StatefulWidget {
  final bool isCurrentEpisode;
  final bool isDarkMode;
  final int episodeIndex;
  final String episodeTitle;
  final VoidCallback? onTap;

  const _EpisodeCardWithHover({
    required this.isCurrentEpisode,
    required this.isDarkMode,
    required this.episodeIndex,
    required this.episodeTitle,
    this.onTap,
  });

  @override
  State<_EpisodeCardWithHover> createState() => _EpisodeCardWithHoverState();
}

class _EpisodeCardWithHoverState extends State<_EpisodeCardWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrentEpisode)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrentEpisode) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentEpisode
                ? Colors.green.withValues(alpha: 0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode
                        ? const Color(0xFF1A3D2E) // 深色模式下的浅绿色
                        : const Color(0xFFE8F5E9)) // 浅色模式下的浅绿色
                    : (widget.isDarkMode
                        ? Colors.grey[700]
                        : Colors.grey[300])),
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrentEpisode
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              // 左上角集数
              Positioned(
                top: 4,
                left: 6,
                child: Text(
                  '${widget.episodeIndex + 1}',
                  style: TextStyle(
                    color: widget.isCurrentEpisode
                        ? Colors.green
                        : (widget.isDarkMode ? Colors.white : Colors.black),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // 中间集数名称
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Text(
                    widget.episodeTitle,
                    style: TextStyle(
                      color: widget.isCurrentEpisode
                          ? Colors.green
                          : (widget.isDarkMode ? Colors.white : Colors.black),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的换源卡片（PC 端专用）
class _SourceCardWithHover extends StatefulWidget {
  final bool isCurrentSource;
  final bool isDarkMode;
  final SearchResult source;
  final SourceSpeed? speedInfo;
  final VoidCallback? onTap;

  const _SourceCardWithHover({
    required this.isCurrentSource,
    required this.isDarkMode,
    required this.source,
    this.speedInfo,
    this.onTap,
  });

  @override
  State<_SourceCardWithHover> createState() => _SourceCardWithHoverState();
}

class _SourceCardWithHoverState extends State<_SourceCardWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrentSource)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrentSource) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentSource
                ? Colors.green.withValues(alpha: 0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode
                        ? const Color(0xFF1A3D2E) // 深色模式下的浅绿色
                        : const Color(0xFFE8F5E9)) // 浅色模式下的浅绿色
                    : (widget.isDarkMode
                        ? Colors.grey[700]
                        : Colors.grey[300])),
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrentSource
                ? Border.all(color: Colors.green, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              // 右上角集数信息
              if (widget.source.episodes.length > 1)
                Positioned(
                  top: 4,
                  right: 6,
                  child: Text(
                    '${widget.source.episodes.length}集',
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

              // 中间源名称
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.source.sourceName,
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode ? Colors.white : Colors.black),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 左下角分辨率信息
              if (widget.speedInfo != null &&
                  widget.speedInfo!.quality.toLowerCase() != '未知')
                Positioned(
                  bottom: 4,
                  left: 6,
                  child: Text(
                    widget.speedInfo!.quality,
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

              // 右下角速率信息
              if (widget.speedInfo != null &&
                  widget.speedInfo!.loadSpeed.isNotEmpty &&
                  !widget.speedInfo!.loadSpeed.toLowerCase().contains('超时'))
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Text(
                    widget.speedInfo!.loadSpeed,
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的按钮组件（PC 端专用）
class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _HoverButton({
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPC = DeviceUtils.isPC();

    return MouseRegion(
      cursor: (isPC && widget.enabled && widget.onTap != null)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: isPC ? (_) => setState(() => _isHovered = true) : null,
      onExit: isPC ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ColorFiltered(
            colorFilter: (isPC && _isHovered && widget.enabled)
                ? const ColorFilter.mode(
                    Colors.green,
                    BlendMode.modulate,
                  )
                : const ColorFilter.mode(
                    Colors.white,
                    BlendMode.modulate,
                  ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
