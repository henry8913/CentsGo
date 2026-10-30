import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'garage/garage_tab.dart';
import 'list/list_tab.dart';
import 'map/map_tab.dart';
import 'search/search_tab.dart';
import 'trip/trip_tab.dart';

/// Width of the content column on tablets and desktops. Phones use the full
/// width, so the app stays edge-to-edge where it matters.
const double kContentMaxWidth = 780;

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state, this.initialTab = 0});

  final AppState state;
  final int initialTab;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int _index = widget.initialTab.clamp(0, 4);

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.format_list_bulleted, active: Icons.format_list_bulleted, label: 'Lista'),
    (icon: Icons.map_outlined, active: Icons.map, label: 'Mappa'),
    (icon: Icons.search, active: Icons.search, label: 'Cerca'),
    (icon: Icons.route_outlined, active: Icons.route, label: 'Viaggio'),
    (icon: Icons.directions_car_outlined, active: Icons.directions_car, label: 'Garage'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = widget.state;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) => IndexedStack(
                index: _index,
                children: [
                  ListTab(
                    state: state,
                    onOpenMap: () => setState(() => _index = 1),
                    onOpenSearch: () => setState(() => _index = 2),
                  ),
                  MapTab(state: state, onOpenList: () => setState(() => _index = 0)),
                  SearchTab(state: state, onOpenList: () => setState(() => _index = 0)),
                  TripTab(state: state),
                  GarageTab(state: state),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            // heightFactor: 1 keeps the bar as tall as its content, instead of
            // expanding to the remaining screen height (which would collapse
            // the page body).
            heightFactor: 1,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _index == i ? _items[i].active : _items[i].icon,
                          label: _items[i].label,
                          selected: _index == i,
                          onTap: () => setState(() => _index = i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.brand : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 0, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? p.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
