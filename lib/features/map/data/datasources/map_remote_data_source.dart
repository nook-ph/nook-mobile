import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

abstract class MapRemoteDataSource {
    Future<List<int>> getNearbyCafes();
}

class MapRemoteDataSourceImpl {
  final SupabaseClient supabase;

  MapRemoteDataSourceImpl(this.supabase);
}
