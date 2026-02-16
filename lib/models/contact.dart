class Contact {
  final String contactName;
  final String phoneNumber;
  final bool isRegistered;
  final String? userId;
  final String? fullName;
  final String? username;
  final String? profilePictureUrl;
  final bool isOnline;
  final String? bio;

  Contact({
    required this.contactName,
    required this.phoneNumber,
    required this.isRegistered,
    this.userId,
    this.fullName,
    this.username,
    this.profilePictureUrl,
    this.isOnline = false,
    this.bio,
  });

  Map<String, dynamic> toJson() {
    return {
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'isRegistered': isRegistered,
      'userId': userId,
      'fullName': fullName,
      'username': username,
      'profilePictureUrl': profilePictureUrl,
      'isOnline': isOnline,
      'bio': bio,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactName: json['contactName'] ?? 'Unknown',
      phoneNumber: json['phoneNumber'] ?? '',
      isRegistered: json['isRegistered'] ?? false,
      userId: json['userId'],
      fullName: json['fullName'],
      username: json['username'],
      profilePictureUrl: json['profilePictureUrl'],
      isOnline: json['isOnline'] ?? false,
      bio: json['bio'],
    );
  }
}

// Note: તમારા code માં ContactItem પણ use થાય છે
// જે same structure છે
typedef ContactItem = Contact;