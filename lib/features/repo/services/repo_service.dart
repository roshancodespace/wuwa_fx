import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wufx/core/services/app_logger.dart';
import 'package:wufx/features/configs/models/wuwa_config.dart';

class RepoState {
  final bool isSyncing;
  final String syncStatus;
  final double syncProgress;
  final String? commitSha;
  final DateTime? lastSynced;

  const RepoState({
    this.isSyncing = false,
    this.syncStatus = 'Initializing repository...',
    this.syncProgress = 0.0,
    this.commitSha,
    this.lastSynced,
  });

  RepoState copyWith({
    bool? isSyncing,
    String? syncStatus,
    double? syncProgress,
    String? commitSha,
    DateTime? lastSynced,
  }) {
    return RepoState(
      isSyncing: isSyncing ?? this.isSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
      syncProgress: syncProgress ?? this.syncProgress,
      commitSha: commitSha ?? this.commitSha,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}

class RepoSyncResult {
  final bool success;
  final String statusMessage;
  final bool wasUpdated;
  final String? commitSha;
  final DateTime? lastSynced;
  final List<WuwaConfig> configs;
  final Directory? cacheDir;

  const RepoSyncResult({
    required this.success,
    required this.statusMessage,
    this.wasUpdated = false,
    this.commitSha,
    this.lastSynced,
    this.configs = const [],
    this.cacheDir,
  });
}

class RepoService {
  static const String keyCachedCommitSha = "cached_commit_sha";
  static const String keyLastSyncedTime = "last_synced_time";
  static const String keySelectedConfigPath = "selected_config_path";

  /// Parses GitHub repo URL to extract owner and repo name.
  static Map<String, String>? parseGitHubUrl(String url) {
    try {
      var clean = url.trim();
      if (clean.endsWith('.git')) {
        clean = clean.substring(0, clean.length - 4);
      }
      if (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      final uri = Uri.parse(clean);
      if (uri.host.contains('github.com') && uri.pathSegments.length >= 2) {
        return {'owner': uri.pathSegments[0], 'repo': uri.pathSegments[1]};
      }
    } catch (e) {
      AppLogger.w('Failed to parse GitHub URL: $url', e);
    }
    return null;
  }

  /// Fetches the latest commit SHA for the default branch using GitHub API.
  static Future<String?> fetchLatestCommitSha(String owner, String repo) async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/commits?per_page=1',
      );
      AppLogger.i('Fetching latest commit SHA from GitHub API: $url');
      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'WuFX-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final sha = data[0]['sha'] as String;
          AppLogger.i(
            'Latest commit SHA fetched successfully: ${sha.substring(0, 7)}',
          );
          return sha;
        }
      } else {
        AppLogger.w(
          'GitHub API returned non-200 status code: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      AppLogger.w('Error fetching commit SHA from GitHub API', e);
    }
    return null;
  }

  /// Main method to sync repository: check SHA, download zip if needed, extract, and scan configs.
  static Future<RepoSyncResult> syncRepo(
    String repoUrl, {
    bool forceUpdate = false,
    Function(String status, double progress)? onProgress,
  }) async {
    AppLogger.i(
      'Starting syncRepo for URL: $repoUrl (forceUpdate: $forceUpdate)',
    );
    final repoInfo = parseGitHubUrl(repoUrl);
    if (repoInfo == null) {
      AppLogger.e('Invalid GitHub repository URL format: $repoUrl');
      return const RepoSyncResult(
        success: false,
        statusMessage: 'Invalid GitHub repository URL format.',
      );
    }

    final owner = repoInfo['owner']!;
    final repo = repoInfo['repo']!;

    try {
      final appDir = await getApplicationSupportDirectory();
      final cacheDir = Directory(
        path.join(appDir.path, 'repo_cache', '${owner}_$repo'),
      );
      final prefs = await SharedPreferences.getInstance();

      final cachedShaKey = '${keyCachedCommitSha}_$repoUrl';
      final lastSyncedKey = '${keyLastSyncedTime}_$repoUrl';

      final cachedSha = prefs.getString(cachedShaKey);
      final lastSyncedStr = prefs.getString(lastSyncedKey);
      final lastSynced = lastSyncedStr != null
          ? DateTime.tryParse(lastSyncedStr)
          : null;

      final cacheExists =
          await cacheDir.exists() && !await _isDirectoryEmpty(cacheDir);

      AppLogger.i(
        'Cache check: exists=$cacheExists, cachedSha=${cachedSha?.substring(0, 7) ?? "none"}, lastSynced=$lastSynced',
      );

      // Don't check GitHub for updates if synced within the last 5 minutes!
      if (!forceUpdate &&
          cacheExists &&
          lastSynced != null &&
          DateTime.now().difference(lastSynced).inMinutes < 5) {
        AppLogger.i(
          'Repository was synced within the last 5 minutes (${DateTime.now().difference(lastSynced).inMinutes}m ago). Skipping network check.',
        );
        onProgress?.call('Recently synced (< 5m ago). Loading cache...', 0.9);
        final configs = await scanConfigs(cacheDir);
        return RepoSyncResult(
          success: true,
          statusMessage:
              'Up to date (${cachedSha != null && cachedSha.length >= 7 ? cachedSha.substring(0, 7) : "cached"})',
          wasUpdated: false,
          commitSha: cachedSha,
          lastSynced: lastSynced,
          configs: configs,
          cacheDir: cacheDir,
        );
      }

      onProgress?.call('Checking latest commit on GitHub...', 0.1);
      final latestSha = await fetchLatestCommitSha(owner, repo);

      // Check if we are already up-to-date
      if (!forceUpdate &&
          cacheExists &&
          latestSha != null &&
          cachedSha == latestSha) {
        AppLogger.i(
          'Local cache SHA matches latest GitHub SHA (${latestSha.substring(0, 7)}). Repository is up to date!',
        );
        onProgress?.call('Repository is up to date! Loading configs...', 0.9);
        final configs = await scanConfigs(cacheDir);
        return RepoSyncResult(
          success: true,
          statusMessage: 'Up to date (${latestSha.substring(0, 7)})',
          wasUpdated: false,
          commitSha: latestSha,
          lastSynced: lastSynced,
          configs: configs,
          cacheDir: cacheDir,
        );
      }

      // If offline/API failed but we have a valid cache, use cached version
      if (!forceUpdate &&
          cacheExists &&
          latestSha == null &&
          cachedSha != null) {
        AppLogger.w(
          'Could not check latest commit from GitHub API, but valid local cache found. Falling back to offline mode.',
        );
        onProgress?.call('Offline mode: loading cached configurations...', 0.9);
        final configs = await scanConfigs(cacheDir);
        return RepoSyncResult(
          success: true,
          statusMessage: 'Offline mode (${cachedSha.substring(0, 7)})',
          wasUpdated: false,
          commitSha: cachedSha,
          lastSynced: lastSynced,
          configs: configs,
          cacheDir: cacheDir,
        );
      }

      // We need to download and update!
      AppLogger.i('Update required or forced. Starting archive download...');
      onProgress?.call('Update needed. Downloading repository archive...', 0.2);
      final targetSha = latestSha ?? cachedSha;
      await _downloadAndExtractZip(
        owner,
        repo,
        targetSha,
        cacheDir,
        onProgress,
      );

      final newSha = latestSha ?? cachedSha ?? 'unknown';
      if (latestSha != null) {
        await prefs.setString(cachedShaKey, latestSha);
      }
      final now = DateTime.now();
      await prefs.setString(lastSyncedKey, now.toIso8601String());

      onProgress?.call('Scanning configurations...', 0.95);
      final configs = await scanConfigs(cacheDir);
      AppLogger.i(
        'Scan complete. Found ${configs.length} configuration items.',
      );

      return RepoSyncResult(
        success: true,
        statusMessage:
            'Updated to commit ${newSha.length >= 7 ? newSha.substring(0, 7) : newSha}',
        wasUpdated: true,
        commitSha: newSha,
        lastSynced: now,
        configs: configs,
        cacheDir: cacheDir,
      );
    } catch (e) {
      AppLogger.e('Repository sync failed with exception', e);
      try {
        final appDir = await getApplicationSupportDirectory();
        final cacheDir = Directory(
          path.join(appDir.path, 'repo_cache', '${owner}_$repo'),
        );
        if (await cacheDir.exists() && !await _isDirectoryEmpty(cacheDir)) {
          AppLogger.i(
            'Fallback: Loading existing cached configurations after download failure.',
          );
          final configs = await scanConfigs(cacheDir);
          final prefs = await SharedPreferences.getInstance();
          final cachedSha = prefs.getString('${keyCachedCommitSha}_$repoUrl');
          final lastSyncedStr = prefs.getString(
            '${keyLastSyncedTime}_$repoUrl',
          );
          final lastSynced = lastSyncedStr != null
              ? DateTime.tryParse(lastSyncedStr)
              : null;

          return RepoSyncResult(
            success: true,
            statusMessage: 'Update failed. Using cached configs.',
            wasUpdated: false,
            commitSha: cachedSha,
            lastSynced: lastSynced,
            configs: configs,
            cacheDir: cacheDir,
          );
        }
      } catch (fallbackError) {
        AppLogger.e('Fallback cache scan also failed', fallbackError);
      }

      return RepoSyncResult(
        success: false,
        statusMessage: 'Failed to sync repository: $e',
      );
    }
  }

  static Future<bool> _isDirectoryEmpty(Directory dir) async {
    try {
      return await dir.list().isEmpty;
    } catch (e) {
      return true;
    }
  }

  static Future<void> _downloadAndExtractZip(
    String owner,
    String repo,
    String? sha,
    Directory targetDir,
    Function(String status, double progress)? onProgress,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final List<String> urlsToTry = [];
    if (sha != null && sha.isNotEmpty && sha != 'unknown') {
      urlsToTry.add('https://github.com/$owner/$repo/archive/$sha.zip');
    }
    urlsToTry.add(
      'https://github.com/$owner/$repo/archive/refs/heads/main.zip',
    );
    urlsToTry.add(
      'https://github.com/$owner/$repo/archive/refs/heads/master.zip',
    );

    AppLogger.i(
      'Will attempt downloading zip from ${urlsToTry.length} possible URLs',
    );

    File? downloadedZip;
    for (final urlStr in urlsToTry) {
      try {
        AppLogger.i('Attempting download: $urlStr');
        onProgress?.call('Downloading zip archive...', 0.3);
        final response = await http
            .get(Uri.parse(urlStr), headers: {'User-Agent': 'WuFX-App'})
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final tempFile = File(
            path.join(
              tempDir.path,
              '${repo}_archive_${DateTime.now().millisecondsSinceEpoch}.zip',
            ),
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          downloadedZip = tempFile;
          AppLogger.i(
            'Successfully downloaded archive from $urlStr (${(response.bodyBytes.length / 1024).toStringAsFixed(1)} KB)',
          );
          break;
        } else {
          AppLogger.w(
            'HTTP GET failed for $urlStr: Status ${response.statusCode} - ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        AppLogger.w('Exception downloading from $urlStr', e);
      }
    }

    if (downloadedZip == null) {
      AppLogger.e('All download URLs exhausted. Failed to download archive.');
      throw Exception('Could not download code archive from GitHub.');
    }

    try {
      AppLogger.i('Starting extraction of zip archive: ${downloadedZip.path}');
      onProgress?.call('Extracting archive...', 0.6);
      final bytes = await downloadedZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find root directory name inside zip (e.g. 'Mobile-WuWa-Config-main')
      String? rootPrefix;
      for (final file in archive) {
        final parts = path.split(file.name);
        if (parts.length > 1) {
          rootPrefix = parts[0];
          break;
        }
      }
      AppLogger.i(
        'Zip archive decoded (${archive.length} entries). Root folder prefix: $rootPrefix',
      );

      final tempExtractDir = Directory(
        path.join(
          tempDir.path,
          '${repo}_extract_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      if (await tempExtractDir.exists()) {
        await tempExtractDir.delete(recursive: true);
      }
      await tempExtractDir.create(recursive: true);

      int count = 0;
      final total = archive.length;
      for (final file in archive) {
        if (file.isFile) {
          String relPath = file.name;
          if (rootPrefix != null && relPath.startsWith(rootPrefix)) {
            final parts = path.split(relPath);
            if (parts.length > 1) {
              relPath = path.joinAll(parts.sublist(1));
            }
          }
          final outFile = File(path.join(tempExtractDir.path, relPath));
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
        count++;
        if (count % 20 == 0) {
          onProgress?.call(
            'Extracting files ($count/$total)...',
            0.6 + (0.3 * (count / total)),
          );
        }
      }
      AppLogger.i(
        'Extracted $count files into temp directory: ${tempExtractDir.path}',
      );

      onProgress?.call('Updating local cache...', 0.92);
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      try {
        await tempExtractDir.rename(targetDir.path);
      } catch (e) {
        AppLogger.w('Rename failed ($e). Falling back to deep copyDirectory.');
        await _copyDirectory(tempExtractDir, targetDir);
        await tempExtractDir.delete(recursive: true);
      }
      AppLogger.i(
        'Local cache directory updated successfully: ${targetDir.path}',
      );
    } finally {
      if (await downloadedZip.exists()) {
        await downloadedZip.delete();
      }
    }
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(
          path.join(destination.path, path.basename(entity.path)),
        );
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        await entity.copy(
          path.join(destination.path, path.basename(entity.path)),
        );
      }
    }
  }

  /// Scans the local cache directory for configuration folders (folders containing .ini files).
  static Future<List<WuwaConfig>> scanConfigs(Directory cacheDir) async {
    if (!await cacheDir.exists()) {
      AppLogger.w(
        'scanConfigs: Cache directory does not exist: ${cacheDir.path}',
      );
      return [];
    }

    AppLogger.i('Scanning configs in cache directory: ${cacheDir.path}');
    final List<WuwaConfig> configs = [];
    final topLevelEntities = await cacheDir.list().toList();

    for (final topEntity in topLevelEntities) {
      if (topEntity is Directory) {
        final categoryName = path.basename(topEntity.path);
        if (categoryName.startsWith('.') || categoryName == 'build') continue;

        await _scanDirectoryForConfigs(
          dir: topEntity,
          category: categoryName,
          repoRoot: cacheDir.path,
          configs: configs,
          parentName: null,
        );
      }
    }

    configs.sort((a, b) {
      final catComp = a.category.compareTo(b.category);
      if (catComp != 0) return catComp;
      if (a.isExperimental != b.isExperimental) {
        return a.isExperimental ? 1 : -1;
      }
      return a.name.compareTo(b.name);
    });

    return configs;
  }

  static Future<void> _scanDirectoryForConfigs({
    required Directory dir,
    required String category,
    required String repoRoot,
    required List<WuwaConfig> configs,
    String? parentName,
  }) async {
    try {
      final entities = await dir.list().toList();
      final List<String> iniFiles = [];
      final List<Directory> subDirs = [];

      for (final entity in entities) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          if (fileName.toLowerCase().endsWith('.ini')) {
            iniFiles.add(fileName);
          }
        } else if (entity is Directory) {
          final dirName = path.basename(entity.path);
          if (!dirName.startsWith('.')) {
            subDirs.add(entity);
          }
        }
      }

      final dirName = path.basename(dir.path);
      if (iniFiles.isNotEmpty && dirName != category) {
        final relativePath = path.relative(dir.path, from: repoRoot);
        final isExp =
            dirName.toLowerCase().contains('experimental') ||
            dirName.startsWith('Z_') ||
            dirName.startsWith('z_');

        iniFiles.sort();

        configs.add(
          WuwaConfig(
            id: relativePath,
            name: dirName,
            category: category,
            relativePath: relativePath,
            absolutePath: dir.path,
            iniFiles: iniFiles,
            isExperimental: isExp,
            parentName: parentName,
          ),
        );
      }

      final nextParent = (dirName != category && iniFiles.isNotEmpty)
          ? dirName
          : parentName;
      for (final subDir in subDirs) {
        await _scanDirectoryForConfigs(
          dir: subDir,
          category: category,
          repoRoot: repoRoot,
          configs: configs,
          parentName: nextParent,
        );
      }
    } catch (e) {
      AppLogger.e('Error scanning directory ${dir.path}', e);
    }
  }

  static Future<String?> getSelectedConfigPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySelectedConfigPath);
  }

  static Future<void> setSelectedConfigPath(String? relativePath) async {
    final prefs = await SharedPreferences.getInstance();
    if (relativePath == null) {
      await prefs.remove(keySelectedConfigPath);
    } else {
      await prefs.setString(keySelectedConfigPath, relativePath);
    }
  }
}
