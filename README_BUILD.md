# 📱 SYS Rohden Medição - Build do APK

## 🚀 Como Gerar o APK

### 📋 Pré-requisitos
- **Flutter SDK** instalado e configurado
- **Android SDK** configurado
- **PowerShell** (Windows)

### ⚡ Execução Rápida

1. **Abra o PowerShell** na pasta do projeto Flutter:
   ```powershell
   cd SYS_ROHDEN_MEDICAO
   ```

2. **Execute o script:**
   ```powershell
   .\build_apk.ps1
   ```

3. **Aguarde o processo** (pode levar alguns minutos)

4. **APK será gerado e movido automaticamente** para:
   ```
   SYS_ROHDEN\SETORES_MODULOS\GESTAO_DE_OBRAS\SYS_ROHDEN_MEDICAO\
   ```

## 🔄 O que o Script Faz

### 1. **Incrementa a Versão Automaticamente**
- Lê a versão atual do `pubspec.yaml`
- Incrementa o build number (+1)
- Atualiza o arquivo automaticamente

### 2. **Executa o Build Flutter**
- `flutter clean` - Limpa cache
- `flutter pub get` - Baixa dependências  
- `flutter build apk --release` - Gera APK

### 3. **Move o APK para o Backend**
- Copia o APK gerado para a pasta do sistema
- Renomeia com a versão: `sys_rohden_medicao_v1.0.0+2.apk`
- Salva informações em `version_info.json`

## 📊 Versionamento

### Formato: `MAJOR.MINOR.PATCH+BUILD`
- **1.0.0+1** - Primeira versão
- **1.0.0+2** - Segunda build (correções)
- **1.0.0+3** - Terceira build
- **1.1.0+4** - Nova funcionalidade (manual)

### Incremento Automático
O script incrementa apenas o **BUILD NUMBER** automaticamente.
Para mudanças de versão maior, edite manualmente o `pubspec.yaml`.

## 📁 Estrutura Após Build

```
SYS_ROHDEN_MEDICAO/
├── build_apk.ps1                    # Script de build
├── pubspec.yaml                     # Versão atualizada
└── build/app/outputs/flutter-apk/
    └── app-release.apk              # APK original

SYS_ROHDEN/SETORES_MODULOS/GESTAO_DE_OBRAS/SYS_ROHDEN_MEDICAO/
├── sys_rohden_medicao_v1.0.0+2.apk # APK com versão
├── version_info.json               # Informações da build
└── templates/
    └── sys_rohden_medicao.html     # Página de download
```

## 🌐 Página de Download

Após gerar o APK, os usuários podem baixar em:
```
http://localhost/sys_rohden_medicao
```

A página mostra:
- ✅ Versão atual disponível
- 📱 Tamanho do arquivo
- 📅 Data da última build
- 🔽 Botão de download

## 🐛 Solução de Problemas

### "Flutter não encontrado"
```powershell
# Verificar instalação
flutter --version

# Adicionar ao PATH se necessário
$env:PATH += ";C:\caminho\para\flutter\bin"
```

### "Android SDK não configurado"
```powershell
# Configurar variáveis de ambiente
$env:ANDROID_HOME = "C:\caminho\para\android-sdk"
$env:PATH += ";$env:ANDROID_HOME\tools;$env:ANDROID_HOME\platform-tools"
```

### "Erro de permissão"
```powershell
# Executar como administrador
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Build muito lenta
- Primeira build sempre demora mais
- Verifique conexão com internet
- Feche outros programas pesados

## 📋 Exemplo de Execução

```powershell
PS C:\...\SYS_ROHDEN_MEDICAO> .\build_apk.ps1

========================================
  SYS ROHDEN MEDICAO - BUILD APK
========================================

[2025-01-08 15:30:15] [INFO] Incrementando versão: 1.0.0+1 -> 1.0.0+2
[2025-01-08 15:30:16] [SUCCESS] Versão atualizada no pubspec.yaml: version: 1.0.0+2
[2025-01-08 15:30:17] [INFO] Executando flutter clean...
[2025-01-08 15:30:19] [INFO] Executando flutter pub get...
[2025-01-08 15:30:25] [INFO] Executando flutter build apk...
[2025-01-08 15:32:10] [SUCCESS] Build do APK concluído com sucesso!
[2025-01-08 15:32:11] [SUCCESS] APK copiado para: C:\...\sys_rohden_medicao_v1.0.0+2.apk
[2025-01-08 15:32:11] [INFO] Tamanho do APK: 25.4 MB
[2025-01-08 15:32:12] [SUCCESS] Informações da versão salvas

========================================
   BUILD CONCLUÍDO COM SUCESSO!
========================================

O APK foi gerado e movido para a pasta do backend!
```

## 🎯 Próximos Passos

Após executar o script:

1. ✅ **APK gerado** com nova versão
2. ✅ **Movido para pasta do sistema**  
3. ✅ **Página web atualizada** automaticamente
4. ✅ **Usuários podem baixar** a nova versão

---

**Desenvolvido por:** Sistema Rohden  
**Data:** Janeiro 2025