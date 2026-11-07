import 'package:flutter/material.dart';

import '../../models/lost_item.dart';

extension ItemStatusStyle on ItemStatus {
  String get label => switch (this) {
    ItemStatus.lost => 'Perdido',
    ItemStatus.found => 'Encontrado',
  };

  IconData get icon => switch (this) {
    ItemStatus.lost => Icons.search,
    ItemStatus.found => Icons.check_circle_outline,
  };

  Color backgroundColor(ColorScheme colors) => switch (this) {
    ItemStatus.lost => colors.errorContainer,
    ItemStatus.found => colors.primaryContainer,
  };

  Color foregroundColor(ColorScheme colors) => switch (this) {
    ItemStatus.lost => colors.onErrorContainer,
    ItemStatus.found => colors.onPrimaryContainer,
  };
}
