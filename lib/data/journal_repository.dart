import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/sector.dart';

/// Everything the app reads and writes. Two implementations:
/// [FirestoreJournalRepository] for real use, [DemoJournalRepository]
/// for the in-memory demo (no Firebase, nothing saved).
///
/// Writes return immediately: the local cache applies them at once and
/// streams update straight away, with or without signal (FR-5).
abstract class JournalRepository {
  /// The signed-in user.
  String get uid;

  /// True for the demo, which keeps data in memory only.
  bool get isDemo;

  /// A new ID generated on the device, so records can be created offline.
  String newId();

  Stream<List<Crag>> watchCrags();
  void createCrag(Crag crag);
  void updateCrag(Crag crag);

  Stream<List<Sector>> watchSectors(String cragId);
  void createSector(Sector sector);
  void updateSector(Sector sector);

  /// Routes of one crag, by name.
  Stream<List<ClimbRoute>> watchRoutes(String cragId);

  /// Every route; history and the yearly report look routes up by ID.
  Stream<List<ClimbRoute>> watchAllRoutes();
  void createRoute(ClimbRoute route);
  void updateRoute(ClimbRoute route);

  /// The user's own ascents, newest first.
  Stream<List<Ascent>> watchMyAscents();
  void createAscent(Ascent ascent);
  void updateAscent(Ascent ascent);
  void deleteAscent(String id);
}
