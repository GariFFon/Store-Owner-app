import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/models.dart';

class UserService {
  // Cache all users to implement pagination
  static List<User>? _cachedUsers;
  static const int _itemsPerPage = 6; // Show 6 users per page

  /// Fetch users from the API with pagination
  /// [page] - Page number to fetch (default: 1)
  static Future<UsersResponse> getUsers({int page = 1}) async {
    try {
      // If we don't have cached users, fetch them all
      if (_cachedUsers == null) {
        final response = await ApiService.get('/users');

        if (response['data'] != null && response['data'] is List) {
          _cachedUsers = (response['data'] as List<dynamic>)
              .map(
                (userJson) => User.fromJson(userJson as Map<String, dynamic>),
              )
              .toList();
        } else {
          throw ApiException('Invalid response format');
        }
      }

      // Return paginated response
      return UsersResponse.paginated(_cachedUsers!, page, _itemsPerPage);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch users: ${e.toString()}');
      }
    }
  }

  /// Get a single user by ID
  static Future<User> getUser(int id) async {
    try {
      final response = await ApiService.get('/users/$id');

      if (response['data'] != null) {
        return User.fromJson(response['data'] as Map<String, dynamic>);
      } else {
        throw ApiException('User not found');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch user: ${e.toString()}');
      }
    }
  }

  /// Create a new user
  static Future<User> createUser({
    required String name,
    required String username,
    required String email,
    String phone = '',
    String website = '',
  }) async {
    try {
      final response = await ApiService.post(
        '/users',
        body: {
          'name': name,
          'username': username,
          'email': email,
          'phone': phone,
          'website': website,
        },
      );

      if (response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        return User(
          id: int.tryParse(data['id']?.toString() ?? '0') ?? 0,
          name: name,
          username: username,
          email: email,
          phone: phone,
          website: website,
        );
      } else {
        throw ApiException('Failed to create user');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to create user: ${e.toString()}');
      }
    }
  }

  /// Update a user
  static Future<User> updateUser({
    required int id,
    required String name,
    required String username,
    required String email,
    String phone = '',
    String website = '',
  }) async {
    try {
      final response = await ApiService.put(
        '/users/$id',
        body: {
          'name': name,
          'username': username,
          'email': email,
          'phone': phone,
          'website': website,
        },
      );

      if (response['data'] != null) {
        return User(
          id: id,
          name: name,
          username: username,
          email: email,
          phone: phone,
          website: website,
        );
      } else {
        throw ApiException('Failed to update user');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to update user: ${e.toString()}');
      }
    }
  }

  /// Delete a user
  static Future<bool> deleteUser(int id) async {
    try {
      final response = await ApiService.delete('/users/$id');
      return response['statusCode'] == 200 || response['statusCode'] == 204;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to delete user: ${e.toString()}');
      }
    }
  }

  /// Clear cached users (useful for refresh)
  static void clearCache() {
    _cachedUsers = null;
  }
}
