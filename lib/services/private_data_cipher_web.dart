import 'package:firebase_auth/firebase_auth.dart';
import 'canonical_catalog_cipher.dart';
import 'canonical_catalog_cipher_web.dart';

CanonicalCatalogCipher createPrivateDataCipher() => WebCanonicalCatalogCipher(
    currentUid: () => FirebaseAuth.instance.currentUser?.uid,
    authorized: () => FirebaseAuth.instance.currentUser != null,
    databaseName: 'medcases.private.keys.v1');
