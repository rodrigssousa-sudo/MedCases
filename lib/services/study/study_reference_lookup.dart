import 'dart:convert';
import 'package:http/http.dart' as http;

/// Bibliographic lookup only. Never sends patient/free-form text or calls an LLM.
/// Unrecognized topics remain pending rather than guessing a citation.
class StudyReferenceLookup {
  static const topics = {
    'ketoacidosis': ['cetoacidosis', 'cetoacidose', 'cetoacidosis diabetica'],
    'nephrotic syndrome': ['nefrotico', 'nefrotica', 'nefrótico', 'nefrótica'],
    'metformin': ['metformina', 'metformin'],
    'myocardial infarction': ['infarto', 'iam', 'infarction'],
    'asthma': ['asma', 'asthma'],
    'sepsis': ['sepse', 'sepsis'],
  };
  static String? topic(String query) {
    final q=query.toLowerCase();
    for(final entry in topics.entries) {
      if(entry.value.any((v)=>RegExp('\\b${RegExp.escape(v)}\\b').hasMatch(q)))return entry.key;
    }
    return null;
  }
  static Future<List<({String title,String url})>> resolve(String query,{http.Client? client}) async {
    final term=topic(query);if(term==null)return const [];
    final owned=client==null;final c=client??http.Client();
    try {
      final uri=Uri.https('www.ebi.ac.uk','/europepmc/webservices/rest/search',{
        'query':'TITLE_ABS:"$term" AND (PUB_TYPE:"review" OR PUB_TYPE:"guideline")',
        'format':'json','pageSize':'4','resultType':'core','sort':'CITED desc'});
      final response=await c.get(uri).timeout(const Duration(seconds:6));
      if(response.statusCode!=200)return const [];
      final data=jsonDecode(response.body) as Map<String,dynamic>;
      final rows=(data['resultList'] as Map?)?['result'] as List? ?? const [];
      return rows.whereType<Map>().where((r)=>r['source']=='MED' &&
        RegExp(r'^\d+$').hasMatch('${r['id']}') && r['title'] is String && (r['title'] as String).isNotEmpty)
        .map((r)=>(title:r['title'] as String,url:'https://pubmed.ncbi.nlm.nih.gov/${r['id']}/')).toList();
    }catch(_){return const [];}finally{if(owned)c.close();}
  }
}
