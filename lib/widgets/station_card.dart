import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/settings.dart';
import '../models/station.dart';
import '../theme/app_theme.dart';
import 'fuel_bar.dart';
import 'ui.dart';

/// Price row mirroring the original list card: brand + address on the left,
/// big price on the right, distance and price freshness at the bottom.
class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.hit,
    required this.fuel,
    required this.min,
    required this.median,
    required this.max,
    this.onTap,
    this.isFavorite = false,
    this.trailingLabel,
  });

  final StationHit hit;
  final String fuel;
  final double min;
  final double median;
  final double max;
  final VoidCallback? onTap;
  final bool isFavorite;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = hit.station;
    final color = convenienceColor(p, hit.price, min, median, max);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 13, 14, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BrandBadge(letter: s.initial),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.brand.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                            color: p.ink,
                                          ),
                                        ),
                                      ),
                                      if (isFavorite)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: Icon(Icons.favorite, size: 13, color: p.bad),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.fullAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: p.muted),
                                  ),
                                  if (s.isHighway)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: p.surfaceAlt,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Autostrada ${s.highway}',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.slate),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                PriceTag(
                                  price: Fmt.price(hit.price),
                                  color: color,
                                  size: 20,
                                  unit: '/${Fuels.unit(fuel)}',
                                ),
                                if (trailingLabel != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    trailingLabel!,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.muted),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Divider(color: p.border, height: 1),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 14, color: p.muted),
                            const SizedBox(width: 4),
                            Text(
                              Fmt.km(hit.distanceKm),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.muted),
                            ),
                            const Spacer(),
                            Icon(Icons.schedule, size: 14, color: p.muted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Aggiornato ${Fmt.relative(s.updatedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: p.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
