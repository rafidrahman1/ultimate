import 'package:flutter/material.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:url_launcher/url_launcher.dart';

/// A Google Maps link to a place: the spot, plus Google's own place when
/// [placeId] is one (ids this app made, like `dev:…` or `usr:…`, aren't).
Uri? googleMapsUri({GeoPoint? point, String? placeId}) {
  final googleId = placeId != null && !placeId.contains(':') ? placeId : null;
  if (point == null && googleId == null) return null;
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': point != null ? '${point.latitude},${point.longitude}' : 'place',
    'query_place_id': ?googleId,
  });
}

bool canOpenInMaps({GeoPoint? point, String? placeId}) =>
    googleMapsUri(point: point, placeId: placeId) != null;

/// Opens the place in the Google Maps app (or the browser without it).
Future<void> openPlaceInMaps(
  BuildContext context, {
  GeoPoint? point,
  String? placeId,
}) async {
  final uri = googleMapsUri(point: point, placeId: placeId);
  if (uri == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Couldn\'t open Google Maps.')),
    );
  }
}
