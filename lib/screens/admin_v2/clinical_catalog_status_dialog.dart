import 'package:flutter/material.dart';
Future<void> showClinicalCatalogStatus(BuildContext context, Future<Map<String,dynamic>> Function(Map<String,dynamic>) read) async {
 try {
  var result=await read({'action':'clinicalCatalog'});
  if(result['contentVersion']==null){
   final drafts=(result['versions'] as List? ?? []).where((v)=>v['status']=='DRAFT').toList();
   if(drafts.isNotEmpty && context.mounted){
    final selected=await showDialog<String>(context:context,builder:(context)=>SimpleDialog(title:const Text('Versões do catálogo remoto'),children:[for(final version in drafts)SimpleDialogOption(onPressed:()=>Navigator.pop(context,version['contentVersion'] as String),child:Text('${version['contentVersion']} · ${version['ownerCount']} patologias · rascunho'))]));
    if(selected==null)return;result=await read({'action':'clinicalCatalog','contentVersion':selected});
   }
  }
  if(!context.mounted)return;
  const labels={'activeVersion':'Versão ativa','contentVersion':'Versão consultada','ownerCount':'Patologias','manifestSha256':'Hash do manifest','status':'Estado','coverage':'Cobertura','hashGate':'Integridade dos hashes','parity':'Paridade PT/ES e Estudo/Plantão'};
  await showDialog<void>(context:context,builder:(context)=>AlertDialog(title:const Text('Catálogo clínico remoto'),content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[for(final entry in labels.entries)Padding(padding:const EdgeInsets.symmetric(vertical:4),child:SelectableText('${entry.value}: ${result[entry.key] ?? "Não disponível"}')),if(result['validationError']!=null)Text('Validação bloqueada: ${result['validationError']}'),const Text('A contagem de owners não comprova a cobertura por modo e idioma.'),
for (final owner in (result['owners'] as List? ?? const [])) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 SelectableText('${owner['ownerId']}'),
 for (final mode in ['study', 'plantao']) for (final locale in ['pt', 'es']) Text('${mode == "study" ? "Estudo" : "Plantão"} ${locale.toUpperCase()}: ${owner["availableModes"]?[mode]?[locale] == true ? "✓" : "—"} · referências: ${owner["referenceState"]?[mode]?[locale] ?? "desconhecido"}'),
])),
const Text('Guias editoriais seguem seu fluxo separado de rascunho e publicação.')]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Fechar'))]));
 }catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Não foi possível consultar o catálogo remoto.')));}
}
