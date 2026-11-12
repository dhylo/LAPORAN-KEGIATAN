import 'package:flutter/material.dart';

import 'mac_tokens.dart';

class MacCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const MacCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: Padding(padding: padding, child: child),
    );
  }
}

class MacSection extends StatelessWidget {
  final String title;
  final Widget child;

  const MacSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        MacCard(padding: EdgeInsets.zero, child: child),
      ],
    );
  }
}

class MacToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  const MacToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(MacMetrics.toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        height: MacMetrics.toolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class MacSidebar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const MacSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: MacMetrics.sidebarWidth,
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
            child: Row(
              children: [
                Icon(Icons.insights_outlined, color: colors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Laporan',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _label(context, 'Menu'),
          _item(context, 'Beranda', Icons.home_outlined),
          _item(context, 'Inspeksi Bulanan', Icons.fact_check_outlined),
          const SizedBox(height: 14),
          _label(context, 'Master Data'),
          _item(context, 'Pengaturan Master', Icons.settings_outlined),
          const Spacer(),
          Text(
            'Inspeksi & Monitoring',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String title, IconData icon) {
    final active = title == selected;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => onSelected(title),
        borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? colors.primary.withValues(alpha: 0.14) : null,
            borderRadius: BorderRadius.circular(MacMetrics.smallRadius),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? colors.primary : colors.onSurface,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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

class MacScaffold extends StatelessWidget {
  final String selected;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final ValueChanged<String>? onSelected;

  const MacScaffold({
    super.key,
    required this.selected,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.floatingActionButton,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: MacShell(
        selected: selected,
        title: title,
        subtitle: subtitle,
        actions: actions,
        onSelected: onSelected,
        child: body,
      ),
    );
  }
}

class MacShell extends StatelessWidget {
  final String selected;
  final Widget child;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final ValueChanged<String>? onSelected;

  const MacShell({
    super.key,
    required this.selected,
    required this.child,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MacSidebar(
          selected: selected,
          onSelected: (value) {
            if (value == selected) return;
            if (onSelected != null) {
              onSelected!(value);
              return;
            }
            if (value == 'Beranda') {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        Expanded(
          child: Column(
            children: [
              if (title != null)
                MacToolbar(title: title!, subtitle: subtitle, actions: actions),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}
