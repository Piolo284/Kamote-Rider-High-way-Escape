/// Tunable constants shared by gameplay systems and components.
///
/// The world uses a fixed logical width of [worldWidth] units; the camera
/// zooms so this width fills the phone screen, and the visible height adapts
/// to the device's aspect ratio.
class GameConfig {
  GameConfig._();

  // ---------------------------------------------------------------- layout
  static const double worldWidth = 400;
  static const double minVisibleHeight = 640;

  static const int laneCount = 4;
  static const double laneWidth = 68;
  static const double roadLeft = 64;
  static const double roadRight = roadLeft + laneWidth * laneCount; // 336
  static const double shoulderWidth = 10;

  /// Lanes 0 and 1 carry oncoming traffic (Philippine roads drive on the right).
  static const int oncomingLaneCount = 2;

  static double laneCenter(int lane) => roadLeft + laneWidth * (lane + 0.5);
  static bool isOncomingLane(int lane) => lane < oncomingLaneCount;

  /// Player sits at this fraction of the visible height.
  static const double playerYFraction = 0.76;

  /// Entities spawn this far above the top of the screen.
  static const double spawnY = -150;

  /// Roadside scenery spawns much farther ahead so the 3D view has
  /// buildings and trees all the way to the horizon.
  static const double propSpawnY = -1900;

  // ----------------------------------------------------------------- speed
  /// Converts in-game meters into world units for scrolling.
  static const double pixelsPerMeter = 14;

  static double kmhToPixelsPerSecond(double kmh) => kmh / 3.6 * pixelsPerMeter;

  /// Largest frame step simulated at once; prevents tunnelling after hitches.
  static const double maxFrameDt = 1 / 20;

  // ------------------------------------------------------------------ fuel
  static const double maxFuel = 100;
  static const double baseFuelDrainPerSecond = 2.1;
  static const double fuelPickupAmount = 28;
  static const double lowFuelThreshold = 25;

  // ----------------------------------------------------------------- chase
  static const double chaseDuration = 10;
  static const double invulnerabilitySeconds = 1.3;

  // --------------------------------------------------------- progression
  static const double metersPerEnvironment = 1000;
  static const int environmentCount = 5;
  static const int chaseEscapeBonus = 75;

  /// Distance before hazards begin spawning at the start of a run.
  static const double hazardFreeStartMeters = 70;
}
