import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

import 'auth_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authApi,
    required this.user,
  });

  final AuthApi authApi;
  final Map<String, dynamic> user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _isFirstLogin = false;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
    _checkFirstLogin();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
        _buildNumber = '1';
      });
    }
  }

  Future<void> _checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
    });
  }

  Future<void> _checkFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    final hasLoggedBefore = prefs.getBool('has_logged_$userId') ?? false;
    
    if (!hasLoggedBefore) {
      setState(() {
        _isFirstLogin = true;
      });
      // Marcar que já logou pelo menos uma vez
      await prefs.setBool('has_logged_$userId', true);
      
      // Mostrar dialog obrigatório para cadastrar digital
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMandatoryBiometricSetup();
      });
    }
  }

  void _showMandatoryBiometricSetup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configuração Obrigatória'),
        content: const Text(
          'Para maior segurança, é obrigatório cadastrar sua digital na primeira vez que acessa o sistema.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedIndex = 1; // Ir para aba Config
              });
              _setupBiometric();
            },
            child: const Text('Cadastrar Digital'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Medição'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await widget.authApi.logout();
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildConfigTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final userName = widget.user['user_name']?.toString() ?? '';
    final userId = widget.user['user_id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com informações do usuário
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bem-vindo, $userName',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: $userId',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Versão do App',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _appVersion.isNotEmpty ? 'v$_appVersion' : 'v1.0.0',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Build',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _buildNumber.isNotEmpty ? '#$_buildNumber' : '#1',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Seção de funcionalidades
          Text(
            'Funcionalidades',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.api, color: Colors.green),
              ),
              title: const Text('Testar Conexão'),
              subtitle: const Text('Verificar se a API está funcionando'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                try {
                  final me = await widget.authApi.me();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Sessão OK: ${me['user_name']}'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erro na conexão: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.construction, color: Colors.blue),
              ),
              title: const Text('Medições'),
              subtitle: const Text('Gerenciar medições de obras'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚧 Funcionalidade em desenvolvimento'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configurações',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(
                _biometricEnabled ? Icons.fingerprint : Icons.fingerprint_outlined,
                color: _biometricEnabled ? Colors.green : Colors.grey,
              ),
              title: const Text('Login com Digital'),
              subtitle: Text(
                _biometricEnabled 
                  ? 'Digital cadastrada - Login offline habilitado'
                  : 'Cadastre sua digital para login rápido e offline',
              ),
              trailing: Switch(
                value: _biometricEnabled,
                onChanged: (value) {
                  if (value) {
                    _setupBiometric();
                  } else {
                    _disableBiometric();
                  }
                },
              ),
            ),
          ),
          if (_biometricEnabled) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.security, color: Colors.blue),
                title: const Text('Testar Digital'),
                subtitle: const Text('Verificar se sua digital está funcionando'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _testBiometric,
              ),
            ),
          ],
          
          // Informações do App
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informações do App',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Versão:'),
                      Text(
                        _appVersion.isNotEmpty ? 'v$_appVersion' : 'v1.0.0',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Build:'),
                      Text(
                        _buildNumber.isNotEmpty ? '#$_buildNumber' : '#1',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Desenvolvido por:'),
                      Text(
                        'Sistema Rohden',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setupBiometric() async {
    try {
      // Verificar se o dispositivo suporta biometria
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        _showMessage('Biometria não disponível neste dispositivo');
        return;
      }

      // Verificar se há biometrias cadastradas
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _showMessage('Nenhuma digital cadastrada no dispositivo. Cadastre uma digital nas configurações do sistema.');
        return;
      }

      // Autenticar para cadastrar
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Cadastre sua digital para login rápido e seguro',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        // Salvar configuração
        final prefs = await SharedPreferences.getInstance();
        final userId = widget.user['user_id']?.toString() ?? '';
        final userName = widget.user['user_name']?.toString() ?? '';
        
        // Criar hash único para este usuário
        final userHash = sha256.convert(utf8.encode('$userId-$userName')).toString();
        
        await prefs.setBool('biometric_enabled_$userId', true);
        await prefs.setString('biometric_user_hash_$userId', userHash);
        await prefs.setString('biometric_user_data_$userId', jsonEncode(widget.user));
        
        setState(() {
          _biometricEnabled = true;
        });
        
        _showMessage('Digital cadastrada com sucesso! Agora você pode fazer login offline.');
      }
    } catch (e) {
      _showMessage('Erro ao configurar digital: $e');
    }
  }

  Future<void> _disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    
    await prefs.setBool('biometric_enabled_$userId', false);
    await prefs.remove('biometric_user_hash_$userId');
    await prefs.remove('biometric_user_data_$userId');
    
    setState(() {
      _biometricEnabled = false;
    });
    
    _showMessage('Login com digital desabilitado');
  }

  Future<void> _testBiometric() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Teste sua digital',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        _showMessage('Digital reconhecida com sucesso!');
      }
    } catch (e) {
      _showMessage('Erro ao testar digital: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
