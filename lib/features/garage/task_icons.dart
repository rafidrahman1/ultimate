import 'package:flutter/material.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';

const _byJob = <String, IconData>{
  'oil': Icons.oil_barrel_rounded,
  'oil-filter': Icons.filter_alt_rounded,
  'oil-strainer': Icons.filter_alt_outlined,
  'air-filter': Icons.air_rounded,
  'spark-plug': Icons.bolt_rounded,
  'valve-clearance': Icons.tune_rounded,
  'coolant': Icons.thermostat_rounded,
  'coolant-hoses': Icons.water_rounded,
  'fuel-filter': Icons.local_gas_station_rounded,
  'throttle-body': Icons.speed_rounded,
  'carb-service': Icons.local_gas_station_outlined,
  'idle-adjust': Icons.speed_rounded,
  'exhaust-check': Icons.cloud_outlined,
  'chain-lube': Icons.water_drop_rounded,
  'chain-adjust': Icons.link_rounded,
  'chain-sprockets': Icons.settings_rounded,
  'drive-belt': Icons.link_rounded,
  'final-drive-oil': Icons.oil_barrel_outlined,
  'gearbox-oil': Icons.oil_barrel_outlined,
  'cvt-belt': Icons.link_rounded,
  'cvt-rollers': Icons.settings_rounded,
  'clutch-adjust': Icons.tune_rounded,
  'clutch-fluid': Icons.water_drop_outlined,
  'clutch-plates': Icons.layers_rounded,
  'cables-lube': Icons.cable_rounded,
  'brake-fluid': Icons.water_drop_outlined,
  'brake-pads': Icons.stop_circle_outlined,
  'brake-shoes': Icons.stop_circle_outlined,
  'brake-discs': Icons.album_rounded,
  'brake-hoses': Icons.cable_rounded,
  'fork-oil': Icons.vertical_align_center_rounded,
  'rear-shock': Icons.compress_rounded,
  'steering-bearings': Icons.explore_outlined,
  'swingarm-lube': Icons.water_drop_rounded,
  'wheel-bearings': Icons.trip_origin_rounded,
  'tyres': Icons.tire_repair_rounded,
  'tyre-pressure': Icons.tire_repair_rounded,
  'spokes': Icons.radio_button_unchecked_rounded,
  'battery': Icons.battery_charging_full_rounded,
  'lights': Icons.lightbulb_outline_rounded,
  'general': Icons.build_circle_outlined,
  'fasteners': Icons.hardware_rounded,
  'helmet': Icons.sports_motorsports_rounded,
};

const _byCategory = <CatalogCategory, IconData>{
  CatalogCategory.engine: Icons.settings_suggest_rounded,
  CatalogCategory.drive: Icons.settings_rounded,
  CatalogCategory.brakes: Icons.stop_circle_outlined,
  CatalogCategory.suspension: Icons.compress_rounded,
  CatalogCategory.wheels: Icons.tire_repair_rounded,
  CatalogCategory.electrical: Icons.bolt_rounded,
  CatalogCategory.general: Icons.build_rounded,
};

/// The icon for a maintenance job; custom jobs get a plain wrench.
IconData taskIcon(String taskId) =>
    _byJob[taskId] ??
    switch (catalogItem(taskId)) {
      final item? => _byCategory[item.category]!,
      null => Icons.build_rounded,
    };
