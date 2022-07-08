import 'package:proclaim/proclaim.dart';

class User {
  final String name;
  final bool active;
  final String status;
  User(this.name, this.active, this.status);

  @override
  String toString() => 'User($name, $active, $status)';
}

class NameKey extends Key<User> {
  @override
  String getKey(User user) => user.name;
}

String _activeStatusKeyStr(bool active, String status) => '$active:$status';

class ActiveStatusKey extends Key<User> {
  @override
  String getKey(User user) => _activeStatusKeyStr(user.active, user.status);
}

extension ByActiveStatus on IndexMultiple<ActiveStatusKey, User> {
  List<User> getAll(bool active, String status) =>
      getByKeyStr(_activeStatusKeyStr(active, status));
}

class UserProclaim extends Proclaim<NameKey, User> {
  late IndexMultiple<ActiveStatusKey, User> byActiveStatus;

  UserProclaim() : super(NameKey()) {
    byActiveStatus = addIndexMultiple('active-status', ActiveStatusKey());
  }
}

void main() async {
  var source = MapSource<User>();
  var res = UserProclaim()..setSource(source);
  await res.save(User('John', true, 'pending'));
  await res.save(User('Shawna', true, 'complete'));
  await res.save(User('Meili', false, 'complete'));
  await res.save(User('Yetir', true, 'pending'));
  print(res.byActiveStatus.getAll(true, 'pending'));
  // => (User(John, true, pending), User(Yetir, true, pending))
}
