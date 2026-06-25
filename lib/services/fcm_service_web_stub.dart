// fcm_service_web_stub.dart — stub condicional para Web
// Exporta os mesmos tipos que firebase_messaging exporta no mobile,
// mas firebase_messaging já suporta Web nativamente via dart:js —
// este stub NÃO é necessário se firebase_messaging estiver no pubspec.
//
// Mantido vazio por segurança de import condicional.
// O import condicional em fcm_service.dart aponta aqui apenas se
// dart.library.html estiver disponível E firebase_messaging não for
// resolvido — na prática firebase_messaging resolve no web também.
export 'package:firebase_messaging/firebase_messaging.dart';
