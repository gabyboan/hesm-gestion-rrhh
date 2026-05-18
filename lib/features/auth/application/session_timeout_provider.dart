import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_timeout_service.dart';

final sessionTimeoutProvider = Provider<SessionTimeoutService>((ref) {
  final sb = Supabase.instance.client;
  final svc = SessionTimeoutService(sb);

  ref.onDispose(svc.stop);
  return svc;
});
