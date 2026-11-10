enum ConnType { ssh, telnet, local }

enum AuthType { password, key }

enum ForwardType { local, remote }

int defaultPort(ConnType t) => t == ConnType.telnet ? 23 : 22;

String connTypeLabel(ConnType t) => switch (t) {
      ConnType.ssh => 'SSH',
      ConnType.telnet => 'Telnet',
      ConnType.local => 'Local',
    };

class Connection {
  final String id;
  String name;
  ConnType type;
  String host;
  int port;
  String username;
  AuthType auth;
  String? identityId;
  String? startupSnippetId;
  int useCount;

  Connection({
    required this.id,
    this.name = '',
    this.type = ConnType.ssh,
    this.host = '',
    this.port = 22,
    this.username = '',
    this.auth = AuthType.password,
    this.identityId,
    this.startupSnippetId,
    this.useCount = 0,
  });

  String get address {
    if (type == ConnType.local) return 'Local shell';
    final user = username.isEmpty ? '' : '$username@';
    final p = port == defaultPort(type) ? '' : ':$port';
    return '$user$host$p';
  }

  String get label => name.isNotEmpty ? name : address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'host': host,
        'port': port,
        'username': username,
        'auth': auth.name,
        'identityId': identityId,
        'startupSnippetId': startupSnippetId,
        'useCount': useCount,
      };

  factory Connection.fromJson(Map<String, dynamic> j) => Connection(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: ConnType.values.byName(j['type'] as String? ?? 'ssh'),
        host: j['host'] as String? ?? '',
        port: j['port'] as int? ?? 22,
        username: j['username'] as String? ?? '',
        auth: AuthType.values.byName(j['auth'] as String? ?? 'password'),
        identityId: j['identityId'] as String?,
        startupSnippetId: j['startupSnippetId'] as String?,
        useCount: j['useCount'] as int? ?? 0,
      );
}

/// An SSH key. The private key and passphrase live in secure storage.
class Identity {
  final String id;
  String name;
  String keyType;
  String publicKey;

  Identity({required this.id, this.name = '', this.keyType = '', this.publicKey = ''});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'keyType': keyType, 'publicKey': publicKey};

  factory Identity.fromJson(Map<String, dynamic> j) => Identity(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        keyType: j['keyType'] as String? ?? '',
        publicKey: j['publicKey'] as String? ?? '',
      );
}

class Snippet {
  final String id;
  String name;
  String command;

  Snippet({required this.id, this.name = '', this.command = ''});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'command': command};

  factory Snippet.fromJson(Map<String, dynamic> j) => Snippet(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        command: j['command'] as String? ?? '',
      );
}

/// Local (-L): listen on the phone, connect from the server.
/// Remote (-R): listen on the server, connect from the phone.
class PortForward {
  final String id;
  String name;
  String connectionId;
  ForwardType type;
  int bindPort;
  String targetHost;
  int targetPort;

  PortForward({
    required this.id,
    this.name = '',
    this.connectionId = '',
    this.type = ForwardType.local,
    this.bindPort = 8080,
    this.targetHost = 'localhost',
    this.targetPort = 80,
  });

  String get summary {
    final t = type == ForwardType.local ? 'L' : 'R';
    return '$t  $bindPort → $targetHost:$targetPort';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'connectionId': connectionId,
        'type': type.name,
        'bindPort': bindPort,
        'targetHost': targetHost,
        'targetPort': targetPort,
      };

  factory PortForward.fromJson(Map<String, dynamic> j) => PortForward(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        connectionId: j['connectionId'] as String? ?? '',
        type: ForwardType.values.byName(j['type'] as String? ?? 'local'),
        bindPort: j['bindPort'] as int? ?? 8080,
        targetHost: j['targetHost'] as String? ?? 'localhost',
        targetPort: j['targetPort'] as int? ?? 80,
      );
}
