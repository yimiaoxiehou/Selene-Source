part of '../player_screen.dart';
// ignore_for_file: invalid_use_of_protected_member
// extension 内调用 State.setState 是安全的，lint 无法识别扩展成员上下文

/// 拆分自 player_screen.dart（原 _PlayerScreenState 成员方法）
extension on _PlayerScreenState {
  /// 构建播放器组件
  Widget _buildPlayerWidget() {
    final isPC = DeviceUtils.isPC();

    return Stack(
      children: [
        if (!_isCasting)
          VideoPlayerWidget(
            surface: VideoPlayerSurface.desktop,
            url: null,
            onBackPressed: _onBackPressed,
            onControllerCreated: (controller) {
              _videoPlayerController = controller;
            },
            onReady: _onVideoPlayerReady,
            onNextEpisode: _onNextEpisode,
            onVideoCompleted: _onVideoCompleted,
            onPause: () {
              // 暂停时保存进度
              _saveProgress(force: true, scene: '暂停');
            },
            isLastEpisode: currentDetail != null &&
                currentEpisodeIndex >= currentDetail!.episodes.length - 1,
            onCastStarted: _onCastStarted,
            videoTitle: videoTitle,
            currentEpisodeIndex: currentEpisodeIndex,
            totalEpisodes: totalEpisodes,
            sourceName: currentDetail?.sourceName ?? currentSource,
            onWebFullscreenChanged: (isWebFullscreen) {
              setState(() {
                _isWebFullscreen = isWebFullscreen;
              });
            },
          ),
        if (_isCasting && _dlnaDevice != null)
          DLNAPlayer(
            device: _dlnaDevice,
            onBackPressed: _onBackPressed,
            onNextEpisode: _onNextEpisode,
            onVideoCompleted: _onVideoCompleted,
            isLastEpisode: currentDetail != null &&
                currentEpisodeIndex >= currentDetail!.episodes.length - 1,
            onChangeDevice: _onChangeDevice,
            resumePosition: _castStartPosition,
            onStopCasting: _onStopCasting,
            onProgressUpdate: _onDLNAProgressUpdate,
            onPause: () {
              // 暂停时保存进度
              _saveProgress(force: true, scene: 'DLNA暂停');
            },
            onReady: _onVideoPlayerReady,
            onControllerCreated: (controller) {
              _dlnaPlayerController = controller;
            },
          ),
        // 切换播放源/集数时的加载蒙版（只遮挡播放器）
        SwitchLoadingOverlay(
          isVisible: _showSwitchLoadingOverlay,
          message: _switchLoadingMessage,
          animationController: _switchLoadingAnimationController,
          onBackPressed: _isWebFullscreen ? _exitWebFullscreen : _onBackPressed,
        ),
      ],
    );
  }
}
