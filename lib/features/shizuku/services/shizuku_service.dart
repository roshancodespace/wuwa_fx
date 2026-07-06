import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shizuku_api/shizuku_api.dart';
import 'package:wufx/core/services/app_logger.dart';
import 'package:wufx/features/configs/models/wuwa_config.dart';

class ShizukuState {
  final bool isBinderRunning;
  final bool isPermissionGranted;
  final bool isChecking;
  final bool isBusy;
  final String? lastMessage;

  const ShizukuState({
    this.isBinderRunning = false,
    this.isPermissionGranted = false,
    this.isChecking = false,
    this.isBusy = false,
    this.lastMessage,
  });

  bool get isReady => isBinderRunning && isPermissionGranted;

  ShizukuState copyWith({
    bool? isBinderRunning,
    bool? isPermissionGranted,
    bool? isChecking,
    bool? isBusy,
    String? lastMessage,
  }) {
    return ShizukuState(
      isBinderRunning: isBinderRunning ?? this.isBinderRunning,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      isChecking: isChecking ?? this.isChecking,
      isBusy: isBusy ?? this.isBusy,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}

class ShizukuService {
  static final ShizukuApi _api = ShizukuApi();
  static final ValueNotifier<ShizukuState> state = ValueNotifier<ShizukuState>(
    const ShizukuState(),
  );

  static const String targetConfigDir =
      '/sdcard/Android/data/com.kurogame.wutheringwaves.global/files/UE4Game/Client/Client/Saved/Config';
  static const String targetVulkanCacheDir =
      '/sdcard/Android/data/com.kurogame.wutheringwaves.global/files/VulkanProgramBinaryCache';
  static const String gameRootDir =
      '/sdcard/Android/data/com.kurogame.wutheringwaves.global';
  static const String gameUe4Dir =
      '/sdcard/Android/data/com.kurogame.wutheringwaves.global/files/UE4Game';

  /// Checks if Shizuku binder is running and if permission is granted.
  static Future<void> checkStatus() async {
    AppLogger.i('Checking Shizuku binder and permission status...');
    state.value = state.value.copyWith(isChecking: true, lastMessage: null);
    try {
      final bool isBinderRunning = await _api.pingBinder() ?? false;
      bool isPermissionGranted = false;
      if (isBinderRunning) {
        isPermissionGranted = (await _api.checkPermission()) == true;
      }
      AppLogger.i(
        'Shizuku status: binder=$isBinderRunning, permission=$isPermissionGranted',
      );
      state.value = state.value.copyWith(
        isBinderRunning: isBinderRunning,
        isPermissionGranted: isPermissionGranted,
        isChecking: false,
      );
    } catch (e) {
      AppLogger.e('Error checking Shizuku status', e);
      state.value = state.value.copyWith(
        isBinderRunning: false,
        isPermissionGranted: false,
        isChecking: false,
        lastMessage: 'Error checking Shizuku: $e',
      );
    }
  }

  /// Triggers Shizuku permission request popup.
  static Future<bool> requestPermission() async {
    AppLogger.i('Requesting Shizuku permission from user...');
    state.value = state.value.copyWith(isChecking: true, lastMessage: null);
    try {
      final bool allowed = (await _api.requestPermission()) == true;
      AppLogger.i('Shizuku permission request result: $allowed');
      await checkStatus();
      return allowed;
    } catch (e) {
      AppLogger.e('Shizuku permission request failed', e);
      state.value = state.value.copyWith(
        isChecking: false,
        lastMessage: 'Permission request failed: $e',
      );
      return false;
    }
  }

  /// Runs an ADB shell command via Shizuku.
  static Future<bool> runCommand(String command) async {
    AppLogger.i('Executing Shizuku shell command: $command');
    try {
      final res = await _api.runCommand(command);
      AppLogger.i('Command executed successfully: $res');
      return res != null;
    } catch (e) {
      AppLogger.e('Shizuku command execution failed: $command', e);
      state.value = state.value.copyWith(lastMessage: 'Command failed: $e');
      return false;
    }
  }

  /// Verifies if the game is installed and has been launched at least once.
  /// Returns an error message if verification fails, or null if everything is okay.
  static Future<String?> verifyGameInstallation() async {
    try {
      // Check if root game directory exists (Game installed)
      final rootCheck = await _api.runCommand(
        'if [ -d "$gameRootDir" ]; then echo "EXISTS"; else echo "MISSING"; fi',
      );
      if (rootCheck == null || !rootCheck.contains('EXISTS')) {
        return 'Wuthering Waves is not installed (or data folder not found). Please install the game first!';
      }

      // Check if UE4Game directory exists (Game opened at least once)
      final ue4Check = await _api.runCommand(
        'if [ -d "$gameUe4Dir" ]; then echo "EXISTS"; else echo "MISSING"; fi',
      );
      if (ue4Check == null || !ue4Check.contains('EXISTS')) {
        return 'Game installed, but never launched! Please open Wuthering Waves at least once to initialize game files.';
      }

      return null; // All checks passed!
    } catch (e) {
      AppLogger.e('Error verifying game installation', e);
      return 'Failed to verify game installation: $e';
    }
  }

  /// Applies a configuration by copying its .ini files to the game directory.
  static Future<bool> applyConfig(WuwaConfig config) async {
    AppLogger.i(
      'Applying configuration: "${config.name}" (${config.iniFiles.length} files)',
    );
    if (!state.value.isReady) {
      AppLogger.w(
        'Cannot apply config: Shizuku is not ready (binder=${state.value.isBinderRunning}, perm=${state.value.isPermissionGranted})',
      );
      state.value = state.value.copyWith(
        lastMessage: 'Shizuku is not running or permission not granted.',
      );
      return false;
    }

    state.value = state.value.copyWith(
      isBusy: true,
      lastMessage: 'Verifying game installation...',
    );

    final installError = await verifyGameInstallation();
    if (installError != null) {
      AppLogger.w('Game verification failed: $installError');
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage: installError,
      );
      return false;
    }

    state.value = state.value.copyWith(
      isBusy: true,
      lastMessage: 'Applying ${config.name}...',
    );

    try {
      // Create target directory if it doesn't exist
      await _api.runCommand('mkdir -p "$targetConfigDir"');

      for (final fileName in config.iniFiles) {
        final sourcePath = path.join(config.absolutePath, fileName);
        final destPath = path.join(targetConfigDir, fileName);

        // Copy file and set permissions
        final cmd = 'cp -f "$sourcePath" "$destPath" && chmod 666 "$destPath"';
        AppLogger.i('Copying file: $fileName -> $destPath');
        await _api.runCommand(cmd);
      }

      AppLogger.i('Successfully applied config: "${config.name}"');
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage: 'Successfully applied "${config.name}"!',
      );
      return true;
    } catch (e) {
      AppLogger.e('Failed to apply configuration "${config.name}"', e);
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage: 'Failed to apply config: $e',
      );
      return false;
    }
  }

  /// Secondary feature: Force recompile by deleting Vulkan program binary cache.
  static Future<bool> forceRecompile() async {
    AppLogger.i('Starting Force Recompile: clearing Vulkan shader cache...');
    if (!state.value.isReady) {
      AppLogger.w('Cannot clear Vulkan cache: Shizuku is not ready.');
      state.value = state.value.copyWith(
        lastMessage: 'Shizuku is not running or permission not granted.',
      );
      return false;
    }

    state.value = state.value.copyWith(
      isBusy: true,
      lastMessage: 'Verifying game installation...',
    );

    final installError = await verifyGameInstallation();
    if (installError != null) {
      AppLogger.w('Game verification failed for recompile: $installError');
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage: installError,
      );
      return false;
    }

    final cacheCheck = await _api.runCommand(
      'if [ -d "$targetVulkanCacheDir" ]; then echo "EXISTS"; else echo "MISSING"; fi',
    );
    if (cacheCheck == null || !cacheCheck.contains('EXISTS')) {
      AppLogger.i('Vulkan cache directory not found, nothing to clear.');
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage:
            'Vulkan shader cache is already clean or game has not generated shaders yet!',
      );
      return true;
    }

    state.value = state.value.copyWith(
      isBusy: true,
      lastMessage: 'Clearing Vulkan shader cache...',
    );

    try {
      await _api.runCommand('rm -rf "$targetVulkanCacheDir"');
      AppLogger.i(
        'Vulkan shader cache deleted successfully from $targetVulkanCacheDir',
      );
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage:
            'Vulkan shader cache cleared! Game will recompile shaders on next launch.',
      );
      return true;
    } catch (e) {
      AppLogger.e('Failed to clear Vulkan shader cache', e);
      state.value = state.value.copyWith(
        isBusy: false,
        lastMessage: 'Failed to clear Vulkan cache: $e',
      );
      return false;
    }
  }
}
