import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../models/ai_analysis.dart';
import '../models/memory_item.dart';

class NottlerApp extends StatelessWidget {
  const NottlerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Nottler',
          theme: _nottlerTheme(Brightness.light),
          darkTheme: _nottlerTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: !controller.aiStatus.languageModel
              ? ModelSetupPage(controller: controller)
              : controller.isOnboarded
                  ? AppShell(controller: controller)
                  : OnboardingPage(controller: controller),
        );
      },
    );
  }
}

ThemeData _nottlerTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff6750a4),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'GoogleSansFlex',
    // On Android 12 and newer Flutter can take the device wallpaper palette.
    // The expressive seed remains the accessible fallback everywhere else.
    useSystemColors: true,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: M3ExpressiveShape.large),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      iconColor: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
        TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      useIndicator: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: M3ExpressiveShape.large,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: M3ExpressiveShape.large,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: M3ExpressiveShape.large,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double?>(0),
      backgroundColor:
          WidgetStatePropertyAll<Color?>(scheme.surfaceContainerHigh),
      shape: WidgetStatePropertyAll<OutlinedBorder?>(
        RoundedRectangleBorder(borderRadius: M3ExpressiveShape.large),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry?>(
        EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: M3ExpressiveShape.extraLargeRadius),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.55),
      space: 1,
    ),
  );
}

/// Rounded and expressive shape roles used across the app.
///
/// Flutter does not expose Material's full 35-shape catalog as a runtime API,
/// so these roles keep the system coherent while preserving room for custom
/// decorative shapes where an individual screen needs them.
class M3ExpressiveShape {
  const M3ExpressiveShape._();

  static const extraSmallRadius = Radius.circular(8);
  static const smallRadius = Radius.circular(12);
  static const mediumRadius = Radius.circular(16);
  static const largeRadius = Radius.circular(28);
  static const extraLargeRadius = Radius.circular(36);
  static const fullRadius = Radius.circular(999);

  static const extraSmall = BorderRadius.all(extraSmallRadius);
  static const small = BorderRadius.all(smallRadius);
  static const medium = BorderRadius.all(mediumRadius);
  static const large = BorderRadius.all(largeRadius);
  static const extraLarge = BorderRadius.all(extraLargeRadius);
  static const full = BorderRadius.all(fullRadius);
}

/// Shared motion tokens keep navigation and direct manipulation cohesive.
class M3ExpressiveMotion {
  const M3ExpressiveMotion._();

  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 420);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: M3ExpressiveMotion.medium,
      curve: M3ExpressiveMotion.emphasizedDecelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayPage(controller: widget.controller),
      CalendarPage(controller: widget.controller),
      SearchPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];
    final content = PageView(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _selectedIndex = index),
      children: pages,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectPage,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today),
                    label: 'Today'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendar'),
                NavigationDestination(
                    icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings'),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  extended: constraints.maxWidth >= 840,
                  minExtendedWidth: 220,
                  labelType: constraints.maxWidth >= 840
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 20),
                    child: Icon(Icons.auto_awesome_rounded),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.today_outlined),
                        selectedIcon: Icon(Icons.today),
                        label: Text('Today')),
                    NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: Text('Calendar')),
                    NavigationRailDestination(
                        icon: Icon(Icons.search), label: Text('Search')),
                    NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings')),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: content,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(30)),
                child: Icon(Icons.notifications_active,
                    size: 42, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 28),
              Text('Keep the important\nthings in view.',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Text(
                'Nottler turns notifications into a calm, searchable memory. Everything is processed privately on this device.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 28),
              const _PrivacyRow(
                  icon: Icons.lock_outline,
                  title: 'Private by default',
                  detail: 'No notification text leaves your phone'),
              const _PrivacyRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Local intelligence',
                  detail: 'Classification and embeddings run offline'),
              const _PrivacyRow(
                  icon: Icons.battery_saver_outlined,
                  title: 'Lightweight',
                  detail: 'A small model first; deeper AI is optional'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await controller.openNotificationSettings();
                    await controller.completeOnboarding();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Set up notification access'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                  child: TextButton(
                      onPressed: controller.completeOnboarding,
                      child: const Text('Do this later'))),
            ],
          ),
        ),
      ),
    );
  }
}

class ModelSetupPage extends StatefulWidget {
  const ModelSetupPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ModelSetupPage> createState() => _ModelSetupPageState();
}

class _ModelSetupPageState extends State<ModelSetupPage> {
  Timer? _statusTimer;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      widget.controller.refreshAiStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    final error = await widget.controller.downloadLanguageModel();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = widget.controller.aiStatus;
    final downloading = _downloading || status.languageModelDownloading;
    final progress = status.languageModelDownloadProgress;
    final progressValue = progress > 0 ? progress / 100 : null;
    final modelMessage = widget.controller.aiStatus.languageModelMessage ??
        'A local language model is required before Nottler can start.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(30)),
                    child: Icon(Icons.memory,
                        size: 42, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(height: 28),
                  Text('Install local AI',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text(
                    'Nottler requires its on-device language model. Download it once, then notification processing runs locally on this phone.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: colors.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Qwen3 0.6B INT4 no-think',
                              style: TextStyle(
                                  color: colors.onSecondaryContainer,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('347 MB • LiteRT-LM • GPU/CPU local runtime',
                              style: TextStyle(
                                  color: colors.onSecondaryContainer)),
                          const SizedBox(height: 10),
                          Text(modelMessage,
                              style: TextStyle(
                                  color: colors.onSecondaryContainer)),
                          if (downloading) ...[
                            const SizedBox(height: 14),
                            LinearProgressIndicator(value: progressValue),
                            const SizedBox(height: 6),
                            Text(
                              progress > 0
                                  ? '$progress% downloaded'
                                  : 'Preparing download…',
                              style: TextStyle(
                                  color: colors.onSecondaryContainer),
                            ),
                          ],
                          if (status.languageModelStorageAvailableBytes >
                              0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'App storage: ${_formatBytes(status.languageModelStorageAvailableBytes)} available',
                              style: TextStyle(
                                  color: colors.onSecondaryContainer),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: downloading ? null : _download,
                      icon: downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(downloading
                          ? 'Downloading and preparing…'
                          : 'Download model'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The download needs internet access only for the model file. Notification content is not uploaded.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow(
      {required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        children: [
          Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(detail,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

enum _TodayFilter { all, urgent, scheduled, unscheduled }

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  var _filter = _TodayFilter.all;
  var _showCompleted = true;
  String? _selectedId;

  List<MemoryItem> _filtered(
    List<MemoryItem> items,
    AppController controller,
  ) {
    return items.where((item) {
      final scheduled = controller.scheduledAt(item);
      return switch (_filter) {
        _TodayFilter.all => true,
        _TodayFilter.urgent => item.importance >= 80,
        _TodayFilter.scheduled => scheduled != null,
        _TodayFilter.unscheduled => scheduled == null,
      };
    }).toList();
  }

  void _select(MemoryItem item) => setState(() => _selectedId = item.id);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final wideLayout = MediaQuery.sizeOf(context).width >= 850;
    final open = widget.controller.items
        .where((item) => item.status == 'active' || item.status == 'snoozed')
        .toList()
      ..sort((a, b) => _todaySort(widget.controller, now, a, b));
    final overdue = _filtered(
      open.where((item) {
        final scheduled = widget.controller.scheduledAt(item);
        return scheduled != null && !scheduled.isAfter(now);
      }).toList(),
      widget.controller,
    );
    final laterToday = _filtered(
      open.where((item) {
        final scheduled = widget.controller.scheduledAt(item);
        return scheduled != null &&
            scheduled.isAfter(now) &&
            _sameDay(scheduled, now);
      }).toList(),
      widget.controller,
    );
    final later = _filtered(
      open.where((item) {
        final scheduled = widget.controller.scheduledAt(item);
        return scheduled != null && !_sameDay(scheduled, now) && scheduled.isAfter(now);
      }).toList(),
      widget.controller,
    );
    final unscheduled = _filtered(
      open.where((item) => widget.controller.scheduledAt(item) == null).toList(),
      widget.controller,
    );
    final focus = overdue.isNotEmpty
        ? overdue.first
        : laterToday.isNotEmpty
            ? laterToday.first
            : open.isNotEmpty
                ? open.first
                : null;
    final completedTodayItems = widget.controller.items
        .where((item) =>
            item.status == 'completed' && _sameDay(item.updatedAt, now))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final completedToday = completedTodayItems.length;
    final todayOpen = open.where((item) {
      final scheduled = widget.controller.scheduledAt(item);
      return scheduled == null || !_isAfterToday(scheduled, now);
    }).length;
    final totalForProgress = completedToday + todayOpen;
    MemoryItem? selected = focus;
    for (final item in open) {
      if (item.id == _selectedId) {
        selected = item;
        break;
      }
    }

    final children = <Widget>[
      _TodayHeader(
        controller: widget.controller,
        now: now,
      ),
      const SizedBox(height: 20),
      if (!widget.controller.notificationAccessGranted) ...[
        _CaptureStatusBanner(controller: widget.controller),
        const SizedBox(height: 16),
      ],
      _TodayProgress(
        completed: completedToday,
        total: totalForProgress,
        open: todayOpen,
      ),
      if (focus != null) ...[
        const SizedBox(height: 20),
        _FocusCard(
          item: focus,
          controller: widget.controller,
          now: now,
          onOpen: () => _openReminder(context, focus, widget.controller),
        ),
      ],
      const SizedBox(height: 28),
      Text('Your reminders',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _TodayFilter.values
              .map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      if (overdue.isNotEmpty)
        _TodaySection(
          title: 'Now',
          subtitle: 'Needs your attention',
          items: overdue,
          controller: widget.controller,
          onOpen: (item) => wideLayout
              ? _select(item)
              : _openReminder(context, item, widget.controller),
        ),
      if (laterToday.isNotEmpty)
        _TodaySection(
          title: 'Today',
          items: laterToday,
          controller: widget.controller,
          onOpen: (item) => wideLayout
              ? _select(item)
              : _openReminder(context, item, widget.controller),
        ),
      if (later.isNotEmpty)
        _TodaySection(
          title: 'Later',
          items: later,
          controller: widget.controller,
          onOpen: (item) => wideLayout
              ? _select(item)
              : _openReminder(context, item, widget.controller),
        ),
      if (unscheduled.isNotEmpty)
        _TodaySection(
          title: 'Unscheduled',
          subtitle: 'Choose a time when you are ready',
          items: unscheduled,
          controller: widget.controller,
          onOpen: (item) => wideLayout
              ? _select(item)
              : _openReminder(context, item, widget.controller),
        ),
      if (completedTodayItems.isNotEmpty)
        _CompletedTodaySection(
          items: completedTodayItems,
          controller: widget.controller,
          expanded: _showCompleted,
          onToggle: () => setState(() => _showCompleted = !_showCompleted),
        ),
      if (overdue.isEmpty &&
          laterToday.isEmpty &&
          later.isEmpty &&
          unscheduled.isEmpty &&
          completedTodayItems.isEmpty)
        _EmptyToday(capturing: widget.controller.notificationAccessGranted),
    ];

    return SafeArea(
      child: LayoutBuilder(builder: (context, _) {
        final list = RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: children,
          ),
        );
        if (!wideLayout) return list;
        return Row(
          children: [
            Expanded(child: list),
            VerticalDivider(width: 1, color: colors.outlineVariant),
            SizedBox(
              width: 360,
              child: _TodayDetailPane(
                item: selected,
                controller: widget.controller,
                now: now,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.controller, required this.now});

  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
            Text('Today',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            const SizedBox(height: 3),
            Text(_todayDate(now),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ]),
        ),
        IconButton.filledTonal(
          tooltip: 'History',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HistoryPage(controller: controller))),
          icon: const Icon(Icons.history),
        ),
      ],
    );
  }
}

class _CaptureStatusBanner extends StatelessWidget {
  const _CaptureStatusBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.notifications_off_outlined,
            color: colors.onTertiaryContainer),
        title: Text('Notification capture is paused',
            style: TextStyle(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w700)),
        subtitle: Text('Turn on access so new reminders can appear here.',
            style: TextStyle(color: colors.onTertiaryContainer)),
        trailing: TextButton(
          onPressed: controller.openNotificationSettings,
          child: const Text('Set up'),
        ),
      ),
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({
    required this.completed,
    required this.total,
    required this.open,
  });

  final int completed;
  final int total;
  final int open;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = total == 0 ? 1.0 : completed / total;
    return Card(
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.task_alt_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                total == 0 ? 'You are all caught up' : '$completed of $total completed',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('$open left today',
                style: TextStyle(color: colors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: M3ExpressiveShape.full,
            child: LinearProgressIndicator(value: value, minHeight: 8),
          ),
        ]),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.item,
    required this.controller,
    required this.now,
    required this.onOpen,
  });

  final MemoryItem item;
  final AppController controller;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dueAt = controller.scheduledAt(item);
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: colors.onPrimaryContainer),
            const SizedBox(width: 8),
            Text('Next up',
                style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            if (item.importance >= 80)
              _ImportancePill(color: colors.onPrimaryContainer),
          ]),
          const SizedBox(height: 14),
          Text(item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onPrimaryContainer)),
          const SizedBox(height: 14),
          _DueLabel(dueAt: dueAt, now: now, foreground: colors.onPrimaryContainer),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.tonalIcon(
              onPressed: () => controller.updateStatus(item, 'completed'),
              icon: const Icon(Icons.check),
              label: const Text('Complete'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onPrimaryContainer,
                  side: BorderSide(color: colors.onPrimaryContainer)),
              onPressed: () => controller.rescheduleItem(
                  item, DateTime.now().add(const Duration(hours: 1)),
                  snooze: true),
              icon: const Icon(Icons.snooze_outlined),
              label: const Text('Snooze'),
            ),
            TextButton(onPressed: onOpen, child: const Text('Details')),
          ]),
        ]),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.title,
    required this.items,
    required this.controller,
    required this.onOpen,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<MemoryItem> items;
  final AppController controller;
  final ValueChanged<MemoryItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),
        ...items.map((item) => MemoryCard(
              item: item,
              controller: controller,
              onOpen: () => onOpen(item),
            )),
      ]),
    );
  }
}

class _CompletedTodaySection extends StatelessWidget {
  const _CompletedTodaySection({
    required this.items,
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  final List<MemoryItem> items;
  final AppController controller;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Completed today',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(expanded ? 'Hide' : 'Show ${items.length}'),
          ),
        ]),
        if (expanded) ...[
          const SizedBox(height: 6),
          ...items.map((item) => _CompletedReminderTile(
                item: item,
                controller: controller,
              )),
        ],
      ]),
    );
  }
}

class _CompletedReminderTile extends StatelessWidget {
  const _CompletedReminderTile({
    required this.item,
    required this.controller,
  });

  final MemoryItem item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: colors.onSecondaryContainer),
        ),
        title: Text(item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Completed ${_clockTime(item.updatedAt)} · ${item.sourceApp}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Restore reminder',
          onPressed: () => controller.updateStatus(item, 'active'),
          icon: const Icon(Icons.undo),
        ),
      ),
    );
  }
}

class _TodayDetailPane extends StatelessWidget {
  const _TodayDetailPane({
    required this.item,
    required this.controller,
    required this.now,
  });

  final MemoryItem? item;
  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (item == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text('Select a reminder to see its details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant)),
        ),
      );
    }
    final dueAt = controller.scheduledAt(item!);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Reminder details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: M3ExpressiveShape.medium),
          child: Icon(_iconForCategory(item!.category),
              color: colors.onSecondaryContainer),
        ),
        const SizedBox(height: 18),
        Text(item!.title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _DueLabel(dueAt: dueAt, now: now, foreground: colors.primary),
        const SizedBox(height: 18),
        Text(item!.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => controller.updateStatus(item!, 'completed'),
          icon: const Icon(Icons.check),
          label: const Text('Mark complete'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => controller.rescheduleItem(
              item!, DateTime.now().add(const Duration(hours: 1)),
              snooze: true),
          icon: const Icon(Icons.snooze_outlined),
          label: const Text('Snooze for one hour'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _openReminder(context, item!, controller),
          child: const Text('Open full details'),
        ),
      ],
    );
  }
}

class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.dueAt, required this.now, required this.foreground});

  final DateTime? dueAt;
  final DateTime now;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final text = dueAt == null ? 'No time set' : _relativeDue(dueAt!, now);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(dueAt == null ? Icons.event_available_outlined : Icons.schedule,
          size: 17, color: foreground),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: TextStyle(color: foreground))),
    ]);
  }
}

class _ImportancePill extends StatelessWidget {
  const _ImportancePill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.7)),
          borderRadius: M3ExpressiveShape.full,
        ),
        child: Text('Priority',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

void _openReminder(
  BuildContext context,
  MemoryItem item,
  AppController controller,
) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailPage(item: item, controller: controller)));
}

String _filterLabel(_TodayFilter filter) => switch (filter) {
      _TodayFilter.all => 'All',
      _TodayFilter.urgent => 'Urgent',
      _TodayFilter.scheduled => 'Scheduled',
      _TodayFilter.unscheduled => 'Unscheduled',
    };

int _todaySort(AppController controller, DateTime now, MemoryItem a, MemoryItem b) {
  final aDue = controller.scheduledAt(a);
  final bDue = controller.scheduledAt(b);
  if (aDue == null && bDue != null) return 1;
  if (aDue != null && bDue == null) return -1;
  if (aDue != null && bDue != null) {
    final byDue = aDue.compareTo(bDue);
    if (byDue != 0) return byDue;
  }
  return b.importance.compareTo(a.importance);
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year && first.month == second.month && first.day == second.day;

bool _isAfterToday(DateTime value, DateTime now) =>
    DateTime(value.year, value.month, value.day)
        .isAfter(DateTime(now.year, now.month, now.day));

String _todayDate(DateTime date) => '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';

String _weekday(int weekday) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday - 1];

String _relativeDue(DateTime dueAt, DateTime now) {
  final time = _clockTime(dueAt);
  if (_sameDay(dueAt, now)) return dueAt.isAfter(now) ? 'Today · $time' : 'Overdue · $time';
  final tomorrow = now.add(const Duration(days: 1));
  if (_sameDay(dueAt, tomorrow)) return 'Tomorrow · $time';
  return '${_month(dueAt.month).substring(0, 3)} ${dueAt.day} · $time';
}

String _clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.capturing});

  final bool capturing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.auto_awesome, size: 38, color: colors.primary),
            const SizedBox(height: 12),
            Text(capturing ? 'You are all caught up' : 'A clear day',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(
                capturing
                    ? 'Nottler is listening privately for notifications that need your attention.'
                    : 'Turn on notification access when you are ready to start capturing reminders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 9),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class MemoryCard extends StatefulWidget {
  const MemoryCard({
    super.key,
    required this.item,
    required this.controller,
    this.onOpen,
  });

  final MemoryItem item;
  final AppController controller;
  final VoidCallback? onOpen;

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dueAt = widget.controller.scheduledAt(widget.item);
    final radius = _pressed
        ? BorderRadius.circular(20)
        : M3ExpressiveShape.large;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedPhysicalModel(
        duration: M3ExpressiveMotion.quick,
        curve: M3ExpressiveMotion.emphasizedDecelerate,
        shape: BoxShape.rectangle,
        borderRadius: radius,
        elevation: 0,
        color: colors.surfaceContainerLow,
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            onTap: widget.onOpen ??
                () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DetailPage(
                        item: widget.item, controller: widget.controller))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: M3ExpressiveShape.medium),
                    child: Icon(_iconForCategory(widget.item.category),
                        color: colors.onSecondaryContainer),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(widget.item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(widget.item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.onSurfaceVariant)),
                        const SizedBox(height: 7),
                        Wrap(spacing: 7, runSpacing: 5, children: [
                          if (dueAt != null)
                            _ReminderDueBadge(dueAt: dueAt, now: DateTime.now()),
                          if (widget.item.importance >= 80)
                            _ReminderImportanceBadge(),
                          Text(
                              '${widget.item.category}  •  ${widget.item.sourceApp ?? 'Notification'}',
                              style:
                                  TextStyle(fontSize: 12, color: colors.primary)),
                        ]),
                      ])),
                  const SizedBox(width: 6),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Complete',
                      onPressed: () => widget.controller
                          .updateStatus(widget.item, 'completed'),
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More reminder actions',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) {
                        if (action == 'snooze') {
                          widget.controller.rescheduleItem(
                            widget.item,
                            DateTime.now().add(const Duration(hours: 1)),
                            snooze: true,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'snooze',
                          child: Text('Snooze for one hour'),
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderDueBadge extends StatelessWidget {
  const _ReminderDueBadge({required this.dueAt, required this.now});

  final DateTime dueAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overdue = !dueAt.isAfter(now);
    final background = overdue ? colors.errorContainer : colors.primaryContainer;
    final foreground = overdue ? colors.onErrorContainer : colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: M3ExpressiveShape.small,
      ),
      child: Text(_relativeDue(dueAt, now),
          style: TextStyle(
              color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ReminderImportanceBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: M3ExpressiveShape.small,
      ),
      child: Text('Priority',
          style: TextStyle(
              color: colors.onTertiaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final date = _dateKey(_selected);
    final selectedItems = widget.controller.items
        .where((item) =>
            item.date == date &&
            (item.status == 'active' || item.status == 'snoozed'))
        .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Calendar',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Card(
            child: CalendarDatePicker(
              initialDate: _selected,
              firstDate: DateTime(2020),
              lastDate: DateTime(2040),
              onDateChanged: (date) => setState(() => _selected = date),
            ),
          ),
          const SizedBox(height: 22),
          Text(_prettyDate(_selected),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (selectedItems.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Nothing scheduled for this day.')))
          else
            ...selectedItems.map((item) =>
                MemoryCard(item: item, controller: widget.controller)),
          const SizedBox(height: 22),
          Text('Upcoming',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...widget.controller.items
              .where((item) =>
                  (item.status == 'active' || item.status == 'snoozed') &&
                  item.date != null &&
                  item.date != date)
              .take(8)
              .map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                        child: Icon(_iconForCategory(item.category), size: 19)),
                    title: Text(item.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${item.date}  •  ${item.category}'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DetailPage(
                            item: item, controller: widget.controller))),
                  )),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.controller.searchQuery.isEmpty
        ? widget.controller.items
        : widget.controller.searchResults;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Search memory',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Search by words or meaning. Matching stays on-device.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          SearchBar(
            controller: _searchController,
            onChanged: widget.controller.search,
            hintText: 'payments from SBI',
            leading: const Icon(Icons.search),
            trailing: widget.controller.searchQuery.isEmpty
                ? null
                : [
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.search('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ],
          ),
          const SizedBox(height: 22),
          if (results.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No matching reminders yet.')))
          else
            ...results.map((item) =>
                MemoryCard(item: item, controller: widget.controller)),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Card(
            child: Column(children: [
              ListTile(
                  leading: Icon(Icons.notifications_active_outlined,
                      color: colors.primary),
                  title: const Text('Notification access'),
                  subtitle: Text(controller.notificationAccessGranted
                      ? 'Connected and listening'
                      : 'Required to capture notifications'),
                  trailing: Switch(
                      value: controller.notificationAccessGranted,
                      onChanged: (_) => controller.openNotificationSettings())),
              const Divider(height: 1),
              ListTile(
                  leading: Icon(Icons.history, color: colors.primary),
                  title: const Text('Processing history'),
                  subtitle: Text(
                      '${controller.logs.length} notifications stored locally'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HistoryPage(controller: controller)))),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.filter_alt_outlined, color: colors.primary),
                title: const Text('Notification filters'),
                subtitle: Text(
                  '${controller.blockedPackages.length} apps blocked • ${controller.mutedCategories.length} categories muted',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FilterPage(controller: controller))),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.alarm_outlined, color: colors.primary),
                title: const Text('Deadline reminders'),
                subtitle: const Text('Alert one hour before a scheduled time'),
                trailing: Switch(
                  value: controller.remindersEnabled,
                  onChanged: controller.setRemindersEnabled,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.shield_outlined, color: colors.primary),
                title: const Text('Privacy & storage'),
                subtitle: const Text('Manage or delete your local data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PrivacyPage(controller: controller))),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class FilterPage extends StatelessWidget {
  const FilterPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification filters')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Choose what Nottler saves. Filters are applied on this device before a reminder is created.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text('Apps', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (controller.capturedApps.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Apps will appear here after Nottler captures a notification.'),
              ),
            )
          else
            Card(
              child: Column(
                children: controller.capturedApps
                    .map(
                      (app) => SwitchListTile(
                        title: Text(app.name),
                        subtitle: Text('Block notifications from ${app.name}'),
                        value: !controller.blockedPackages
                            .contains(app.packageName),
                        onChanged: (allowed) =>
                            controller.setAppBlocked(app.packageName, !allowed),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 22),
          Text('Categories', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: NotificationCategory.values
                  .map(
                    (category) => SwitchListTile(
                      title: Text(category.label),
                      subtitle: Text(
                          'Save ${category.label.toLowerCase()} notifications'),
                      value: !controller.mutedCategories.contains(category),
                      onChanged: (allowed) =>
                          controller.setCategoryMuted(category, !allowed),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Only keep high-priority notifications'),
            subtitle:
                const Text('Mutes notifications with a priority below 70.'),
            value: controller.muteLowPriority,
            onChanged: controller.setMuteLowPriority,
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & storage')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stored on this device',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                      '${controller.items.length} reminders • ${controller.logs.length} processed notifications'),
                  const SizedBox(height: 6),
                  Text(
                    'Nottler does not upload this data.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Delete data by app',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (controller.capturedApps.isEmpty)
            const Text('No app data has been stored yet.')
          else
            Card(
              child: Column(
                children: controller.capturedApps
                    .map(
                      (app) => ListTile(
                        title: Text(app.name),
                        subtitle: const Text(
                            'Delete this app’s reminders and history'),
                        trailing: const Icon(Icons.delete_outline),
                        onTap: () => _confirmAppClear(context, app),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all history'),
            onPressed: () => _confirmAllClear(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAppClear(BuildContext context, CapturedApp app) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete ${app.name} data?',
      message:
          'This removes all saved reminders and processing history from ${app.name}.',
    );
    if (confirmed && context.mounted) await controller.clearDataForApp(app);
  }

  Future<void> _confirmAllClear(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete all history?',
      message:
          'This permanently removes every saved reminder and notification history item from this device.',
    );
    if (confirmed && context.mounted) await controller.clearAllHistory();
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: controller.logs.isEmpty
          ? const Center(child: Text('No notifications have been processed.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = controller.logs[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: CircleAvatar(
                      child: Icon(_iconForCategory(record.category.label),
                          size: 19)),
                  title: Text(
                      record.payload.title.isEmpty
                          ? record.payload.appName
                          : record.payload.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${record.category.label}  •  ${(record.categoryConfidence * 100).round()}% confidence\n${record.payload.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.item, required this.controller});

  final MemoryItem item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder'), actions: [
        IconButton(
            onPressed: () async {
              await controller.deleteItem(item);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline))
      ]),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Row(children: [
            Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: M3ExpressiveShape.medium),
                child: Icon(_iconForCategory(item.category),
                    color: colors.onSecondaryContainer, size: 28)),
            const SizedBox(width: 15),
            Expanded(
                child: Text(item.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 24),
          Text(item.description,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.45)),
          const SizedBox(height: 24),
          _DetailRow(
              icon: Icons.label_outline,
              label: 'Category',
              value: item.category),
          if (item.date != null)
            _DetailRow(
                icon: Icons.event_outlined, label: 'Date', value: item.date!),
          if (item.time != null)
            _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Time',
                value: item.time!),
          if (item.responsibleParty != null)
            _DetailRow(
                icon: Icons.person_outline,
                label: 'From',
                value: item.responsibleParty!),
          if (item.sourceApp != null)
            _DetailRow(
                icon: Icons.apps_outlined,
                label: 'Source',
                value: item.sourceApp!),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _pickSchedule(context, controller, item),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Schedule reminder'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showSnoozeOptions(context, controller, item),
            icon: const Icon(Icons.snooze_outlined),
            label: const Text('Snooze'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _pickCategory(context, controller, item),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Correct category'),
          ),
          const SizedBox(height: 26),
          if (item.status == 'active')
            FilledButton.icon(
                onPressed: () async {
                  await controller.updateStatus(item, 'completed');
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Mark complete'))
          else
            OutlinedButton.icon(
                onPressed: () async {
                  await controller.updateStatus(item, 'active');
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.undo),
                label: const Text('Restore reminder')),
        ],
      ),
    );
  }
}

Future<void> _pickSchedule(
  BuildContext context,
  AppController controller,
  MemoryItem item,
) async {
  final current = controller.scheduledAt(item) ??
      DateTime.now().add(const Duration(hours: 1));
  final date = await showDatePicker(
    context: context,
    initialDate: current.isBefore(DateTime.now()) ? DateTime.now() : current,
    firstDate: DateTime.now(),
    lastDate: DateTime(DateTime.now().year + 5),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null || !context.mounted) return;
  final dueAt =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!dueAt.isAfter(DateTime.now())) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a time in the future.')));
    return;
  }
  await controller.rescheduleItem(item, dueAt);
  if (context.mounted) Navigator.of(context).pop();
}

Future<void> _showSnoozeOptions(
  BuildContext context,
  AppController controller,
  MemoryItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          const ListTile(title: Text('Snooze reminder')),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('For 1 hour'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await controller.rescheduleItem(
                  item, DateTime.now().add(const Duration(hours: 1)),
                  snooze: true);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Until tomorrow morning'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final tomorrow = DateTime.now().add(const Duration(days: 1));
              await controller.rescheduleItem(
                item,
                DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
                snooze: true,
              );
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Choose date and time'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickSchedule(context, controller, item);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Future<void> _pickCategory(
  BuildContext context,
  AppController controller,
  MemoryItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Correct category')),
          ...NotificationCategory.values.map(
            (category) => ListTile(
              title: Text(category.label),
              trailing: category.label == item.category
                  ? const Icon(Icons.check)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                await controller.updateCategory(item, category);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label  ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value))
        ]),
      );
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

bool _isScheduledForLater(MemoryItem item, DateTime now) {
  if (item.date == null) return false;
  final scheduled = DateTime.tryParse('${item.date}T${item.time ?? '23:59'}');
  return scheduled != null && scheduled.isAfter(now);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _prettyDate(DateTime date) =>
    '${_month(date.month)} ${date.day}, ${date.year}';
String _month(int month) => const [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][month];

IconData _iconForCategory(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('bank') || lower.contains('finance')) {
    return Icons.account_balance_outlined;
  }
  if (lower.contains('delivery')) return Icons.local_shipping_outlined;
  if (lower.contains('travel')) return Icons.flight_outlined;
  if (lower.contains('work')) return Icons.work_outline;
  if (lower.contains('shop')) return Icons.shopping_bag_outlined;
  if (lower.contains('message')) return Icons.chat_bubble_outline;
  if (lower.contains('social')) return Icons.people_outline;
  return Icons.notifications_none;
}
