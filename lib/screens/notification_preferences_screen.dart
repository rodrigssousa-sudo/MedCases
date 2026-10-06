import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/fcm_service.dart';
import '../services/notifications/notification_contract.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}
class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> with WidgetsBindingObserver {
  AuthorizationStatus? permission;
  Future<void> _permission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) setState(() => permission = settings.authorizationStatus);
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _permission(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  bool updates=true, marketing=true, ready=false;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); _permission(); }
  Future<void> _load() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString('notification.preferences');
    final data=raw==null ? <String,dynamic>{} : jsonDecode(raw) as Map<String,dynamic>;
    if(mounted)setState((){updates=(data['productUpdates'] as bool?) ?? const NotificationPreferences().productUpdates;marketing=(data['marketingEngagement'] as bool?) ?? const NotificationPreferences().marketingEngagement;ready=true;});
  }
  Future<void> _save() => FcmService.updatePreferences(NotificationPreferences(productUpdates:updates,marketingEngagement:marketing));
  @override
  Widget build(BuildContext context) {
    final es=context.watch<AppProvider>().lang=='es';
    return Scaffold(appBar:AppBar(title:Text(es?'Notificaciones':'Notificações')),
      body:ListView(children:[
        ListTile(title:Text(es?'Resultados y temporizadores':'Resultados e timers'),
          subtitle:Text(permission == AuthorizationStatus.denied ? (es?'Notificaciones bloqueadas en Ajustes.':'Notificações bloqueadas nos Ajustes.') : permission == AuthorizationStatus.authorized ? (es?'Notificaciones permitidas.':'Notificações permitidas.') : permission == AuthorizationStatus.provisional ? (es?'Entrega silenciosa autorizada.':'Entrega silenciosa autorizada.') : (es?'Permiso pendiente.':'Permissão pendente.')),
          trailing:IconButton(icon:const Icon(Icons.notifications_active_outlined),
            tooltip:es?'Permitir notificaciones':'Permitir notificações',onPressed:() async { if (permission == AuthorizationStatus.denied) { await openAppSettings(); } else { await FcmService.requestPermission(); } await _permission(); })),
        SwitchListTile(title:Text(es?'Novedades del producto':'Novidades do produto'),value:updates,
          onChanged:!ready?null:(v){setState(()=>updates=v);_save();}),
        SwitchListTile(title:Text(es?'Recordatorios para volver a MedCases':'Lembretes para voltar ao MedCases'),
          subtitle:Text(es?'Hasta 3 por semana. Sin avisos entre las 21 y las 8.':'Até 3 por semana. Sem avisos entre 21h e 8h.'),value:marketing,
          onChanged:!ready?null:(v){setState(()=>marketing=v);_save();}),
        Padding(padding:const EdgeInsets.all(16),child:Text(es?
          'Desactivar estas opciones no desactiva resultados, transcripciones ni temporizadores.':
          'Desativar estas opções não desativa resultados, transcrições ou timers.')),
      ]));
  }
}
