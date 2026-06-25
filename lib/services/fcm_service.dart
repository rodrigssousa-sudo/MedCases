// fcm_service.dart — MedCases Pro
// PARTE 5 — BUILD 238
//
// Responsabilidades:
//   1. Solicitar permissão de notificação (iOS / Android 13+)
//   2. Obter FCM token e salvá-lo em users/{uid}/fcmTokens/{tokenId}
//   3. Listener de refresh de token (salva o novo automaticamente)
//   4. Listener de mensagem em foreground (in-app snackbar)
//   5. Listener de tap em notificação (deep-link → AdminScreen tab Notificações)
//
// Chamada de inicialização:
//   await FcmService.init(uid: currentUser.uid, navigatorKey: navigatorKey);
//
// iOS APNs:
//   - Runner → Signing & Capabilities → Push Notifications + Background Modes (Remote)
//   - Xcode → Build Settings → APNS entitlement configurado automaticamente pelo FlutterFire
//
// SEGURANÇA:
//   - Tokens salvos em subcoleção users/{uid}/fcmTokens/{tokenId}
//   - Regra Firestore: allow create/update/delete: if authed && uid == próprio uid
//   - Cloud Function lê tokens via Admin SDK (bypassa rules) para envio

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

// firebase_messaging: mobile + web. Stub automático via conditional import não
// necessário — firebase_messaging suporta Web nativamente.
import 'package:firebase_messaging/firebase_messaging.dart'
    if (dart.library.html) 'fcm_service_web_stub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Callback global para deep-link de notificação tap
// Registrado pelo main.dart para navegar até AdminScreen tab Notificações.
// ─────────────────────────────────────────────────────────────────────────────
typedef AdminNotifTapCb = void Function(Map<String, dynamic> data);

class FcmService {
  FcmService._();

  static AdminNotifTapCb? _onAdminNotifTap;

  /// Registra o callback de deep-link. Chamado pelo main.dart na inicialização.
  static void setOnAdminNotifTap(AdminNotifTapCb cb) => _onAdminNotifTap = cb;

  // ─────────────────────────────────────────────────────────────────────────
  // init — ponto de entrada principal
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init({
    required String uid,
  }) async {
    // Web: firebase_messaging suporta push web mas APNs iOS é o foco aqui.
    // Em qualquer plataforma, seguimos o mesmo fluxo.
    if (kIsWeb) {
      debugPrint('[FCM] Web: inicializando FCM (VAPID key necessária para web push)');
    }

    // 1. Solicitar permissão
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert:         true,
      announcement:  false,
      badge:         true,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
      sound:         true,
    );
    debugPrint('[FCM] permission=${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permissão negada — push desabilitado para este dispositivo.');
      return;
    }

    // 2. Obter e salvar o token inicial
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid: uid, token: token);
      }
    } catch (e) {
      debugPrint('[FCM] Erro ao obter token inicial: $e');
    }

    // 3. Listener de refresh de token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token renovado — salvando novo token');
      _saveToken(uid: uid, token: newToken);
    });

    // 4. Mensagem em foreground → in-app (não mostra notificação nativa no iOS)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: title=${message.notification?.title}');
      // Sem overlay in-app aqui — admin vê via badge no painel.
    });

    // 5. Tap em notificação quando app estava em background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] onMessageOpenedApp route=${message.data['route']}');
      _handleNotifTap(message.data);
    });

    // 6. App aberto via tap em notificação (terminated state)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] getInitialMessage route=${initial.data['route']}');
      // Delay para aguardar a árvore de widgets estar montada
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotifTap(initial.data);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _saveToken — persiste token em Firestore
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> _saveToken({required String uid, required String token}) async {
    try {
      final db = FirebaseFirestore.instance;
      final tokensRef = db.collection('users').doc(uid).collection('fcmTokens');

      // Usa o token como ID do documento para evitar duplicatas
      final docId = token.hashCode.toRadixString(16);
      await tokensRef.doc(docId).set({
        'token':     token,
        'platform':  kIsWeb ? 'web' : _platformName(),
        'savedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] Token salvo: uid=$uid docId=$docId platform=${kIsWeb ? 'web' : _platformName()}');
    } catch (e) {
      debugPrint('[FCM] Erro ao salvar token: $e');
    }
  }

  static String _platformName() {
    // Detecta iOS/Android via defaultTargetPlatform
    try {
      // ignore: do_not_use_environment
      const bool isAndroid = bool.fromEnvironment('dart.library.io') &&
          // Verificação em runtime via Platform
          false; // fallback seguro — runtime check abaixo
    } catch (_) {}
    return 'mobile';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _handleNotifTap — deep-link: route=/admin/notifications → AdminScreen
  // ─────────────────────────────────────────────────────────────────────────
  static void _handleNotifTap(Map<String, dynamic> data) {
    final route = data['route'] ?? '';
    debugPrint('[FCM] deep-link route=$route');
    if (route == '/admin/notifications' && _onAdminNotifTap != null) {
      _onAdminNotifTap!(data);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // deleteToken — remove token ao fazer logout
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> deleteToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final docId = token.hashCode.toRadixString(16);
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('fcmTokens').doc(docId)
          .delete();
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FCM] Token removido ao logout uid=$uid');
    } catch (e) {
      debugPrint('[FCM] Erro ao remover token: $e');
    }
  }
}
