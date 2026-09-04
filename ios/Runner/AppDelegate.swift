import AVFoundation
import CryptoKit
import Firebase
import Flutter
import Security
import UIKit

// BUILD 279 — Anti-Flash iOS: sincronismo nativo entre LaunchScreen.storyboard e Flutter.
//
// PROBLEMA: o storyboard nativo encerra antes da árvore de widgets Flutter estar
// renderizada. O UIWindow exibe sua backgroundColor padrão (branco/transparente)
// por 1-3 frames → flash branco visível → risco de rejeição App Store (Guideline 2.1).
//
// SOLUÇÃO (3 camadas):
//   1. LaunchScreen.storyboard → backgroundColor #0F1116 (já corrigido no XML)
//   2. UIWindow.backgroundColor = #0F1116 (esta camada — cobertura nativa UIKit)
//   3. MaterialApp.color + builder Container dark (camada Flutter — main.dart)
//
// A cor #0F1116 é idêntica ao scaffoldBackgroundColor do dark theme do MedCases,
// garantindo transição invisível entre storyboard → UIKit → Flutter.

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // BUILD 279: força a cor de fundo da UIWindow para o dark background do MedCases.
    // Executado APÓS super.application() para garantir que a window já foi criada
    // pelo FlutterAppDelegate. Cobre o gap entre LaunchScreen e o primeiro frame Flutter.
    // #0F1116 = red:15 green:17 blue:22 (sRGB) → mesmo que scaffoldBackgroundColor dark.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let window = self.window {
      window.backgroundColor = UIColor(
        red: 15.0 / 255.0,
        green: 17.0 / 255.0,
        blue: 22.0 / 255.0,
        alpha: 1.0
      )
    }

    if
      let controller = window?.rootViewController as? FlutterViewController
    {
      MedCasesLongFormAtRestChannel.register(
        messenger: controller.binaryMessenger
      )
      MedCasesStudyImportedAudioSegmenterChannel.register(
        messenger: controller.binaryMessenger
      )
      MedCasesStudyBackgroundTranscriptionChannel.register(
        messenger: controller.binaryMessenger
      )
    }

    return result
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    MedCasesStudyBackgroundTranscriptionChannel.handleBackgroundEvents(
      identifier: identifier,
      completionHandler: completionHandler
    )
  }

}

private final class MedCasesLongFormAtRestChannel {
  private static let channelName = "medcases/audio_at_rest_v2"
  private static let secureDirectoryName = "MedCasesLongFormSecure"
  private static let keychainService =
    "com.medcasespro.med.longform.atrest.aesgcm"
  private static let keyAliasPrefix = "aesgcm."
  private static let envelopeSchema =
    "medcases.long_form_sensitive_envelope.v1"
  private static let algorithmName = "AES-256-GCM"
  private static let keyByteCount = 32

  private static let allowedAssetKinds: Set<String> = [
    "activeAudioSegment",
    "closedAudioSegment",
    "recordingManifest",
    "batchQueue",
    "segmentTranscriptCheckpoint",
    "reviewedTranscript",
    "retentionMetadata",
    "transportPlaintextStaging",
  ]

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "capabilities":
          result([
            "platform": "ios",
            "channel": channelName,
            "secureRootKind": "applicationSupportNoBackup",
            "activeFileProtection": "completeUnlessOpen",
            "durableFileProtection": "complete",
            "keyStore": "Keychain",
            "keyAccessibility": "whenUnlockedThisDeviceOnly",
            "cipher": algorithmName,
            "keyExportToFlutter": false,
            "productionIntegrationEnabled": false,
          ])

        case "secureRoot":
          result(try secureRoot().path)

        case "protectActiveAudioFile":
          let args = try dictionaryArguments(call.arguments)
          let path = try string(args, "path")
          try protectFile(
            path: path,
            protection: .completeUnlessOpen
          )
          result(nil)

        case "protectDurableFile":
          let args = try dictionaryArguments(call.arguments)
          let path = try string(args, "path")
          try protectFile(
            path: path,
            protection: .complete
          )
          result(nil)

        case "seal":
          let args = try dictionaryArguments(call.arguments)
          let clearText = try bytes(args, "clearText")
          let identity = try cryptoIdentity(args)
          let keyData = try loadOrCreateKeyData(
            keyId: identity.keyId
          )
          let key = SymmetricKey(data: keyData)
          let sealed = try AES.GCM.seal(
            clearText,
            using: key,
            authenticating: identity.aad
          )
          guard let combined = sealed.combined else {
            throw BridgeFailure(
              code: "ios_aes_gcm_combined_unavailable"
            )
          }
          result(FlutterStandardTypedData(bytes: combined))

        case "open":
          let args = try dictionaryArguments(call.arguments)
          let sealedData = try bytes(args, "sealedData")
          let identity = try cryptoIdentity(args)
          let keyData = try loadExistingKeyData(
            keyId: identity.keyId
          )
          let key = SymmetricKey(data: keyData)
          let box = try AES.GCM.SealedBox(combined: sealedData)
          let clear = try AES.GCM.open(
            box,
            using: key,
            authenticating: identity.aad
          )
          result(FlutterStandardTypedData(bytes: clear))

        case "sealFile":
          let args = try dictionaryArguments(call.arguments)
          let identity = try cryptoIdentity(args)
          try requireClosedAudioIdentity(identity)
          let source = try existingRegularFileURL(
            args: args,
            key: "sourcePath"
          )
          let destination = try destinationFileURL(
            args: args,
            key: "destinationPath"
          )
          let clear = try Data(
            contentsOf: source,
            options: [.mappedIfSafe]
          )
          let keyData = try loadOrCreateKeyData(
            keyId: identity.keyId
          )
          let key = SymmetricKey(data: keyData)
          let sealed = try AES.GCM.seal(
            clear,
            using: key,
            authenticating: identity.aad
          )
          guard let combined = sealed.combined else {
            throw BridgeFailure(
              code: "ios_aes_gcm_combined_unavailable"
            )
          }
          try writeNativeFileCryptoOutput(
            data: combined,
            destination: destination
          )
          result([
            "path": destination.path,
            "byteCount": combined.count,
          ])

        case "openFile":
          let args = try dictionaryArguments(call.arguments)
          let identity = try cryptoIdentity(args)
          try requireClosedAudioIdentity(identity)
          let source = try existingRegularFileURL(
            args: args,
            key: "sourcePath"
          )
          let destination = try destinationFileURL(
            args: args,
            key: "destinationPath"
          )
          let sealedData = try Data(
            contentsOf: source,
            options: [.mappedIfSafe]
          )
          let keyData = try loadExistingKeyData(
            keyId: identity.keyId
          )
          let key = SymmetricKey(data: keyData)
          let box = try AES.GCM.SealedBox(combined: sealedData)
          let clear = try AES.GCM.open(
            box,
            using: key,
            authenticating: identity.aad
          )
          try writeNativeFileCryptoOutput(
            data: clear,
            destination: destination
          )
          result([
            "path": destination.path,
            "byteCount": clear.count,
          ])

        default:
          result(FlutterMethodNotImplemented)
        }
      } catch let failure as BridgeFailure {
        result(
          FlutterError(
            code: failure.code,
            message: nil,
            details: nil
          )
        )
      } catch {
        result(
          FlutterError(
            code: "ios_at_rest_native_failure",
            message: nil,
            details: nil
          )
        )
      }
    }
  }

  private struct CryptoIdentity {
    let keyId: String
    let assetKind: String
    let aad: Data
  }

  private struct BridgeFailure: Error {
    let code: String
  }

  private static func secureRoot() throws -> URL {
    guard let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw BridgeFailure(code: "ios_application_support_missing")
    }

    let root = base.appendingPathComponent(
      secureDirectoryName,
      isDirectory: true
    )

    if !FileManager.default.fileExists(atPath: root.path) {
      try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true,
        attributes: [
          .protectionKey: FileProtectionType.completeUnlessOpen,
        ]
      )
    } else {
      try FileManager.default.setAttributes(
        [
          .protectionKey: FileProtectionType.completeUnlessOpen,
        ],
        ofItemAtPath: root.path
      )
    }

    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableRoot = root
    try mutableRoot.setResourceValues(values)

    return root.standardizedFileURL
  }

  private static func protectFile(
    path: String,
    protection: FileProtectionType
  ) throws {
    let fileURL = URL(fileURLWithPath: path).standardizedFileURL
    let root = try secureRoot()
    try requireInsideRoot(fileURL: fileURL, root: root)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw BridgeFailure(code: "ios_protected_file_missing")
    }

    try FileManager.default.setAttributes(
      [
        .protectionKey: protection,
      ],
      ofItemAtPath: fileURL.path
    )

    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableURL = fileURL
    try mutableURL.setResourceValues(values)
  }

  private static func requireInsideRoot(
    fileURL: URL,
    root: URL
  ) throws {
    let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
    let resolvedFile =
      fileURL.resolvingSymlinksInPath().standardizedFileURL

    let prefix = resolvedRoot.path.hasSuffix("/")
      ? resolvedRoot.path
      : resolvedRoot.path + "/"

    guard resolvedFile.path.hasPrefix(prefix) else {
      throw BridgeFailure(code: "ios_path_outside_secure_root")
    }
  }

  private static func requireClosedAudioIdentity(
    _ identity: CryptoIdentity
  ) throws {
    guard identity.assetKind == "closedAudioSegment" else {
      throw BridgeFailure(
        code: "ios_file_crypto_requires_closed_audio"
      )
    }
  }

  private static func existingRegularFileURL(
    args: [String: Any],
    key: String
  ) throws -> URL {
    let path = try string(args, key)
    let fileURL = URL(fileURLWithPath: path).standardizedFileURL
    let root = try secureRoot()
    try requireInsideRoot(fileURL: fileURL, root: root)

    let values = try fileURL.resourceValues(
      forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
    )

    guard values.isSymbolicLink != true else {
      throw BridgeFailure(code: "ios_file_crypto_symlink_forbidden")
    }

    guard values.isRegularFile == true else {
      throw BridgeFailure(code: "ios_file_crypto_source_not_regular")
    }

    return fileURL
  }

  private static func destinationFileURL(
    args: [String: Any],
    key: String
  ) throws -> URL {
    let path = try string(args, key)
    let destination = URL(
      fileURLWithPath: path
    ).standardizedFileURL
    let root = try secureRoot()

    guard destination.path != root.path else {
      throw BridgeFailure(code: "ios_file_crypto_destination_invalid")
    }

    let parent = destination.deletingLastPathComponent()
    try requireInsideRoot(fileURL: parent, root: root)

    let parentValues = try parent.resourceValues(
      forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
    )
    guard parentValues.isSymbolicLink != true else {
      throw BridgeFailure(
        code: "ios_file_crypto_parent_symlink_forbidden"
      )
    }
    guard parentValues.isDirectory == true else {
      throw BridgeFailure(code: "ios_file_crypto_parent_invalid")
    }

    if FileManager.default.fileExists(atPath: destination.path) {
      throw BridgeFailure(
        code: "ios_file_crypto_destination_exists"
      )
    }

    return destination
  }

  private static func writeNativeFileCryptoOutput(
    data: Data,
    destination: URL
  ) throws {
    let manager = FileManager.default
    let temporary = destination
      .deletingLastPathComponent()
      .appendingPathComponent(
        ".\(destination.lastPathComponent).\(UUID().uuidString).tmp"
      )

    defer {
      if manager.fileExists(atPath: temporary.path) {
        try? manager.removeItem(at: temporary)
      }
    }

    let created = manager.createFile(
      atPath: temporary.path,
      contents: data,
      attributes: [
        .protectionKey: FileProtectionType.complete,
      ]
    )

    guard created else {
      throw BridgeFailure(
        code: "ios_file_crypto_temp_create_failed"
      )
    }

    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableTemporary = temporary
    try mutableTemporary.setResourceValues(values)

    try manager.moveItem(
      at: temporary,
      to: destination
    )

    try protectFile(
      path: destination.path,
      protection: .complete
    )
  }

  private static func dictionaryArguments(
    _ arguments: Any?
  ) throws -> [String: Any] {
    guard let args = arguments as? [String: Any] else {
      throw BridgeFailure(code: "ios_arguments_invalid")
    }
    return args
  }

  private static func string(
    _ args: [String: Any],
    _ key: String
  ) throws -> String {
    guard
      let value = args[key] as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw BridgeFailure(code: "ios_argument_\(key)_invalid")
    }
    return value
  }

  private static func bytes(
    _ args: [String: Any],
    _ key: String
  ) throws -> Data {
    if let typed = args[key] as? FlutterStandardTypedData {
      return typed.data
    }
    if let data = args[key] as? Data {
      return data
    }
    throw BridgeFailure(code: "ios_argument_\(key)_invalid")
  }

  private static func cryptoIdentity(
    _ args: [String: Any]
  ) throws -> CryptoIdentity {
    let keyId = try string(args, "keyId")
    let sessionId = try string(args, "sessionId")
    let assetKind = try string(args, "assetKind")
    let logicalName = try string(args, "logicalName")

    guard keyId.range(
      of: #"^[A-Za-z0-9._-]{1,64}$"#,
      options: .regularExpression
    ) != nil else {
      throw BridgeFailure(code: "ios_key_id_invalid")
    }

    guard sessionId.range(
      of: #"^[A-Za-z0-9._-]{1,96}$"#,
      options: .regularExpression
    ) != nil else {
      throw BridgeFailure(code: "ios_session_id_invalid")
    }

    guard logicalName.range(
      of: #"^[A-Za-z0-9._-]{1,128}$"#,
      options: .regularExpression
    ) != nil else {
      throw BridgeFailure(code: "ios_logical_name_invalid")
    }

    guard allowedAssetKinds.contains(assetKind) else {
      throw BridgeFailure(code: "ios_asset_kind_invalid")
    }

    let aadString = [
      envelopeSchema,
      algorithmName,
      keyId,
      sessionId,
      assetKind,
      logicalName,
    ].joined(separator: "\n")

    guard let aad = aadString.data(using: .utf8) else {
      throw BridgeFailure(code: "ios_aad_encoding_failed")
    }

    return CryptoIdentity(
      keyId: keyId,
      assetKind: assetKind,
      aad: aad
    )
  }

  private static func keychainQuery(
    keyId: String
  ) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keyAliasPrefix + keyId,
    ]
  }

  private static func loadExistingKeyData(
    keyId: String
  ) throws -> Data {
    var query = keychainQuery(keyId: keyId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(
      query as CFDictionary,
      &item
    )

    guard status == errSecSuccess else {
      throw BridgeFailure(code: "ios_key_not_found")
    }

    guard
      let data = item as? Data,
      data.count == keyByteCount
    else {
      throw BridgeFailure(code: "ios_key_material_invalid")
    }

    return data
  }

  private static func loadOrCreateKeyData(
    keyId: String
  ) throws -> Data {
    do {
      return try loadExistingKeyData(keyId: keyId)
    } catch let failure as BridgeFailure {
      guard failure.code == "ios_key_not_found" else {
        throw failure
      }
    }

    var bytes = [UInt8](
      repeating: 0,
      count: keyByteCount
    )

    guard SecRandomCopyBytes(
      kSecRandomDefault,
      keyByteCount,
      &bytes
    ) == errSecSuccess else {
      throw BridgeFailure(code: "ios_secure_random_failed")
    }

    let keyData = Data(bytes)

    var add = keychainQuery(keyId: keyId)
    add[kSecValueData as String] = keyData
    add[kSecAttrAccessible as String] =
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(
      add as CFDictionary,
      nil
    )

    if status == errSecDuplicateItem {
      return try loadExistingKeyData(keyId: keyId)
    }

    guard status == errSecSuccess else {
      throw BridgeFailure(code: "ios_keychain_add_failed")
    }

    return keyData
  }
}

private final class MedCasesStudyImportedAudioSegmenterChannel {
  private static let channelName =
    "medcases/study_imported_audio_segmenter_v1"
  private static let rootName = "MedCasesStudyImportedAudio"

  private struct SegmenterFailure: Error {
    let code: String
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "segmentAudio":
          let args = try dictionaryArguments(call.arguments)
          let jobId = try safeJobId(args)
          let sourcePath = try string(args, "sourcePath")
          let maxDurationMs = try positiveInt(args, "maxDurationMs")
          let segmentDurationMs = try positiveInt(
            args,
            "segmentDurationMs"
          )

          try segmentAudio(
            jobId: jobId,
            sourcePath: sourcePath,
            maxDurationMs: maxDurationMs,
            segmentDurationMs: segmentDurationMs,
            result: result
          )

        case "deleteJob":
          let args = try dictionaryArguments(call.arguments)
          let jobId = try safeJobId(args)
          let directory = try jobDirectory(jobId: jobId)
          if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
          }
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      } catch let failure as SegmenterFailure {
        result(
          FlutterError(
            code: failure.code,
            message: nil,
            details: nil
          )
        )
      } catch {
        result(
          FlutterError(
            code: "ios_study_audio_segmenter_failure",
            message: nil,
            details: nil
          )
        )
      }
    }
  }

  private static func segmentAudio(
    jobId: String,
    sourcePath: String,
    maxDurationMs: Int,
    segmentDurationMs: Int,
    result: @escaping FlutterResult
  ) throws {
    guard maxDurationMs <= 4 * 60 * 60 * 1000 else {
      throw SegmenterFailure(code: "ios_segmenter_max_over_4h")
    }

    guard
      segmentDurationMs >= 60_000,
      segmentDurationMs <= 15 * 60 * 1000
    else {
      throw SegmenterFailure(code: "ios_segmenter_duration_invalid")
    }

    let source = URL(fileURLWithPath: sourcePath).standardizedFileURL
    let values = try source.resourceValues(
      forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
    )

    guard values.isSymbolicLink != true else {
      throw SegmenterFailure(code: "ios_segmenter_symlink_forbidden")
    }
    guard values.isRegularFile == true else {
      throw SegmenterFailure(code: "ios_segmenter_source_invalid")
    }

    let asset = AVURLAsset(url: source)

    let assetDurationSeconds = CMTimeGetSeconds(asset.duration)
    let audioTracks = asset.tracks(withMediaType: .audio)

    guard !audioTracks.isEmpty else {
      throw SegmenterFailure(code: "ios_segmenter_audio_track_missing")
    }

    var durationCandidates = [Double]()

    if assetDurationSeconds.isFinite && assetDurationSeconds > 0 {
      durationCandidates.append(assetDurationSeconds)
    }

    var maximumTrackEndSeconds = 0.0
    for track in audioTracks {
      let trackEnd = CMTimeRangeGetEnd(track.timeRange)
      let trackEndSeconds = CMTimeGetSeconds(trackEnd)

      if trackEndSeconds.isFinite && trackEndSeconds > 0 {
        durationCandidates.append(trackEndSeconds)
        maximumTrackEndSeconds = max(
          maximumTrackEndSeconds,
          trackEndSeconds
        )
      }
    }

    guard let durationSeconds = durationCandidates.max(),
          durationSeconds.isFinite,
          durationSeconds > 0 else {
      throw SegmenterFailure(code: "ios_segmenter_duration_unavailable")
    }

    let assetDurationMs =
      assetDurationSeconds.isFinite && assetDurationSeconds > 0
        ? Int((assetDurationSeconds * 1000.0).rounded())
        : 0
    let trackDurationMs =
      maximumTrackEndSeconds > 0
        ? Int((maximumTrackEndSeconds * 1000.0).rounded())
        : 0
    let durationMs = Int((durationSeconds * 1000.0).rounded())

    print(
      "[StudyImportedAudioNative] "
        + "assetDurationMs=\(assetDurationMs) "
        + "trackDurationMs=\(trackDurationMs) "
        + "chosenDurationMs=\(durationMs)"
    )

    guard durationMs <= maxDurationMs else {
      throw SegmenterFailure(code: "study_audio_over_4h")
    }

    let directory = try jobDirectory(jobId: jobId)

    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }

    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [
        .protectionKey: FileProtectionType.completeUnlessOpen,
      ]
    )

    var dirValues = URLResourceValues()
    dirValues.isExcludedFromBackup = true
    var mutableDirectory = directory
    try mutableDirectory.setResourceValues(dirValues)

    let segmentCount = Int(
      ceil(Double(durationMs) / Double(segmentDurationMs))
    )

    var payloads = [[String: Any]]()

    func exportSegment(_ index: Int) {
      if index >= segmentCount {
        result([
          "durationMs": durationMs,
          "segments": payloads,
        ])
        return
      }

      let startMs = index * segmentDurationMs
      let endMs = min(durationMs, startMs + segmentDurationMs)
      let activeMs = endMs - startMs

      let destination = directory.appendingPathComponent(
        String(format: "segment_%05d.m4a", index)
      )

      guard let exporter = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetAppleM4A
      ) else {
        result(
          FlutterError(
            code: "ios_segmenter_export_session_unavailable",
            message: nil,
            details: ["index": index]
          )
        )
        return
      }

      exporter.outputURL = destination
      exporter.outputFileType = .m4a
      exporter.shouldOptimizeForNetworkUse = false

      let start = CMTime(
        seconds: Double(startMs) / 1000.0,
        preferredTimescale: 600
      )
      let length = CMTime(
        seconds: Double(activeMs) / 1000.0,
        preferredTimescale: 600
      )
      exporter.timeRange = CMTimeRange(start: start, duration: length)

      exporter.exportAsynchronously {
        switch exporter.status {
        case .completed:
          do {
            try FileManager.default.setAttributes(
              [
                .protectionKey:
                  FileProtectionType.completeUnlessOpen,
              ],
              ofItemAtPath: destination.path
            )

            var fileValues = URLResourceValues()
            fileValues.isExcludedFromBackup = true
            var mutableDestination = destination
            try mutableDestination.setResourceValues(fileValues)

            payloads.append([
              "index": index,
              "path": destination.path,
              "startMs": startMs,
              "durationMs": activeMs,
            ])

            exportSegment(index + 1)
          } catch {
            result(
              FlutterError(
                code: "ios_segmenter_protection_failed",
                message: nil,
                details: ["index": index]
              )
            )
          }

        case .failed:
          result(
            FlutterError(
              code: "ios_segmenter_export_failed",
              message: exporter.error?.localizedDescription,
              details: ["index": index]
            )
          )

        case .cancelled:
          result(
            FlutterError(
              code: "ios_segmenter_export_cancelled",
              message: nil,
              details: ["index": index]
            )
          )

        default:
          result(
            FlutterError(
              code: "ios_segmenter_export_unexpected_status",
              message: nil,
              details: [
                "index": index,
                "status": exporter.status.rawValue,
              ]
            )
          )
        }
      }
    }

    exportSegment(0)
  }

  private static func jobDirectory(jobId: String) throws -> URL {
    guard let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw SegmenterFailure(code: "ios_segmenter_support_missing")
    }

    let root = base.appendingPathComponent(rootName, isDirectory: true)

    if !FileManager.default.fileExists(atPath: root.path) {
      try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true,
        attributes: [
          .protectionKey: FileProtectionType.completeUnlessOpen,
        ]
      )
    }

    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var mutableRoot = root
    try mutableRoot.setResourceValues(values)

    return root.appendingPathComponent(jobId, isDirectory: true)
  }

  private static func dictionaryArguments(
    _ arguments: Any?
  ) throws -> [String: Any] {
    guard let args = arguments as? [String: Any] else {
      throw SegmenterFailure(code: "ios_segmenter_arguments_invalid")
    }
    return args
  }

  private static func safeJobId(
    _ args: [String: Any]
  ) throws -> String {
    let value = try string(args, "jobId")
    guard value.range(
      of: #"^studyimp_[a-f0-9]{16}$"#,
      options: .regularExpression
    ) != nil else {
      throw SegmenterFailure(code: "ios_segmenter_job_id_invalid")
    }
    return value
  }

  private static func string(
    _ args: [String: Any],
    _ key: String
  ) throws -> String {
    guard
      let value = args[key] as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw SegmenterFailure(
        code: "ios_segmenter_argument_\(key)_invalid"
      )
    }
    return value
  }

  private static func positiveInt(
    _ args: [String: Any],
    _ key: String
  ) throws -> Int {
    guard let value = args[key] as? Int, value > 0 else {
      throw SegmenterFailure(
        code: "ios_segmenter_argument_\(key)_invalid"
      )
    }
    return value
  }
}

private final class MedCasesStudyBackgroundUploadDelegate:
  NSObject,
  URLSessionDelegate,
  URLSessionTaskDelegate
{
  let identifier: String
  var completionHandler: (() -> Void)?

  init(identifier: String) {
    self.identifier = identifier
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if let error = error {
      NSLog(
        "[StudyBackgroundTranscriptionNative] task=%ld error=%@",
        task.taskIdentifier,
        String(describing: error)
      )
    } else if let response = task.response as? HTTPURLResponse {
      NSLog(
        "[StudyBackgroundTranscriptionNative] task=%ld status=%ld",
        task.taskIdentifier,
        response.statusCode
      )
    }
  }

  func urlSessionDidFinishEvents(
    forBackgroundURLSession session: URLSession
  ) {
    DispatchQueue.main.async {
      let completion = self.completionHandler
      self.completionHandler = nil
      completion?()
    }
  }
}

private final class MedCasesStudyBackgroundTranscriptionChannel {
  private static let channelName =
    "medcases/study_background_transcription_v1"
  private static let sessionPrefix =
    "medcases.study.background.transcription"

  private static var delegates =
    [String: MedCasesStudyBackgroundUploadDelegate]()
  private static var sessions = [String: URLSession]()

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "enqueue" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        guard let args = call.arguments as? [String: Any],
              let jobId = args["jobId"] as? String,
              let grant = args["grant"] as? String,
              let uploadBaseUrl = args["uploadBaseUrl"] as? String,
              let segments = args["segments"] as? [[String: Any]],
              !jobId.isEmpty,
              !grant.isEmpty,
              !uploadBaseUrl.isEmpty,
              !segments.isEmpty
        else {
          throw NSError(
            domain: "MedCasesStudyBackgroundTranscription",
            code: 1
          )
        }

        try enqueue(
          jobId: jobId,
          grant: grant,
          uploadBaseUrl: uploadBaseUrl,
          segments: segments
        )
        result(true)
      } catch {
        result(
          FlutterError(
            code: "ios_background_transcription_enqueue_failed",
            message: String(describing: error),
            details: nil
          )
        )
      }
    }
  }

  static func handleBackgroundEvents(
    identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    let delegate = delegates[identifier]
      ?? MedCasesStudyBackgroundUploadDelegate(identifier: identifier)
    delegates[identifier] = delegate
    delegate.completionHandler = completionHandler

    if sessions[identifier] == nil {
      let configuration =
        URLSessionConfiguration.background(withIdentifier: identifier)
      configuration.sessionSendsLaunchEvents = true
      configuration.isDiscretionary = false
      configuration.waitsForConnectivity = true
      configuration.httpMaximumConnectionsPerHost = 2

      sessions[identifier] = URLSession(
        configuration: configuration,
        delegate: delegate,
        delegateQueue: nil
      )
    }
  }

  private static func enqueue(
    jobId: String,
    grant: String,
    uploadBaseUrl: String,
    segments: [[String: Any]]
  ) throws {
    guard let bundleId = Bundle.main.bundleIdentifier else {
      throw NSError(
        domain: "MedCasesStudyBackgroundTranscription",
        code: 2
      )
    }

    let safeJobId = jobId.replacingOccurrences(
      of: #"[^A-Za-z0-9_-]"#,
      with: "",
      options: .regularExpression
    )

    let identifier =
      "\(bundleId).\(sessionPrefix).\(safeJobId)"

    let delegate = delegates[identifier]
      ?? MedCasesStudyBackgroundUploadDelegate(identifier: identifier)
    delegates[identifier] = delegate

    let configuration =
      URLSessionConfiguration.background(withIdentifier: identifier)
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.waitsForConnectivity = true
    configuration.httpMaximumConnectionsPerHost = 2

    let session = URLSession(
      configuration: configuration,
      delegate: delegate,
      delegateQueue: nil
    )
    sessions[identifier] = session

    guard let base = URL(string: uploadBaseUrl) else {
      throw NSError(
        domain: "MedCasesStudyBackgroundTranscription",
        code: 3
      )
    }

    for segment in segments {
      guard let index = segment["index"] as? Int,
            let path = segment["path"] as? String,
            let mimeType = segment["mimeType"] as? String
      else {
        throw NSError(
          domain: "MedCasesStudyBackgroundTranscription",
          code: 4
        )
      }

      let fileUrl = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: path) else {
        throw NSError(
          domain: "MedCasesStudyBackgroundTranscription",
          code: 5
        )
      }

      let target = base.appendingPathComponent(String(index))
      var request = URLRequest(url: target)
      request.httpMethod = "PUT"
      request.setValue(
        "Study \(grant)",
        forHTTPHeaderField: "Authorization"
      )
      request.setValue(
        "application/octet-stream",
        forHTTPHeaderField: "Content-Type"
      )
      request.setValue(
        mimeType,
        forHTTPHeaderField: "x-medcases-audio-mime"
      )

      let task = session.uploadTask(
        with: request,
        fromFile: fileUrl
      )
      task.taskDescription = "study:\(jobId):\(index)"
      task.resume()
    }

    NSLog(
      "[StudyBackgroundTranscriptionNative] queued job=%@ segments=%ld",
      jobId,
      segments.count
    )
  }
}
