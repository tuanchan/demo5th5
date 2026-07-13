import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://ikmiqdviqgormlzxwfbk.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_GlisQgO2oTCwSegzymweFg_YemKTyIr';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static User? get currentUser => client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;
}
