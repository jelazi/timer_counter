import 'package:flutter/material.dart';

import '../../../core/theme/desktop_theme.dart';
import 'window_drag_area.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String? section;

  const SidebarItem({required this.icon, required this.label, this.section});
}

/// Source-list style navigation (Finder / Mail): section headers, compact rows,
/// rounded selection. [topInset] leaves room for the window controls.
class DesktopSidebar extends StatelessWidget {
  final List<SidebarItem> items;
  final List<SidebarItem> bottomItems;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double topInset;
  final Widget? footer;

  const DesktopSidebar({super.key, required this.items, this.bottomItems = const [], required this.selectedIndex, required this.onSelected, required this.topInset, this.footer});

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final rows = <Widget>[];
    String? lastSection;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.section != null && item.section != lastSection) {
        rows.add(_SectionHeader(item.section!, first: rows.isEmpty));
        lastSection = item.section;
      }
      rows.add(_SidebarRow(item: item, selected: i == selectedIndex, onTap: () => onSelected(i)));
    }

    return ColoredBox(
      color: mac.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WindowDragArea(child: SizedBox(height: topInset)),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10), children: rows),
          ),
          if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 0), child: footer),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              children: [
                for (var j = 0; j < bottomItems.length; j++)
                  _SidebarRow(item: bottomItems[j], selected: items.length + j == selectedIndex, onTap: () => onSelected(items.length + j)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool first;

  const _SectionHeader(this.label, {required this.first});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, first ? 2 : 14, 10, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: MacColors.of(context).tertiaryLabel),
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarRow({required this.item, required this.selected, required this.onTap});

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final background = widget.selected ? mac.sidebarSelection : (_hover ? mac.sidebarSelection.withValues(alpha: mac.sidebarSelection.a * 0.45) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 28,
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: background, borderRadius: DesktopTheme.controlRadius),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
