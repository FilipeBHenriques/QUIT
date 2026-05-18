class AppEnv {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gvtgjtsksqbastxncxga.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_zKC9vR8BON13XM5vcKFqvw_zYYPX0lP',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1007838318849-13qflspstb8e8kh5tmfb6q1eklr8euel.apps.googleusercontent.com',
  );
}
