enum ItemStatus {
  lost('lost'),
  found('found');

  const ItemStatus(this.value);

  final String value;

  static ItemStatus fromValue(String value) {
    return values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw FormatException('Unknown item status: $value'),
    );
  }
}

abstract final class LostItemLimits {
  static const int nameMaxLength = 60;
  static const int descriptionMaxLength = 200;
  static const int locationMaxLength = 60;
}

class LostItemDraft {
  const LostItemDraft({
    required this.name,
    required this.description,
    required this.location,
    required this.status,
  });

  final String name;
  final String description;
  final String location;
  final ItemStatus status;

  @override
  bool operator ==(Object other) {
    return other is LostItemDraft &&
        other.name == name &&
        other.description == description &&
        other.location == location &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(name, description, location, status);
}

class LostItem {
  const LostItem({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String location;
  final ItemStatus status;
  final DateTime? createdAt;

  LostItemDraft toDraft({ItemStatus? status}) {
    return LostItemDraft(
      name: name,
      description: description,
      location: location,
      status: status ?? this.status,
    );
  }
}
