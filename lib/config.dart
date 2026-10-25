/// Which storage the app runs on, chosen at build time:
///
/// * default: local mode, everything on the device, no sign-in (M1).
/// * `--dart-define=DEMO=true`: in-memory sample data, nothing saved.
/// * `--dart-define=CLOUD=true`: Firebase sign-in and sync (M2).
const bool kDemo = bool.fromEnvironment('DEMO');
const bool kCloud = bool.fromEnvironment('CLOUD');
