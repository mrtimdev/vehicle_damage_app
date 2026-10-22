import 'package:flutter/material.dart';

/// Represents the selected vehicle inspection scope and defect focus tags.
class InspectionScope {
  final String selectedArea;
  final Set<String> activeDefectTags;

  const InspectionScope({
    required this.selectedArea,
    required this.activeDefectTags,
  });

  static const String defaultArea = 'Full Vehicle (All Systems & Machine)';

  // Preset inspection areas covering full vehicle, machine/engine, truck systems, interior, and exterior
  static const List<({String label, IconData icon})> inspectionAreas = [
    (
      label: defaultArea,
      icon: Icons.verified_outlined,
    ),
    (
      label: 'Engine & Machine Bay',
      icon: Icons.precision_manufacturing_outlined,
    ),
    (
      label: 'Suspension, Brakes & Chassis',
      icon: Icons.build_circle_outlined,
    ),
    (
      label: 'Electrical, Battery & Wiring',
      icon: Icons.electrical_services_outlined,
    ),
    (
      label: 'Dashboard & Warning Lights',
      icon: Icons.speed_outlined,
    ),
    (
      label: 'Cargo Bed, Box & Hydraulics',
      icon: Icons.local_shipping_outlined,
    ),
    (
      label: 'Interior & Cabin',
      icon: Icons.airline_seat_recline_normal_outlined,
    ),
    (label: 'All Exterior (360°)', icon: Icons.directions_car_outlined),
    (label: 'Front Bumper & Grille', icon: Icons.flip_to_front_outlined),
    (label: 'Rear Bumper & Trunk', icon: Icons.flip_to_back_outlined),
    (label: 'Doors & Side Panels', icon: Icons.sensor_door_outlined),
    (label: 'Lights & Glass', icon: Icons.light_mode_outlined),
    (label: 'Wheels & Tires', icon: Icons.tire_repair_outlined),
    (label: 'Underbody & Frame', icon: Icons.handyman_outlined),
  ];

  // Comprehensive vehicle & machine fault tags (all selected by default)
  static const List<String> allDefectTags = [
    'Engine / Machine Fault',
    'Fluid / Oil Leak',
    'Suspension / Brake Wear',
    'Electrical / Battery',
    'Dashboard Warning',
    'Hydraulic / Cargo Fault',
    'Dents & Creases',
    'Deep Scratches',
    'Cracked Glass',
    'Broken Lamp/Mirror',
    'Panel Misalignment',
    'Rust / Corrosion',
    'Paint Chipping',
  ];

  factory InspectionScope.initial() => InspectionScope(
        selectedArea: defaultArea,
        activeDefectTags: Set<String>.unmodifiable(allDefectTags),
      );

  bool get isDefault =>
      selectedArea == defaultArea &&
      activeDefectTags.length == allDefectTags.length;

  InspectionScope copyWith({
    String? selectedArea,
    Set<String>? activeDefectTags,
  }) {
    return InspectionScope(
      selectedArea: selectedArea ?? this.selectedArea,
      activeDefectTags: activeDefectTags ?? Set<String>.from(this.activeDefectTags),
    );
  }
}
