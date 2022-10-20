import 'change.dart';
import 'source.dart';

class MapSource<Record> extends Source<Record> {
  late final Map<String, Record> map;

  MapSource([Map<String, Record>? map]) : map = map ?? {};

  @override
  Map<String, Record> initialLoad() {
    return map;
  }

  @override
  Future<Change<Record>?> save(
    String key,
    Record record, {
    bool force = false,
  }) async {
    var existing = map[key];
    if (existing == record) {
      if (!force) {
        return null;
      }
    }
    map[key] = record;
    if (existing == null) {
      return Added(key, record);
    }
    return Updated(key, record);
  }

  @override
  Future<Change<Record>?> remove(String key) async {
    var existing = map[key];
    if (existing == null) {
      return null;
    }
    map.remove(key);
    return Removed(key, existing);
  }

  @override
  String toString() {
    return 'MapSource($map)';
  }

  @override
  Future<int> delete() async {
    var x = map.length;
    map.clear();
    return x;
  }
}
