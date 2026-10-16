import 'dart:ui';

/// Visual body style used by the procedural bike painter.
enum BikeStyle { underbone, scooter, sidecar, tricycle, sport, naked, adventure, cruiser }

enum Rarity { common, uncommon, rare, epic, legendary }

extension RarityLabel on Rarity {
  String get label => switch (this) {
    Rarity.common => 'Common',
    Rarity.uncommon => 'Uncommon',
    Rarity.rare => 'Rare',
    Rarity.epic => 'Epic',
    Rarity.legendary => 'Legendary',
  };

  Color get color => switch (this) {
    Rarity.common => const Color(0xFF9E9E9E),
    Rarity.uncommon => const Color(0xFF4CAF50),
    Rarity.rare => const Color(0xFF2196F3),
    Rarity.epic => const Color(0xFF9C27B0),
    Rarity.legendary => const Color(0xFFFFA000),
  };
}

/// A fictional impounded motorcycle the player can unlock.
///
/// [speed] is the relative 1–15 rating from the design table.
/// [handling] and [fuelEfficiency] are 1–10 ratings used for trade-offs.
class Motorcycle {
  const Motorcycle({
    required this.id,
    required this.name,
    required this.tier,
    required this.price,
    required this.speed,
    required this.handling,
    required this.fuelEfficiency,
    required this.rarity,
    required this.style,
    required this.bodyColor,
    required this.accentColor,
    required this.description,
  });

  final String id;
  final String name;
  final int tier;
  final int price;
  final int speed;
  final int handling;
  final int fuelEfficiency;
  final Rarity rarity;
  final BikeStyle style;
  final Color bodyColor;
  final Color accentColor;
  final String description;

  bool get isFree => price == 0;

  /// Cruising speed in in-game km/h before difficulty scaling.
  double get topSpeedKmh => 72 + speed * 4.2;

  /// Seconds needed to slide one lane over. Better handling = quicker.
  double get laneChangeSeconds => 0.27 - handling * 0.013;

  /// Acceleration in km/h per second.
  double get accelerationKmhPerSec => 26 + handling * 3.5;

  /// Multiplier applied to the base fuel drain. Efficient bikes drain slower.
  double get fuelDrainMultiplier => 1.25 - fuelEfficiency * 0.05;
}

class MotorcycleCatalog {
  MotorcycleCatalog._();

  static const String starterId = 'kamote_110';

  static const List<Motorcycle> all = [
    // Tier 1
    Motorcycle(
      id: 'kamote_110',
      name: 'Kamote 110',
      tier: 1,
      price: 0,
      speed: 1,
      handling: 6,
      fuelEfficiency: 8,
      rarity: Rarity.common,
      style: BikeStyle.underbone,
      bodyColor: Color(0xFFE53935),
      accentColor: Color(0xFFFFFFFF),
      description: 'Rusty underbone with a loud pipe and zero shame. Everyone starts somewhere.',
    ),
    Motorcycle(
      id: 'barangay_125',
      name: 'Barangay 125',
      tier: 1,
      price: 1000,
      speed: 2,
      handling: 5,
      fuelEfficiency: 9,
      rarity: Rarity.common,
      style: BikeStyle.scooter,
      bodyColor: Color(0xFF1E88E5),
      accentColor: Color(0xFFFFEB3B),
      description: 'Seized after a fiesta joyride. Sips fuel like a tita sips coffee.',
    ),
    Motorcycle(
      id: 'sidecar_sprint',
      name: 'Sidecar Sprint',
      tier: 1,
      price: 2000,
      speed: 3,
      handling: 3,
      fuelEfficiency: 9,
      rarity: Rarity.common,
      style: BikeStyle.sidecar,
      bodyColor: Color(0xFF43A047),
      accentColor: Color(0xFFFFFFFF),
      description: 'Comes with a sidecar nobody asked for. Heavy steering, great mileage.',
    ),
    // Tier 2
    Motorcycle(
      id: 'tricycle_escape',
      name: 'Tricycle Escape',
      tier: 2,
      price: 3500,
      speed: 4,
      handling: 2,
      fuelEfficiency: 10,
      rarity: Rarity.uncommon,
      style: BikeStyle.tricycle,
      bodyColor: Color(0xFFFFB300),
      accentColor: Color(0xFF6D4C41),
      description: 'A full trike cab bolted on. Turns like a barge, runs forever.',
    ),
    Motorcycle(
      id: 'highway_cub',
      name: 'Highway Cub',
      tier: 2,
      price: 5000,
      speed: 5,
      handling: 7,
      fuelEfficiency: 6,
      rarity: Rarity.uncommon,
      style: BikeStyle.underbone,
      bodyColor: Color(0xFF00897B),
      accentColor: Color(0xFFFFFFFF),
      description: 'Nimble little cub with a sporty tune. Great for weaving.',
    ),
    Motorcycle(
      id: 'provincial_flash',
      name: 'Provincial Flash',
      tier: 2,
      price: 7000,
      speed: 6,
      handling: 6,
      fuelEfficiency: 5,
      rarity: Rarity.uncommon,
      style: BikeStyle.scooter,
      bodyColor: Color(0xFFF4511E),
      accentColor: Color(0xFF212121),
      description: 'Famous along the national road. Fast, but thirsty.',
    ),
    // Tier 3
    Motorcycle(
      id: 'road_rebel_150',
      name: 'Road Rebel 150',
      tier: 3,
      price: 10000,
      speed: 7,
      handling: 7,
      fuelEfficiency: 5,
      rarity: Rarity.rare,
      style: BikeStyle.naked,
      bodyColor: Color(0xFF263238),
      accentColor: Color(0xFFFF5252),
      description: 'Stripped-down street fighter. Balanced all-rounder.',
    ),
    Motorcycle(
      id: 'falcon_street_200',
      name: 'Falcon Street 200',
      tier: 3,
      price: 14000,
      speed: 8,
      handling: 8,
      fuelEfficiency: 4,
      rarity: Rarity.rare,
      style: BikeStyle.sport,
      bodyColor: Color(0xFFFDD835),
      accentColor: Color(0xFF212121),
      description: 'Sharp handling sport bike. Fuel tank is mostly decoration.',
    ),
    Motorcycle(
      id: 'midnight_racer',
      name: 'Midnight Racer',
      tier: 3,
      price: 18000,
      speed: 9,
      handling: 6,
      fuelEfficiency: 6,
      rarity: Rarity.rare,
      style: BikeStyle.sport,
      bodyColor: Color(0xFF311B92),
      accentColor: Color(0xFF00E5FF),
      description: 'Impounded at 2 AM with neon underglow. Surprisingly economical.',
    ),
    // Tier 4
    Motorcycle(
      id: 'thunder_250',
      name: 'Thunder 250',
      tier: 4,
      price: 24000,
      speed: 10,
      handling: 7,
      fuelEfficiency: 3,
      rarity: Rarity.epic,
      style: BikeStyle.naked,
      bodyColor: Color(0xFF1565C0),
      accentColor: Color(0xFFFFFFFF),
      description: 'Twin-cylinder roar you can hear two barangays away.',
    ),
    Motorcycle(
      id: 'asphalt_phantom',
      name: 'Asphalt Phantom',
      tier: 4,
      price: 32000,
      speed: 11,
      handling: 9,
      fuelEfficiency: 3,
      rarity: Rarity.epic,
      style: BikeStyle.sport,
      bodyColor: Color(0xFF212121),
      accentColor: Color(0xFF76FF03),
      description: 'Matte black ghost. Razor handling, burns fuel quick.',
    ),
    Motorcycle(
      id: 'mountain_stalker',
      name: 'Mountain Stalker',
      tier: 4,
      price: 42000,
      speed: 12,
      handling: 8,
      fuelEfficiency: 5,
      rarity: Rarity.epic,
      style: BikeStyle.adventure,
      bodyColor: Color(0xFF558B2F),
      accentColor: Color(0xFFFF6F00),
      description: 'Adventure tourer with jerry-can mounts. Built for long runs.',
    ),
    // Tier 5
    Motorcycle(
      id: 'highway_king_400',
      name: 'Highway King 400',
      tier: 5,
      price: 55000,
      speed: 13,
      handling: 6,
      fuelEfficiency: 4,
      rarity: Rarity.legendary,
      style: BikeStyle.cruiser,
      bodyColor: Color(0xFF8D6E63),
      accentColor: Color(0xFFFFD54F),
      description: 'Chrome cruiser. Rules the highway, wide turning circle.',
    ),
    Motorcycle(
      id: 'impound_legend',
      name: 'Impound Legend',
      tier: 5,
      price: 75000,
      speed: 14,
      handling: 9,
      fuelEfficiency: 2,
      rarity: Rarity.legendary,
      style: BikeStyle.sport,
      bodyColor: Color(0xFFC62828),
      accentColor: Color(0xFFFFD600),
      description: 'Impounded 37 times. Nobody knows who keeps paying the release fee.',
    ),
    Motorcycle(
      id: 'kamote_xtreme',
      name: 'Kamote Xtreme',
      tier: 5,
      price: 100000,
      speed: 15,
      handling: 10,
      fuelEfficiency: 1,
      rarity: Rarity.legendary,
      style: BikeStyle.sport,
      bodyColor: Color(0xFFFF6F00),
      accentColor: Color(0xFF6A1B9A),
      description: 'The ultimate kamote machine. Absurdly fast, drinks gasoline like water.',
    ),
  ];

  static final Map<String, Motorcycle> _byId = {for (final m in all) m.id: m};

  static Motorcycle? byIdOrNull(String id) => _byId[id];

  static Motorcycle byId(String id) => _byId[id] ?? all.first;

  static bool exists(String id) => _byId.containsKey(id);
}
