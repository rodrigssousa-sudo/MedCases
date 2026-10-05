import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One release-scoped activation decision shared by Study and Plantao.
abstract final class GiBatch01PublicationState {
  static const version = 'GI-JIT-2026-10-04-G07-v1.0';
  static const manifestSha256 = 'ac2a944d3f7474d28d2d611062e6862a085ebc5c5fd14f2a835e43914f29a080';
  static const expectedHashes = <String, String>{
    "sindrome_intestino_irritavel": "bae4f38d9ff9f215a4fa8344805fdd2efe719b6516fb0f6128532482d526485d",
    "constipacao_funcional": "4aa0c1458c2c6897e8e5426b2ef818303dd17285cf645a2576d1342cddc66f5e",
    "diarrea_aguda_009": "6e9ace1216c68f5eadbc4e3aa4bc4195b33f41f3f12e1f9ebfd116d73386b802",
    "diarreia_cronica": "a0bdec2ff6124015f0987dc1dc1ecb6c5606cbaf6a4e9f4a8020b6f560bc65f7",
    "infeccao_clostridioides_difficile": "115f00265189ecf8b8076bf3a21cb4f3088dc602b138d77f335a190dbcdfd492",
    "amebiase": "29a5c550eca6992cdd06a3de8c8779e3005e574b3bb7b38a161ba2a147d2cbb1",
    "giardiase": "e5f511a64823bc346d1ce4e300be7c46e3d9747a583f8c88f047e6091e58bd8e",
    "criptosporidiose": "a380500b1892c967ef2d6a00f0d05aad61b0221c68794438ff88875dc903ffdf",
    "ciclosporiase": "9b7e291925f970b255c73e8e8cb4b213d6c7fcbc897a206ff059d07886a90be3",
    "cistoisosporiase": "4a1261917bfff3bb798ff60b13bb30645857741a7ae57624d80f0085b43263ea",
    "balantidiase": "005f4fb9aac26a68e9eaa5bbcb5773294650a4bf2fbf7ffdb4b4a55bff674ece",
    "ascaridiase": "b7302e6c3743c9a6ce38e7f5713f78804cedc2e60515486df46805a766334e7f",
    "enterobiase": "2baf91d275897cdded0413a9d7933c79eafcb36b363f64d1ac62b84d55a0444e",
    "tricuriase": "46b58f016bd83416ae1b33f6cc6869d834a8e68f13a6729fa7c752127512ff4d",
    "ancilostomiase": "3b06d9657ca22e6949c4a25aad517a8967120dd8c2506b691e487d734b1c667d",
    "estrongiloidiase": "e3aae0f8d5e1e1676fd8d245a69940c09d3190cacf7c7b65ff676dd80226a1f5",
    "teniase": "7735e5b61b4953768ee03d108bc94aee535af394eaf7ea1a1b5b1a3d7d47944e",
    "difilobotriase": "d8589df1d549a441abe217ba70a01c706a0242d533485c7582b9e6f08865c5ac",
    "doenca_celiaca": "ac3f3c7c7b0c086a4f9adabaebfe94a1aa50de6cc0843282a907411d9e03918b",
    "sensibilidade_gluten_nao_celiaca": "a77673891e847cc27d100c718a77b19fac1ad3c3260e98a9a5f8d84b1ab5c567",
    "intolerancia_lactose": "37c6a30b307899d15aeaa34fb29ce7bdda2a3591ef714106fb0ec5b1a3ae14eb",
    "ma_absorcao_frutose": "e024173ce42aad35438a84b3b808d6926e3da4db9dba52a25e2338df921210f3",
    "sindrome_ma_absorcao": "2064551e658f183c2a579b2c61a6870472d007a87c3531671e03a5a427c8f31a",
    "supercrescimento_bacteriano_intestino_delgado": "7df0c40c72824ae7ae11ac0622afa388bab32e387bed46a8814801fb65e96dc1",
    "insuficiencia_intestinal": "c973d57f61bd967b150347e2c38eec010668396fb04688427d02211d206a5cac",
    "sindrome_intestino_curto": "a63933a1b5eaea10544679b752f35b6288a3314c2c5f184622582af0a4acf5b5",
    "crohn_complicado_2025": "370257590b07de26557f2f6f8b191ea37239acfb8a3c46d1c1d72318e8b3b3b4",
    "crohn_flare_luminal_2025": "370257590b07de26557f2f6f8b191ea37239acfb8a3c46d1c1d72318e8b3b3b4",
    "colite_ulcerativa_aguda_grave_2025": "b4efa01c491189954287720c872fb7b00038939403fafc72df512d6e1262c083",
    "colite_ulcerativa_flare_2025": "b4efa01c491189954287720c872fb7b00038939403fafc72df512d6e1262c083",
    "doenca_inflamatoria_intestinal_nao_classificada": "a967a5cb5950742f1d05002dbb3333cb2686a6ee7c6dcedde336a7d9ef66ade1",
    "colite_microscopica": "8a8f45e47b389f54208163d9e68ddf12a471fe3a406ffafab7666c802d992b6a",
    "colite_citomegalovirus": "b0d2e36d8e68979f89efcd2c698a35f362682ee6678731bdb774dcf9cccf217e",
    "colite_isquemica": "df633fd7c0b3d17173f094ddafe94bf5ff0b3d86550cb30a32e3d913c4dd4a09",
    "lesao_intestinal_radiacao": "fa7b7e7ac341308afad70048692f4d2a1c66878769499e0eadb2d0e4ba5e3dc7",
    "proctite_infecciosa": "dbd7e53cb84f552ce2e36f6322161577f8832fdba42bd46cbebb03580320115e",
    "diverticulose_2026": "10685145738d0cda8bd14c39cb39c2238533739fe2124b550b59b3c18fbb7e29",
    "diverticulitis_aguda_015": "44e46e4bbcd19deca1dc2fbff3effdb03b2d77588177fd2d690252476a24592d",
    "diverticulitis_complicada_2026": "44e46e4bbcd19deca1dc2fbff3effdb03b2d77588177fd2d690252476a24592d",
    "sangramento_diverticular_agudo": "26204911044a8b1badfbe901c5b6a4c88e4393b650bf7dbea9ff97eb917ceb5d",
    "apendicite_aguda": "82004edbd1141d1f0b87d39b115d6aa4bbd907eeede4ca8149d00af4e882d450",
    "obstrucao_adesiva_delgado_asbo": "7017b02035b7c5ba4de36a84e2757495aec94fcf1950404d5f6c139130c9f489",
    "obstrucao_intestino_delgado": "fda4b3fd9c28c97a0731f310ca140add001f65bd909a18991fa491e26e845f69",
    "obstrucao_colorretal_aguda": "02fe0eaaa1725d863659804a9cc550f6cca67e060957e704d4653b7f0d11e90b",
    "ileo_paralitico": "85ae5ce4b5d5e8a1ca6a4f8dc5872e6948aa7b708a0f4181224074eccddedc90",
    "pseudo_obstrucao_colonica_aguda_ogilvie": "51714ba8f4fd3939ccabdc4c1bff0004c1e11d0825f2a6b518404f1414dc1342",
    "pseudo_obstrucao_intestinal_cronica": "2e538cf7642cbdc025933a9ee8ead5aeb8b789ed288a0c0517a80a354f8a03ff",
    "volvulo_sigmoide": "d19587cf6e38644229002dab03c1d9a3eb7f7caf21fe2c0c19fb0b5b9f67eb90",
    "volvulo_cecal": "082995d40f5c023ac12121218870a5c65ba915127a795f23270eeef8c0ca1662",
    "intussuscepcao_intestinal_adulto": "d8130461793eb23799ba665c6833a06dd81386c9b033da14f7f92a062c8f3bf8",
    "obstrucao_mecanica_alca_fechada_estrangulamento": "98641f25703791639937bce57e6b292c8ffcda34528e10e0e7a944c7333de95b",
    "impactacao_fecal_fecaloma": "6876ad6d25ea544a2a8d5491047cb6f9db9de8008b888ff57dbd0b6ef7c564c7",
    "colite_estercoral_impactacao_fecal": "6876ad6d25ea544a2a8d5491047cb6f9db9de8008b888ff57dbd0b6ef7c564c7",
    "perfuracao_viscera_oca_peritonite_secundaria": "a93e53c5591ba184db72e44ea49ae1ca1644018d21f39a196b8a16a85b4e990e",
  };
  static final active = ValueNotifier<bool>(false);
  static StreamSubscription<User?>? _auth;
  static StreamSubscription<DocumentSnapshot<Map<String,dynamic>>>? _publication;
  static int _generation = 0;
  static void start() {
    if (_auth != null) return;
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      final generation=++_generation;
      _publication?.cancel();
      _publication = null;
      if (user == null) { active.value=false; return; }
      _publication = FirebaseFirestore.instance.doc('app_config/global').snapshots(includeMetadataChanges:true).listen((snapshot) {
        if (generation != _generation) return;
        // First activation must be confirmed by server, never an unverified local write.
        if (snapshot.metadata.hasPendingWrites || snapshot.metadata.isFromCache) return;
        applyManifest(snapshot.data()?['giBatch01Publication']);
      },onError:(Object error) { /* Keep baseline until a verified manifest arrives. */ });
    });
  }
  static bool applyManifest(Object? marker) {
    if (marker is! Map || marker['version'] != version || marker['published'] != true || marker['manifestSha256'] != manifestSha256) { active.value=false; return false; }
    final h=marker['approvedHashes'];
    final modes=marker['modeLocales'];
    if (h is! Map || h.length!=expectedHashes.length || marker['ownerCount']!=expectedHashes.length || modes is! List || modes.length!=4 || !modes.toSet().containsAll(['study_pt','study_es','plantao_pt','plantao_es']) || !expectedHashes.entries.every((e)=>h[e.key]==e.value)) { active.value=false; return false; }
    active.value=true;
    return true;
  }
}
