import 'package:flutter/material.dart';

/// An icon a rider can pick to tell their bikes apart.
class BikeIcon {
  const BikeIcon(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const bikeIcons = <BikeIcon>[
  BikeIcon('motorcycle', 'Motorcycle', Icons.two_wheeler_rounded),
  BikeIcon('scooter', 'Scooter', Icons.moped_rounded),
  BikeIcon('bicycle', 'Bicycle', Icons.pedal_bike_rounded),
];

/// The icon for [key]; the plain motorcycle when empty or unknown.
BikeIcon bikeIconFor(String key) =>
    bikeIcons.firstWhere((i) => i.key == key, orElse: () => bikeIcons.first);
