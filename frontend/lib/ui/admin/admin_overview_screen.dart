// AdminOverviewScreen — dashboard landing tab. Renders the admin-wide
// aggregates from GET /api/admin/stats: an asphalt "operations board" hero
// with the total and live active/pending/resolved split, secondary stat
// cards (users, reports today, resolution rate), a crafted 14-day trend
// chart and the category breakdown. Trend gaps are filled with zeroes so
// the axis is stable.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/admin_stats.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/freshness_bar.dart';
import '../widgets/remote_view.dart';
import '../widgets/route_aware_polling.dart';

class AdminOverviewScreen extends StatefulWidget {
  /// True while this tab is the selected dashboard tab; polling is gated on
  /// it so only the visible tab issues background refreshes.
  final bool active;

  /// Test seam: injects the stats loader so widget tests can render the
  /// dashboard with a fixed dataset instead of hitting the network.
  final Future<AdminStats> Function()? loadStats;

  const AdminOverviewScreen({super.key, this.active = true, this.loadStats});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen>
    with RouteAwarePolling {
  final _api = AdminApi();
  final _viewKey = GlobalKey<RemoteViewState<AdminStats>>();
  DateTime? _lastUpdated;

  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  Future<void> poll() async {
    if (!widget.active) return;
    _viewKey.currentState?.reload();
  }

  @override
  void didUpdateWidget(AdminOverviewScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) poll();
  }

  Future<AdminStats> _load() => widget.loadStats?.call() ?? _api.stats();

  @override
  Widget build(BuildContext context) {
    return RemoteView<AdminStats>(
      key: _viewKey,
      load: _load,
      onData: (_) {
        if (mounted) setState(() => _lastUpdated = DateTime.now());
      },
      builder: (context, s) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          FreshnessBar(lastUpdated: _lastUpdated, onRefresh: poll),
          const SizedBox(height: 18),
          _Reveal(child: _HeroBand(stats: s)),
          const SizedBox(height: 24),
          _Reveal(child: _SecondaryStats(stats: s)),
          const SizedBox(height: 32),
          _Reveal(
            child: _SectionHeader(
              eyebrow: context.t('admin.analytics'),
              title: context.t('admin.reports'),
              trailing: context.t('admin.period_total'),
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(child: _TrendChart(daily: s.daily)),
          const SizedBox(height: 32),
          _Reveal(
            child: _SectionHeader(
              eyebrow: context.t('admin.breakdown'),
              title: context.t('admin.categories'),
              trailing: context
                  .t('admin.categories_tracked')
                  .replaceAll('{n}', '${s.categories.length}'),
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(child: _CategoryBreakdown(categories: s.categories)),
        ],
      ),
    );
  }
}

// Gentle fade-and-rise entrance for each block, so the board reads as
// layered rather than dropped in all at once.
class _Reveal extends StatelessWidget {
  final Widget child;
  const _Reveal({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero band — the "operations board": total in road-sign yellow over asphalt,
// with the live status split nested beside it.
// ---------------------------------------------------------------------------

class _HeroBand extends StatelessWidget {
  final AdminStats stats;
  const _HeroBand({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl - 2),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.ink, AppColors.inkElevated],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _HeroGridPainter()),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.safety.withValues(alpha: 0.10),
                          AppColors.safety.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 460;
                    final total = _TotalBlock(stats: stats);
                    final split = _StatusSplit(stats: stats);
                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          total,
                          const SizedBox(height: 20),
                          split,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: total),
                        const SizedBox(width: 28),
                        split,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  final AdminStats stats;
  const _TotalBlock({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('admin.stat_total').toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedCounter(
          value: stats.total,
          duration: const Duration(milliseconds: 900),
          style: const TextStyle(
            color: AppColors.safetySoft,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('admin.hero_sub'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatusSplit extends StatelessWidget {
  final AdminStats stats;
  const _StatusSplit({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = <(Color, String, int)>[
      (AppColors.warning, context.t('admin.stat_active'), stats.active),
      (AppColors.link, context.t('admin.stat_pending'), stats.pending),
      (AppColors.success, context.t('admin.stat_resolved'), stats.resolved),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (color, label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 20),
                AnimatedCounter(
                  value: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Faint blueprint grid with a few safety-yellow pins, hinting at the
// city map the reports came from.
class _HeroGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final pin = Paint()..color = AppColors.safety.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.20), 3, pin);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.55), 2, pin);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.78), 2.5, pin);
  }

  @override
  bool shouldRepaint(covariant _HeroGridPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Secondary stat cards — users, reports today, resolution rate.
// ---------------------------------------------------------------------------

class _SecondaryStats extends StatelessWidget {
  final AdminStats stats;
  const _SecondaryStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final today = stats.daily.isEmpty
        ? 0
        : stats.daily.reduce((a, b) => a.date.isAfter(b.date) ? a : b).count;
    final resolution =
        stats.total == 0 ? 0 : (stats.resolved * 100 / stats.total).round();

    final cards = <_StatCard>[
      _StatCard(
        icon: Icons.people_alt_outlined,
        label: context.t('admin.stat_users'),
        value: stats.users,
        color: AppColors.calmBlue,
      ),
      _StatCard(
        icon: Icons.today_outlined,
        label: context.t('admin.reports_today'),
        value: today,
        color: AppColors.link,
      ),
      _StatCard(
        icon: Icons.trending_up_rounded,
        label: context.t('admin.resolution_rate'),
        value: resolution,
        color: AppColors.success,
        suffix: '%',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 640;
        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String? suffix;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    );
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg - 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedCounter(value: value, style: valueStyle),
                      if (suffix != null) Text(suffix!, style: valueStyle),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section furniture.
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? trailing;
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  color: AppColors.link,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

// Nested "plate in a tray" card used by the trend chart and category rows.
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg - 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 14-day trend chart — hand-painted bars over faint gridlines. The axis is
// always left-to-right by time, today is highlighted in safety yellow.
// ---------------------------------------------------------------------------

class _TrendChart extends StatelessWidget {
  final List<DailyCount> daily;
  const _TrendChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in daily) _key(d.date): d.count};
    final now = DateTime.now();
    final days = <MapEntry<DateTime, int>>[];
    for (int i = 13; i >= 0; i--) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      days.add(MapEntry(day, byDate[_key(day)] ?? 0));
    }
    final max = days.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    final sum = days.fold<int>(0, (a, e) => a + e.value);

    return _Shell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.t('admin.reports').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: sum,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.t('admin.period_total'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: CustomPaint(
                size: Size.infinite,
                painter: _TrendBarsPainter(days: days, max: max),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(
                    color: AppColors.ink,
                    label: context.t('admin.legend_daily')),
                const SizedBox(width: 18),
                _LegendDot(
                    color: AppColors.safety,
                    label: context.t('admin.legend_today')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrendBarsPainter extends CustomPainter {
  final List<MapEntry<DateTime, int>> days;
  final int max;
  _TrendBarsPainter({required this.days, required this.max});

  static const _labelPad = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartH = size.height - _labelPad;
    final slot = size.width / days.length;
    final barW = (slot * 0.5).clamp(2.0, 20.0).toDouble();

    final grid = Paint()
      ..color = AppColors.line.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    for (final q in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = chartH - q * chartH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final todayIndex = days.length - 1;
    final band = Paint()..color = AppColors.paperDeep.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(todayIndex * slot, 0, slot, chartH),
        const Radius.circular(8),
      ),
      band,
    );

    canvas.drawLine(
      Offset(0, chartH),
      Offset(size.width, chartH),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1.5,
    );

    for (var i = 0; i < days.length; i++) {
      final entry = days[i];
      final isToday = i == todayIndex;
      final cx = i * slot + slot / 2;
      final value = entry.value;
      final h = max == 0 ? 0.0 : chartH * (value / max);

      final barH = value == 0 ? 2.0 : (h < 4 ? 4.0 : h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, chartH - barH, barW, barH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()
          ..color = value == 0
              ? AppColors.line
              : isToday
                  ? AppColors.safety
                  : AppColors.ink,
      );

      final label = TextPainter(
        text: TextSpan(
          text: '${entry.key.day}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? AppColors.ink : AppColors.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(cx - label.width / 2, chartH + 5));

      if (isToday && value > 0) {
        final valueText = TextPainter(
          text: TextSpan(
            text: '$value',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final vY = (chartH - barH - 13).clamp(2.0, chartH - 20);
        valueText.paint(canvas, Offset(cx - valueText.width / 2, vY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBarsPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.max != max;
}

// ---------------------------------------------------------------------------
// Category breakdown — icon tile, count/percentage, tinted gradient bar.
// ---------------------------------------------------------------------------

class _CategoryBreakdown extends StatelessWidget {
  final List<CategoryCount> categories;
  const _CategoryBreakdown({required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _Shell(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              context.t('admin.no_reports'),
              style: const TextStyle(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }
    final total = categories.fold<int>(0, (a, c) => a + c.count);
    final max =
        categories.map((c) => c.count).fold<int>(1, (a, b) => a > b ? a : b);
    return _Shell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Column(
          children: [
            for (final c in categories)
              _CategoryRow(category: c, total: total, max: max),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryCount category;
  final int total;
  final int max;
  const _CategoryRow({
    required this.category,
    required this.total,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final reportCategory = ReportCategory.fromApi(category.category);
    final count = category.count;
    final pct = total == 0 ? 0 : (count * 100 / total).round();
    final widthFactor = max == 0 ? 0.0 : count / max;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: reportCategory.tileBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(reportCategory.icon, color: reportCategory.tint, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reportCategory.localizedLabel(
                            context.watch<LocaleState>().isArabic),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    AnimatedCounter(
                      value: count,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(height: 8, color: AppColors.paperDeep),
                        FractionallySizedBox(
                          widthFactor: widthFactor,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  reportCategory.tint,
                                  Color.lerp(
                                      reportCategory.tint, Colors.white, 0.35)!,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
