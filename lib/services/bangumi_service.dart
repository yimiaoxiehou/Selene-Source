import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bangumi.dart';
import 'api_service.dart';
import 'douban_cache_service.dart';

/// Bangumi 数据服务（函数级缓存，一天过期）
class BangumiService {
  static final DoubanCacheService _cache = DoubanCacheService();
  static bool _initialized = false;

  static Future<void> _initCache() async {
    if (!_initialized) {
      await _cache.init();
      _initialized = true;
    }
  }

  /// 获取当天的新番放送（根据当前星期几）
  static Future<ApiResponse<List<BangumiItem>>> getTodayCalendar(
    BuildContext context,
  ) async {
    final weekday = DateTime.now().weekday; // 1..7
    return getCalendarByWeekday(context, weekday);
  }

  /// 获取指定星期的新番放送
  ///
  /// 数据源优先级：
  ///   1. bgmlist.com（STB 可直连的镜像，标题与后端片源索引一致 → 播放源可检索）
  ///   2. api.bgm.tv/calendar（原逻辑，STB 不可达，仅作兜底）
  ///
  /// 封面统一由 anical.cn 首页解析补全（anical 只提供封面，不提供可检索片名，
  /// 因此仅做封面增强，不替换列表/片名，避免播放源搜索失败）。
  static Future<ApiResponse<List<BangumiItem>>> getCalendarByWeekday(
    BuildContext context,
    int weekday, // 1..7 (Monday..Sunday)
  ) async {
    await _initCache();

    List<BangumiItem>? items;

    // 1. 主源：bgmlist.com（扁平列表，weekday 取自首播 begin）
    try {
      const apiUrl = 'https://bgmlist.com/api/v1/bangumi/onair';
      final headers = {
        'User-Agent': 'selene/1.0.0 (Android)',
        'Accept': 'application/json',
      };
      final response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> raw =
            body['items'] is List ? body['items'] as List<dynamic> : <dynamic>[];
        try {
          await _cache.set('bgmlist_onair_raw_v1', raw, const Duration(hours: 6));
        } catch (_) {}
        items = _filterBgmlistByWeekday(raw, weekday);
      }
    } catch (_) {}

    // 2. 回退：api.bgm.tv/calendar（原逻辑）
    if (items == null) {
      try {
        const apiUrl = 'https://api.bgm.tv/calendar';
        final headers = {
          'User-Agent':
              'senshinya/selene/1.0.0 (Android) (http://github.com/senshinya/selene)',
          'Accept': 'application/json',
        };
        final response = await http
            .get(Uri.parse(apiUrl), headers: headers)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final List<dynamic> responseData = json.decode(response.body);
          final List<BangumiCalendarResponse> calendarData = responseData
              .map((item) =>
                  BangumiCalendarResponse.fromJson(item as Map<String, dynamic>))
              .toList();
          BangumiCalendarResponse? targetDay;
          for (final day in calendarData) {
            if (day.weekday.id == weekday) {
              targetDay = day;
              break;
            }
          }
          items = targetDay?.items ?? <BangumiItem>[];
          try {
            await _cache.set(
              'bangumi_calendar_raw_v1',
              responseData,
              const Duration(days: 1),
            );
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (items == null) {
      return ApiResponse.error('获取每日放送数据失败');
    }

    // 3. 用 anical.cn 封面补全（仅封面，不影响片名/播放源检索）
    final anicalCards = await _fetchAnicalCards();
    items = _enrichWithAnicalCovers(items, anicalCards);

    return ApiResponse.success(items);
  }

  /// 将 bgmlist 扁平列表按星期过滤（broadcast 为每周 recurrence，星期取自首播 begin）
  static List<BangumiItem> _filterBgmlistByWeekday(
    List<dynamic> raw,
    int weekday,
  ) {
    final out = <BangumiItem>[];
    for (final it in raw) {
      if (it is! Map<String, dynamic>) continue;
      final begin = (it['begin'] ?? '').toString();
      int wd = 0;
      if (begin.isNotEmpty) {
        final dt = DateTime.tryParse(begin);
        if (dt != null) wd = dt.weekday;
      }
      if (wd != weekday) continue;
      out.add(_bgmlistToBangumiItem(it));
    }
    return out;
  }

  /// 将单个 bgmlist 条目转换为 BangumiItem（bgmlist 不含封面图，images 留空，稍后补全）
  static BangumiItem _bgmlistToBangumiItem(Map<String, dynamic> m) {
    final trans = m['titleTranslate'];
    final String name = (m['title'] ?? '').toString();
    String? nameCn;
    if (trans is Map &&
        trans['zh-Hans'] is List &&
        (trans['zh-Hans'] as List).isNotEmpty) {
      nameCn = (trans['zh-Hans'] as List).first?.toString();
    }

    int id = 0;
    for (final s in (m['sites'] as List? ?? <dynamic>[])) {
      if (s is Map && s['site'] == 'bangumi') {
        id = int.tryParse((s['id'] ?? '').toString()) ?? 0;
        break;
      }
    }

    final begin = (m['begin'] ?? '').toString();
    int wd = 0;
    if (begin.isNotEmpty) {
      final dt = DateTime.tryParse(begin);
      if (dt != null) wd = dt.weekday;
    }

    final url = id != 0
        ? 'https://bgm.tv/subject/$id'
        : (m['officialSite'] ?? '').toString();

    return BangumiItem(
      id: id,
      url: url,
      type: 0,
      name: name,
      nameCn: nameCn,
      summary: '',
      airDate: begin.split('T').first,
      airWeekday: wd,
      rating: const BangumiRating(total: 0, count: {}, score: 0.0),
      rank: 0,
      images: const BangumiImages(
        large: '',
        common: '',
        medium: '',
        small: '',
        grid: '',
      ),
      collection: const BangumiCollection(doing: 0),
    );
  }

  /// 用 anical 封面补全 bgmlist 列表项（标题精确匹配，尽力而为）
  static List<BangumiItem> _enrichWithAnicalCovers(
    List<BangumiItem> items,
    List<_AnicalCard> anicalCards,
  ) {
    if (anicalCards.isEmpty) return items;
    final coverMap = <String, String>{};
    for (final c in anicalCards) {
      coverMap[_normalize(c.title)] = c.cover;
    }
    return items.map((item) {
      final key = _normalize(item.nameCn ?? item.name);
      final cover = coverMap[key];
      if (cover == null || cover.isEmpty) return item;
      return BangumiItem(
        id: item.id,
        url: item.url,
        type: item.type,
        name: item.name,
        nameCn: item.nameCn,
        summary: item.summary,
        airDate: item.airDate,
        airWeekday: item.airWeekday,
        rating: item.rating,
        rank: item.rank,
        images: BangumiImages(
          large: cover,
          common: cover,
          medium: cover,
          small: cover,
          grid: cover,
        ),
        collection: item.collection,
      );
    }).toList();
  }

  static String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), '').trim();

  // ───────────────────────── anical.cn 封面源 ─────────────────────────

  /// 抓取并解析 anical.cn 首页，返回按星期分组的新番卡片（标题 + 封面）。
  /// 失败或不可达时返回空列表（调用方走 bgmlist / api.bgm.tv 兜底，封面留空）。
  static Future<List<_AnicalCard>> _fetchAnicalCards() async {
    const cacheKey = 'anical_home_html_v1';
    String? html;
    try {
      final cached = await _cache.get<String>(cacheKey, (raw) => raw as String);
      if (cached != null && cached.isNotEmpty) html = cached;
    } catch (_) {}

    if (html == null) {
      try {
        const apiUrl = 'https://www.anical.cn/';
        final headers = {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        };
        final response = await http
            .get(Uri.parse(apiUrl), headers: headers)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          html = response.body;
          try {
            await _cache.set(cacheKey, html, const Duration(hours: 6));
          } catch (_) {}
        }
      } catch (_) {
        // 网络异常，走兜底
      }
    }

    if (html == null || html.isEmpty) return <_AnicalCard>[];
    // 在独立 isolate 中解析（~175KB HTML），避免阻塞 UI 线程造成掉帧
    final htmlToParse = html;
    return Isolate.run(() => _parseAnicalHome(htmlToParse));
  }

  /// 解析 anical.cn 首页 HTML：7 个 panel（panel-1..7 = 周一..周日），
  /// 每个 panel 内 <a class="anime-mini-card"> 含封面(src)与标题(alt)。
  static List<_AnicalCard> _parseAnicalHome(String html) {
    final out = <_AnicalCard>[];
    // 记录每个 panel 的起始位置，用于确定卡片所属星期
    final panelStart = <int, int>{};
    for (final m in RegExp(r'id="panel-(\d)"').allMatches(html)) {
      panelStart[int.parse(m.group(1)!)] = m.start;
    }
    final cardRe = RegExp(
      r'<a href="/anime/(\d+)\.html" class="anime-mini-card">.*?src="([^"]+)"\s+alt="([^"]+)"',
      dotAll: true,
    );
    for (final m in cardRe.allMatches(html)) {
      final anicalId = m.group(1)!;
      final cover = m.group(2)!;
      final title = m.group(3)!.trim();
      if (title.isEmpty) continue;
      // 选择起始位置 <= 卡片位置的最大 panel 编号
      int wd = 1;
      int? chosen;
      final pos = m.start;
      for (final e in panelStart.entries) {
        if (e.value <= pos && (chosen == null || e.value > panelStart[chosen]!)) {
          chosen = e.key;
        }
      }
      wd = chosen ?? 1;
      out.add(
        _AnicalCard(
          title: title,
          cover: cover,
          weekday: wd,
          anicalId: anicalId,
          url: 'https://www.anical.cn/anime/$anicalId.html',
        ),
      );
    }
    return out;
  }

  /// 获取 Bangumi 详情数据
  ///
  /// 参数说明：
  /// - bangumiId: Bangumi ID
  static Future<ApiResponse<BangumiDetails>> getBangumiDetails(
    BuildContext context, {
    required String bangumiId,
  }) async {
    await _initCache();

    // 生成缓存键
    final cacheKey = _cache.generateBangumiDetailsCacheKey(
      bangumiId: bangumiId,
    );

    // 尝试从缓存获取数据
    try {
      final cachedData = await _cache.get<BangumiDetails>(
        cacheKey,
        (raw) {
          if (raw is! Map<String, dynamic>) {
            throw FormatException('Bangumi 缓存数据格式错误: ${raw.runtimeType}');
          }
          return BangumiDetails.fromJson(raw);
        },
      );

      if (cachedData != null) {
        return ApiResponse.success(cachedData);
      }
    } catch (e) {
      // 缓存读取失败，清理可能损坏的缓存，继续执行网络请求
      try {
        // 清理这个特定的缓存项
        await _cache.set(cacheKey, null, Duration.zero);
      } catch (_) {}
    }

    try {
      final apiUrl = 'https://api.bgm.tv/v0/subjects/$bangumiId';
      final headers = {
        'User-Agent':
            'senshinya/selene/1.0.0 (Android) (http://github.com/senshinya/selene)',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          final details = BangumiDetails.fromJson(data);

          // 缓存成功的结果，缓存时间为24小时
          try {
            await _cache.set(
              cacheKey,
              details.toJson(),
              const Duration(days: 3),
            );
          } catch (cacheError) {
            // 静默处理缓存错误
          }

          return ApiResponse.success(details, statusCode: response.statusCode);
        } catch (parseError) {
          return ApiResponse.error('Bangumi 详情数据解析失败: ${parseError.toString()}');
        }
      } else {
        return ApiResponse.error(
          '获取 Bangumi 详情数据失败: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Bangumi 详情数据请求异常: ${e.toString()}');
    }
  }
}

/// anical.cn 首页解析出的新番卡片（标题 + 封面 + 星期）
class _AnicalCard {
  final String title;
  final String cover;
  final int weekday; // 1..7 (周一..周日)
  final String anicalId;
  final String url;

  const _AnicalCard({
    required this.title,
    required this.cover,
    required this.weekday,
    required this.anicalId,
    required this.url,
  });
}
