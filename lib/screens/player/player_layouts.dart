part of '../player_screen.dart';
// ignore_for_file: invalid_use_of_protected_member
// extension 内调用 State.setState 是安全的，lint 无法识别扩展成员上下文

/// 拆分自 player_screen.dart（原 _PlayerScreenState 成员方法）
extension on _PlayerScreenState {
  /// 构建播放器层（使用 Positioned 控制位置和大小）
  Widget _buildPlayerLayer(ThemeData theme) {
    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final topOffset = statusBarHeight + macOSPadding;

    if (_isWebFullscreen) {
      // 网页全屏模式：播放器占据整个屏幕（保留顶部安全区域）
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: Column(
          children: [
            // 顶部安全区域
            Container(
              height: topOffset,
              color: Colors.black,
            ),
            // 播放器
            Expanded(
              child: Container(
                key: _playerKey,
                color: Colors.black,
                child: _buildPlayerWidget(),
              ),
            ),
          ],
        ),
      );
    } else {
      // 非网页全屏模式：根据不同布局计算播放器位置
      if (_isTablet && !_isPortraitTablet) {
        // 平板横屏模式：播放器在左侧65%区域
        final screenWidth = MediaQuery.of(context).size.width;
        final leftWidth = screenWidth * 0.65;
        final playerHeight = leftWidth / (16 / 9);

        return Positioned(
          top: topOffset,
          left: 0,
          width: leftWidth,
          height: playerHeight,
          child: Container(
            key: _playerKey,
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      } else if (_isPortraitTablet) {
        // 平板竖屏模式：播放器占50%高度
        final screenHeight = MediaQuery.of(context).size.height;
        final playerHeight = (screenHeight - topOffset) * 0.5;

        return Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          height: playerHeight,
          child: Container(
            key: _playerKey,
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      } else {
        // 手机模式：16:9 比例
        final screenWidth = MediaQuery.of(context).size.width;
        final playerHeight = screenWidth / (16 / 9);

        return Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          height: playerHeight,
          child: Container(
            key: _playerKey,
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      }
    }
  }

  /// 构建手机模式布局（不包含播放器）
  Widget _buildPhoneLayout(ThemeData theme) {
    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final playerHeight = screenWidth / (16 / 9);

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: Colors.black,
        ),
        // 播放器占位空间
        SizedBox(height: playerHeight),
        Expanded(
          child: _buildVideoDetailSection(theme),
        ),
      ],
    );
  }

  /// 构建平板竖屏模式布局（不包含播放器）
  Widget _buildPortraitTabletLayout(ThemeData theme) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final playerHeight = (screenHeight - statusBarHeight - macOSPadding) * 0.5;

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: Colors.black,
        ),
        // 播放器占位空间
        SizedBox(height: playerHeight),
        Expanded(
          child: _buildVideoDetailSection(theme),
        ),
      ],
    );
  }

  /// 构建平板横屏模式布局（不包含播放器）
  Widget _buildTabletLandscapeLayout(ThemeData theme) {
    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final leftWidth = screenWidth * 0.65;
    final playerHeight = leftWidth / (16 / 9);

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: Colors.black,
        ),
        Expanded(
          child: Row(
            children: [
              // 左侧：播放器和详情（65%）
              Expanded(
                flex: 65,
                child: Column(
                  children: [
                    // 播放器占位空间
                    SizedBox(height: playerHeight),
                    Expanded(
                      child: _buildVideoDetailSection(theme),
                    ),
                  ],
                ),
              ),
              // 右侧：详情面板（35%）
              Expanded(
                flex: 35,
                child: Container(
                  color: Colors.transparent,
                  child: PlayerDetailsPanel(
                    theme: theme,
                    doubanDetails: doubanDetails,
                    currentDetail: currentDetail,
                    showCloseButton: false,
                    showTitle: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建加载覆盖层
  Widget _buildLoadingOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    // macOS 下需要额外的顶部 padding 来避免与透明标题栏重叠
    final topPadding = DeviceUtils.isMacOS()
        ? MediaQuery.of(context).padding.top + 32
        : MediaQuery.of(context).padding.top + 8;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFe6f3fb),
                  Color(0xFFeaf3f7),
                  Color(0xFFf7f7f3),
                  Color(0xFFe9ecef),
                  Color(0xFFdbe3ea),
                  Color(0xFFd3dde6),
                ],
                stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
              ),
        color: isDarkMode ? Colors.black : null,
      ),
      child: Stack(
        children: [
          // PC 端左上角返回按钮
          if (DeviceUtils.isPC())
            Positioned(
              top: topPadding + 4,
              left: 16,
              child: _HoverBackButton(
                onTap: _onBackPressed,
                iconColor: isDarkMode
                    ? const Color(0xFFffffff)
                    : const Color(0xFF2c3e50),
              ),
            ),
          // 中心加载内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 旋转的背景方块（半透明绿色）
                    RotationTransition(
                      turns: _loadingAnimationController,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ecc71).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // 中间的图标容器（减小尺寸，删除阴影）
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _loadingEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // 进度条
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ecc71),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 加载文案
                AnimatedBuilder(
                  animation: _textAnimationController,
                  builder: (context, child) {
                    return Text(
                      _loadingMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: (isDarkMode ? Colors.white70 : Colors.black54)
                            .withOpacity(
                          0.3 + (_textAnimationController.value * 0.7),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
