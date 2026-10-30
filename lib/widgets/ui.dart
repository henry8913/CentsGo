import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small round icon button used in headers and over the map.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge = 0,
    this.filled = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final button = Material(
      color: filled ? p.brand : p.surface,
      shape: const CircleBorder(),
      elevation: filled ? 0 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: filled ? Colors.transparent : p.border),
          ),
          child: Icon(icon, size: 21, color: filled ? Colors.white : p.brand),
        ),
      ),
    );
    final withBadge = badge > 0
        ? Badge(
            backgroundColor: p.bad,
            label: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white)),
            child: button,
          )
        : button;
    return tooltip == null ? withBadge : Tooltip(message: tooltip!, child: withBadge);
  }
}

/// Rounded selection chip (fuel type, filters, sort modes).
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.trailing,
    this.dense = false,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? trailing;
  final bool dense;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = color ?? p.brand;
    return Material(
      color: selected ? accent : p.surface,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 15, vertical: dense ? 8 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? accent : p.border, width: 1.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: dense ? 12.5 : 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : p.ink,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort selector with the pill background used by the original list header.
class SegmentedSort extends StatelessWidget {
  const SegmentedSort({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.dense = false,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 7 : 9),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? p.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: dense ? 12.5 : 13.5,
                      fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                      color: i == selectedIndex ? Colors.white : p.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Consistent screen header: display-face title, subtitle and optional action.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: displayStyle(p, size: 30, color: p.brand)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(fontSize: 13.5, color: p.muted)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.padding = const EdgeInsets.fromLTRB(2, 18, 2, 8)});

  final String title;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 17,
                letterSpacing: 0.4,
                color: context.palette.ink,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
    this.caption,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = color ?? p.brand;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w500, color: p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: Money.style(p, size: 21, color: p.ink)),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(unit!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.muted)),
                ],
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: p.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: p.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: p.brand),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: p.muted),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: p.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.info_outline, this.color, this.action});

  final String text;
  final IconData icon;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = color ?? p.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.35, color: p.ink, fontWeight: FontWeight.w500),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Deterministic pastel colour for the round brand badge in the list.
Color brandTint(String brand) {
  const palette = [
    Color(0xFFFFEEE2),
    Color(0xFFFDEFE0),
    Color(0xFFF8EAD9),
    Color(0xFFF3E7E0),
    Color(0xFFFFE9D2),
    Color(0xFFF6E8E3),
  ];
  var hash = 0;
  for (final code in brand.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.letter, this.size = 42});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brandTint(letter),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: p.ink),
      ),
    );
  }
}

/// Standard bottom sheet with grabber + title, used across the app.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  bool expand = false,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.surface,
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * (heightFactor ?? 0.9);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const SheetHandle(),
            Flexible(child: child),
          ],
        ),
      );
    },
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 42,
        height: 4.5,
        decoration: BoxDecoration(
          color: context.palette.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class PriceTag extends StatelessWidget {
  const PriceTag({
    super.key,
    required this.price,
    required this.color,
    this.size = 21,
    this.unit,
  });

  final String price;
  final Color color;
  final double size;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(price, style: Money.style(context.palette, size: size, color: color)),
        if (unit != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(unit!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
      ],
    );
  }
}
