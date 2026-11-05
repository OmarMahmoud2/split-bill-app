import 'package:split_bill_app/services/admin_user_actions.dart';

/// In-memory [AdminActionBackend]: documents keyed by path.
class FakeAdminBackend implements AdminActionBackend {
  FakeAdminBackend([Map<String, Map<String, dynamic>>? docs])
    : docs = docs ?? {};

  final Map<String, Map<String, dynamic>> docs;
  final List<List<AdminWrite>> commits = [];

  /// When true, any commit containing an adminAudit write is refused like
  /// undeployed rules would.
  bool denyAudit = false;
  int _ids = 0;

  List<Map<String, dynamic>> get audits => [
    for (final e in docs.entries)
      if (e.key.startsWith('adminAudit/')) e.value,
  ];

  @override
  Future<void> commit(List<AdminWrite> writes) async {
    if (denyAudit && writes.any((w) => w.path.startsWith('adminAudit/'))) {
      throw const _Denied();
    }
    commits.add(writes);
    for (final w in writes) {
      switch (w.kind) {
        case AdminWriteKind.delete:
          docs.remove(w.path);
        case AdminWriteKind.update:
          if (!docs.containsKey(w.path)) throw StateError('not-found');
          _apply(w);
        case AdminWriteKind.set:
          if (!w.merge) docs[w.path] = {};
          _apply(w);
      }
    }
  }

  void _apply(AdminWrite w) {
    final doc = docs.putIfAbsent(w.path, () => {});
    w.data.forEach((k, v) {
      if (v == AdminValue.deleteField) {
        doc.remove(k);
      } else {
        doc[k] = v;
      }
    });
  }

  @override
  Future<List<String>> queryPaths(
    String collection,
    String field,
    Object value,
  ) async => [
    for (final e in docs.entries)
      if (e.key.startsWith('$collection/') &&
          e.key.split('/').length == 2 &&
          e.value[field] == value)
        e.key,
  ];

  @override
  Future<List<String>> listCollection(String path) async => [
    for (final k in docs.keys)
      if (k.startsWith('$path/') &&
          k.split('/').length == path.split('/').length + 1)
        k,
  ];

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async => docs[path];

  @override
  String newId(String collection) => 'id${_ids++}';

  @override
  bool isPermissionDenied(Object error) => error is _Denied;
}

class _Denied implements Exception {
  const _Denied();
}
