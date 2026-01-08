import 'package:flutter/material.dart';

import 'auth_api.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.authApi,
    required this.user,
  });

  final AuthApi authApi;
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final userName = user['user_name']?.toString() ?? '';
    final userId = user['user_id']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Medição'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await authApi.logout();
              } finally {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário: $userName', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('ID: $userId'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final me = await authApi.me();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sessão OK: ${me['user_name']}')),
                );
              },
              child: const Text('Testar /api/me'),
            ),
          ],
        ),
      ),
    );
  }
}
