import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../fcm_service.dart';
import 'notification_contract.dart';

/// Records ownership after the existing local result save. No clinical text
/// leaves the device: the notice contains only opaque IDs and an event type.
class DurableResultNotification {
  static Future<void> publish({required NotificationEvent event,
    required String resourceId, required String ownerUid}) async {
    try {
      if (FirebaseAuth.instance.currentUser?.uid != ownerUid) return;
      final id=sha256.convert(utf8.encode('$ownerUid:${event.name}:$resourceId')).toString();
      final prefs=await SharedPreferences.getInstance();
      await prefs.setString('notification.resource.$ownerUid.$id',resourceId);
      if(FirebaseAuth.instance.currentUser?.uid != ownerUid)return;
      await FirebaseFunctions.instance.httpsCallable('publishDurableNotice').call({
        'eventType':NotificationContract.wireNames[event.index],'resourceId':id,
        'installationId':await FcmService.installationId()});
    }catch(_){debugPrint('[NOTIFICATIONS] durable_notice_pending');}
  }
}
