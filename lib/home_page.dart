import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'auth_api.dart';
import 'login_page.dart';

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabled = false;
  bool _isUpdating = false;
  double _updateProgress = 0;
  String _appVersion = '';
  String _buildNumber = '';
  late PageController _pageController;
  late AnimationController _fabController;
  late AnimationController _cardController;

  // Paleta de cores suave e moderna
  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color navBar = Color(0xFF2D3748);
  static const Color primaryBlue = Color(0xFF667EEA);
  static const Color primaryPurple = Color(0xFF764BA2);
  static const Color accentTeal = Color(0xFF56CCF2);
  static const Color accentPink = Color(0xFFF093FB);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textGray = Color(0xFF718096);
  static const Color borderLight = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkBiometricStatus();
    _loadAppVersion();
    _checkFirstLogin();
    _fabController.forward();
    _cardController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabController.dispose();
    _cardController.dispose();
    super.dispose();
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
    if (kIsWeb) {
      setState(() => _biometricEnabled = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled_$userId') ?? false;
    });
  }

  Future<void> _checkFirstLogin() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    final hasLoggedBefore = prefs.getBool('has_logged_$userId') ?? false;
    
    if (!hasLoggedBefore) {
      await prefs.setBool('has_logged_$userId', true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeDialog();
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb) {
      _showMessage('❌ Atualização não disponível no navegador');
      return;
    }

    setState(() => _isUpdating = true);
    
    try {
      final response = await http.get(
        Uri.parse('${widget.authApi.baseUrl}/sys_rohden_medicao/api/versions')
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['versions'].isNotEmpty) {
          final latest = data['versions'][0];
          final latestVersion = latest['full_version'].toString();
          
          if (latestVersion != _appVersion) {
            _showUpdateDialog(latestVersion);
          } else {
            _showMessage('✅ Você já está na versão mais recente!');
          }
        }
      } else {
        _showMessage('❌ Não foi possível verificar atualizações');
      }
    } catch (e) {
      _showMessage('❌ Erro ao verificar atualizações');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showUpdateDialog(String newVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [primaryBlue, primaryPurple]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nova Atualização!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versão $newVersion disponível.\nDeseja atualizar agora?',
                style: const TextStyle(color: textGray, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textGray,
                        side: const BorderSide(color: borderLight, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Depois',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [primaryBlue, primaryPurple]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _performUpdate();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Atualizar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performUpdate() async {
    setState(() {
      _isUpdating = true;
      _updateProgress = 0;
    });

    try {
      final downloadUrl = '${widget.authApi.baseUrl}/sys_rohden_medicao/api/download_apk';
      
      OtaUpdate().execute(
        downloadUrl,
        destinationFilename: 'sys_rohden_medicao.apk',
      ).listen(
        (OtaEvent event) {
          setState(() {
            _isUpdating = true;
            if (event.status == OtaStatus.DOWNLOADING) {
              _updateProgress = double.tryParse(event.value ?? '0') ?? 0;
            } else if (event.status == OtaStatus.INSTALLING) {
              _isUpdating = false;
              _showMessage('📦 Instalando atualização...');
            }
          });
        },
        onDone: () {
          setState(() => _isUpdating = false);
        },
        onError: (error) {
          setState(() => _isUpdating = false);
          _showMessage('❌ Erro no download');
        },
      );
    } catch (e) {
      setState(() => _isUpdating = false);
      _showMessage('❌ Erro ao iniciar atualização');
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryBlue, primaryPurple],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.waving_hand, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bem-vindo!',
                style: TextStyle(
                  color: textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Primeiro acesso ao sistema.\n\nRecomendamos cadastrar sua digital para acesso rápido.',
                style: TextStyle(
                  color: textGray,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textGray,
                        side: const BorderSide(color: borderLight, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Depois',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryBlue, primaryPurple],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() => _currentIndex = 1);
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                          Future.delayed(const Duration(milliseconds: 500), _setupBiometric);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cadastrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: [
            _buildObrasPage(),
            _buildConfigPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: navBar,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Obras',
                index: 0,
              ),
              const SizedBox(width: 80),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Config',
                index: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [primaryBlue, primaryPurple])
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Curves.elasticOut,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accentTeal, primaryBlue],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentTeal.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showMessage('📐 Nova medição em breve'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildObrasPage() {
    final userName = widget.user['user_name']?.toString() ?? 'Usuário';
    
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        _showMessage('🔄 Sincronização em desenvolvimento');
      },
      color: primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header simples
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá,',
                  style: TextStyle(
                    color: textGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Quick Actions (sem o card de status offline)
          FadeTransition(
            opacity: _cardController,
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    gradient: const LinearGradient(colors: [accentTeal, Color(0xFF2EC4B6)]),
                    icon: Icons.sync_rounded,
                    title: 'Sincronizar',
                    onTap: () => _showMessage('🔄 Sincronizando...'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    gradient: const LinearGradient(colors: [successGreen, Color(0xFF66BB6A)]),
                    icon: Icons.add_circle_outline,
                    title: 'Nova Medição',
                    onTap: () => _showMessage('📐 Em breve'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Minhas Obras',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderLight),
                ),
                child: const Icon(Icons.search_rounded, color: primaryBlue, size: 20),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          FadeTransition(
            opacity: _cardController,
            child: _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required Gradient gradient,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue.withOpacity(0.1), primaryPurple.withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 50,
              color: primaryBlue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nenhuma obra encontrada',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sincronize para carregar suas obras',
            style: TextStyle(
              fontSize: 12,
              color: textGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [primaryBlue, primaryPurple]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showMessage('🔄 Sincronizando...'),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Sincronizar Agora',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header Config
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Configurações',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textDark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        
        FadeTransition(
          opacity: _cardController,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, primaryPurple],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, size: 46, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.user['user_name']?.toString() ?? 'Usuário',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.user['user_id']?.toString() ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 26),
        
        const Text(
          'Segurança',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: -0.3,
          ),
        ),
        
        const SizedBox(height: 12),
        
        _buildSettingCard(
          icon: _biometricEnabled ? Icons.fingerprint : Icons.fingerprint_outlined,
          iconColor: _biometricEnabled ? successGreen : textGray,
          title: 'Login Biométrico',
          subtitle: _biometricEnabled ? 'Ativo' : 'Desativado',
          trailing: Switch(
            value: _biometricEnabled,
            onChanged: (value) {
              if (value) {
                _setupBiometric();
              } else {
                _disableBiometric();
              }
            },
            activeColor: successGreen,
            activeTrackColor: successGreen.withOpacity(0.3),
          ),
        ),
        
        if (_biometricEnabled) ...[
          const SizedBox(height: 12),
          _buildSettingCard(
            icon: Icons.check_circle_outline,
            iconColor: primaryBlue,
            title: 'Testar Biometria',
            subtitle: 'Verificar funcionamento',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGray),
            onTap: _testBiometric,
          ),
        ],
        
        const SizedBox(height: 26),
        
        const Text(
          'Sistema',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: -0.3,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Botão de Atualizar
        _buildSettingCard(
          icon: _isUpdating ? Icons.hourglass_empty : Icons.system_update,
          iconColor: warningOrange,
          title: 'Atualizar Sistema',
          subtitle: _isUpdating 
              ? 'Baixando: ${_updateProgress.toInt()}%' 
              : 'Verificar novas versões',
          trailing: _isUpdating 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(warningOrange),
                  ),
                )
              : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGray),
          onTap: _isUpdating ? null : _checkForUpdate,
        ),
        
        if (_isUpdating && _updateProgress > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _updateProgress / 100,
                backgroundColor: borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(warningOrange),
                minHeight: 6,
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 26),
        
        const Text(
          'Informações',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: -0.3,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Versão',
                  style: TextStyle(
                    fontSize: 13,
                    color: textGray,
                  ),
                ),
              ),
              Text(
                'v$_appVersion',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 26),
        
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF5350), Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF5350).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            label: const Text(
              'Sair do Sistema',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: textDark,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: textGray,
            ),
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Future<void> _setupBiometric() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        _showMessage('❌ Biometria não disponível');
        return;
      }

      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _showMessage('❌ Cadastre digital no Android');
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Cadastre sua digital',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        final userId = widget.user['user_id']?.toString() ?? '';
        final userName = widget.user['user_name']?.toString() ?? '';
        
        final userHash = sha256.convert(utf8.encode('$userId-$userName')).toString();
        
        await prefs.setBool('biometric_enabled_$userId', true);
        await prefs.setString('biometric_user_hash_$userId', userHash);
        await prefs.setString('biometric_user_data_$userId', jsonEncode(widget.user));
        
        setState(() => _biometricEnabled = true);
        _showMessage('✅ Digital cadastrada!');
      }
    } catch (e) {
      _showMessage('❌ Erro: $e');
    }
  }

  Future<void> _disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    
    await prefs.setBool('biometric_enabled_$userId', false);
    await prefs.remove('biometric_user_hash_$userId');
    await prefs.remove('biometric_user_data_$userId');
    
    setState(() => _biometricEnabled = false);
    _showMessage('Digital removida');
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
        _showMessage('✅ Digital reconhecida!');
      }
    } catch (e) {
      _showMessage('❌ Erro: $e');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 30),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sair do Sistema',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deseja realmente sair?',
                style: TextStyle(color: textGray, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textGray,
                        side: const BorderSide(color: borderLight, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Sair',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.authApi.logout();
      } finally {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LoginPage(authApi: widget.authApi),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: navBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
