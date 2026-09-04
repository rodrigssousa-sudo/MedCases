import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'clinical_long_form_native_secure_persistence_adapters.dart';
import 'clinical_long_form_sensitive_at_rest_policy.dart';

typedef ClinicalLongFormPlaintextStagingAction<T> = Future<T> Function(
  File stagingFile,
);

final class ClinicalLongFormPlaintextStagingGcReport {
  const ClinicalLongFormPlaintextStagingGcReport({
    required this.deletedFiles,
    required this.alreadyMissingFiles,
    required this.preservedEntries,
  });

  final int deletedFiles;
  final int alreadyMissingFiles;
  final int preservedEntries;
}

final class ClinicalLongFormPlaintextStagingLease {
  ClinicalLongFormPlaintextStagingLease._({
    required ClinicalLongFormSecurePlaintextStagingLifecycle owner,
    required this.file,
    required this.createdAtUtc,
    required this.expiresAtUtc,
  }) : _owner = owner;

  final ClinicalLongFormSecurePlaintextStagingLifecycle _owner;
  final File file;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;

  bool _used = false;
  bool _closed = false;

  bool get used => _used;
  bool get closed => _closed;

  Future<T> useOnce<T>(
    ClinicalLongFormPlaintextStagingAction<T> action,
  ) {
    return _owner._useLease<T>(
      lease: this,
      action: action,
    );
  }
}

final class ClinicalLongFormSecurePlaintextStagingLifecycle {
  ClinicalLongFormSecurePlaintextStagingLifecycle({
    required Directory secureRootDirectory,
    required NativeSecureClinicalLongFormClosedAudioAdapter closedAudioAdapter,
    DateTime Function()? nowUtc,
    String Function()? nonceFactory,
  })  : _secureRootDirectory = secureRootDirectory,
        _closedAudioAdapter = closedAudioAdapter,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _nonceFactory = nonceFactory ?? _secureNonceHex;

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool remoteTransportWiringEnabled = false;
  static const bool remoteRealAudioEnabled = false;
  static const bool plaintextRemotePersistenceAllowed = false;
  static const bool plaintextDurablePersistenceAllowed = false;
  static const bool plaintextLeaseSingleUseRequired = true;
  static const bool deleteInFinallyRequired = true;
  static const bool crashRecoveryGcRequired = true;
  static const bool broadRecursiveDeleteAllowed = false;
  static const bool patientIdentityInFilenameAllowed = false;
  static const int maximumPlaintextLifetimeSeconds =
      ClinicalLongFormSensitiveAtRestPolicy
          .transportPlaintextMaximumLifetimeSeconds;

  final Directory _secureRootDirectory;
  final NativeSecureClinicalLongFormClosedAudioAdapter _closedAudioAdapter;
  final DateTime Function() _nowUtc;
  final String Function() _nonceFactory;

  Directory get stagingRootDirectory => Directory(
        _join(_secureRootDirectory.path, 'transport_plaintext_staging'),
      );

  Future<ClinicalLongFormPlaintextStagingLease> createLease({
    required String sessionId,
    required int segmentIndex,
    required File sealedSource,
  }) async {
    _validateSessionId(sessionId);
    _validateSegmentIndex(segmentIndex);

    final root = await _requireSecureRoot();
    final stagingRoot = await _ensureStagingRoot(root);
    final sessionDirectory = await _ensureSessionDirectory(
      stagingRoot,
      sessionId,
    );

    final nonce = _nonceFactory();
    _validateNonce(nonce);

    final fileName = 'staging_${nonce}_segment_'
        '${segmentIndex.toString().padLeft(5, '0')}.m4a';
    final stagingFile = File(
      _join(sessionDirectory.path, fileName),
    );

    final createdAtUtc = _nowUtc().toUtc();
    final expiresAtUtc = createdAtUtc.add(
      const Duration(seconds: maximumPlaintextLifetimeSeconds),
    );

    try {
      await _closedAudioAdapter.openToPlaintextStaging(
        sessionId: sessionId,
        segmentIndex: segmentIndex,
        sealedSource: sealedSource,
        stagingM4a: stagingFile,
      );

      await _requireManagedStagingFile(
        stagingFile,
        allowMissing: false,
      );
      await stagingFile.setLastModified(createdAtUtc);

      return ClinicalLongFormPlaintextStagingLease._(
        owner: this,
        file: stagingFile,
        createdAtUtc: createdAtUtc,
        expiresAtUtc: expiresAtUtc,
      );
    } catch (_) {
      await _deleteManagedFileIfPresent(stagingFile);
      rethrow;
    }
  }

  Future<ClinicalLongFormPlaintextStagingGcReport>
      collectExpiredPlaintextResidue() {
    return _collectManagedResidue(
      deleteAllManagedFiles: false,
      nowUtc: _nowUtc().toUtc(),
    );
  }

  /// Startup/recovery owner.
  ///
  /// No plaintext lease is resumable across a process crash/restart. Therefore
  /// every managed staging file found at recovery is orphaned and delete-only.
  Future<ClinicalLongFormPlaintextStagingGcReport>
      recoverCrashPlaintextResidue() {
    return _collectManagedResidue(
      deleteAllManagedFiles: true,
      nowUtc: _nowUtc().toUtc(),
    );
  }

  Future<T> _useLease<T>({
    required ClinicalLongFormPlaintextStagingLease lease,
    required ClinicalLongFormPlaintextStagingAction<T> action,
  }) async {
    if (!identical(lease._owner, this)) {
      throw StateError('Plaintext staging lease owner mismatch.');
    }
    if (lease._closed) {
      throw StateError('Plaintext staging lease is closed.');
    }
    if (lease._used) {
      throw StateError('Plaintext staging lease is single-use.');
    }

    lease._used = true;

    final now = _nowUtc().toUtc();
    final remaining = lease.expiresAtUtc.difference(now);

    if (remaining <= Duration.zero) {
      try {
        await _deleteManagedFileIfPresent(lease.file);
      } finally {
        lease._closed = true;
      }
      throw StateError('Plaintext staging lease expired.');
    }

    await _requireManagedStagingFile(
      lease.file,
      allowMissing: false,
    );

    final expiry = Completer<T>();
    late final Timer expiryTimer;

    expiryTimer = Timer(remaining, () {
      _deleteManagedFileIfPresent(lease.file).then(
        (_) {
          if (!expiry.isCompleted) {
            expiry.completeError(
              StateError('Plaintext staging lease expired during use.'),
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!expiry.isCompleted) {
            expiry.completeError(error, stackTrace);
          }
        },
      );
    });

    try {
      final actionFuture = action(lease.file);
      return await Future.any<T>(
        <Future<T>>[
          actionFuture,
          expiry.future,
        ],
      );
    } finally {
      expiryTimer.cancel();
      try {
        await _deleteManagedFileIfPresent(lease.file);
      } finally {
        lease._closed = true;
      }
    }
  }

  Future<ClinicalLongFormPlaintextStagingGcReport> _collectManagedResidue({
    required bool deleteAllManagedFiles,
    required DateTime nowUtc,
  }) async {
    final root = await _requireSecureRoot();
    final stagingRoot = stagingRootDirectory;

    final stagingType = await FileSystemEntity.type(
      stagingRoot.path,
      followLinks: false,
    );

    if (stagingType == FileSystemEntityType.notFound) {
      return const ClinicalLongFormPlaintextStagingGcReport(
        deletedFiles: 0,
        alreadyMissingFiles: 0,
        preservedEntries: 0,
      );
    }
    if (stagingType == FileSystemEntityType.link) {
      throw StateError('Plaintext staging root symlink is forbidden.');
    }
    if (stagingType != FileSystemEntityType.directory) {
      throw StateError('Plaintext staging root is not a directory.');
    }

    final resolvedStagingRoot = Directory(
      await stagingRoot.resolveSymbolicLinks(),
    );
    _requirePathInsideRoot(
      childPath: resolvedStagingRoot.path,
      rootPath: root.path,
    );

    var deleted = 0;
    var missing = 0;
    var preserved = 0;

    await for (final sessionEntry in stagingRoot.list(followLinks: false)) {
      final sessionType = await FileSystemEntity.type(
        sessionEntry.path,
        followLinks: false,
      );

      if (sessionType != FileSystemEntityType.directory) {
        preserved++;
        continue;
      }

      final sessionDirectory = Directory(sessionEntry.path);
      final sessionName = _basename(sessionDirectory.path);

      if (!_sessionIdPattern.hasMatch(sessionName)) {
        preserved++;
        continue;
      }

      await for (final entity in sessionDirectory.list(followLinks: false)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );

        if (type != FileSystemEntityType.file) {
          preserved++;
          continue;
        }

        final file = File(entity.path);
        final fileName = _basename(file.path);

        if (!_managedFilePattern.hasMatch(fileName)) {
          preserved++;
          continue;
        }

        final resolvedFilePath = await file.resolveSymbolicLinks();
        _requirePathInsideRoot(
          childPath: resolvedFilePath,
          rootPath: resolvedStagingRoot.path,
        );

        var shouldDelete = deleteAllManagedFiles;

        if (!shouldDelete) {
          final stat = await file.stat();
          final deadline = stat.modified.toUtc().add(
                const Duration(
                  seconds: maximumPlaintextLifetimeSeconds,
                ),
              );
          shouldDelete = !deadline.isAfter(nowUtc.toUtc());
        }

        if (!shouldDelete) {
          preserved++;
          continue;
        }

        if (!await file.exists()) {
          missing++;
          continue;
        }

        await file.delete();
        deleted++;
      }

      await _deleteDirectoryIfEmpty(sessionDirectory);
    }

    await _deleteDirectoryIfEmpty(stagingRoot);

    return ClinicalLongFormPlaintextStagingGcReport(
      deletedFiles: deleted,
      alreadyMissingFiles: missing,
      preservedEntries: preserved,
    );
  }

  Future<Directory> _requireSecureRoot() async {
    final type = await FileSystemEntity.type(
      _secureRootDirectory.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.link) {
      throw StateError('Secure root symlink is forbidden.');
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Secure root must already exist.');
    }

    return Directory(
      await _secureRootDirectory.resolveSymbolicLinks(),
    );
  }

  Future<Directory> _ensureStagingRoot(Directory secureRoot) async {
    final directory = stagingRootDirectory;
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.notFound) {
      await directory.create();
    } else if (type == FileSystemEntityType.link) {
      throw StateError('Plaintext staging root symlink is forbidden.');
    } else if (type != FileSystemEntityType.directory) {
      throw StateError('Plaintext staging root is not a directory.');
    }

    final resolved = Directory(
      await directory.resolveSymbolicLinks(),
    );
    _requirePathInsideRoot(
      childPath: resolved.path,
      rootPath: secureRoot.path,
    );
    return resolved;
  }

  Future<Directory> _ensureSessionDirectory(
    Directory stagingRoot,
    String sessionId,
  ) async {
    final directory = Directory(
      _join(stagingRoot.path, sessionId),
    );
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.notFound) {
      await directory.create();
    } else if (type == FileSystemEntityType.link) {
      throw StateError('Plaintext staging session symlink is forbidden.');
    } else if (type != FileSystemEntityType.directory) {
      throw StateError('Plaintext staging session path is invalid.');
    }

    final resolved = Directory(
      await directory.resolveSymbolicLinks(),
    );
    _requirePathInsideRoot(
      childPath: resolved.path,
      rootPath: stagingRoot.path,
    );
    return resolved;
  }

  Future<void> _requireManagedStagingFile(
    File file, {
    required bool allowMissing,
  }) async {
    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.notFound && allowMissing) {
      return;
    }
    if (type == FileSystemEntityType.link) {
      throw StateError('Plaintext staging file symlink is forbidden.');
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('Plaintext staging target is not a regular file.');
    }

    final fileName = _basename(file.path);
    if (!_managedFilePattern.hasMatch(fileName)) {
      throw StateError('Plaintext staging filename is not managed.');
    }

    final stagingRoot = stagingRootDirectory;
    final stagingRootType = await FileSystemEntity.type(
      stagingRoot.path,
      followLinks: false,
    );
    if (stagingRootType == FileSystemEntityType.link) {
      throw StateError('Plaintext staging root symlink is forbidden.');
    }
    if (stagingRootType != FileSystemEntityType.directory) {
      throw StateError('Plaintext staging root is not a directory.');
    }

    final resolvedStagingRootPath = await stagingRoot.resolveSymbolicLinks();
    final resolvedFilePath = await file.resolveSymbolicLinks();

    _requirePathInsideRoot(
      childPath: resolvedFilePath,
      rootPath: resolvedStagingRootPath,
    );
  }

  Future<void> _deleteManagedFileIfPresent(File file) async {
    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.notFound) {
      return;
    }

    await _requireManagedStagingFile(
      file,
      allowMissing: false,
    );
    await file.delete();
    await _deleteDirectoryIfEmpty(file.parent);
    await _deleteDirectoryIfEmpty(stagingRootDirectory);
  }

  Future<void> _deleteDirectoryIfEmpty(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type == FileSystemEntityType.link) {
      throw StateError('Staging cleanup will not delete symlink directories.');
    }
    if (type != FileSystemEntityType.directory) {
      return;
    }

    if (!await directory.list(followLinks: false).isEmpty) {
      return;
    }
    await directory.delete();
  }

  static String _secureNonceHex() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static void _requirePathInsideRoot({
    required String childPath,
    required String rootPath,
  }) {
    final normalizedRoot = _stripTrailingSeparators(rootPath);
    final normalizedChild = _stripTrailingSeparators(childPath);

    if (normalizedChild == normalizedRoot) {
      return;
    }

    final prefix = '$normalizedRoot${Platform.pathSeparator}';
    if (!normalizedChild.startsWith(prefix)) {
      throw StateError('Plaintext staging path escaped secure root.');
    }
  }

  static String _stripTrailingSeparators(String path) {
    var value = path;
    while (value.length > 1 && value.endsWith(Platform.pathSeparator)) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _basename(String path) {
    final separator = Platform.pathSeparator;
    final parts = path.split(separator);
    return parts.isEmpty ? path : parts.last;
  }

  static void _validateSessionId(String sessionId) {
    if (!_sessionIdPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
  }

  static void _validateSegmentIndex(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex > 99999) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
  }

  static void _validateNonce(String nonce) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce)) {
      throw StateError('Plaintext staging nonce is invalid.');
    }
  }

  static final RegExp _sessionIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,96}$');

  static final RegExp _managedFilePattern =
      RegExp(r'^staging_[a-f0-9]{32}_segment_\d{5}\.m4a$');
}

String _join(String left, String right) {
  final separator = Platform.pathSeparator;
  if (left.endsWith(separator)) {
    return '$left$right';
  }
  return '$left$separator$right';
}
