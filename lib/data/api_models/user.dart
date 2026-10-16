/// Who is signed in, as the app sees it.
///
/// Deliberately not the Firebase `User`: keeping this tiny model at the data
/// layer boundary is what lets the repository and the ViewModels be tested
/// without touching Firebase at all.
class AppUser {
  const AppUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'AppUser($id, $email)';
}
