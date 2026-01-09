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
  bool _isSyncing = false;
  bool _isLoadingObras = false;
  bool _isLoadingPedidos = false;
  bool _isFabExpanded = false;
  List<dynamic> _obras = [];
  List<dynamic> _pedidosObra = [];
  Map<String, dynamic>? _selectedObra;
  Map<String, dynamic>? _selectedPedido;
  String _filterStatus = 'Todas';
  double _updateProgress = 0;
  String _appVersion = '';
  String _buildNumber = '';
  late PageController _pageController;
  late AnimationController _fabAnimationController;

  // Paleta Empresarial
  static const Color primaryNavy = Color(0xFF1E3A8A);
  static const Color secondaryNavy = Color(0xFF0F2557);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color bgGray = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _checkBiometricStatus();
    _loadAppVersion();
    _checkFirstLogin();
    _fetchObras();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
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

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
      _selectedObra = null;
      _selectedPedido = null;
      _pedidosObra = [];
    });
    await _fetchObras();
    setState(() => _isSyncing = false);
    _showMessage('✅ Sincronizado');
  }

  Future<void> _fetchObras() async {
    setState(() => _isLoadingObras = true);
    try {
      final response = await http.get(
        Uri.parse('${widget.authApi.baseUrl}/sys_rohden_medicao/api/obras'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _obras = data['data'] ?? [];
          });
        }
      }
    } catch (e) {
      _showMessage('❌ Erro ao buscar obras');
    } finally {
      setState(() => _isLoadingObras = false);
    }
  }

  Future<void> _fetchPedidos(Map<String, dynamic> obra) async {
    setState(() => _isLoadingPedidos = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.authApi.baseUrl}/sys_rohden_medicao/api/obras/pedidos?ds_obra=${Uri.encodeComponent(obra['DS_OBRA'])}&nm_clifor=${Uri.encodeComponent(obra['NM_CLIFOR'])}',
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pedidosObra = data['data'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Erro ao buscar pedidos: $e');
    } finally {
      setState(() => _isLoadingPedidos = false);
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return textSecondary;
    switch (status.toUpperCase()) {
      case 'ENTREGUE':
      case 'CONCLUIDO':
        return successGreen;
      case 'EM_TRANSITO':
      case 'PENDENTE':
        return warningOrange;
      case 'ATRASADO':
        return errorRed;
      default:
        return primaryNavy;
    }
  }

  String _getStatusLabel(String? status) {
    if (status == null) return 'Novo';
    switch (status.toUpperCase()) {
      case 'ENTREGUE':
        return 'Entregue';
      case 'EM_TRANSITO':
        return 'Em Trânsito';
      case 'PENDENTE':
        return 'Pendente';
      case 'ATRASADO':
        return 'Atrasado';
      case 'CONCLUIDO':
        return 'Concluído';
      default:
        return 'Novo';
    }
  }

  List<dynamic> get _filteredObras {
    if (_filterStatus == 'Todas') return _obras;
    return _obras.where((o) => 
      _getStatusLabel(o['ST_SITUACAO_FRETE']) == _filterStatus
    ).toList();
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb) {
      _showMessage('❌ Atualização não disponível');
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
            _showMessage('✅ Versão atualizada');
          }
        }
      }
    } catch (e) {
      _showMessage('❌ Erro ao verificar');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showUpdateDialog(String newVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.system_update, color: accentGold, size: 20),
            ),
            SizedBox(width: 12),
            Text('Atualização', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Versão $newVersion disponível.\nAtualizar agora?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Depois'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Atualizar'),
          ),
        ],
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
            if (event.status == OtaStatus.DOWNLOADING) {
              _updateProgress = double.tryParse(event.value ?? '0') ?? 0;
            } else if (event.status == OtaStatus.INSTALLING) {
              _isUpdating = false;
              _showMessage('📦 Instalando...');
            }
          });
        },
        onDone: () => setState(() => _isUpdating = false),
        onError: (error) {
          setState(() => _isUpdating = false);
          _showMessage('❌ Erro no download');
        },
      );
    } catch (e) {
      setState(() => _isUpdating = false);
      _showMessage('❌ Erro');
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryNavy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.waving_hand, color: primaryNavy, size: 20),
            ),
            SizedBox(width: 12),
            Text('Bem-vindo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Primeiro acesso detectado.\n\nRecomendamos cadastrar autenticação biométrica.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Agora Não'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2);
              _pageController.jumpToPage(2);
              Future.delayed(Duration(milliseconds: 300), _setupBiometric);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Configurar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      body: Column(
        children: [
          _buildSimpleHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              children: [
                _buildDashboardPage(),
                _buildObrasPage(),
                _buildSettingsPage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCorporateBottomNav(),
      floatingActionButton: _currentIndex == 1 
          ? (_selectedPedido != null ? _buildMedirFAB() : _buildSpeedDialFAB()) 
          : null,
    );
  }

  Widget _buildMedirFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        _showMessage('🚀 Iniciando medição do Pedido ${_selectedPedido!['NR_PEDIDO_VENDA']}');
        // Aqui viria a navegação para a tela de medição real
      },
      backgroundColor: primaryNavy,
      elevation: 4,
      icon: Icon(Icons.straighten, color: Colors.white),
      label: Text(
        'Medir Pedido: ${_selectedPedido!['NR_PEDIDO_VENDA']}',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSimpleHeader() {
    final userName = widget.user['user_name']?.toString() ?? 'Usuário';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryNavy, secondaryNavy],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYS MEDICAO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      userName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_currentIndex <= 1)
                Material(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _isSyncing ? null : _syncData,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSyncing)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          else
                            Icon(Icons.sync, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            _isSyncing ? 'Sync...' : 'Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDialFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabExpanded) ...[
          _buildMiniFAB(
            icon: Icons.photo_camera,
            label: 'Foto',
            color: accentGold,
            onTap: () {
              setState(() => _isFabExpanded = false);
              _showMessage('📷 Câmera em breve');
            },
          ),
          SizedBox(height: 12),
          _buildMiniFAB(
            icon: Icons.note_add,
            label: 'Nota',
            color: warningOrange,
            onTap: () {
              setState(() => _isFabExpanded = false);
              _showMessage('📝 Notas em breve');
            },
          ),
          SizedBox(height: 12),
        ],
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryNavy, secondaryNavy],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryNavy.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _isFabExpanded = !_isFabExpanded);
                if (_isFabExpanded) {
                  _fabAnimationController.forward();
                } else {
                  _fabAnimationController.reverse();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: AnimatedRotation(
                  turns: _isFabExpanded ? 0.125 : 0,
                  duration: Duration(milliseconds: 200),
                  child: Icon(
                    _isFabExpanded ? Icons.close : Icons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFAB({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
        SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorporateBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavButton(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                index: 0,
              ),
              _buildNavButton(
                icon: Icons.apartment_outlined,
                activeIcon: Icons.apartment,
                label: 'Obras',
                index: 1,
              ),
              _buildNavButton(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Config',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? primaryNavy.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? primaryNavy : textSecondary,
              size: 22,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? primaryNavy : textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardPage() {
    return RefreshIndicator(
      onRefresh: _syncData,
      color: primaryNavy,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildMetricCard(
                title: 'Obras',
                value: _obras.length.toString(),
                icon: Icons.apartment,
                color: primaryNavy,
              ),
              _buildMetricCard(
                title: 'Medições',
                value: _obras.where((o) => o['PROXIMA_MEDICAO'] != null).length.toString(),
                icon: Icons.straighten,
                color: accentGold,
              ),
              _buildMetricCard(
                title: 'Pedidos',
                value: _obras.fold(0, (sum, o) => sum + (o['TOTAL_PEDIDOS'] as int? ?? 0)).toString(),
                icon: Icons.inventory_2,
                color: warningOrange,
              ),
              _buildMetricCard(
                title: 'Pendentes',
                value: '0',
                icon: Icons.pending_actions,
                color: successGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObrasPage() {
    return Column(
      children: [
        // Filtros em chips
        Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('Todas'),
              _buildFilterChip('Novo'),
              _buildFilterChip('Em Trânsito'),
              _buildFilterChip('Pendente'),
              _buildFilterChip('Atrasado'),
              _buildFilterChip('Entregue'),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: _syncData,
            color: primaryNavy,
            child: _isLoadingObras && _obras.isEmpty
                ? _buildSkeletonList()
                : _filteredObras.isEmpty
                    ? _buildEmptyState()
                    : _buildObrasList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : textPrimary,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterStatus = label);
        },
        backgroundColor: cardWhite,
        selectedColor: primaryNavy,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? primaryNavy : borderColor,
          width: 1,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (context, index) => SizedBox(height: 10),
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgGray,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bgGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 150,
                    decoration: BoxDecoration(
                      color: bgGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 100,
                    decoration: BoxDecoration(
                      color: bgGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObrasList() {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _filteredObras.length,
      separatorBuilder: (context, index) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final obra = _filteredObras[index];
        return _buildObraCard(obra);
      },
    );
  }

  Widget _buildObraCard(Map<String, dynamic> obra) {
    final isSelected = _selectedObra?['DS_OBRA'] == obra['DS_OBRA'];
    final statusColor = _getStatusColor(obra['ST_SITUACAO_FRETE']);
    final statusLabel = _getStatusLabel(obra['ST_SITUACAO_FRETE']);

    return Hero(
      tag: 'obra_${obra['DS_OBRA']}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryNavy : borderColor.withOpacity(0.5),
              width: isSelected ? 1.5 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? primaryNavy.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showObraDetailsBottomSheet(obra),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Barra de status colorida no topo
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.apartment, color: statusColor, size: 22),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    obra['DS_OBRA'] ?? 'Sem nome',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              obra['NM_CLIFOR'] ?? 'Cliente não informado',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  '${obra['DS_CIDADE'] ?? ''} - ${obra['CD_ESTADO'] ?? ''}',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                                Spacer(),
                                if (obra['TOTAL_PEDIDOS'] != null && obra['TOTAL_PEDIDOS'] > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryNavy.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.inventory_2, size: 10, color: primaryNavy),
                                        SizedBox(width: 4),
                                        Text(
                                          '${obra['TOTAL_PEDIDOS']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: primaryNavy,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showObraDetailsBottomSheet(Map<String, dynamic> obra) {
    setState(() {
      _selectedObra = obra;
      _selectedPedido = null;
      _pedidosObra = [];
    });
    
    _fetchPedidos(obra);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: bgGray,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryNavy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.apartment, color: primaryNavy, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              obra['DS_OBRA'] ?? 'Detalhes da Obra',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Cliente: ${obra['NM_CLIFOR'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                
                // TabBar
                TabBar(
                  labelColor: primaryNavy,
                  unselectedLabelColor: textSecondary,
                  indicatorColor: primaryNavy,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  tabs: [
                    Tab(text: 'Informações'),
                    Tab(text: 'Pedidos'),
                  ],
                ),
                
                Divider(height: 1),

                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Informações
                      ListView(
                        controller: scrollController,
                        padding: EdgeInsets.all(20),
                        children: [
                          _buildSectionHeader('Dados de Localização'),
                          SizedBox(height: 12),
                          _buildInfoGrid([
                            _buildDetailItem('Cidade', obra['DS_CIDADE']),
                            _buildDetailItem('Estado', obra['CD_ESTADO']),
                            _buildDetailItem('Endereço', 'Ver no mapa...'),
                            _buildDetailItem('Região', 'Sul'),
                          ]),
                          
                          SizedBox(height: 24),
                          _buildSectionHeader('Status e Planejamento'),
                          SizedBox(height: 12),
                          _buildInfoGrid([
                            _buildDetailItem('Situação', _getStatusLabel(obra['ST_SITUACAO_FRETE'])),
                            _buildDetailItem('Próxima Medição', obra['DT_PROXIMA_MEDICAO'] ?? 'Pendente'),
                            _buildDetailItem('Volumes', obra['QT_VOLUMES']?.toString() ?? '0'),
                            _buildDetailItem('Peso Est.', '0 kg'),
                          ]),

                          SizedBox(height: 24),
                          _buildSectionHeader('Contatos'),
                          SizedBox(height: 12),
                          _buildSettingTile(
                            icon: Icons.person_outline,
                            iconColor: primaryNavy,
                            title: obra['NM_CLIFOR'] ?? 'Cliente',
                            subtitle: 'Principal Responsável',
                            trailing: Icon(Icons.phone, color: successGreen, size: 20),
                          ),
                          SizedBox(height: 32),
                        ],
                      ),

                      // Tab 2: Pedidos
                      StatefulBuilder(
                        builder: (context, setBottomSheetState) {
                          return _isLoadingPedidos 
                            ? Center(child: CircularProgressIndicator(color: primaryNavy))
                            : _pedidosObra.isEmpty
                              ? _buildEmptyPedidos()
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: EdgeInsets.all(16),
                                  itemCount: _pedidosObra.length,
                                  separatorBuilder: (context, index) => SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final pedido = _pedidosObra[index];
                                    final isSelected = _selectedPedido?['NR_PEDIDO_VENDA'] == pedido['NR_PEDIDO_VENDA'];
                                    
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: cardWhite,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? primaryNavy : borderColor.withOpacity(0.5),
                                          width: isSelected ? 1.5 : 0.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        onTap: () {
                                          setState(() => _selectedPedido = pedido);
                                          setBottomSheetState(() {});
                                        },
                                        leading: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (isSelected ? primaryNavy : textSecondary).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.inventory_2_outlined, 
                                            color: isSelected ? primaryNavy : textSecondary,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          'Pedido #${pedido['NR_PEDIDO_VENDA']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? primaryNavy : textPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Volumes: ${pedido['QT_VOLUMES'] ?? 0}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        trailing: isSelected 
                                          ? Icon(Icons.check_circle, color: primaryNavy)
                                          : Icon(Icons.arrow_forward_ios, size: 14, color: borderColor),
                                      ),
                                    );
                                  },
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Quando fechar o bottom sheet, limpamos a seleção se necessário ou mantemos
      // para o FAB aparecer na tela de Obras.
    });
  }

  Widget _buildEmptyPedidos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: borderColor),
          SizedBox(height: 16),
          Text(
            'Nenhum pedido encontrado',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: children,
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value ?? 'Não informado',
            style: TextStyle(
              fontSize: 14,
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryNavy.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open,
                size: 56,
                color: primaryNavy.withOpacity(0.3),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Nenhuma obra encontrada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sincronize para carregar',
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncData,
              icon: Icon(Icons.sync, size: 18),
              label: Text('Sincronizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor.withOpacity(0.5), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryNavy, secondaryNavy]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: Colors.white, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['user_name']?.toString() ?? 'Usuário',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID: ${widget.user['user_id']?.toString() ?? '-'}',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 20),
        _buildSectionTitle('Segurança'),
        SizedBox(height: 10),
        
        _buildSettingTile(
          icon: Icons.fingerprint,
          iconColor: _biometricEnabled ? successGreen : textSecondary,
          title: 'Biometria',
          subtitle: _biometricEnabled ? 'Ativa' : 'Desativada',
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
          ),
        ),
        
        if (_biometricEnabled) ...[
          SizedBox(height: 10),
          _buildSettingTile(
            icon: Icons.verified_user,
            iconColor: primaryNavy,
            title: 'Testar',
            subtitle: 'Verificar biometria',
            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
            onTap: _testBiometric,
          ),
        ],
        
        SizedBox(height: 20),
        _buildSectionTitle('Sistema'),
        SizedBox(height: 10),
        
        _buildSettingTile(
          icon: _isUpdating ? Icons.hourglass_empty : Icons.system_update,
          iconColor: accentGold,
          title: 'Atualizar',
          subtitle: _isUpdating ? 'Download: ${_updateProgress.toInt()}%' : 'Verificar',
          trailing: _isUpdating
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(accentGold)),
                )
              : Icon(Icons.arrow_forward_ios, size: 14, color: textSecondary),
          onTap: _isUpdating ? null : _checkForUpdate,
        ),
        
        if (_isUpdating && _updateProgress > 0) ...[
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _updateProgress / 100,
              backgroundColor: borderColor,
              valueColor: AlwaysStoppedAnimation(accentGold),
              minHeight: 4,
            ),
          ),
        ],
        
        SizedBox(height: 20),
        _buildSectionTitle('Informações'),
        SizedBox(height: 10),
        
        _buildSettingTile(
          icon: Icons.info_outline,
          iconColor: primaryNavy,
          title: 'Versão',
          subtitle: 'v$_appVersion',
        ),
        
        SizedBox(height: 24),
        
        ElevatedButton.icon(
          onPressed: _logout,
          icon: Icon(Icons.logout, size: 18),
          label: Text('Sair'),
          style: ElevatedButton.styleFrom(
            backgroundColor: errorRed,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingTile({
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 0.5),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: textSecondary),
        ),
        trailing: trailing,
      ),
    );
  }

  Future<void> _setupBiometric() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        _showMessage('❌ Não disponível');
        return;
      }

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _showMessage('❌ Configure no Android');
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Configurar biometria',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
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
        _showMessage('✅ Configurada');
      }
    } catch (e) {
      _showMessage('❌ Erro');
    }
  }

  Future<void> _disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = widget.user['user_id']?.toString() ?? '';
    
    await prefs.setBool('biometric_enabled_$userId', false);
    await prefs.remove('biometric_user_hash_$userId');
    await prefs.remove('biometric_user_data_$userId');
    
    setState(() => _biometricEnabled = false);
    _showMessage('Desativada');
  }

  Future<void> _testBiometric() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Testar',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (didAuthenticate) {
        _showMessage('✅ Sucesso');
      }
    } catch (e) {
      _showMessage('❌ Erro');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sair', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Confirmar saída?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.authApi.logout();
      } finally {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginPage(authApi: widget.authApi)),
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
        content: Text(message, style: TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(12),
        duration: Duration(seconds: 2),
      ),
    );
  }
}