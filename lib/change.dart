import 'package:equatable/equatable.dart';

/// The Change class is an ADT, meaning we're using the Dart type system
/// at compile time to help us check that we're considering all possible
/// kinds of change: Added, Updated, Removed
abstract class Change<Record> with EquatableMixin {
  Object id;
  Record record;

  Change(this.id, this.record);

  T when<T>({
    required T Function(Loaded<Record>) loaded,
    required T Function(Added<Record>) added,
    required T Function(Updated<Record>) updated,
    required T Function(Removed<Record>) removed,
  }) {
    if (this is Loaded) return loaded(this as Loaded<Record>);
    if (this is Added) return added(this as Added<Record>);
    if (this is Updated) return updated(this as Updated<Record>);
    if (this is Removed) return removed(this as Removed<Record>);
    throw Exception('Invalid Change');
  }

  @override
  List<Object> get props => [id];
}

class Added<Record> extends Change<Record> {
  bool didOverrideDefault;
  Added(Object id, Record record, {this.didOverrideDefault = false})
      : super(id, record);

  @override
  String toString() => 'Added($id: $record)';
}

class Updated<Record> extends Change<Record> {
  Updated(Object id, Record record) : super(id, record);

  @override
  String toString() => 'Updated($id: $record)';
}

class Removed<Record> extends Change<Record> {
  Removed(Object id, Record record) : super(id, record);

  @override
  String toString() => 'Removed($id: $record)';
}

class Loaded<Record> extends Change<Record> {
  Loaded(Object id, Record record) : super(id, record);

  @override
  String toString() => 'Loaded($id: $record)';
}
