class Contact {
  final String id;
  final String name;
  final String? username;
  final String? mobile;
  final String? email;

  Contact({
    required this.id,
    required this.name,
    this.username,
    this.mobile,
    this.email,
  });
}
