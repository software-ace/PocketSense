/// Supabase connection config for Pocket Sense.
///
/// The publishable key is public by design — row-level security gates access,
/// so it is safe to ship inside the app binary. Do NOT put the service-role
/// key here; that one must stay server-side only.
class Config {
  Config._();
  static const String supabaseUrl = 'https://effnfuwgjupfigckapst.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_h5wB9Upy7TWHWp3b8gInCA_ZZaOMnTx';
}
