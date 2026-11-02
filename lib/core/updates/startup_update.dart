import 'lan_release.dart';
import 'windows_update_service.dart';

enum StartupUpdateStatus {
  disabled,
  checking,
  current,
  available,
  notConfigured,
  unavailable,
}

class StartupUpdateState {
  const StartupUpdateState(this.status, {this.release});
  final StartupUpdateStatus status;
  final LanRelease? release;
}

Future<StartupUpdateState> checkStartupUpdates() async {
  if (!WindowsUpdateService.enabled) {
    return const StartupUpdateState(StartupUpdateStatus.disabled);
  }
  try {
    final service = WindowsUpdateService.instance;
    await service.initialize();
    if (service.share == null) {
      return const StartupUpdateState(StartupUpdateStatus.notConfigured);
    }
    final release = await service.checkForUpdates();
    return release == null
        ? const StartupUpdateState(StartupUpdateStatus.current)
        : StartupUpdateState(StartupUpdateStatus.available, release: release);
  } catch (_) {
    return const StartupUpdateState(StartupUpdateStatus.unavailable);
  }
}
