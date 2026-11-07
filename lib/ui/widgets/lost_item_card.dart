import 'package:flutter/material.dart';

import '../../models/lost_item.dart';
import 'status_badge.dart';

class LostItemCard extends StatelessWidget {
  const LostItemCard({super.key, required this.item, this.onTap});

  final LostItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final createdAt = item.createdAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.name, style: textTheme.titleMedium),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(item.location, style: textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.description, style: textTheme.bodyMedium),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Cadastrado em ${formatDateTime(createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      'às ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
