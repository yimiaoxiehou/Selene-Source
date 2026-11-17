import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/video_player_surface.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_card.dart';
import '../services/api_service.dart';
import '../services/m3u8_service.dart';
import '../services/douban_service.dart';
import '../services/user_data_service.dart';
import '../services/search_service.dart';
import '../models/search_result.dart';
import '../models/douban_movie.dart';
import '../models/play_record.dart';
import '../services/page_cache_service.dart';
import '../widgets/switch_loading_overlay.dart';
import '../widgets/dlna_player.dart';
import '../widgets/dlna_device_dialog.dart';
import '../utils/device_utils.dart';
import '../widgets/player_details_panel.dart';
import '../widgets/player_episodes_panel.dart';
import '../widgets/player_sources_panel.dart';
import '../widgets/windows_title_bar.dart';

part 'player/player_widget_builder.dart';
part 'player/player_sections.dart';
part 'player/player_layouts.dart';
part 'player/player_hover_widgets.dart';

class PlayerScreen extends StatefulWidget {
  final String? source;
  final String? id;
  final String title;
  final String? year;
  final String? stitle;
  final String? stype;
  final String? prefer;

  const PlayerScreen({
    super.key,
    this.source,
    this.id,
    required this.title,
    this.year,
    this.stitle,
    this.stype,
    this.prefer,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late SystemUiOverlayStyle _originalStyle;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showError = false;

  // 缓存设备类型，避免分辨率变化时改变布局
  late bool _isTablet;
  late bool _isPortraitTablet;

  // 加载状态
  bool _isLoading = true;
  String _loadingMessage = '正在搜索播放源...';
  String _loadingEmoji = '🔍'; // 加载图标 emoji
  double _loadingProgress = 0.0; // 加载进度百分比 (0.0 - 1.0)
  late AnimationController _loadingAnimationController;
  late AnimationController _textAnimationController;

  // 播放信息
  SearchResult? currentDetail;
  String searchTitle = '';
  String videoTitle = '';
  String videoDesc = '';
  String videoYear = '';
  String videoCover = '';
  int videoDoubanID = 0;
  String currentSource = '';
  String currentID = '';
  bool needPrefer = false;
  int totalEpisodes = 0;
  int currentEpisodeIndex = 0;

  // 豆瓣详情数据
  DoubanMovieDetails? doubanDetails;

  // 所有源信息
  List<SearchResult> allSources = [];
  // 所有源测速结果
  Map<String, SourceSpeed> allSourcesSpeed = {};

  // VideoPlayerWidget 的控制器
  VideoPlayerWidgetController? _videoPlayerController;

  // 收藏状态
  bool _isFavorite = false;

  // 切换播放源/集数时的加载蒙版状态
  bool _showSwitchLoadingOverlay = false;
  String _switchLoadingMessage = '切换播放源...';
  late AnimationController _switchLoadingAnimationController;

  // 投屏状态
  bool _isCasting = false;
  dynamic _dlnaDevice;
  Duration? _castStartPosition;
  Duration? _dlnaCurrentPosition; // DLNA 当前播放位置
  Duration? _dlnaCurrentDuration; // DLNA 视频总时长
  DLNAPlayerController? _dlnaPlayerController;

  // 选集相关状态
  bool _isEpisodesReversed = false;
  final ScrollController _episodesScrollController = ScrollController();

  // 换源相关状态
  final ScrollController _sourcesScrollController = ScrollController();

  // 刷新相关状态
  bool _isRefreshing = false;
  late AnimationController _refreshAnimationController;

  // 保存进度相关状态
  DateTime? _lastSaveTime;
  int? _lastSavePosition; // 上次保存的播放位置（秒）
  static const Duration _saveProgressInterval = Duration(seconds: 10);
  Duration? _resumeStartAt;

  // 网页全屏状态
  bool _isWebFullscreen = false;

  // 播放器的 GlobalKey，用于保持播放器状态
  final GlobalKey _playerKey = GlobalKey();
  int _loadGeneration = 0;

  bool _isActiveLoad(int generation) =>
      mounted && generation == _loadGeneration;

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _switchLoadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    // 添加应用生命周期监听器
    WidgetsBinding.instance.addObserver(this);
  }

  /// 设置竖屏方向
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// 恢复所有方向
  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void initParam() {
    currentSource = widget.source ?? '';
    currentID = widget.id ?? '';
    videoTitle = widget.title;
    videoYear = widget.year ?? '';
    needPrefer = widget.prefer != null && widget.prefer == 'true';
    searchTitle = widget.stitle ?? '';

    print('=== PlayerScreen 初始化参数 ===');
    print('currentSource: $currentSource');
    print('currentID: $currentID');
    print('videoTitle: $videoTitle');
    print('videoYear: $videoYear');
    print('needPrefer: $needPrefer');
    print('stitle: ${widget.stitle}');
    print('stype: ${widget.stype}');
    print('prefer: ${widget.prefer}');
  }

  void initVideoData() async {
    final loadGeneration = ++_loadGeneration;

    if (widget.source == null &&
        widget.id == null &&
        widget.title.isEmpty &&
        widget.stitle == null) {
      showError('缺少必要参数');
      return;
    }

    // 读取优选测速配置
    final preferSpeedTest = await UserDataService.getPreferSpeedTest();
    if (!_isActiveLoad(loadGeneration)) return;

    if (!preferSpeedTest ||
        (widget.source != null &&
            widget.id != null &&
            (widget.prefer == null || widget.prefer != 'true'))) {
      updateLoadingMessage('正在获取播放源详情...');
      updateLoadingProgress(0.5);
      updateLoadingEmoji('🔍');
    } else {
      updateLoadingMessage('正在搜索播放源...');
      updateLoadingProgress(0.33);
      updateLoadingEmoji('🔍');
    }

    // 初始化参数
    initParam();

    // 执行查询
    allSources = await fetchSourcesData(
        (searchTitle.isNotEmpty) ? searchTitle : videoTitle);
    if (!_isActiveLoad(loadGeneration)) return;

    if (currentSource.isNotEmpty &&
        currentID.isNotEmpty &&
        !allSources.any((source) =>
            source.source == currentSource && source.id == currentID)) {
      allSources = await fetchSourceDetail(currentSource, currentID);
      if (!_isActiveLoad(loadGeneration)) return;
    }
    if (allSources.isEmpty) {
      showError('未找到匹配结果');
      return;
    }

    // 指定源和id且无需优选
    currentDetail = allSources.first;
    if (currentSource.isNotEmpty && currentID.isNotEmpty && !needPrefer) {
      final target = allSources.where(
          (source) => source.source == currentSource && source.id == currentID);
      currentDetail = target.isNotEmpty ? target.first : null;
    }
    if (currentDetail == null) {
      showError('未找到匹配结果');
      return;
    }

    // 未指定源和 id/需要优选，且优选测速开关打开时，执行优选
    if ((currentSource.isEmpty || currentID.isEmpty || needPrefer) &&
        preferSpeedTest) {
      updateLoadingMessage('正在优选最佳播放源...');
      updateLoadingProgress(0.66);
      updateLoadingEmoji('⚡');
      currentDetail = await preferBestSource();
      if (!_isActiveLoad(loadGeneration)) return;
    }
    setInfosByDetail(currentDetail!);

    // 检查收藏状态
    _checkFavoriteStatus();

    // 获取播放记录
    int playEpisodeIndex = 0;
    int playTime = 0;
    if (mounted) {
      final allPlayRecords = await PageCacheService().getPlayRecords(context);
      if (!_isActiveLoad(loadGeneration)) return;
      // 查找是否有当前视频的播放记录
      if (allPlayRecords.success && allPlayRecords.data != null) {
        final matchingRecords = allPlayRecords.data!.where((record) =>
            record.id == currentID && record.source == currentSource);
        if (matchingRecords.isNotEmpty) {
          playEpisodeIndex = matchingRecords.first.index - 1;
          playTime = matchingRecords.first.playTime;
        }
      }
    }

    // 设置进度为 100%
    updateLoadingProgress(1.0);
    updateLoadingMessage('准备就绪，即将开始播放...');
    updateLoadingEmoji('✨');

    if (mounted) {
      setState(() {
        _showSwitchLoadingOverlay = true;
        _switchLoadingMessage = '视频加载中...';
      });
    }

    // 延时 1 秒后隐藏加载界面
    Future.delayed(const Duration(seconds: 1), () {
      if (_isActiveLoad(loadGeneration)) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // 设置播放
    if (!_isActiveLoad(loadGeneration)) return;
    startPlay(playEpisodeIndex, playTime);
  }

  void startPlay(int targetIndex, int playTime) {
    if (targetIndex >= currentDetail!.episodes.length) {
      targetIndex = 0;
      return;
    }
    if (mounted) {
      setState(() {
        currentEpisodeIndex = targetIndex;
      });
    }
    // 重置上次保存的位置，因为切换了集数
    _lastSavePosition = null;
    // 将 playTime 转换为 Duration 并传递给 updateVideoUrl
    final startAt = playTime > 0 ? Duration(seconds: playTime) : null;
    _resumeStartAt = startAt;
    updateVideoUrl(currentDetail!.episodes[targetIndex], startAt: null);
    _scrollToCurrentEpisode();
  }

  void setInfosByDetail(SearchResult detail) {
    videoTitle = detail.title;
    videoDesc = detail.desc ?? '';
    videoYear = detail.year;
    videoCover = detail.poster;
    currentSource = detail.source;
    currentID = detail.id;
    totalEpisodes = detail.episodes.length;

    // 保存旧的豆瓣ID用于比较
    int oldVideoDoubanID = videoDoubanID;

    // 设置当前豆瓣 ID
    if (detail.doubanId != null && detail.doubanId! > 0) {
      // 如果当前 searchResult 有有效的 doubanID，直接使用
      videoDoubanID = detail.doubanId!;
    } else {
      // 否则统计出现次数最多的 doubanID
      Map<int, int> doubanIDCount = {};
      for (var result in allSources) {
        int? tmpDoubanID = result.doubanId;
        if (tmpDoubanID == null || tmpDoubanID == 0) {
          continue;
        }
        doubanIDCount[tmpDoubanID] = (doubanIDCount[tmpDoubanID] ?? 0) + 1;
      }
      videoDoubanID = doubanIDCount.entries.isEmpty
          ? 0
          : doubanIDCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
    }

    // 如果豆瓣ID发生变化且有效，获取豆瓣详情
    if (videoDoubanID != oldVideoDoubanID && videoDoubanID > 0) {
      _fetchDoubanDetails();
    }

    // 延迟调用自动滚动，确保UI已更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrentEpisode();
      _scrollToCurrentSource();
    });
  }

  /// 获取豆瓣详情数据
  Future<void> _fetchDoubanDetails() async {
    if (videoDoubanID <= 0) {
      doubanDetails = null;
      return;
    }

    try {
      final requestDoubanId = videoDoubanID.toString();
      final response = await DoubanService.getDoubanDetails(
        context,
        doubanId: requestDoubanId,
      );
      if (!mounted || videoDoubanID.toString() != requestDoubanId) return;

      if (response.success && response.data != null) {
        setState(() {
          doubanDetails = response.data;
          // 如果当前视频描述为空或是"暂无简介"，使用豆瓣的描述
          if ((videoDesc.isEmpty || videoDesc == '暂无简介') &&
              response.data!.summary != null &&
              response.data!.summary!.isNotEmpty) {
            videoDesc = response.data!.summary!;
          }
        });
      } else {
        print('获取豆瓣详情失败: ${response.message}');
      }
    } catch (e) {
      print('获取豆瓣详情异常: $e');
    }
  }

  Future<SearchResult> preferBestSource() async {
    final m3u8Service = M3U8Service();
    final result = await m3u8Service.preferBestSource(allSources);

    // 更新测速结果
    final speedResults = result['allSourcesSpeed'] as Map<String, dynamic>;
    for (final entry in speedResults.entries) {
      final speedData = entry.value as Map<String, dynamic>;
      allSourcesSpeed[entry.key] = SourceSpeed(
        quality: speedData['quality'] as String,
        loadSpeed: speedData['loadSpeed'] as String,
        pingTime: speedData['pingTime'] as String,
      );
    }

    return result['bestSource'] as SearchResult;
  }

  // 处理返回按钮点击
  void _onBackPressed() async {
    // 如果正在投屏，停止投屏
    if (_isCasting && _dlnaDevice != null) {
      try {
        // 显示弹窗让用户选择
        final shouldStop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('停止投屏'),
            content: const Text('DLNA 设备可继续保持播放，是否需要停止？\n\n（保持播放时无法同步进度和播放记录）'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('保持'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('停止'),
              ),
            ],
          ),
        );
        if (!mounted) return;

        // 如果用户选择停止，才调用 stop
        if (shouldStop == true) {
          try {
            _dlnaDevice.stop();
            debugPrint('用户选择停止投屏');
          } catch (e) {
            debugPrint('停止投屏失败: $e');
          }
        } else {
          debugPrint('用户选择保持播放');
        }
      } catch (e) {
        debugPrint('停止投屏失败: $e');
      }
    }

    // 关闭页面前保存进度
    if (!mounted) return;
    _saveProgress(force: true, scene: '返回按钮');
    Navigator.of(context).pop();
  }

  // 退出网页全屏
  void _exitWebFullscreen() {
    if (!DeviceUtils.isPC()) {
      return;
    }
    // 通知播放器控件退出网页全屏
    // 播放器控件会通过 onWebFullscreenChanged 回调来更新 _isWebFullscreen 状态
    if (_videoPlayerController != null) {
      _videoPlayerController!.exitWebFullscreen();
    }
  }

  /// 保存播放进度（同步函数，提前获取参数避免异步问题）
  void _saveProgress({bool force = false, required String scene}) {
    try {
      if (currentDetail == null) return;

      // 获取当前播放位置和总时长
      Duration? currentPosition;
      Duration? duration;

      if (_isCasting) {
        // 投屏状态：从 DLNA 播放器获取
        currentPosition = _dlnaCurrentPosition;
        duration = _dlnaCurrentDuration;
      } else {
        // 本地播放：根据设备类型从对应播放器获取
        if (_videoPlayerController == null) return;
        currentPosition = _videoPlayerController!.currentPosition;
        duration = _videoPlayerController!.duration;
      }

      if (currentPosition == null || duration == null) return;

      // 如果播放进度小于 1 s，则不保存
      if (currentPosition.inSeconds < 1) {
        return;
      }

      final playTime = currentPosition.inSeconds;
      final totalTime = duration.inSeconds;
      // 如果不是强制保存，检查时间间隔和进度变化
      if (!force) {
        final now = DateTime.now();
        // 检查时间间隔
        if (_lastSaveTime != null &&
            now.difference(_lastSaveTime!) < _saveProgressInterval) {
          return; // 时间间隔不够，跳过保存
        }
        // 检查进度是否发生变化（允许1秒的误差）
        if (_lastSavePosition != null && playTime == _lastSavePosition!) {
          return; // 进度没有明显变化，跳过保存
        }
      }

      // 更新最后保存时间和位置
      _lastSaveTime = DateTime.now();
      _lastSavePosition = playTime;

      // 提前获取所有需要的参数，避免异步执行时参数被改变
      final currentIDSnapshot = currentID;
      final currentSourceSnapshot = currentSource;
      final videoTitleSnapshot = videoTitle;
      final videoYearSnapshot = videoYear;
      final videoCoverSnapshot = videoCover;
      final currentEpisodeIndexSnapshot = currentEpisodeIndex;
      final totalEpisodesSnapshot = totalEpisodes;
      final searchTitleSnapshot = searchTitle;
      final sourceNameSnapshot = currentDetail?.sourceName ?? currentSource;

      // 创建播放记录对象
      final playRecord = PlayRecord(
        id: currentIDSnapshot,
        source: currentSourceSnapshot,
        title: videoTitleSnapshot,
        sourceName: sourceNameSnapshot,
        year: videoYearSnapshot,
        cover: videoCoverSnapshot,
        index: currentEpisodeIndexSnapshot + 1, // 转换为1开始的索引
        totalEpisodes: totalEpisodesSnapshot,
        playTime: playTime,
        totalTime: totalTime,
        saveTime: DateTime.now().millisecondsSinceEpoch, // 当前时间戳（毫秒）
        searchTitle: searchTitleSnapshot,
      );

      // 异步保存播放记录（不等待结果）
      PageCacheService().savePlayRecord(playRecord, context).then((_) {
        debugPrint(
            '保存播放进度 [场景: $scene]: source: $currentSourceSnapshot, id: $currentIDSnapshot, 第${currentEpisodeIndexSnapshot + 1}集, 时间: ${playTime}秒');
      }).catchError((e) {
        debugPrint('保存播放进度失败 [场景: $scene]: $e');
      });
    } catch (e) {
      debugPrint('保存播放进度失败: $e');
    }
  }

  /// 检查并保存进度（基于时间间隔）
  void _checkAndSaveProgress() {
    _saveProgress(scene: '定时保存');
  }

  /// 应用生命周期状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        if (DeviceUtils.isPC()) {
          break;
        }
        // 应用进入后台前保存进度
        _saveProgress(force: true, scene: '应用进入后台');
        break;
      case AppLifecycleState.resumed:
        if (DeviceUtils.isPC()) {
          break;
        }
        _lastSaveTime = null;
        _lastSavePosition = null;
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// 显示错误信息
  void showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _showError = true;
        _isLoading = false;
      });
    }
  }

  /// 隐藏错误信息
  void hideError() {
    if (mounted) {
      setState(() {
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  void updateLoadingMessage(String message) {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
      });
    }
  }

  /// 更新加载进度
  void updateLoadingProgress(double progress) {
    if (mounted) {
      setState(() {
        _loadingProgress = progress.clamp(0.0, 1.0);
      });
    }
  }

  /// 更新加载 emoji
  void updateLoadingEmoji(String emoji) {
    if (mounted) {
      setState(() {
        _loadingEmoji = emoji;
      });
    }
  }

  /// 动态更新视频数据源
  Future<void> updateVideoUrl(String newUrl, {Duration? startAt}) async {
    print("newUrl: $newUrl, startAt: $startAt");
    try {
      // 获取 M3U8 代理 URL
      final m3u8ProxyUrl = await UserDataService.getM3u8ProxyUrl();

      // 如果代理 URL 不为空，则将 newUrl encode 后拼接到代理 URL 后面
      String finalUrl = newUrl;
      if (m3u8ProxyUrl.isNotEmpty) {
        final encodedUrl = Uri.encodeComponent(newUrl);
        finalUrl = '$m3u8ProxyUrl$encodedUrl';
        print("使用 M3U8 代理: $finalUrl");
      }

      if (_isCasting) {
        // 构建标题：{title} - {第 x 集} - {sourceName}
        // 如果总集数为 1，则不显示集数
        final sourceName = currentDetail?.sourceName ?? currentSource;
        String formattedTitle;
        if (totalEpisodes > 1) {
          final episodeNumber = currentEpisodeIndex + 1;
          formattedTitle = '$videoTitle - 第 $episodeNumber 集 - $sourceName';
        } else {
          formattedTitle = '$videoTitle - $sourceName';
        }
        // 投屏状态：调用 DLNA 播放器的 updateVideoUrl
        _dlnaPlayerController?.updateVideoUrl(finalUrl, formattedTitle,
            startAt: startAt);
      } else {
        // 本地播放：根据设备类型调用对应播放器的 updateDataSource
        await _videoPlayerController?.updateDataSource(finalUrl,
            startAt: startAt);
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 跳转到指定进度
  Future<void> seekToProgress(Duration position) async {
    try {
      await _videoPlayerController?.seekTo(position);
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 跳转到指定秒数
  Future<void> seekToSeconds(double seconds) async {
    await seekToProgress(Duration(seconds: seconds.round()));
  }

  /// 获取当前播放位置
  Duration? get currentPosition {
    if (_isCasting) {
      // 投屏状态：从 DLNA 播放器获取
      return _dlnaCurrentPosition;
    } else {
      return _videoPlayerController?.currentPosition;
    }
  }

  /// 处理视频播放器 ready 事件
  void _onVideoPlayerReady() {
    if (!mounted) return;

    // 视频播放器准备就绪时的处理逻辑
    debugPrint('Video player is ready!');

    setState(() {
      // 隐藏切换加载蒙版
      _showSwitchLoadingOverlay = false;
    });

    // 重置最后保存时间，允许立即保存
    _lastSaveTime = null;

    // 添加视频播放状态监听器来触发保存检查
    _addVideoProgressListener();

    // 延时三秒 seek 到 _resumeStartAt
    if (_resumeStartAt != null) {
      final tmpStartAt = _resumeStartAt;
      _resumeStartAt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tmpStartAt != null) {
          seekToProgress(tmpStartAt);
        }
      });
    }
  }

  /// 添加视频播放进度监听器
  void _addVideoProgressListener() {
    if (_videoPlayerController != null) {
      // 添加进度监听器
      _videoPlayerController!.addProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 移除视频播放进度监听器
  void _removeVideoProgressListener() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.removeProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 视频播放进度更新回调
  void _onVideoProgressUpdate() {
    // 检查并保存进度（基于时间间隔）
    _checkAndSaveProgress();
  }

  /// 处理下一集按钮点击
  void _onNextEpisode() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      _showToast('已经是最后一集了');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换选集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '下一集按钮');

    // 播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 处理视频播放完成
  void _onVideoCompleted() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      _showToast('播放完成');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '自动播放下一集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '自动播放下一集');

    // 自动播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 显示Toast消息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 检查收藏状态
  void _checkFavoriteStatus() {
    if (currentSource.isNotEmpty && currentID.isNotEmpty) {
      final cacheService = PageCacheService();
      final isFavorited =
          cacheService.isFavoritedSync(currentSource, currentID);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorited;
        });
      }
    }
  }

  /// 切换收藏状态
  void _toggleFavorite() async {
    if (currentSource.isEmpty || currentID.isEmpty) return;

    final cacheService = PageCacheService();

    if (_isFavorite) {
      // 取消收藏
      final result =
          await cacheService.removeFavorite(currentSource, currentID, context);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _isFavorite = false;
        });
      }
    } else {
      // 添加收藏
      final favoriteData = {
        'cover': videoCover,
        'save_time': DateTime.now().millisecondsSinceEpoch,
        'source_name': currentDetail?.sourceName ?? '',
        'title': videoTitle,
        'total_episodes': totalEpisodes,
        'year': videoYear,
      };

      final result = await cacheService.addFavorite(
          currentSource, currentID, favoriteData, context);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _isFavorite = true;
        });
      }
    }
  }

  /// 切换选集排序
  void _toggleEpisodesOrder() {
    setState(() {
      _isEpisodesReversed = !_isEpisodesReversed;
    });
    // 切换排序后自动滚动到当前集数
    _scrollToCurrentEpisode();
  }

  /// 滚动到当前源
  void _scrollToCurrentSource() {
    if (currentDetail == null) return;

    // 换源已收起，直接执行滚动
    _performScrollToCurrentSource();
  }

  /// 执行滚动到当前源的具体逻辑
  void _performScrollToCurrentSource() {
    if (!mounted ||
        currentDetail == null ||
        !_sourcesScrollController.hasClients) {
      return;
    }

    // 找到当前源在allSources中的索引
    final currentSourceIndex = allSources.indexWhere(
        (source) => source.source == currentSource && source.id == currentID);

    if (currentSourceIndex == -1) return;

    // 动态计算卡片宽度
    // 在平板横屏模式下，需要考虑左侧区域只占65%的宽度
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth = (_isTablet && !_isPortraitTablet)
        ? screenWidth * 0.65 // 平板横屏：只使用左侧65%的宽度
        : screenWidth; // 其他情况：使用全屏宽度

    const listViewPadding = 16.0; // ListView的左右padding
    const itemMargin = 6.0; // 每个item的右边距
    final availableWidth =
        effectiveWidth - (listViewPadding * 2); // 减去左右padding
    final cardsPerView = _isTablet ? 6.2 : 3.2;
    final cardWidth = (availableWidth / cardsPerView) - itemMargin; // 减去右边距

    // 计算选中项在可视区域中央的偏移量
    // 可视区域中心 = (有效宽度 - ListView左右padding) / 2
    // 选中项应该位于这个中心位置
    final visibleAreaWidth = effectiveWidth - (listViewPadding * 2);
    final visibleCenter = visibleAreaWidth / 2;
    final itemCenter = cardWidth / 2;

    // 计算需要滚动的距离，使选中项的中心对准可视区域的中心
    // 注意：要减去第一个item的左边距（因为ListView有左padding）
    final targetOffset = (currentSourceIndex * (cardWidth + itemMargin)) -
        (visibleCenter - itemCenter - listViewPadding);

    // 确保不滚动到负值或超出范围
    final maxScrollExtent = _sourcesScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScrollExtent);

    _sourcesScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 切换视频源
  void _switchSource(SearchResult newSource) async {
    if (!mounted) return;

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换播放源...';
    });

    // 保存当前播放进度
    final currentProgress = currentPosition?.inSeconds ?? 0;
    final currentEpisode = currentEpisodeIndex;

    // 记录旧的源信息，用于删除播放记录
    final oldSource = currentSource;
    final oldID = currentID;

    setState(() {
      currentDetail = newSource;
      currentSource = newSource.source;
      currentID = newSource.id;
      currentEpisodeIndex = currentEpisode; // 保持当前集数
      totalEpisodes = newSource.episodes.length;
      _isEpisodesReversed = false;
    });

    // 删除之前的播放记录（如果源发生了变化）
    if (oldSource.isNotEmpty &&
        oldID.isNotEmpty &&
        (oldSource != newSource.source || oldID != newSource.id)) {
      try {
        await PageCacheService().deletePlayRecord(oldSource, oldID, context);
        if (!mounted) return;
        debugPrint('删除旧源播放记录: $oldSource+$oldID');
      } catch (e) {
        debugPrint('删除旧源播放记录失败: $e');
        if (!mounted) return;
      }
    }

    // 更新视频信息
    setInfosByDetail(newSource);

    // 重新检查收藏状态（因为源和ID可能已改变）
    _checkFavoriteStatus();

    // 开始播放新源，使用当前播放器的进度
    startPlay(currentEpisode, currentProgress);

    // 延迟滚动到当前源，等待UI更新完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrentSource();
    });
  }

  /// 自动滚动到当前集数
  void _scrollToCurrentEpisode() {
    if (currentDetail == null) return;

    // 如果选集展开，先收起选集，然后滚动到当前集数
    _performScrollToCurrentEpisode();
  }

  /// 执行滚动到当前集数的具体逻辑
  void _performScrollToCurrentEpisode() {
    if (!mounted ||
        currentDetail == null ||
        !_episodesScrollController.hasClients) {
      return;
    }

    // 动态计算按钮宽度
    // 在平板横屏模式下，需要考虑左侧区域只占65%的宽度
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth = (_isTablet && !_isPortraitTablet)
        ? screenWidth * 0.65 // 平板横屏：只使用左侧65%的宽度
        : screenWidth; // 其他情况：使用全屏宽度

    const listViewPadding = 16.0; // ListView的左右padding
    const itemMargin = 6.0; // 每个item的右边距
    final availableWidth =
        effectiveWidth - (listViewPadding * 2); // 减去左右padding
    final cardsPerView = _isTablet ? 6.2 : 3.2;
    final buttonWidth = (availableWidth / cardsPerView) - itemMargin; // 减去右边距

    final targetIndex = _isEpisodesReversed
        ? currentDetail!.episodes.length - 1 - currentEpisodeIndex
        : currentEpisodeIndex;

    // 计算选中项在可视区域中央的偏移量
    // 可视区域中心 = (有效宽度 - ListView左右padding) / 2
    // 选中项应该位于这个中心位置
    final visibleAreaWidth = effectiveWidth - (listViewPadding * 2);
    final visibleCenter = visibleAreaWidth / 2;
    final itemCenter = buttonWidth / 2;

    // 计算需要滚动的距离，使选中项的中心对准可视区域的中心
    // 注意：要减去第一个item的左边距（因为ListView有左padding）
    final targetOffset = (targetIndex * (buttonWidth + itemMargin)) -
        (visibleCenter - itemCenter - listViewPadding);

    // 确保不滚动到负值或超出范围
    final maxScrollExtent = _episodesScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScrollExtent);

    _episodesScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 投屏开始回调
  void _onCastStarted(dynamic device) {
    // 保存当前播放位置
    final currentPos = _videoPlayerController?.currentPosition;

    setState(() {
      _isCasting = true;
      _dlnaDevice = device;
      _castStartPosition = currentPos;
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    });
  }

  /// DLNA 进度更新回调
  void _onDLNAProgressUpdate(Duration position, Duration duration) {
    _dlnaCurrentPosition = position;
    _dlnaCurrentDuration = duration;
    // 检查并保存进度
    _checkAndSaveProgress();
  }

  /// 停止投屏回调
  void _onStopCasting(Duration currentPosition) async {
    // 显示弹窗让用户选择
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('停止投屏'),
        content: const Text('DLNA 设备可继续保持播放，是否需要停止？\n\n（保持播放时无法同步进度和播放记录）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保持'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('停止'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    // 如果用户选择停止，才调用 stop
    if (shouldStop == true) {
      try {
        _dlnaDevice.stop();
        debugPrint('用户选择停止投屏');
      } catch (e) {
        debugPrint('停止投屏失败: $e');
      }
    } else {
      debugPrint('用户选择保持播放');
    }

    debugPrint('停止投屏，当前位置: ${currentPosition.inSeconds}秒');

    // 先保存需要恢复的位置和集数，避免异步回调中值丢失
    final resumeSeconds = currentPosition.inSeconds;
    final resumeEpisodeIndex = currentEpisodeIndex;

    setState(() {
      _isCasting = false;
      _dlnaDevice = null;
      _castStartPosition = null;
      _dlnaCurrentPosition = null;
      _dlnaCurrentDuration = null;
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '视频加载中...';
    });

    // 等待下一帧，确保 MobileVideoPlayerWidget 已经重新创建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentDetail != null) {
        debugPrint('恢复播放: 第${resumeEpisodeIndex + 1}集, ${resumeSeconds}秒');
        // 调用 startPlay 重新初始化播放器
        startPlay(resumeEpisodeIndex, resumeSeconds);
      }
    });
  }

  /// 换设备回调
  void _onChangeDevice() async {
    if (currentDetail == null) return;

    // 获取当前播放的 URL
    final currentUrl = currentDetail!.episodes[currentEpisodeIndex];

    // 显示设备选择对话框
    await showDialog(
      context: context,
      builder: (context) => DLNADeviceDialog(
        currentUrl: currentUrl,
        currentDevice: _dlnaDevice,
        resumePosition: _castStartPosition,
        videoTitle: videoTitle,
        currentEpisodeIndex: currentEpisodeIndex,
        totalEpisodes: totalEpisodes,
        sourceName: currentDetail?.sourceName ?? currentSource,
        onCastStarted: (device) {
          if (!mounted) return;
          setState(() {
            _dlnaDevice = device;
          });
        },
      ),
    );
  }


  /// 获取视频详情
  Future<List<SearchResult>> fetchSourceDetail(String source, String id) async {
    // 检查是否启用本地搜索
    final isLocalSearch = await UserDataService.getLocalSearch();
    if (isLocalSearch) {
      return await SearchService.getDetailSync(source, id);
    } else {
      return await ApiService.fetchSourceDetail(source, id);
    }
  }

  /// 搜索视频源数据（带过滤）
  Future<List<SearchResult>> fetchSourcesData(String query) async {
    // 检查是否启用本地搜索
    final isLocalSearch = await UserDataService.getLocalSearch();
    final isLocalMode = await UserDataService.getIsLocalMode();

    List<SearchResult> results;
    if (isLocalSearch || isLocalMode) {
      // 使用本地搜索
      results = await SearchService.searchSync(query);
    } else {
      // 使用服务器搜索
      results = await ApiService.fetchSourcesData(query);
    }

    // 直接在这里展开过滤逻辑
    return results.where((result) {
      // 标题匹配检查
      final titleMatch = result.title.replaceAll(' ', '').toLowerCase() ==
          (widget.title.replaceAll(' ', '').toLowerCase());

      // 年份匹配检查
      final yearMatch = widget.year == null ||
          result.year.toLowerCase() == widget.year!.toLowerCase();

      // 类型匹配检查
      bool typeMatch = true;
      if (widget.stype != null) {
        if (widget.stype == 'tv') {
          typeMatch = result.episodes.length > 1;
        } else if (widget.stype == 'movie') {
          typeMatch = result.episodes.length == 1;
        }
      }

      return titleMatch && yearMatch && typeMatch;
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // 缓存设备类型，避免分辨率变化时改变布局
      _isTablet = DeviceUtils.isTablet(context);
      _isPortraitTablet = DeviceUtils.isPortraitTablet(context);

      // 设置屏幕方向（平板除外）
      // 如果是平板，不强制竖屏
      if (!_isTablet) {
        _setPortraitOrientation();
      }
      // 保存当前的系统UI样式
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      _originalStyle = SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      );
      _isInitialized = true;

      // 初始化视频数据
      initVideoData();
    }
  }

  @override
  void dispose() {
    // 保存进度
    _saveProgress(force: true, scene: '页面销毁');
    // 移除视频进度监听器
    _removeVideoProgressListener();
    // 移除应用生命周期监听器
    WidgetsBinding.instance.removeObserver(this);
    // 恢复屏幕方向
    _restoreOrientation();
    // 恢复原始的系统UI样式
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    // 销毁播放器
    _videoPlayerController?.dispose();
    // 释放滚动控制器
    _episodesScrollController.dispose();
    _sourcesScrollController.dispose();
    // 释放动画控制器
    _refreshAnimationController.dispose();
    _loadingAnimationController.dispose();
    _textAnimationController.dispose();
    _switchLoadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor:
            isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
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
            color: isDarkMode ? theme.scaffoldBackgroundColor : null,
          ),
          child: Column(
            children: [
              // Windows 自定义标题栏（播放页使用纯黑背景）
              if (Platform.isWindows)
                const WindowsTitleBar(
                  customBackgroundColor: Color(0xFF000000),
                ),
              // 主要内容
              Expanded(
                child: Stack(
                  children: [
                    // 主要内容（不包含播放器）
                    if (!_isWebFullscreen)
                      if (_isTablet && !_isPortraitTablet)
                        // 平板横屏模式：左右布局
                        _buildTabletLandscapeLayout(theme)
                      else if (_isPortraitTablet)
                        // 平板竖屏模式：上下布局，播放器占50%高度
                        _buildPortraitTabletLayout(theme)
                      else
                        // 手机模式：保持原有布局
                        _buildPhoneLayout(theme),
                    // 播放器层（使用 Positioned 控制位置和大小）
                    _buildPlayerLayer(theme),
                    // 错误覆盖层
                    if (_showError && _errorMessage != null)
                      _buildErrorOverlay(theme),
                    // 加载覆盖层
                    if (_isLoading) _buildLoadingOverlay(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

