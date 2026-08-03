import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ManagerProfileOption {
  const ManagerProfileOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.opensHotelSelection,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool opensHotelSelection;
}

const List<ManagerProfileOption> kManagerProfileOptions = [
  ManagerProfileOption(
    value: 'villa_owner',
    label: 'Propriétaire de villa',
    subtitle: 'Villas & maisons privées',
    icon: LucideIcons.home,
    opensHotelSelection: false,
  ),
  ManagerProfileOption(
    value: 'apartment_condo_owner',
    label: 'Appartement / condo',
    subtitle: 'Appartements & condos',
    icon: LucideIcons.building,
    opensHotelSelection: false,
  ),
];

ManagerProfileOption? managerProfileOptionByValue(String? value) {
  if (value == null) return null;
  for (final option in kManagerProfileOptions) {
    if (option.value == value) return option;
  }
  return null;
}

String? legacyDirectorTypeToValue(String? legacyType) {
  switch (legacyType) {
    case 'Directeur d\'Hôtel':
      return 'hotel_manager';
    case 'Directeur de Résidence':
      return 'building_manager';
    case 'Propriétaire de Villa':
      return 'villa_owner';
    case 'Propriétaire d\'Appartement':
      return 'apartment_condo_owner';
    default:
      return null;
  }
}

String? resolveManagerProfileValue(Map<String, dynamic>? data) {
  if (data == null) return null;
  final String? profileType = data['propertyProfileType'] as String?;
  if (profileType != null && profileType.isNotEmpty) {
    return profileType;
  }
  final String? legacyType = data['directorType'] as String?;
  return legacyDirectorTypeToValue(legacyType);
}

String resolveManagerProfileLabel(
  Map<String, dynamic>? data,
  String profileValue,
) {
  final String? label = data?['propertyProfileLabel'] as String?;
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return managerProfileOptionByValue(profileValue)?.label ?? profileValue;
}
