part of '../player_screen.dart';
// ignore_for_file: invalid_use_of_protected_member
// extension 内调用 State.setState 是安全的，lint 无法识别扩展成员上下文

/// 拆分自 player_screen.dart（原 _PlayerScreenState 成员方法）
extension on _PlayerScreenState {
  /// 构建视频详情展示区域
  Widget _buildVideoDetailSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    if (currentDetail == null) {
      return Container(
        color: Colors.transparent,
        child: const Center(
          child: Text('加载中...'),
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 标题和收藏按钮行
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      videoTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite
                          ? const Color(0xFFe74c3c)
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // 源名称、年份和分类信息行
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 12, bottom: 16),
              child: Row(
                children: [
                  // 源名称（带边框样式）
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentDetail!.sourceName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 年份
                  if (videoYear.isNotEmpty && videoYear != 'unknown')
                    Text(
                      videoYear,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  if (videoYear.isNotEmpty && videoYear != 'unknown')
                    const SizedBox(width: 12),

                  // 分类信息（绿色文字样式，充满可用空间但不与详情按钮重叠）
                  if (currentDetail!.class_ != null &&
                      currentDetail!.class_!.isNotEmpty)
                    Expanded(
                      child: Text(
                        currentDetail!.class_!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2ecc71),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  if (currentDetail!.class_ == null ||
                      currentDetail!.class_!.isEmpty)
                    const Spacer(),

                  const SizedBox(width: 12),

                  // 详情按钮（平板横屏模式下不显示）
                  if (!(_isTablet && !_isPortraitTablet))
                    GestureDetector(
                      onTap: () {
                        _showDetailsPanel();
                      },
                      child: Stack(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '详情',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(width: 18),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: 4,
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 视频描述行
            if (videoDesc.isNotEmpty ||
                (doubanDetails?.summary != null &&
                    doubanDetails!.summary!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 0, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (videoDesc.isNotEmpty && videoDesc != '暂无简介')
                        ? videoDesc
                        : (doubanDetails?.summary ?? '暂无简介'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            // 选集区域
            _buildEpisodesSection(theme),

            const SizedBox(height: 16),

            // 换源区域
            _buildSourcesSection(theme),

            const SizedBox(height: 16),

            // 相关推荐区域
            _buildRecommendsSection(theme),
          ],
        ),
      ),
    );
  }

  /// 构建相关推荐区域
  Widget _buildRecommendsSection(ThemeData theme) {
    // 如果没有豆瓣详情或推荐列表为空，不显示此区域
    if (doubanDetails == null || doubanDetails!.recommends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 推荐标题行
        Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '相关推荐',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // 推荐卡片网格
        _buildRecommendsGrid(theme)
      ],
    );
  }

  /// 构建推荐卡片网格
  Widget _buildRecommendsGrid(ThemeData theme) {
    final recommends = doubanDetails!.recommends;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double padding = 16.0;
        final double spacing = 12.0;
        final crossAxisCount = _isTablet ? 6 : 3;
        final double availableWidth =
            screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1));
        final double minItemWidth = 80.0;
        final double calculatedItemWidth = availableWidth / crossAxisCount;
        final double itemWidth = math.max(calculatedItemWidth, minItemWidth);
        final double itemHeight = itemWidth * 2.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: itemWidth / itemHeight,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 4,
            ),
            itemCount: recommends.length,
            itemBuilder: (context, index) {
              final recommend = recommends[index];
              final videoInfo = recommend.toVideoInfo();

              return VideoCard(
                videoInfo: videoInfo,
                from: 'douban',
                cardWidth: itemWidth,
                onTap: () => _onRecommendTap(recommend),
              );
            },
          ),
        );
      },
    );
  }

  /// 处理推荐卡片点击
  void _onRecommendTap(DoubanRecommendItem recommend) {
    // 投屏状态下，弹窗提示用户先关闭投屏
    if (_isCasting) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先关闭投屏后再切换视频'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 本地播放：根据设备类型暂停对应播放器
    if (_videoPlayerController?.isPlaying == true) {
      _videoPlayerController?.pause();
    }

    // 跳转到新的播放页，只传递title参数
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: recommend.title,
        ),
      ),
    );
  }

  /// 构建选集区域
  Widget _buildEpisodesSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    // 如果总集数只有一集，则不展示选集区域
    if (totalEpisodes <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 选集标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '选集',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),

              // 正序/倒序按钮
              _HoverButton(
                onTap: _toggleEpisodesOrder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _isEpisodesReversed ? '倒序' : '正序',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Transform.translate(
                      offset: const Offset(0, 3),
                      child: Icon(
                        _isEpisodesReversed
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 滚动到当前集数按钮
              Transform.translate(
                offset: const Offset(0, 3.5),
                child: _HoverButton(
                  onTap: _scrollToCurrentEpisode,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 展开按钮
              _HoverButton(
                onTap: _showEpisodesPanel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -1.2),
                      child: Text(
                        '展开',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // 集数卡片横向滚动区域
        LayoutBuilder(
          builder: (context, constraints) {
            // 计算按钮宽度：根据设备类型调整
            final screenWidth = constraints.maxWidth;
            final horizontalPadding = 32.0; // 左右各16
            final availableWidth = screenWidth - horizontalPadding;
            final cardsPerView = _isTablet ? 6.2 : 3.2;
            final buttonWidth = (availableWidth / cardsPerView) - 6; // 减去右边距6
            final buttonHeight = buttonWidth * 1.8 / 3; // 稍微减少高度

            return SizedBox(
              height: buttonHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  controller: _episodesScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: currentDetail!.episodes.length,
                  itemBuilder: (context, index) {
                    final episodeIndex = _isEpisodesReversed
                        ? currentDetail!.episodes.length - 1 - index
                        : index;
                    final isCurrentEpisode =
                        episodeIndex == currentEpisodeIndex;

                    // 获取集数名称，如果episodesTitles为空或长度不够，则使用默认格式
                    String episodeTitle = '';
                    if (currentDetail!.episodesTitles.isNotEmpty &&
                        episodeIndex < currentDetail!.episodesTitles.length) {
                      episodeTitle =
                          currentDetail!.episodesTitles[episodeIndex];
                    } else {
                      episodeTitle = '第${episodeIndex + 1}集';
                    }

                    return Container(
                      width: buttonWidth,
                      margin: const EdgeInsets.only(right: 6),
                      child: AspectRatio(
                        aspectRatio: 3 / 2, // 严格保持3:2宽高比
                        child: _EpisodeCardWithHover(
                          isCurrentEpisode: isCurrentEpisode,
                          isDarkMode: isDarkMode,
                          episodeIndex: episodeIndex,
                          episodeTitle: episodeTitle,
                          onTap: isCurrentEpisode
                              ? null
                              : () {
                                  // 显示切换加载蒙版
                                  setState(() {
                                    _showSwitchLoadingOverlay = true;
                                    _switchLoadingMessage = '切换选集...';
                                  });

                                  // 集数切换前保存进度
                                  _saveProgress(force: true, scene: '选集列表点击');

                                  startPlay(episodeIndex, 0);
                                },
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建选集底部滑出面板
  void _showEpisodesPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 确定列数：竖屏平板4列，横屏平板3列，手机2列
    final crossAxisCount = _isPortraitTablet ? 4 : (_isTablet ? 3 : 2);

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: alignment,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: slideBegin,
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return PlayerEpisodesPanel(
                        theme: theme,
                        episodes: currentDetail!.episodes,
                        episodesTitles: currentDetail!.episodesTitles,
                        currentEpisodeIndex: currentEpisodeIndex,
                        isReversed: _isEpisodesReversed,
                        crossAxisCount: crossAxisCount,
                        onEpisodeTap: (index) {
                          Navigator.pop(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            this.setState(() {
                              _showSwitchLoadingOverlay = true;
                              _switchLoadingMessage = '切换选集...';
                            });
                          });
                          _saveProgress(force: true, scene: '选集面板点击');
                          startPlay(index, 0);
                        },
                        onToggleOrder: () {
                          setState(() {
                            _isEpisodesReversed = !_isEpisodesReversed;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerEpisodesPanel(
                theme: theme,
                episodes: currentDetail!.episodes,
                episodesTitles: currentDetail!.episodesTitles,
                currentEpisodeIndex: currentEpisodeIndex,
                isReversed: _isEpisodesReversed,
                crossAxisCount: crossAxisCount,
                onEpisodeTap: (index) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    this.setState(() {
                      _showSwitchLoadingOverlay = true;
                      _switchLoadingMessage = '切换选集...';
                    });
                  });
                  _saveProgress(force: true, scene: '选集面板点击');
                  startPlay(index, 0);
                },
                onToggleOrder: () {
                  setState(() {
                    _isEpisodesReversed = !_isEpisodesReversed;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 构建详情底部滑出面板
  void _showDetailsPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: alignment,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: slideBegin,
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: PlayerDetailsPanel(
                    theme: theme,
                    doubanDetails: doubanDetails,
                    currentDetail: currentDetail,
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerDetailsPanel(
                theme: theme,
                doubanDetails: doubanDetails,
                currentDetail: currentDetail,
              ),
            );
          },
        );
      },
    );
  }

  /// 构建换源区域
  Widget _buildSourcesSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 换源标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '换源',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              // 刷新按钮
              Transform.translate(
                offset: const Offset(0, 2.6),
                child: _HoverButton(
                  onTap: _isRefreshing ? null : _refreshSourcesSpeed,
                  enabled: !_isRefreshing,
                  child: RotationTransition(
                    turns: _refreshAnimationController,
                    child: Icon(
                      Icons.refresh,
                      size: 20,
                      color: _isRefreshing
                          ? Colors.green
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 滚动到当前源按钮
              Transform.translate(
                offset: const Offset(0, 3.5),
                child: _HoverButton(
                  onTap: _scrollToCurrentSource,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 展开按钮
              _HoverButton(
                onTap: _showSourcesPanel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -1.2),
                      child: Text(
                        '展开',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // 源卡片横向滚动区域
        _buildSourcesHorizontalScroll(theme),
      ],
    );
  }

  /// 构建源卡片横向滚动区域
  Widget _buildSourcesHorizontalScroll(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算卡片宽度：根据设备类型调整
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = 32.0; // 左右各16
        final availableWidth = screenWidth - horizontalPadding;
        final cardsPerView = _isTablet ? 6.2 : 3.2;
        final cardWidth = (availableWidth / cardsPerView) - 6; // 减去右边距6
        final cardHeight = cardWidth * 1.8 / 3; // 稍微减少高度

        return SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              controller: _sourcesScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: allSources.length,
              itemBuilder: (context, index) {
                final source = allSources[index];
                final isCurrentSource =
                    source.source == currentSource && source.id == currentID;
                final sourceKey = '${source.source}_${source.id}';
                final speedInfo = allSourcesSpeed[sourceKey];

                return Container(
                  width: cardWidth,
                  margin: const EdgeInsets.only(right: 6),
                  child: AspectRatio(
                    aspectRatio: 3 / 2, // 严格保持3:2宽高比
                    child: _SourceCardWithHover(
                      isCurrentSource: isCurrentSource,
                      isDarkMode: isDarkMode,
                      source: source,
                      speedInfo: speedInfo,
                      onTap:
                          isCurrentSource ? null : () => _switchSource(source),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 构建换源列表
  void _showSourcesPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: alignment,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: slideBegin,
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      return PlayerSourcesPanel(
                        theme: theme,
                        sources: allSources,
                        currentSource: currentSource,
                        currentId: currentID,
                        sourcesSpeed: allSourcesSpeed,
                        onSourceTap: (source) {
                          this.setState(() {
                            _switchSource(source);
                          });
                          Navigator.pop(context);
                        },
                        onRefresh: () async {
                          await _refreshSourcesSpeed(setState);
                        },
                        videoCover: videoCover,
                        videoTitle: videoTitle,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerSourcesPanel(
                theme: theme,
                sources: allSources,
                currentSource: currentSource,
                currentId: currentID,
                sourcesSpeed: allSourcesSpeed,
                onSourceTap: (source) {
                  this.setState(() {
                    _switchSource(source);
                  });
                  Navigator.pop(context);
                },
                onRefresh: () async {
                  await _refreshSourcesSpeed(setState);
                },
                videoCover: videoCover,
                videoTitle: videoTitle,
              ),
            );
          },
        );
      },
    ).then((_) {
      // 面板关闭后强制更新主界面的源卡片显示
      // 这样测速信息就能立即显示在主界面的源卡片上
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 刷新所有源的测速结果
  Future<void> _refreshSourcesSpeed([StateSetter? stateSetter]) async {
    if (allSources.isEmpty) return;

    final aSetState = stateSetter ?? setState;

    // 如果是从外部调用（非面板），设置刷新状态
    if (stateSetter == null) {
      setState(() {
        _isRefreshing = true;
      });
      _refreshAnimationController.repeat();
    }

    try {
      // 清空之前的测速结果
      allSourcesSpeed.clear();

      // 立即更新UI显示，让用户看到测速信息被清空
      aSetState(() {});

      // 使用新的实时测速方法
      final m3u8Service = M3U8Service();
      await m3u8Service.testSourcesWithCallback(
        allSources,
        (String sourceId, Map<String, dynamic> speedData) {
          // 每个源测速完成后立即更新
          allSourcesSpeed[sourceId] = SourceSpeed(
            quality: speedData['quality'] as String,
            loadSpeed: speedData['loadSpeed'] as String,
            pingTime: speedData['pingTime'] as String,
          );

          // 立即更新UI显示
          aSetState(() {});
        },
        timeout: const Duration(seconds: 10), // 自定义超时时间
      );
    } catch (e) {
      // 静默处理错误
    } finally {
      // 如果是从外部调用（非面板），停止刷新状态
      if (stateSetter == null) {
        setState(() {
          _isRefreshing = false;
        });
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    }
  }

  /// 构建错误覆盖层
  Widget _buildErrorOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

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
          // 装饰性圆点
          Positioned(
            top: 100,
            left: 40,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 50,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 错误图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8C42), Color(0xFFE74C3C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '😵',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 错误标题
                Text(
                  '哎呀, 出现了一些问题',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 错误信息框
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // 提示文字
                Text(
                  '请检查网络连接或尝试刷新页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 按钮组
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // 返回按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            hideError();
                            _onBackPressed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            '返回上页',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 重试按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: hideError,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFE2E8F0),
                            foregroundColor: isDarkMode
                                ? Colors.white
                                : const Color(0xFF3182CE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            '重新尝试',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF3182CE),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
