import ActivityKit
import EventKit
import AVFoundation
import CryptoKit
import Firebase
import FirebaseAuth
import Flutter
import Security
import UIKit
import UserNotifications

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
  private var recordingEventObservers: [NSObjectProtocol] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Forward local notification presentation/taps through Flutter plugins.
    UNUserNotificationCenter.current().delegate = self
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
      let recordingEvents = FlutterMethodChannel(name: "medcases/recording_events_v1", binaryMessenger: controller.binaryMessenger)
      recordingEvents.setMethodCallHandler { call, reply in
        guard call.method == "prepareSession" else { reply(FlutterMethodNotImplemented); return }
        do { try AVAudioSession.sharedInstance().setMode(.default); reply(true) }
        catch { reply(FlutterError(code: "AUDIO_SESSION_MODE", message: nil, details: nil)) }
      }
      recordingEventObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { notification in
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              raw == AVAudioSession.InterruptionType.began.rawValue else { return }
        recordingEvents.invokeMethod("interrupted", arguments: nil)
      })
      recordingEventObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { notification in
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || raw == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
        recordingEvents.invokeMethod("routeChanged", arguments: nil)
      })
      MedCasesOrganizationNative.register(messenger: controller.binaryMessenger)
      MedCasesRecordingDerivedAudio.register(messenger: controller.binaryMessenger)
      let durationChannel = FlutterMethodChannel(name: "medcases/audio_duration_v1", binaryMessenger: controller.binaryMessenger)
      durationChannel.setMethodCallHandler { call, reply in
        guard call.method == "duration", let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else { reply(FlutterMethodNotImplemented); return }
        guard path.hasPrefix("/"), FileManager.default.isReadableFile(atPath: path) else {
          reply(FlutterError(code: "INVALID_AUDIO_PATH", message: nil, details: nil)); return
        }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        var completed = false // accessed only on main queue
        let timeout = DispatchWorkItem {
          guard !completed else { return }; completed = true
          asset.cancelLoading()
          reply(FlutterError(code: "AUDIO_DURATION_TIMEOUT", message: nil, details: nil))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
          var error: NSError?
          let status = asset.statusOfValue(forKey: "duration", error: &error)
          let seconds = status == .loaded ? CMTimeGetSeconds(asset.duration) : Double.nan
          DispatchQueue.main.async {
            guard !completed else { return }; completed = true; timeout.cancel()
            if seconds.isFinite && seconds > 0 && seconds < Double(Int.max) / 1000 {
              reply(Int((seconds * 1000).rounded()))
            } else { reply(FlutterError(code: "AUDIO_DURATION_UNAVAILABLE", message: nil, details: nil)) }
          }
        }
      }
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
    "premiumDrugCatalog",
    "privateUserData",
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

    if assetKind == "premiumDrugCatalog" || assetKind == "privateUserData" {
      guard let uid = Auth.auth().currentUser?.uid else {
        throw BridgeFailure(code: "catalog_auth_required")
      }
      let owner = SHA256.hash(data: Data(uid.utf8)).map { String(format: "%02x", $0) }.joined()
      guard sessionId == owner, keyId == (assetKind == "privateUserData" ? "private." : "catalog.") + String(owner.prefix(48)) else {
        throw BridgeFailure(code: "catalog_owner_mismatch")
      }
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
    guard let identity = task.taskDescription else { return }
    let code = (error as NSError?)?.code ?? 0
    let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
    MedCasesStudyBackgroundTranscriptionChannel.updateDiagnostic(identity, values: [
      "finishedAt": Date().timeIntervalSince1970 * 1000,
      "nativeCode": code, "httpStatus": status,
      "state": error == nil && (200..<300).contains(status) ? "completed" : "failed"
    ])
    // No URL, error description, credentials, audio or response body in logs.
    NSLog("[StudyUpload] status=%ld nativeCode=%ld", status, code)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                  totalBytesExpectedToSend: Int64) {
    guard let identity = task.taskDescription else { return }
    var values: [String: Any] = ["bytesSent": totalBytesSent,
      "state": "uploading"]
    if totalBytesSent == bytesSent { values["uploadStartedAt"] = Date().timeIntervalSince1970 * 1000 }
    if totalBytesExpectedToSend > 0 && totalBytesSent >= totalBytesExpectedToSend {
      values["uploadedAt"] = Date().timeIntervalSince1970 * 1000
      values["state"] = "processing"
    }
    MedCasesStudyBackgroundTranscriptionChannel.updateDiagnostic(identity, values: values)
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

  private static let diagnosticLock = NSLock()
  static func updateDiagnostic(_ identity: String, values: [String: Any]) {
    diagnosticLock.lock(); defer { diagnosticLock.unlock() }
    let key = "medcases.transcription.transport." + identity
    var data = UserDefaults.standard.dictionary(forKey: key) ?? [:]
    data.merge(values) { _, new in new }
    UserDefaults.standard.set(data, forKey: key)
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "appMetadata" {
        result(["appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
                "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"])
        return
      }
      if call.method == "cancel", let args = call.arguments as? [String: Any],
         let jobId = args["jobId"] as? String,
         jobId.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil,
         let bundleId = Bundle.main.bundleIdentifier {
        UserDefaults.standard.set(true, forKey: "medcases.transcription.cancelled." + jobId)
        let identifier = "\(bundleId).\(sessionPrefix).\(jobId)"
        handleBackgroundEvents(identifier: identifier, completionHandler: {})
        sessions[identifier]?.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        result(true)
        return
      }
      if call.method == "diagnostics", let args = call.arguments as? [String: Any],
         let jobId = args["jobId"] as? String, let index = args["index"] as? Int {
        diagnosticLock.lock()
        let data = UserDefaults.standard.dictionary(forKey:
          "medcases.transcription.transport.study:" + jobId + ":" + String(index)) ?? [:]
        diagnosticLock.unlock()
        result(data)
        return
      }
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

    let session = sessions[identifier] ?? URLSession(
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

    var pending: [(URLRequest, URL, String)] = []
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

      pending.append((request, fileUrl, "study:\(jobId):\(index)"))
    }

    session.getAllTasks { tasks in
      if UserDefaults.standard.bool(forKey: "medcases.transcription.cancelled." + jobId) {
        tasks.forEach { $0.cancel() }
        return
      }
      let active = Set(tasks.compactMap { $0.taskDescription })
      for (request, fileUrl, identity) in pending where !active.contains(identity) {
        let task = session.uploadTask(with: request, fromFile: fileUrl)
        task.taskDescription = identity
        updateDiagnostic(identity, values: ["state": "queued",
          "queuedAt": Date().timeIntervalSince1970 * 1000,
          "bytesSent": 0, "httpStatus": 0, "nativeCode": 0])
        task.resume()
      }
    }

    NSLog(
      "[StudyBackgroundTranscriptionNative] queued job=%@ segments=%ld",
      jobId,
      segments.count
    )
  }
}

// Optional transcription derivative. Never opens the master for writing.
private enum MedCasesRecordingDerivedAudio {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "medcases/recording_derived_audio_v1", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, reply in
      guard call.method == "prepare", let args = call.arguments as? [String: String],
            let source = args["source"], let destination = args["destination"],
            let uid = Auth.auth().currentUser?.uid else {
        reply(FlutterError(code: "DERIVATIVE_UNAVAILABLE", message: nil, details: nil)); return
      }
      DispatchQueue.global(qos: .utility).async {
        do {
          let path = try prepare(source: source, destination: destination, uid: uid)
          DispatchQueue.main.async {
            guard Auth.auth().currentUser?.uid == uid else {
              reply(FlutterError(code: "OWNER_CHANGED", message: nil, details: nil)); return
            }
            reply(["path": path])
          }
        } catch {
          DispatchQueue.main.async { reply(FlutterError(code: "DERIVATIVE_UNAVAILABLE", message: nil, details: nil)) }
        }
      }
    }
  }
  private static func prepare(source: String, destination: String, uid: String) throws -> String {
    let fm = FileManager.default
    let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let owner = Data(uid.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    let root = support.appendingPathComponent("medcases_recordings").appendingPathComponent(owner).resolvingSymlinksInPath().path + "/"
    let input = URL(fileURLWithPath: source).resolvingSymlinksInPath()
    let requestedOutput = URL(fileURLWithPath: destination)
    let output = requestedOutput.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(requestedOutput.lastPathComponent)
    guard input.path.hasPrefix(root), output.deletingLastPathComponent().path == input.deletingLastPathComponent().path,
          input.lastPathComponent.hasPrefix("segment_"), input.pathExtension == "m4a",
          output.lastPathComponent == "derived_" + input.deletingPathExtension().lastPathComponent + ".wav" else { throw NSError(domain: "AudioScope", code: 1) }
    // Closed segment names are immutable. A committed derivative is reusable.
    if fm.fileExists(atPath: output.path) { return destination }
    let reader = try AVAudioFile(forReading: input, commonFormat: .pcmFormatFloat32, interleaved: false)
    let format = reader.processingFormat
    guard format.channelCount == 1, reader.length > 0,
          Double(reader.length) / format.sampleRate <= 360 else { throw NSError(domain: "AudioFormat", code: 1) }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else { throw NSError(domain: "AudioBuffer", code: 1) }
    var peak: Float = 0
    var energy: Double = 0
    var samples: Int64 = 0
    while reader.framePosition < reader.length {
      try reader.read(into: buffer)
      guard buffer.frameLength > 0, let data = buffer.floatChannelData?[0] else { break }
      for i in 0..<Int(buffer.frameLength) {
        let value = data[i]
        peak = max(peak, abs(value)); energy += Double(value * value); samples += 1
      }
    }
    guard samples > 0 else { throw NSError(domain: "EmptyAudio", code: 1) }
    let rms = Float(sqrt(energy / Double(samples)))
    // At most +6 dB; do not amplify near-silence. Peak ceiling is -1 dBFS.
    let gain: Float = rms > 0.001 ? min(2, min(0.126 / max(rms, 0.001), 0.89 / max(peak, 0.001))) : 1
    reader.framePosition = 0
    let staging = output.deletingLastPathComponent().appendingPathComponent(".derived-" + UUID().uuidString + ".wav")
    defer { try? fm.removeItem(at: staging) }
    do {
      // Canonical PCM WAV avoids unsupported AAC decoder priming in the
      // gateway's strict media validator. The immutable AAC master is untouched.
      func le16(_ value: UInt16) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
      func le32(_ value: UInt32) -> Data { var v = value.littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
      let byteCount = UInt32(samples * 2)
      var header = Data("RIFF".utf8); header.append(le32(36 + byteCount)); header.append(Data("WAVEfmt ".utf8))
      header.append(le32(16)); header.append(le16(1)); header.append(le16(1))
      header.append(le32(UInt32(format.sampleRate))); header.append(le32(UInt32(format.sampleRate) * 2))
      header.append(le16(2)); header.append(le16(16)); header.append(Data("data".utf8)); header.append(le32(byteCount))
      guard fm.createFile(atPath: staging.path, contents: header) else { throw NSError(domain: "AudioWrite", code: 1) }
      let writer = try FileHandle(forWritingTo: staging)
      defer { try? writer.close() }
      try writer.seekToEnd()
      // DC/rumble cleanup at 45 Hz. No silence trimming, no aggressive gating.
      let alpha = Float(exp(-2 * Double.pi * 45 / format.sampleRate))
      var previousInput: Float = 0
      var previousOutput: Float = 0
      while reader.framePosition < reader.length {
        try reader.read(into: buffer)
        guard buffer.frameLength > 0, let data = buffer.floatChannelData?[0] else { break }
        for i in 0..<Int(buffer.frameLength) {
          let x = data[i]
          let filtered = alpha * (previousOutput + x - previousInput)
          previousInput = x; previousOutput = filtered
          data[i] = max(-0.89, min(0.89, filtered * gain))
        }
        var pcm = Data(capacity: Int(buffer.frameLength) * 2)
        for i in 0..<Int(buffer.frameLength) {
          let sample = Int16((data[i] * 32767).rounded())
          pcm.append(le16(UInt16(bitPattern: sample)))
        }
        try writer.write(contentsOf: pcm)
      }
    } // closes PCM file before committing the derivative
    try fm.moveItem(at: staging, to: output)
    return destination
  }
}

// Personal organization channels are independent of recording/auth/billing.
private enum MedCasesOrganizationNative {
  private static let calendar = EKEventStore()
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "medcases/organization_v1", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, reply in
      if call.method == "notificationPermission" {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .authorized: status = "authorized"
          case .provisional: status = "provisional"
          case .ephemeral: status = "ephemeral"
          case .denied: status = "denied"
          case .notDetermined: status = "notDetermined"
          @unknown default: status = "unavailable"
          }
          DispatchQueue.main.async { reply(status) }
        }
        return
      }
      if call.method == "recordingActivity" {
        guard #available(iOS 16.2, *) else { reply(nil); return }
        Task { @MainActor in
          let args = call.arguments as? [String: Any] ?? [:]
          let id = args["id"] as? String ?? ""
          let owner = args["owner"] as? String ?? ""
          let status = args["status"] as? String ?? "ended"
          let seconds = max(0, (args["elapsedMs"] as? Int ?? 0) / 1000)
          let sample = Date(timeIntervalSince1970: (args["sampleTimeMs"] as? Double ?? Date().timeIntervalSince1970 * 1000) / 1000)
          let active = !id.isEmpty && !owner.isEmpty && Auth.auth().currentUser?.uid == owner && (status == "recording" || status == "paused")
          let state = MedCasesRecordingAttributes.ContentState(startedAt: sample.addingTimeInterval(-Double(seconds)), elapsedSeconds: seconds, status: status, isEs: args["isEs"] as? Bool ?? false)
          // A missed heartbeat must not show an indefinitely running microphone.
          let stale = status == "recording" ? Date().addingTimeInterval(90) : nil
          for activity in Activity<MedCasesRecordingAttributes>.activities {
            if !active || activity.attributes.recordingId != id {
              await activity.end(nil, dismissalPolicy: .immediate)
            } else { await activity.update(ActivityContent(state: state, staleDate: stale)) }
          }
          if active && !Activity<MedCasesRecordingAttributes>.activities.contains(where: { $0.attributes.recordingId == id }) && ActivityAuthorizationInfo().areActivitiesEnabled {
            do { _ = try Activity.request(attributes: MedCasesRecordingAttributes(recordingId: id), content: ActivityContent(state: state, staleDate: stale), pushType: nil) }
            catch { reply(FlutterError(code: "RECORDING_ACTIVITY_UNAVAILABLE", message: nil, details: nil)); return }
          }
          reply(nil)
        }
        return
      }
      if call.method == "timer" || call.method == "endTimer" {
        guard #available(iOS 16.2, *) else { reply(FlutterError(code: "LIVE_ACTIVITY_UNSUPPORTED", message: nil, details: nil)); return }
        Task { @MainActor in
          let args = call.arguments as? [String: Any] ?? [:]
          let id = args["timerId"] as? String ?? ""
          let status = args["status"] as? String ?? "finished"
          let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
          let end = (args["targetEndTime"] as? String).flatMap { iso.date(from: $0) } ?? Date()
          let state = MedCasesTimerAttributes.ContentState(end: end, status: status,
            remaining: args["remainingWhenPaused"] as? Int ?? 0, isEs: args["isEs"] as? Bool ?? false)
          for activity in Activity<MedCasesTimerAttributes>.activities {
            if call.method == "endTimer" || status == "finished" || status == "idle" || activity.attributes.timerId != id {
              await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
            } else { await activity.update(ActivityContent(state: state, staleDate: status == "running" ? end : nil)) }
          }
          if call.method == "timer" && (status == "running" || status == "paused") && (end > Date() || status == "paused") &&
            !Activity<MedCasesTimerAttributes>.activities.contains(where: { $0.attributes.timerId == id }) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { reply(FlutterError(code: "LIVE_ACTIVITY_DISABLED", message: nil, details: nil)); return }
            do { _ = try Activity.request(attributes: MedCasesTimerAttributes(timerId: id), content: ActivityContent(state: state, staleDate: status == "running" ? end : nil), pushType: nil) }
            catch { reply(FlutterError(code: "LIVE_ACTIVITY_FAILED", message: nil, details: nil)); return }
          }
          reply(nil)
        }
        return
      }
      guard let args = call.arguments as? [String: Any],
            let owner = args["owner"] as? String, Auth.auth().currentUser?.uid == owner,
            let id = args["id"] as? String else { reply(FlutterError(code: "CALENDAR_OWNER_INVALID", message: nil, details: nil)); return }
      let marker = "medcases://agenda/\(owner)/\(id)"
      guard call.method == "saveCalendar" || call.method == "deleteCalendar" else { reply(FlutterMethodNotImplemented); return }
      let perform: () -> Void = {
        DispatchQueue.main.async {
          guard Auth.auth().currentUser?.uid == owner else { reply(FlutterError(code: "CALENDAR_OWNER_CHANGED", message: nil, details: nil)); return }
          do {
            let existing = (args["nativeId"] as? String).flatMap { calendar.event(withIdentifier: $0) }
            if call.method == "deleteCalendar" {
              if let event = existing, event.url?.absoluteString == marker { try calendar.remove(event, span: .futureEvents) }
              reply(nil); return
            }
            guard let startMs = args["startMs"] as? NSNumber, let endMs = args["endMs"] as? NSNumber,
                  let title = args["title"] as? String else { throw NSError(domain: "Calendar", code: 1) }
            let start = Date(timeIntervalSince1970: startMs.doubleValue / 1000)
            let end = Date(timeIntervalSince1970: endMs.doubleValue / 1000)
            let predicate = calendar.predicateForEvents(withStart: start.addingTimeInterval(-86400), end: end.addingTimeInterval(86400), calendars: nil)
            let recovered = calendar.events(matching: predicate).first(where: { $0.url?.absoluteString == marker })
            let event = existing ?? recovered ?? EKEvent(eventStore: calendar)
            if event.eventIdentifier != nil && event.url?.absoluteString != marker { throw NSError(domain: "Calendar", code: 2) }
            event.title = title; event.notes = args["notes"] as? String; event.startDate = start; event.endDate = end
            event.url = URL(string: marker); event.timeZone = .current
            if event.calendar == nil { event.calendar = calendar.defaultCalendarForNewEvents }
            let recurrence = args["recurrence"] as? String ?? "none"
            let frequency: EKRecurrenceFrequency? = recurrence == "daily" ? .daily : recurrence == "weekly" ? .weekly : recurrence == "monthly" ? .monthly : nil
            event.recurrenceRules = frequency.map { [EKRecurrenceRule(recurrenceWith: $0, interval: 1, end: nil)] }
            try calendar.save(event, span: .futureEvents)
            reply(event.eventIdentifier)
          } catch { reply(FlutterError(code: "CALENDAR_WRITE_FAILED", message: nil, details: nil)) }
        }
      }
      if #available(iOS 17.0, *) {
        calendar.requestFullAccessToEvents { granted, _ in
          if granted { perform() } else { DispatchQueue.main.async { reply(FlutterError(code: "CALENDAR_PERMISSION_DENIED", message: nil, details: nil)) } }
        }
      } else {
        calendar.requestAccess(to: .event) { granted, _ in
          if granted { perform() } else { DispatchQueue.main.async { reply(FlutterError(code: "CALENDAR_PERMISSION_DENIED", message: nil, details: nil)) } }
        }
      }
    }
  }
}
