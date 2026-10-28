import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'services/user_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReqRes CRUD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // Halaman pertama: input API key
      home: const ApiKeyPage(),
    );
  }
}

// ============================================================
// Halaman Input API Key
// (Muncul sekali di awal sebelum masuk ke daftar user)
// ============================================================
class ApiKeyPage extends StatefulWidget {
  const ApiKeyPage({super.key});

  @override
  State<ApiKeyPage> createState() => _ApiKeyPageState();
}

class _ApiKeyPageState extends State<ApiKeyPage> {
  final _keyController = TextEditingController();

  void _lanjutkan() {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key tidak boleh kosong.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => UserListPage(apiKey: key)),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.vpn_key_rounded, size: 72, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                'ReqRes CRUD',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan API Key dari app.reqres.in',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Paste API key di sini...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                onSubmitted: (_) => _lanjutkan(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _lanjutkan,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Masuk'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _keyController.text = 'reqres-free-v1',
                child: const Text('Gunakan key demo gratis'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserListPage extends StatefulWidget {
  const UserListPage({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late final UserService _service = UserService(apiKey: widget.apiKey);

  // State lokal untuk list yang bisa di-update tanpa refetch
  late Future<List<UserModel>> _usersFuture;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _muatUser();
  }

  /// Fetch ulang daftar user dari API
  void _muatUser() {
    setState(() {
      _usersFuture = _service.getUsers().then((list) {
        _users = list;
        return list;
      });
    });
  }

  void _tampilPesan(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _bukaFormTambah() async {
    final user = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => TambahUserPage(service: _service)),
    );

    if (!mounted || user == null) return;

    // Hitung ID berikutnya agar urut dengan data yang sudah ada (1, 2, 3, 4, 5, 6, 7...)
    final nextId = _users.isEmpty
        ? 1
        : (_users.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1);

    final userUrut = UserModel(
      id: nextId,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatar,
    );

    // Tambahkan user baru ke daftar secara berurutan
    setState(() {
      _users = [..._users, userUrut]..sort((a, b) => a.id.compareTo(b.id));
      _usersFuture = Future.value(_users);
    });

    _tampilPesan(
      '✅ Pengguna "${userUrut.fullName}" (ID: $nextId) berhasil dibuat!',
    );
  }

  // ----------------------------------------------------------
  // Dialog Edit User (PUT)
  // ----------------------------------------------------------
  Future<void> _editUser(UserModel user) async {
    final cFirstName = TextEditingController(text: user.firstName);
    final cLastName = TextEditingController(text: user.lastName);
    final cEmail = TextEditingController(text: user.email);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit Pengguna'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: cFirstName,
                    decoration: const InputDecoration(labelText: 'Nama depan'),
                    validator: _wajibIsi,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cLastName,
                    decoration: const InputDecoration(
                      labelText: 'Nama belakang',
                    ),
                    validator: _wajibIsi,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: cEmail,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: _validasiEmail,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => saving = true);
                      try {
                        await _service.updateUser(
                          id: user.id,
                          firstName: cFirstName.text.trim(),
                          lastName: cLastName.text.trim(),
                          email: cEmail.text.trim(),
                        );
                        if (!mounted) return;
                        setState(() {
                          _users = _users.map((u) {
                            if (u.id != user.id) return u;
                            return UserModel(
                              id: user.id,
                              firstName: cFirstName.text.trim(),
                              lastName: cLastName.text.trim(),
                              email: cEmail.text.trim(),
                              avatar: user.avatar,
                            );
                          }).toList();
                          _usersFuture = Future.value(_users);
                        });
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        _tampilPesan('✅ Pengguna berhasil diperbarui.');
                      } catch (e) {
                        setDialog(() => saving = false);
                        if (!mounted) return;
                        _tampilPesan('❌ Gagal memperbarui: $e');
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    cFirstName.dispose();
    cLastName.dispose();
    cEmail.dispose();
  }

  // ----------------------------------------------------------
  // Hapus User (DELETE)
  // ----------------------------------------------------------
  Future<void> _hapusUser(UserModel user) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text(
          'Hapus "${user.fullName}"? Tindakan ini tidak dapat diurungkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    try {
      await _service.deleteUser(user.id);
      if (!mounted) return;
      setState(() {
        _users.removeWhere((u) => u.id == user.id);
        _usersFuture = Future.value(List.from(_users));
      });
      _tampilPesan('🗑️ Pengguna berhasil dihapus.');
    } catch (e) {
      _tampilPesan('❌ Gagal menghapus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReqRes CRUD — Daftar User'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _muatUser,
          ),
        ],
      ),

      body: FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          // ── Loading ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Memuat data pengguna...'),
                ],
              ),
            );
          }

          // ── Error ──
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'Gagal Memuat Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _muatUser,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Data kosong ──
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Belum ada data pengguna.'));
          }

          // ── List data ──
          return RefreshIndicator(
            onRefresh: () async => _muatUser(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(radius: 26),
                    title: Text(
                      user.fullName.isEmpty
                          ? 'User #${user.id}'
                          : user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${user.email}\nID: ${user.id}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') _editUser(user);
                        if (val == 'hapus') _hapusUser(user);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'hapus',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Hapus'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormTambah,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah User'),
      ),
    );
  }
}

class TambahUserPage extends StatefulWidget {
  const TambahUserPage({super.key, required this.service});

  final UserService service;

  @override
  State<TambahUserPage> createState() => _TambahUserPageState();
}

class _TambahUserPageState extends State<TambahUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _cFirstName = TextEditingController();
  final _cLastName = TextEditingController();
  final _cEmail = TextEditingController();

  bool _loading = false;

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = await widget.service.createUser(
        firstName: _cFirstName.text.trim(),
        lastName: _cLastName.text.trim(),
        email: _cEmail.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, user);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _cFirstName.dispose();
    _cLastName.dispose();
    _cEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pengguna Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 72,
                color: Colors.indigo,
              ),
              const SizedBox(height: 24),

              // Nama Depan
              TextFormField(
                controller: _cFirstName,
                decoration: const InputDecoration(
                  labelText: 'Nama Depan',
                  hintText: 'Contoh: Budi',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _wajibIsi,
              ),
              const SizedBox(height: 16),

              // Nama Belakang
              TextFormField(
                controller: _cLastName,
                decoration: const InputDecoration(
                  labelText: 'Nama Belakang',
                  hintText: 'Contoh: Santoso',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _wajibIsi,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _cEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'nama@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validasiEmail,
              ),
              const SizedBox(height: 28),

              // Tombol Simpan
              FilledButton.icon(
                onPressed: _loading ? null : _simpan,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_loading ? 'Menyimpan...' : 'Simpan Pengguna'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Validator: kolom wajib diisi ──
String? _wajibIsi(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Kolom ini wajib diisi.';
  }
  return null;
}

// ── Validator: format email ──
String? _validasiEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email wajib diisi.';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
    return 'Format email tidak valid.';
  }
  return null;
}
