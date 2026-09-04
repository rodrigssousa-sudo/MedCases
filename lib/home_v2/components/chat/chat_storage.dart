// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT STORAGE
// ============================================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatStorage{

  static const _key="home_v2_chat";

  Future<void> save(List<Map<String,dynamic>> messages) async{

    final prefs=await SharedPreferences.getInstance();

    await prefs.setString(

      _key,

      jsonEncode(messages),

    );

  }

  Future<List<Map<String,dynamic>>> load() async{

    final prefs=await SharedPreferences.getInstance();

    final raw=prefs.getString(_key);

    if(raw==null){

      return [];

    }

    try{

      final decoded=jsonDecode(raw);

      return List<Map<String,dynamic>>.from(decoded);

    }catch(_){

      return [];

    }

  }

  Future<void> clear() async{

    final prefs=await SharedPreferences.getInstance();

    await prefs.remove(_key);

  }

}
