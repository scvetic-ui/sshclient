import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' show SigningKey;

class GeneratedKey {
  final String privatePem;
  final String publicLine;
  GeneratedKey(this.privatePem, this.publicLine);
}

class _Writer {
  final _b = BytesBuilder();
  void u32(int v) => _b.add([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]);
  void str(List<int> s) {
    u32(s.length);
    _b.add(s);
  }

  void raw(List<int> s) => _b.add(s);
  int get length => _b.length;
  Uint8List get bytes => _b.toBytes();
}

/// Generates a new Ed25519 key in OpenSSH format (unencrypted, stored in
/// Android secure storage).
GeneratedKey generateEd25519(String comment) {
  final rnd = Random.secure();
  final seed = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
  final sk = SigningKey.fromSeed(seed);
  final pub = Uint8List.fromList(sk.verifyKey);

  final type = utf8.encode('ssh-ed25519');
  final pubBlob = (_Writer()
        ..str(type)
        ..str(pub))
      .bytes;

  final check = rnd.nextInt(1 << 32);
  final priv = _Writer()
    ..u32(check)
    ..u32(check)
    ..str(type)
    ..str(pub)
    ..str([...seed, ...pub])
    ..str(utf8.encode(comment));
  var pad = 1;
  while (priv.length % 8 != 0) {
    priv.raw([pad++]);
  }

  final out = _Writer()
    ..raw(utf8.encode('openssh-key-v1'))
    ..raw([0])
    ..str(utf8.encode('none'))
    ..str(utf8.encode('none'))
    ..str(const [])
    ..u32(1)
    ..str(pubBlob)
    ..str(priv.bytes);

  final b64 = base64.encode(out.bytes);
  final lines = <String>[];
  for (var i = 0; i < b64.length; i += 70) {
    lines.add(b64.substring(i, min(i + 70, b64.length)));
  }
  final pem =
      '-----BEGIN OPENSSH PRIVATE KEY-----\n${lines.join('\n')}\n-----END OPENSSH PRIVATE KEY-----\n';
  return GeneratedKey(pem, 'ssh-ed25519 ${base64.encode(pubBlob)} $comment');
}

/// Parses an imported private key (OpenSSH or PEM RSA/ECDSA/Ed25519) and
/// returns its public key line. Throws if invalid or passphrase is wrong.
({String type, String publicLine}) inspectPrivateKey(String pem, String? passphrase, String comment) {
  final pairs = SSHKeyPair.fromPem(pem, passphrase);
  if (pairs.isEmpty) throw const FormatException('No key found');
  final kp = pairs.first;
  final blob = kp.toPublicKey().encode();
  return (type: kp.type, publicLine: '${kp.type} ${base64.encode(blob)} $comment');
}

bool isEncryptedKey(String pem) {
  try {
    return SSHKeyPair.isEncryptedPem(pem);
  } catch (_) {
    return false;
  }
}
