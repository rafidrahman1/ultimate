import 'package:motohealth/features/garage/moto_models.dart';

enum CatalogCategory {
  engine('Engine & fuel'),
  drive('Drive & transmission'),
  brakes('Brakes'),
  suspension('Suspension & steering'),
  wheels('Wheels & tyres'),
  electrical('Electrical & lights'),
  general('General & safety');

  const CatalogCategory(this.label);
  final String label;
}

/// A maintenance job any motorcycle might need. Intervals are typical; the
/// rider can edit them per bike. [hint] says which bikes the job applies to,
/// so the AI can decide whether it belongs on a given bike.
class CatalogItem {
  const CatalogItem(
    this.id,
    this.name,
    this.category, {
    this.km,
    this.days,
    this.hint = 'all bikes',
  });

  final String id;
  final String name;
  final CatalogCategory category;
  final double? km;
  final int? days;
  final String hint;

  ServiceTask toTask() =>
      ServiceTask(id: id, name: name, intervalKm: km, intervalDays: days);
}

const _e = CatalogCategory.engine;
const _d = CatalogCategory.drive;
const _b = CatalogCategory.brakes;
const _s = CatalogCategory.suspension;
const _w = CatalogCategory.wheels;
const _x = CatalogCategory.electrical;
const _g = CatalogCategory.general;

/// Every job the app knows about, in the order they are listed.
const maintenanceCatalog = <CatalogItem>[
  // Engine & fuel
  CatalogItem('oil', 'Engine oil', _e, km: 3000, days: 180),
  CatalogItem('oil-filter', 'Oil filter', _e, km: 6000, days: 365),
  CatalogItem('air-filter', 'Air filter', _e, km: 9000, days: 365),
  CatalogItem(
    'spark-plug',
    'Spark plug',
    _e,
    km: 12000,
    hint: 'petrol engines',
  ),
  CatalogItem(
    'valve-clearance',
    'Valve clearance',
    _e,
    km: 12000,
    hint: 'engines with shim or screw-adjust valves; not hydraulic tappets',
  ),
  CatalogItem(
    'coolant',
    'Coolant',
    _e,
    km: 40000,
    days: 730,
    hint: 'liquid-cooled engines only',
  ),
  CatalogItem(
    'coolant-hoses',
    'Coolant hoses & radiator check',
    _e,
    days: 365,
    hint: 'liquid-cooled engines only',
  ),
  CatalogItem(
    'fuel-filter',
    'Fuel filter',
    _e,
    km: 20000,
    hint:
        'bikes with a serviceable fuel filter (many fuel-injected, some carbureted)',
  ),
  CatalogItem(
    'throttle-body',
    'Throttle body clean',
    _e,
    km: 12000,
    hint: 'fuel-injected engines',
  ),
  CatalogItem(
    'carb-service',
    'Carburettor clean & sync',
    _e,
    km: 12000,
    hint: 'carbureted engines',
  ),
  CatalogItem('idle-adjust', 'Idle speed & throttle free play', _e, km: 6000),
  CatalogItem(
    'oil-strainer',
    'Oil strainer / centrifugal filter clean',
    _e,
    km: 12000,
    hint: 'engines that have one instead of or besides a cartridge filter',
  ),
  CatalogItem('exhaust-check', 'Exhaust & mounts check', _e, days: 365),
  // Drive & transmission
  CatalogItem(
    'chain-lube',
    'Chain lube',
    _d,
    km: 500,
    hint: 'chain drive only',
  ),
  CatalogItem(
    'chain-adjust',
    'Chain clean & adjust',
    _d,
    km: 1500,
    hint: 'chain drive only',
  ),
  CatalogItem(
    'chain-sprockets',
    'Chain & sprockets replacement',
    _d,
    km: 20000,
    hint: 'chain drive only',
  ),
  CatalogItem(
    'drive-belt',
    'Drive belt',
    _d,
    km: 30000,
    hint: 'belt final drive (not CVT scooters)',
  ),
  CatalogItem(
    'final-drive-oil',
    'Final drive oil',
    _d,
    km: 12000,
    days: 730,
    hint: 'shaft drive, and scooter final-drive/gear case',
  ),
  CatalogItem(
    'gearbox-oil',
    'Gearbox oil',
    _d,
    km: 12000,
    days: 365,
    hint:
        'engines with a gearbox oil separate from engine oil (many scooters, some older bikes)',
  ),
  CatalogItem(
    'cvt-belt',
    'CVT belt',
    _d,
    km: 20000,
    hint: 'automatic (CVT) scooters',
  ),
  CatalogItem(
    'cvt-rollers',
    'CVT rollers & variator',
    _d,
    km: 12000,
    hint: 'automatic (CVT) scooters',
  ),
  CatalogItem(
    'clutch-adjust',
    'Clutch cable adjust',
    _d,
    km: 6000,
    hint: 'manual clutch with a cable',
  ),
  CatalogItem(
    'clutch-fluid',
    'Clutch fluid',
    _d,
    days: 730,
    hint: 'hydraulic clutch',
  ),
  CatalogItem(
    'clutch-plates',
    'Clutch plates inspection',
    _d,
    km: 25000,
    hint: 'manual clutch',
  ),
  CatalogItem('cables-lube', 'Control cables lube', _d, km: 6000),
  // Brakes
  CatalogItem('brake-fluid', 'Brake fluid', _b, days: 730),
  CatalogItem('brake-pads', 'Brake pads', _b, km: 15000),
  CatalogItem(
    'brake-shoes',
    'Drum brake shoes',
    _b,
    km: 15000,
    hint: 'bikes with a drum brake front or rear',
  ),
  CatalogItem(
    'brake-discs',
    'Brake discs inspection',
    _b,
    km: 30000,
    hint: 'bikes with disc brakes',
  ),
  CatalogItem(
    'brake-hoses',
    'Brake hoses',
    _b,
    days: 1460,
    hint: 'bikes with hydraulic brakes',
  ),
  // Suspension & steering
  CatalogItem('fork-oil', 'Fork oil & seals', _s, km: 20000, days: 1095),
  CatalogItem('rear-shock', 'Rear shock inspection', _s, km: 30000),
  CatalogItem('steering-bearings', 'Steering head bearings', _s, km: 20000),
  CatalogItem('swingarm-lube', 'Swingarm & linkage lube', _s, km: 12000),
  CatalogItem('wheel-bearings', 'Wheel bearings', _s, km: 30000),
  // Wheels & tyres
  CatalogItem('tyres', 'Tyres', _w, km: 20000),
  CatalogItem('tyre-pressure', 'Tyre pressure check', _w, days: 14),
  CatalogItem(
    'spokes',
    'Spokes tension & rim check',
    _w,
    km: 6000,
    hint: 'spoked wheels only',
  ),
  // Electrical
  CatalogItem('battery', 'Battery check', _x, days: 365),
  CatalogItem('lights', 'Lights, horn & indicators check', _x, days: 180),
  // General
  CatalogItem('general', 'General service', _g, km: 6000, days: 365),
  CatalogItem('fasteners', 'Nuts, bolts & fasteners check', _g, km: 6000),
  CatalogItem('helmet', 'Helmet replacement', _g, days: 1825),
];

final _byId = {for (final i in maintenanceCatalog) i.id: i};

CatalogItem? catalogItem(String id) => _byId[id];

/// Jobs a new bike starts with, before the AI narrows the list.
const starterJobIds = [
  'oil',
  'chain-lube',
  'chain-adjust',
  'general',
  'air-filter',
  'spark-plug',
  'brake-fluid',
  'brake-pads',
  'tyres',
  'battery',
];

List<ServiceTask> starterTasks() => [
  for (final id in starterJobIds) _byId[id]!.toTask(),
];
