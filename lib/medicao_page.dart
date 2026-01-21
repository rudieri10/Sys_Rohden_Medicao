import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// ============================================================================
// MODELS (inline no mesmo arquivo)
// ============================================================================

class ItemMedicao {
  String id;
  String codigoProduto;
  String descricaoProduto;
  double quantidade;
  String unidade;
  String? observacao;

  ItemMedicao({
    required this.id,
    required this.codigoProduto,
    required this.descricaoProduto,
    required this.quantidade,
    required this.unidade,
    this.observacao,
  });
}

// ============================================================================
// PÁGINA PRINCIPAL
// ============================================================================

class MedicaoPage extends StatefulWidget {
  final Map<String, dynamic> obra;
  final Map<String, dynamic> pedido;

  const MedicaoPage({
    super.key,
    required this.obra,
    required this.pedido,
  });

  @override
  State<MedicaoPage> createState() => _MedicaoPageState();
}

class _MedicaoPageState extends State<MedicaoPage> {
  // Cores do tema
  static const Color primaryNavy = Color(0xFF1E3A8A);
  static const Color secondaryNavy = Color(0xFF0F2557);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color bgGray = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  // Controllers
  final _observacoesController = TextEditingController();
  
  // Estado
  DateTime _dataMedicao = DateTime.now();
  List<ItemMedicao> _itens = [];
  List<File> _fotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void dispose() {
    _observacoesController.dispose();
    super.dispose();
  }

  // ============================================================================
  // AÇÕES
  // ============================================================================

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataMedicao,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryNavy,
              onPrimary: Colors.white,
              surface: cardWhite,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _dataMedicao) {
      setState(() {
        _dataMedicao = picked;
      });
    }
  }

  void _adicionarItem() {
    _showAddItemDialog();
  }

  void _editarItem(int index) {
    _showAddItemDialog(editingItem: _itens[index], editingIndex: index);
  }

  void _removerItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: errorRed, size: 24),
            SizedBox(width: 12),
            Text('Remover Item', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Deseja realmente remover este item?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _itens.removeAt(index);
              });
              Navigator.pop(context);
              _showMessage('Item removido');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _tirarFoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _fotos.add(File(photo.path));
        });
        _showMessage('Foto adicionada');
      }
    } catch (e) {
      _showMessage('Erro ao tirar foto: $e');
    }
  }

  Future<void> _selecionarDaGaleria() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _fotos.add(File(image.path));
        });
        _showMessage('Foto adicionada');
      }
    } catch (e) {
      _showMessage('Erro ao selecionar foto: $e');
    }
  }

  void _removerFoto(int index) {
    setState(() {
      _fotos.removeAt(index);
    });
    _showMessage('Foto removida');
  }

  void _visualizarFoto(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FotoViewerPage(foto: _fotos[index]),
      ),
    );
  }

  Future<void> _salvarRascunho() async {
    if (!_validarMedicao()) return;
    
    setState(() => _isSaving = true);
    
    await Future.delayed(Duration(seconds: 1)); // Simular salvamento
    
    setState(() => _isSaving = false);
    
    _showMessage('✅ Rascunho salvo');
  }

  Future<void> _finalizarMedicao() async {
    if (!_validarMedicao()) return;
    
    setState(() => _isSaving = true);
    
    await Future.delayed(Duration(seconds: 1)); // Simular salvamento
    
    setState(() => _isSaving = false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: successGreen, size: 28),
            SizedBox(width: 12),
            Text('Sucesso!', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          'Medição finalizada com sucesso!\n\n'
          'Total de itens: ${_itens.length}\n'
          'Total de fotos: ${_fotos.length}',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Fecha dialog
              Navigator.pop(context); // Volta para HomePage
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _validarMedicao() {
    if (_itens.isEmpty) {
      _showMessage('❌ Adicione pelo menos 1 item');
      return false;
    }
    return true;
  }

  // ============================================================================
  // DIALOG ADICIONAR/EDITAR ITEM
  // ============================================================================

  void _showAddItemDialog({ItemMedicao? editingItem, int? editingIndex}) {
    final codigoController = TextEditingController(text: editingItem?.codigoProduto ?? '');
    final descricaoController = TextEditingController(text: editingItem?.descricaoProduto ?? '');
    final quantidadeController = TextEditingController(
      text: editingItem?.quantidade.toString() ?? '',
    );
    final observacaoController = TextEditingController(text: editingItem?.observacao ?? '');
    
    String unidadeSelecionada = editingItem?.unidade ?? 'm';
    
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  editingItem != null ? Icons.edit : Icons.add_box,
                  color: primaryNavy,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Text(
                editingItem != null ? 'Editar Item' : 'Adicionar Item',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Código do Produto',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: codigoController,
                    decoration: InputDecoration(
                      hintText: 'Ex: P001',
                      filled: true,
                      fillColor: bgGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Código obrigatório';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    'Descrição',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: descricaoController,
                    decoration: InputDecoration(
                      hintText: 'Ex: Produto Exemplo',
                      filled: true,
                      fillColor: bgGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Descrição obrigatória';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantidade *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            SizedBox(height: 6),
                            TextFormField(
                              controller: quantidadeController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                filled: true,
                                fillColor: bgGray,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Obrigatório';
                                }
                                final num = double.tryParse(value);
                                if (num == null || num <= 0) {
                                  return 'Inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unidade *',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: bgGray,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: unidadeSelecionada,
                                  isExpanded: true,
                                  items: [
                                    DropdownMenuItem(value: 'm', child: Text('m')),
                                    DropdownMenuItem(value: 'm²', child: Text('m²')),
                                    DropdownMenuItem(value: 'm³', child: Text('m³')),
                                    DropdownMenuItem(value: 'un', child: Text('un')),
                                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                                    DropdownMenuItem(value: 'pç', child: Text('pç')),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      unidadeSelecionada = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    'Observação (opcional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  SizedBox(height: 6),
                  TextFormField(
                    controller: observacaoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Observações sobre o item...',
                      filled: true,
                      fillColor: bgGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                codigoController.dispose();
                descricaoController.dispose();
                quantidadeController.dispose();
                observacaoController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancelar', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final item = ItemMedicao(
                    id: editingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    codigoProduto: codigoController.text,
                    descricaoProduto: descricaoController.text,
                    quantidade: double.parse(quantidadeController.text),
                    unidade: unidadeSelecionada,
                    observacao: observacaoController.text.isEmpty ? null : observacaoController.text,
                  );
                  
                  setState(() {
                    if (editingIndex != null) {
                      _itens[editingIndex] = item;
                      _showMessage('Item atualizado');
                    } else {
                      _itens.add(item);
                      _showMessage('Item adicionado');
                    }
                  });
                  
                  codigoController.dispose();
                  descricaoController.dispose();
                  quantidadeController.dispose();
                  observacaoController.dispose();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(editingItem != null ? 'Salvar' : 'Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _confirmarSaida(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nova Medição',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Pedido #${widget.pedido['NR_PEDIDO_VENDA']}',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: _finalizarMedicao,
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          SizedBox(height: 16),
          _buildDataSection(),
          SizedBox(height: 16),
          _buildItensSection(),
          SizedBox(height: 16),
          _buildFotosSection(),
          SizedBox(height: 16),
          _buildObservacoesSection(),
          SizedBox(height: 16),
          _buildActionButtons(),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryNavy, secondaryNavy],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apartment, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.obra['DS_OBRA'] ?? 'Obra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            widget.obra['NM_CLIFOR'] ?? 'Cliente',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data da Medição',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          SizedBox(height: 8),
          InkWell(
            onTap: _selecionarData,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryNavy, size: 18),
                  SizedBox(width: 12),
                  Text(
                    DateFormat('dd/MM/yyyy').format(_dataMedicao),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItensSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Itens da Medição',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                '${_itens.length} ${_itens.length == 1 ? 'item' : 'itens'}',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _adicionarItem,
            icon: Icon(Icons.add, size: 18),
            label: Text('Adicionar Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_itens.isNotEmpty) ...[
            SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _itens.length,
              separatorBuilder: (context, index) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _itens[index];
                return Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgGray,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.codigoProduto} - ${item.descricaoProduto}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Qtd: ${item.quantidade} ${item.unidade}',
                                  style: TextStyle(fontSize: 12, color: textSecondary),
                                ),
                                if (item.observacao != null) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    'Obs: ${item.observacao}',
                                    style: TextStyle(fontSize: 11, color: textSecondary, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 18, color: primaryNavy),
                            onPressed: () => _editarItem(index),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 18, color: errorRed),
                            onPressed: () => _removerItem(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFotosSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fotos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text(
                '${_fotos.length} ${_fotos.length == 1 ? 'foto' : 'fotos'}',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _tirarFoto,
                  icon: Icon(Icons.camera_alt, size: 18),
                  label: Text('Câmera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selecionarDaGaleria,
                  icon: Icon(Icons.photo_library, size: 18),
                  label: Text('Galeria'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryNavy,
                    side: BorderSide(color: primaryNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (_fotos.isNotEmpty) ...[
            SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _fotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _visualizarFoto(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: FileImage(_fotos[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removerFoto(index),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: errorRed,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservacoesSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observações Gerais',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          SizedBox(height: 8),
          TextFormField(
            controller: _observacoesController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Observações sobre a medição...',
              filled: true,
              fillColor: bgGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _salvarRascunho,
          icon: Icon(Icons.save_outlined, size: 18),
          label: Text('Salvar como Rascunho'),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryNavy,
            side: BorderSide(color: primaryNavy),
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _finalizarMedicao,
          icon: Icon(Icons.check_circle, size: 18),
          label: Text('Finalizar Medição'),
          style: ElevatedButton.styleFrom(
            backgroundColor: successGreen,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _confirmarSaida() {
    if (_itens.isEmpty && _fotos.isEmpty && _observacoesController.text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sair sem salvar?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Há alterações não salvas. Deseja sair mesmo assim?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
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

// ============================================================================
// TELA DE VISUALIZAÇÃO DE FOTO
// ============================================================================

class _FotoViewerPage extends StatelessWidget {
  final File foto;

  const _FotoViewerPage({required this.foto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(foto),
        ),
      ),
    );
  }
}