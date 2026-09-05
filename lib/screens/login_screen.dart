import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import '../services/user_data_service.dart';
import '../services/local_mode_storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import '../widgets/tv_keyboard.dart';
import '../widgets/windows_title_bar.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _subscriptionUrlController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isFormValid = false;
  bool _isLocalMode = false;

  // TV/遥控：当前正在用屏幕键盘编辑的字段（null 表示未在编辑）
  String? _editingField;

  // 最近一次因返回键关闭键盘的时间戳，用于区分“同一次返回按键的系统返回通道”
  // 与“另一次返回按键”，避免关闭键盘后紧跟着被系统返回退出应用。
  DateTime? _editorClosedAt;

  // 点击计数器相关
  int _logoTapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _subscriptionUrlController.addListener(_validateForm);
    _loadSavedUserData();
  }

  void _loadSavedUserData() async {
    final userData = await UserDataService.getAllUserData();
    if (!mounted) return;

    bool hasData = false;

    if (userData['serverUrl'] != null) {
      _urlController.text = userData['serverUrl']!;
      hasData = true;
    }
    if (userData['username'] != null) {
      _usernameController.text = userData['username']!;
      hasData = true;
    }
    if (userData['password'] != null) {
      _passwordController.text = userData['password']!;
      hasData = true;
    }

    // 加载订阅链接（用于回填）
    final subscriptionUrl = await LocalModeStorageService.getSubscriptionUrl();
    if (!mounted) return;

    if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
      _subscriptionUrlController.text = subscriptionUrl;
      hasData = true;
    }

    // 如果有数据被加载，更新UI状态
    if (hasData && mounted) {
      _validateForm();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _subscriptionUrlController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleLogoTap() {
    _logoTapCount++;

    // 取消之前的计时器
    _tapTimer?.cancel();

    // 如果达到10次，切换到本地模式
    if (_logoTapCount >= 10) {
      setState(() {
        _isLocalMode = !_isLocalMode;
        _validateForm();
        _logoTapCount = 0;
      });
      _showToast(
        _isLocalMode ? '已切换到本地模式' : '已切换到服务器模式',
        const Color(0xFF27ae60),
      );
    } else {
      // 设置新的计时器，2秒后重置计数
      _tapTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _logoTapCount = 0;
        });
      });
    }
  }

  /// 本地/服务器模式切换按钮（TV/遥控可聚焦，替代连点 Logo 10 次的隐藏操作）
  Widget _buildModeToggle() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _toggleMode();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return TextButton(
            onPressed: _toggleMode,
            style: TextButton.styleFrom(
              side: focused
                  ? const BorderSide(color: Color(0xFF27ae60), width: 2)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _isLocalMode
                  ? '当前：本地模式（点击切换服务器模式）'
                  : '当前：服务器模式（点击切换本地模式）',
              style: FontUtils.poppins(
                fontSize: 12,
                color: const Color(0xFF7f8c8d),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLocalMode = !_isLocalMode;
      _validateForm();
    });
    _showToast(
      _isLocalMode ? '已切换到本地模式' : '已切换到服务器模式',
      const Color(0xFF27ae60),
    );
  }

  TextEditingController get _editingController {
    switch (_editingField) {
      case 'url':
        return _urlController;
      case 'username':
        return _usernameController;
      case 'password':
        return _passwordController;
      case 'subscription':
        return _subscriptionUrlController;
      default:
        return _urlController;
    }
  }

  void _openEditor(String field) {
    _editorClosedAt = null;
    setState(() => _editingField = field);
  }

  /// 返回键关闭键盘：记录时间戳，供 PopScope.onPopInvoked 判断是否为同一次返回
  void _handleEditorBack() {
    setState(() {
      _editingField = null;
      _editorClosedAt = DateTime.now();
    });
    _validateForm();
  }

  void _applyEditingValue(String v) {
    _editingController.text = v;
    _validateForm();
  }

  void _validateForm() {
    if (!mounted) return;

    setState(() {
      if (_isLocalMode) {
        _isFormValid = _subscriptionUrlController.text.isNotEmpty;
      } else {
        _isFormValid = _urlController.text.isNotEmpty &&
            _usernameController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty;
      }
    });
  }

  // 处理回车键提交
  void _handleSubmit() {
    if (_isLocalMode) {
      _handleLocalModeLogin();
    } else {
      _handleLogin();
    }
  }

  Widget _buildLocalModeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 订阅链接输入框
        TextFormField(
          controller: _subscriptionUrlController,
          style: FontUtils.poppins(
            fontSize: 16,
            color: const Color(0xFF2c3e50),
          ),
          decoration: InputDecoration(
            labelText: '订阅链接',
            labelStyle: FontUtils.poppins(
              color: const Color(0xFF7f8c8d),
              fontSize: 14,
            ),
            hintText: '请输入订阅链接',
            hintStyle: FontUtils.poppins(
              color: const Color(0xFFbdc3c7),
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.link,
              color: Color(0xFF7f8c8d),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入订阅链接';
            }
            return null;
          },
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 32),

        // 登录按钮
        ElevatedButton(
          onPressed:
              (_isLoading || !_isFormValid) ? null : _handleLocalModeLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid && !_isLoading
                ? const Color(0xFF2c3e50)
                : const Color(0xFFbdc3c7),
            foregroundColor: _isFormValid && !_isLoading
                ? Colors.white
                : const Color(0xFF7f8c8d),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '登录中...',
                      style: FontUtils.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  '登录',
                  style: FontUtils.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ],
    );
  }

  String _processUrl(String url) {
    // 去除尾部斜杠
    String processedUrl = url.trim();
    if (processedUrl.endsWith('/')) {
      processedUrl = processedUrl.substring(0, processedUrl.length - 1);
    }
    return processedUrl;
  }

  String _parseCookies(http.Response response) {
    // 解析 Set-Cookie 头部
    List<String> cookies = [];

    // 获取所有 Set-Cookie 头部
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
      // Dart 的 http 包会把多个 Set-Cookie 头部用 ", " 合并成一个字符串。
      // Cookie 属性值（如 Expires=Thu, 01 Jan 1970）本身也含逗号，
      // 因此只在“逗号后紧跟一个新的 name=”处切分，避免误切属性值。
      final pieces = setCookieHeaders.split(
        RegExp(r',\s*(?=[A-Za-z0-9_.-]+\s*=)'),
      );
      for (final piece in pieces) {
        // 每个 cookie 取第一个 ";" 之前的部分，即 name=value
        final nameValue = piece.split(';').first.trim();
        // 跳过空值 cookie（如 dong_media_return_to=）
        if (nameValue.isNotEmpty &&
            nameValue.contains('=') &&
            !nameValue.endsWith('=')) {
          cookies.add(nameValue);
        }
      }
    }

    return cookies.join('; ');
  }

  void _showToast(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleLogin() async {
    if ((_formKey.currentState?.validate() ?? true) && _isFormValid) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 处理 URL
        String baseUrl = _processUrl(_urlController.text);
        String loginUrl = '$baseUrl/api/login';

        // 发送登录请求
        final response = await http.post(
          Uri.parse(loginUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'username': _usernameController.text,
            'password': _passwordController.text,
          }),
        );
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // 根据状态码显示不同的消息
        switch (response.statusCode) {
          case 200:
            // 解析并保存 cookies
            String cookies = _parseCookies(response);

            // 保存用户数据
            await UserDataService.saveUserData(
              serverUrl: baseUrl,
              username: _usernameController.text,
              password: _passwordController.text,
              cookies: cookies,
            );
            if (!mounted) return;

            // 保存模式状态为服务器模式
            await UserDataService.saveIsLocalMode(false);
            if (!mounted) return;

            // _showToast('登录成功！', const Color(0xFF27ae60));

            // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
            break;
          case 401:
            _showToast('用户名或密码错误', const Color(0xFFe74c3c));
            break;
          case 500:
            _showToast('服务器错误', const Color(0xFFe74c3c));
            break;
          default:
            _showToast('网络异常', const Color(0xFFe74c3c));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showToast('网络异常', const Color(0xFFe74c3c));
      }
    }
  }

  void _handleLocalModeLogin() async {
    if (_formKey.currentState?.validate() ?? true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newUrl = _subscriptionUrlController.text.trim();

        // 获取并解析订阅内容
        final response = await http.get(Uri.parse(newUrl));
        if (!mounted) return;

        if (response.statusCode != 200) {
          setState(() {
            _isLoading = false;
          });
          _showToast('获取订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        final content =
            await SubscriptionService.parseSubscriptionContent(response.body);
        if (!mounted) return;

        if (content == null || 
            (content.searchResources == null || content.searchResources!.isEmpty) &&
            (content.liveSources == null || content.liveSources!.isEmpty)) {
          setState(() {
            _isLoading = false;
          });
          _showToast('解析订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        // 检查是否已有订阅 URL
        final existingUrl = await LocalModeStorageService.getSubscriptionUrl();
        if (!mounted) return;

        if (existingUrl != null &&
            existingUrl.isNotEmpty &&
            existingUrl != newUrl) {
          // 弹窗询问是否清空
          setState(() {
            _isLoading = false;
          });

          if (!mounted) return;

          final shouldClear = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                '提示',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              content: Text(
                '检测到已有本地模式内容且订阅链接不一致，是否清空全部本地模式存储？',
                style: FontUtils.poppins(
                  fontSize: 14,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '否',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFF7f8c8d),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    '是',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFFe74c3c),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (!mounted) return;

          if (shouldClear == true) {
            await LocalModeStorageService.clearAllLocalModeData();
            if (!mounted) return;
          } else if (shouldClear == null) {
            // 用户取消了对话框
            return;
          }

          setState(() {
            _isLoading = true;
          });
        }

        // 保存订阅链接和内容
        await LocalModeStorageService.saveSubscriptionUrl(newUrl);
        if (!mounted) return;
        if (content.searchResources != null && content.searchResources!.isNotEmpty) {
          await LocalModeStorageService.saveSearchSources(content.searchResources!);
          if (!mounted) return;
        }
        if (content.liveSources != null && content.liveSources!.isNotEmpty) {
          await LocalModeStorageService.saveLiveSources(content.liveSources!);
          if (!mounted) return;
        }

        // 保存模式状态为本地模式
        await UserDataService.saveIsLocalMode(true);
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // _showToast('本地模式登录成功！', const Color(0xFF27ae60));

        // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showToast('登录失败：${e.toString()}', const Color(0xFFe74c3c));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = DeviceUtils.isTablet(context);
    final isTv = DeviceUtils.isTV();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFe6f3fb), // #e6f3fb 0%
              Color(0xFFeaf3f7), // #eaf3f7 18%
              Color(0xFFf7f7f3), // #f7f7f3 38%
              Color(0xFFe9ecef), // #e9ecef 60%
              Color(0xFFdbe3ea), // #dbe3ea 80%
              Color(0xFFd3dde6), // #d3dde6 100%
            ],
            stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Windows 自定义标题栏（透明背景）
            if (Platform.isWindows) const WindowsTitleBar(forceBlack: true),
            // 主要内容
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 0 : 32.0,
                      vertical: 24.0,
                    ),
                    child: isTv
                        ? _buildTvLayout()
                        : (isTablet
                            ? _buildTabletLayout()
                            : _buildMobileLayout()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 手机端布局（保持原样）
  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Selene 标题 - 可点击
        GestureDetector(
          onTap: _handleLogoTap,
          child: Text(
            'Selene',
            style: FontUtils.sourceCodePro(
              fontSize: 42,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF2c3e50),
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // TV/遥控：可聚焦的模式切换按钮
        _buildModeToggle(),
        const SizedBox(height: 28),

        // 登录表单 - 无边框设计
        Form(
          key: _formKey,
          child: _isLocalMode
              ? _buildLocalModeForm()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // URL 输入框
                    TextFormField(
                      controller: _urlController,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '服务器地址',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: 'https://example.com',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.link,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器地址';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            uri.scheme.isEmpty ||
                            uri.host.isEmpty) {
                          return '请输入有效的URL地址';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 20),

                    // 用户名输入框
                    TextFormField(
                      controller: _usernameController,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '用户名',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: '请输入用户名',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入用户名';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 20),

                    // 密码输入框
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '密码',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: '请输入密码',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 32),

                    // 登录按钮
                    ElevatedButton(
                      onPressed:
                          (_isLoading || !_isFormValid) ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFormValid && !_isLoading
                            ? const Color(0xFF2c3e50) // 与Selene logo相同的颜色
                            : const Color(0xFFbdc3c7), // 禁用时的浅灰色
                        foregroundColor: _isFormValid && !_isLoading
                            ? Colors.white
                            : const Color(0xFF7f8c8d), // 禁用时的文字颜色
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '登录中...',
                                  style: FontUtils.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '登录',
                              style: FontUtils.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // TV/遥控布局：不使用系统 IME，改用可聚焦的只读显示 + 屏幕键盘（覆盖层）
  Widget _buildTvLayout() {
    return PopScope(
      // 返回键统一由此处处理：编辑中则关闭屏幕键盘，否则退出应用。
      // 键盘以覆盖层展示（非对话框路由），因此返回键不会因系统返回路由而退出应用。
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          final DateTime? closedAt = _editorClosedAt;
          if (_editingField != null) {
            // 系统返回通道关闭键盘（KeyEvent 通道未处理时）
            setState(() => _editingField = null);
          } else if (closedAt != null &&
              DateTime.now().difference(closedAt) <
                  const Duration(milliseconds: 700)) {
            // 同一次返回按键已由 KeyEvent 通道关闭键盘，忽略系统返回，不退出
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Stack(
        children: [
          // 编辑中排除表单的焦点，确保遥控按键只作用于屏幕键盘
          ExcludeFocus(
            excluding: _editingField != null,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Selene 标题 - 可点击
                  GestureDetector(
                    onTap: _handleLogoTap,
                    child: Text(
                      'Selene',
                      style: FontUtils.sourceCodePro(
                        fontSize: 42,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF2c3e50),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 可聚焦的模式切换按钮
                  _buildModeToggle(),
                  const SizedBox(height: 28),
                  _isLocalMode ? _buildTvLocalModeForm() : _buildTvServerForm(),
                ],
              ),
            ),
          ),
          if (_editingField != null)
            Positioned.fill(
              child: GestureDetector(
                // 点击遮罩不关闭，避免误触；用返回键关闭
                onTap: () {},
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: TvKeyboard(
                      initialValue: _editingController.text,
                      obscure: _editingField == 'password',
                      onChanged: _applyEditingValue,
                      onDone: (v) {
                        _applyEditingValue(v);
                        _editorClosedAt = null;
                        setState(() => _editingField = null);
                      },
                      onCancel: _handleEditorBack,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTvServerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvTextField(
          label: '服务器地址',
          value: _urlController.text,
          icon: Icons.link,
          onTap: () => _openEditor('url'),
          onChanged: (v) {
            _urlController.text = v;
            _validateForm();
          },
        ),
        const SizedBox(height: 20),
        TvTextField(
          label: '用户名',
          value: _usernameController.text,
          icon: Icons.person,
          onTap: () => _openEditor('username'),
          onChanged: (v) {
            _usernameController.text = v;
            _validateForm();
          },
        ),
        const SizedBox(height: 20),
        TvTextField(
          label: '密码',
          value: _passwordController.text,
          icon: Icons.lock,
          obscure: true,
          onTap: () => _openEditor('password'),
          onChanged: (v) {
            _passwordController.text = v;
            _validateForm();
          },
        ),
        const SizedBox(height: 32),
        _buildTvLoginButton(_handleLogin),
      ],
    );
  }

  Widget _buildTvLocalModeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvTextField(
          label: '订阅链接',
          value: _subscriptionUrlController.text,
          icon: Icons.link,
          onTap: () => _openEditor('subscription'),
          onChanged: (v) {
            _subscriptionUrlController.text = v;
            _validateForm();
          },
        ),
        const SizedBox(height: 32),
        _buildTvLoginButton(_handleLocalModeLogin),
      ],
    );
  }

  /// TV/遥控可聚焦的登录按钮：OK 键触发登录
  Widget _buildTvLoginButton(VoidCallback onPressed) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          if (!_isLoading && _isFormValid) onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final enabled = _isFormValid && !_isLoading;
          return ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled
                  ? const Color(0xFF2c3e50)
                  : const Color(0xFFbdc3c7),
              foregroundColor: enabled ? Colors.white : const Color(0xFF7f8c8d),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              side: focused
                  ? const BorderSide(color: Color(0xFF27ae60), width: 2)
                  : BorderSide.none,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '登录中...',
                        style: FontUtils.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '登录',
                    style: FontUtils.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
          );
        },
      ),
    );
  }

  // 平板端布局（与手机端风格一致，只是限制宽度）
  Widget _buildTabletLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selene 标题 - 可点击
          GestureDetector(
            onTap: _handleLogoTap,
            child: Text(
              'Selene',
              style: FontUtils.sourceCodePro(
                fontSize: 42,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF2c3e50),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // TV/遥控：可聚焦的模式切换按钮
          _buildModeToggle(),
          const SizedBox(height: 28),

          // 登录表单 - 无边框设计
          Form(
            key: _formKey,
            child: _isLocalMode
                ? _buildLocalModeForm()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // URL 输入框
                      TextFormField(
                        controller: _urlController,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '服务器地址',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: 'https://example.com',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.link,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入服务器地址';
                          }
                          final uri = Uri.tryParse(value);
                          if (uri == null ||
                              uri.scheme.isEmpty ||
                              uri.host.isEmpty) {
                            return '请输入有效的URL地址';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 20),

                      // 用户名输入框
                      TextFormField(
                        controller: _usernameController,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '用户名',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: '请输入用户名',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入用户名';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 20),

                      // 密码输入框
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '密码',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: '请输入密码',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF7f8c8d),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 32),

                      // 登录按钮
                      ElevatedButton(
                        onPressed:
                            (_isLoading || !_isFormValid) ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFormValid && !_isLoading
                              ? const Color(0xFF2c3e50)
                              : const Color(0xFFbdc3c7),
                          foregroundColor: _isFormValid && !_isLoading
                              ? Colors.white
                              : const Color(0xFF7f8c8d),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '登录中...',
                                    style: FontUtils.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '登录',
                                style: FontUtils.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
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
