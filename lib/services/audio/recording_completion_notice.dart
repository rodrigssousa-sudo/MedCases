import '../canonical_catalog_cipher.dart' show catalogUidHash;

/// Only safe routing metadata; never accepts transcript or clinical content.
class RecordingCompletionNotice {
  RecordingCompletionNotice(
      {required String ownerUid,
      required String sessionId,
      required String language})
      : id = (int.parse(catalogUidHash(sessionId).substring(0, 8), radix: 16) &
                0x3fffffff) |
            0x40000000,
        payload = 'recording:${catalogUidHash(ownerUid)}:$sessionId',
        title = language.startsWith('es')
            ? 'Transcripción concluida'
            : 'Transcrição concluída',
        body = language.startsWith('es')
            ? 'Tu grabación ya fue transcrita y está lista para revisar.'
            : 'Sua gravação já foi transcrita e está pronta para revisar.';
  final int id;
  final String title, body, payload;
}
