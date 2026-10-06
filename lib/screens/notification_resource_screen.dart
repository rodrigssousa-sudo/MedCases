import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/study/study_library_service.dart';
import '../services/notifications/notification_contract.dart';

class NotificationResourceScreen extends StatefulWidget {
  const NotificationResourceScreen({super.key, required this.destination});
  final NotificationDestination destination;
  @override
  State<NotificationResourceScreen> createState()=>_NotificationResourceScreenState();
}
class _NotificationResourceScreenState extends State<NotificationResourceScreen> {
  late final String? _owner=FirebaseAuth.instance.currentUser?.uid;
  late final Future<String?> _result=_load();
  Future<String?> _load() async {
    if(_owner==null)return null;
    final d=widget.destination;
    final prefs=await SharedPreferences.getInstance();
    final localId=prefs.getString('notification.resource.$_owner.${d.resourceId}');
    if(localId!=null){
      final studies=await StudyLibraryService.loadAll();
      for(final study in studies){
        for(final artifact in study.artifacts){if(artifact.id==localId)return artifact.content;}
      }
      return null;
    }
    if(d.event!=NotificationEvent.transcriptionCompleted)return null;
    final response=await FirebaseFunctions.instance.httpsCallable('getNativeNotificationResource').call({
      'resourceId':d.resourceId,'eventType':NotificationContract.wireNames[d.event.index]});
    final data=response.data;
    return data is Map && data['text'] is String?data['text'] as String:null;
  }
  @override
  Widget build(BuildContext context) {
    final lang=context.watch<AppProvider>().lang;
    return Scaffold(appBar:AppBar(title:Text(NotificationContract.title(widget.destination.event,lang))),
      body:FutureBuilder<String?>(future:_result,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError||snapshot.data==null||FirebaseAuth.instance.currentUser?.uid!=_owner){
          return Center(child:Text(lang=='es'?'Contenido no disponible.':'Conteúdo indisponível.'));
        }
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:MarkdownBody(data:snapshot.data!,selectable:true));
      }));
  }
}
