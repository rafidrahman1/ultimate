import 'package:flutter/material.dart';

IconData iconForTravelMode(String mode) {
  return switch (mode) {
    'MOTORCYCLING' => Icons.two_wheeler,
    'WALKING' => Icons.directions_walk,
    'RUNNING' => Icons.directions_run,
    'CYCLING' => Icons.directions_bike,
    'IN_PASSENGER_VEHICLE' => Icons.directions_car,
    'IN_BUS' => Icons.directions_bus,
    'IN_SUBWAY' => Icons.subway,
    'IN_TRAIN' => Icons.train,
    'IN_TRAM' => Icons.tram,
    'IN_FERRY' => Icons.directions_boat,
    'FLYING' => Icons.flight,
    'SKIING' => Icons.downhill_skiing,
    'SAILING' => Icons.sailing,
    _ => Icons.route,
  };
}
