library proclaim;

import 'dart:async';
import 'dart:collection';

import 'package:rxdart/rxdart.dart';

import 'change.dart';
import 'key.dart';
import 'index.dart';
import 'index_unique.dart';
import 'index_multiple.dart';
import 'source.dart';

export 'change.dart';
export 'key.dart';

export 'index.dart';
export 'index_unique.dart';
export 'index_multiple.dart';

export 'source.dart';
export 'map_source.dart';
export 'hive_source.dart';
export 'utilities/utilities.dart';

const constPrimaryIndex = '_primary';

class Proclaim<PrimaryKey extends Key<Record>, Record extends Object>
    with IterableMixin<Record> {
  final Map<String, Index<Key<Record>, Record>> indices = {};
  final PublishSubject<List<Change<Record>>> _changes = PublishSubject();
  late Source<Record> source;
  late IndexUnique<PrimaryKey, Record> defaultIndex;

  /// Expose the stream of changes that can be subscribed to
  Stream<List<Change<Record>>> get batchedChanges => _changes.stream;

  /// Return each change individually as a stream
  Stream<Change<Record>> get changes => batchedChanges.expand((i) => i);

  /// Return each change individually as a stream (alias for 'changes' stream)
  Stream<Change<Record>> get change => batchedChanges.expand((i) => i);

  /// Return all records in the Proclaim
  Iterable<Record> get records => primaryIndex.values;

  /// Allow to iterate over all the records in the Proclaim
  ///   e.g. `for (row in proclaim) { ... }`
  @override
  Iterator<Record> get iterator => records.iterator;

  /// Return the `primaryIndex` from the set of indices
  IndexUnique<PrimaryKey, Record> get primaryIndex =>
      indices[constPrimaryIndex]! as IndexUnique<PrimaryKey, Record>;

  /// Given a record, return its key as stored in the `primaryIndex`
  String primaryKey(record) => primaryIndex.keyType.getKey(record);

  /// Construct a Proclaim from a `source`. Requires `getKey` as a function
  /// that maps a Record to a Key, so that the Proclaim can construct a
  /// `primaryIndex`.
  Proclaim(PrimaryKey keyType) {
    defaultIndex = IndexUnique<PrimaryKey, Record>(keyType);
    indices[constPrimaryIndex] = defaultIndex;
  }

  setSource(Source<Record> source) {
    for (var index in indices.values) {
      index.clear();
    }

    this.source = source;
    var records = source.initialLoad();

    records.values.forEach(_addToIndices);

    Iterable<Change<Record>> entries =
        records.entries.map((entry) => Loaded<Record>(entry.key, entry.value));

    _changes.add(entries.toList());
  }

  /// Create a unique index and add all current records to it
  IndexUnique<K, Record> addIndexUnique<K extends Key<Record>>(
      String name, K keyType) {
    _assertNewIndexName(name);
    return indices[name] = IndexUnique<K, Record>(keyType)..addAll(records);
  }

  /// Create a 'multiple' index and add all current records to it
  IndexMultiple<K, Record> addIndexMultiple<K extends Key<Record>>(
      String name, K keyType,
      [Compare? compare]) {
    _assertNewIndexName(name);
    return indices[name] = IndexMultiple<K, Record>(keyType, compare)
      ..addAll(records);
  }

  /// Clear all records in proclaim, including all indices
  Future<int> delete() async {
    primaryIndex.clear();
    for (var index in indices.values) {
      index.clear();
    }
    //indices.clear();
    indices[constPrimaryIndex] = defaultIndex;
    return await source.delete();
  }

  /// Clear all records in proclaim, including all indices
  Future<List<Change>> clear() async => await removeAll(records);

  /// Save a `record`, index it, and broadcast the change
  Future<Change<Record>?> save(Record record, {bool force = false}) async {
    var change = await _saveSilently(record, force: force);
    if (change != null) _changes.add([change]);
    return change;
  }

  /// Remove a `record`, de-index it, and broadcast the change
  Future<Change<Record>?> remove(Record record) async {
    var change = await _removeSilently(record);
    if (change != null) _changes.add([change]);
    return change;
  }

  /// Save all `records`, index them, and broadcast the changes
  Future<List<Change>> saveAll(Iterable<Record> records) async {
    return await _changeAll(records, _saveSilently);
  }

  /// Remove all `records`, de-index them, and broadcast the changes
  Future<List<Change>> removeAll(Iterable<Record> records) async {
    return await _changeAll(records, _removeSilently);
  }

  // Index & save one record without broadcasting any changes
  Future<Change<Record>?> _saveSilently(
    Record record, {
    bool force = false,
  }) async {
    var change = await source.save(primaryKey(record), record, force: force);
    change?.when(
        loaded: (change) {},
        added: (change) {
          _addToIndices(change.record);
        },
        updated: (change) {
          var oldRecord = primaryIndex.getByKeyStr(primaryKey(record))[0];
          _removeFromIndices(oldRecord);
          _addToIndices(change.record);
        },
        removed: (change) {});
    return change;
  }

  // De-index & remove one record without broadcasting any changes
  Future<Change<Record>?> _removeSilently(Record record) async {
    var key = primaryKey(record);
    var change = await source.remove(key);
    if (change != null) _removeFromIndices(change.record);
    return change;
  }

  // Apply a change function to each of the `records`, returning the changes
  Future<List<Change<Record>>> _changeAll(
      Iterable<Record> records, changeFn) async {
    var changes = <Change<Record>>[];
    // must turn iterable into list so that records can be removed by changeFn
    for (var record in records.toList()) {
      var change = await changeFn(record);
      if (change != null) changes.add(change);
    }
    if (changes.isNotEmpty) {
      _changes.add(changes);
    }
    return changes;
  }

  // Add record to all indices, including primary index
  void _addToIndices(Record record) {
    for (var index in indices.values) {
      index.add(record);
    }
  }

  // Remove record from all indices, including primary index
  void _removeFromIndices(Record record) {
    for (var index in indices.values) {
      index.remove(record);
    }
  }

  // Throw an exception if index with `name` already exists
  void _assertNewIndexName(String name) {
    if (indices.containsKey(name)) {
      throw ArgumentError('index $name already exists');
    }
  }

  @override
  String toString() => 'Proclaim($source, '
      'size: ${records.length}, '
      'indices: ${indices.keys.toList().join(",")})';
}
