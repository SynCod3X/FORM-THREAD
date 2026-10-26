/// Supply these values at build time with --dart-define.
/// The publishable/anon key is intended for client apps; never use a service
/// role or secret key here.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zqmdlrvolgbwbyzdiqyx.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbWRscnZvbGdid2J5emRpcXl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4Nzc1MzMsImV4cCI6MjEwNzQ1MzUzM30.Rg3l777qzDK9EL-M6xs7pEDCtG64Tvt3QtVs03bgpGA',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
