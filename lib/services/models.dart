/// User model representing individual user data
class User {
  final int id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String website;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.website,
  });

  /// Create User from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      website: json['website'] as String,
    );
  }

  /// Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'website': website,
    };
  }

  /// Get full name (JSONPlaceholder already provides full name)
  String get fullName => name;

  /// Get first name (extract from full name)
  String get firstName => name.split(' ').first;

  /// Get last name (extract from full name)
  String get lastName => name.split(' ').length > 1 ? name.split(' ').last : '';

  /// Generate avatar URL based on user ID
  String get avatar =>
      'https://ui-avatars.com/api/?name=${name.replaceAll(' ', '+')}&background=2196F3&color=fff&size=128';

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email)';
  }
}

/// Support information model
class Support {
  final String url;
  final String text;

  const Support({required this.url, required this.text});

  factory Support.fromJson(Map<String, dynamic> json) {
    return Support(url: json['url'] as String, text: json['text'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'text': text};
  }
}

/// Simple users response for JSONPlaceholder (returns array directly)
class UsersResponse {
  final List<User> data;
  final int total;
  final int totalPages;

  const UsersResponse({
    required this.data,
    required this.total,
    required this.totalPages,
  });

  /// Create from JSONPlaceholder response (direct array)
  factory UsersResponse.fromJsonArray(
    List<dynamic> jsonArray, {
    int itemsPerPage = 10,
  }) {
    final users = jsonArray
        .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
        .toList();

    final total = users.length;
    final totalPages = (total / itemsPerPage).ceil();

    return UsersResponse(data: users, total: total, totalPages: totalPages);
  }

  /// Create paginated response
  factory UsersResponse.paginated(
    List<User> allUsers,
    int page,
    int itemsPerPage,
  ) {
    final startIndex = (page - 1) * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, allUsers.length);
    final paginatedUsers = allUsers.sublist(startIndex, endIndex);

    return UsersResponse(
      data: paginatedUsers,
      total: allUsers.length,
      totalPages: (allUsers.length / itemsPerPage).ceil(),
    );
  }

  @override
  String toString() {
    return 'UsersResponse(total: $total, totalPages: $totalPages, users: ${data.length})';
  }
}
