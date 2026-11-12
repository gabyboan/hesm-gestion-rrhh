import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_attempt_limiter.dart';

final loginAttemptLimiterProvider =
    Provider<LoginAttemptLimiter>((ref) => LoginAttemptLimiter());
