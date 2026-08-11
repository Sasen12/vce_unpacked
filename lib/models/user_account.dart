/// A local user profile on this device.
///
/// Accounts are fully offline — stored in SharedPreferences by
/// [AccountRepository], never sent anywhere. Each account carries:
///   - the credentials needed to unlock it on the login screen
///     (`salt` + SHA-256 `passwordHash` — never the plaintext password),
///   - a fun [icon] (emoji) picked at creation, shown on the login chips
///     and in Settings,
///   - the [subjects] the user chose to study, which filter the dataset
///     inside HomeScreen.
class UserAccount {
  final String username;
  final String passwordHash;
  final String salt;
  final String icon;
  final List<String> subjects;

  const UserAccount({
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.icon,
    required this.subjects,
  });

  UserAccount copyWith({List<String>? subjects}) {
    return UserAccount(
      username: username,
      passwordHash: passwordHash,
      salt: salt,
      icon: icon,
      subjects: subjects ?? this.subjects,
    );
  }

  /// Inputs: `json` — one decoded account object from the SharedPreferences
  /// accounts blob. Outputs: a parsed [UserAccount].
  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      icon: json['icon'] as String,
      subjects: (json['subjects'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'passwordHash': passwordHash,
      'salt': salt,
      'icon': icon,
      'subjects': subjects,
    };
  }
}
