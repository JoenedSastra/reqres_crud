import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_model.dart';

class UserService {
  UserService({required this.apiKey});

  final String apiKey;

  static const String _baseUrl = 'https://reqres.in/api';

  /// Header standar untuk setiap request
  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
  };

  /// Validasi status code HTTP — lempar Exception jika tidak sesuai
  void _checkStatus(http.Response response, List<int> expected) {
    if (!expected.contains(response.statusCode)) {
      throw Exception(
        'Gagal: HTTP ${response.statusCode}. '
        'Server menjawab: ${response.body}',
      );
    }
  }

  /// Wrapper try-catch untuk semua request HTTP
  /// Menangani: koneksi gagal, format JSON tidak valid
  Future<T> _handleErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on http.ClientException catch (e) {
      // Tidak ada koneksi internet atau gagal terhubung ke server
      throw Exception('Tidak ada koneksi internet: ${e.message}');
    } on FormatException {
      throw Exception('Format respons dari server tidak valid.');
    }
  }

  static final Map<int, Map<String, String>> _namaBagus = {
    1: {
      'first': 'Budi',
      'last': 'Santoso',
      'email': 'budi.santoso@gmail.com',
      'avatar': '',
    },
    2: {
      'first': 'Siti',
      'last': 'Rahmawati',
      'email': 'siti.rahmawati@gmail.com',
      'avatar': '',
    },
    3: {
      'first': 'Ahmad',
      'last': 'Fauzi',
      'email': 'ahmad.fauzi@gmail.com',
      'avatar': '',
    },
    4: {
      'first': 'Dian',
      'last': 'Pratama',
      'email': 'dian.pratama@gmail.com',
      'avatar': '',
    },
    5: {
      'first': 'Reza',
      'last': 'Mahendra',
      'email': 'reza.mahendra@gmail.com',
      'avatar': '',
    },
    6: {
      'first': 'Putri',
      'last': 'Anggraini',
      'email': 'putri.anggraini@gmail.com',
      'avatar': '',
    },
  };

  // ----------------------------------------------------------
  // GET: Ambil daftar pengguna (halaman 1)
  // Endpoint: GET https://reqres.in/api/users?page=1
  // ----------------------------------------------------------
  Future<List<UserModel>> getUsers({int page = 1}) {
    return _handleErrors(() async {
      final response = await http.get(
        Uri.parse('$_baseUrl/users?page=$page'),
        headers: _headers,
      );

      _checkStatus(response, [200]);

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      final List<dynamic> data = body['data'] as List<dynamic>;

      return data.map((item) {
        final user = UserModel.fromJson(item as Map<String, dynamic>);
        final infoBagus = _namaBagus[user.id];
        if (infoBagus != null) {
          return UserModel(
            id: user.id,
            email: infoBagus['email']!,
            firstName: infoBagus['first']!,
            lastName: infoBagus['last']!,
            avatar: infoBagus['avatar'] ?? user.avatar,
          );
        }

        final emailBersih = user.email.contains('@reqres.in')
            ? user.email.replaceAll('@reqres.in', '@gmail.com')
            : (user.email.isEmpty
                  ? '${user.firstName.toLowerCase()}@gmail.com'
                  : user.email);

        return UserModel(
          id: user.id,
          email: emailBersih,
          firstName: user.firstName,
          lastName: user.lastName,
          avatar: user.avatar,
        );
      }).toList();
    });
  }

  // ----------------------------------------------------------
  // POST: Buat pengguna baru
  // Endpoint: POST https://reqres.in/api/users
  // ----------------------------------------------------------
  Future<UserModel> createUser({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    return _handleErrors(() async {
      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'name': '$firstName $lastName'.trim(),
          'job': 'Flutter Developer',
          'avatar': '',
        }),
      );

      _checkStatus(response, [201]);

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      return UserModel(
        id: int.tryParse('${body['id']}') ?? 0,
        email: body['email']?.toString() ?? email,
        firstName: body['first_name']?.toString() ?? firstName,
        lastName: body['last_name']?.toString() ?? lastName,
        avatar: body['avatar']?.toString() ?? '',
      );
    });
  }

  // ----------------------------------------------------------
  // PUT: Perbarui data pengguna berdasarkan id
  // Endpoint: PUT https://reqres.in/api/users/:id
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> updateUser({
    required int id,
    required String firstName,
    required String lastName,
    required String email,
  }) {
    return _handleErrors(() async {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$id'),
        headers: _headers,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'name': '$firstName $lastName'.trim(),
          'job': 'Flutter Developer',
        }),
      );

      _checkStatus(response, [200]);

      return jsonDecode(response.body) as Map<String, dynamic>;
    });
  }

  // ----------------------------------------------------------
  // DELETE: Hapus pengguna berdasarkan id
  // Endpoint: DELETE https://reqres.in/api/users/:id
  // ----------------------------------------------------------
  Future<void> deleteUser(int id) {
    return _handleErrors(() async {
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/$id'),
        headers: _headers,
      );

      _checkStatus(response, [200, 204]);
    });
  }
}
