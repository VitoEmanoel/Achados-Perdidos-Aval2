import 'package:flutter/material.dart';

import '../../models/lost_item.dart';
import 'item_status_style.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = status.foregroundColor(colors);
    return Semantics(
      label: 'Situação: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: status.backgroundColor(colors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
