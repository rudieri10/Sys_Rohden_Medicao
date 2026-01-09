# ========================================
#   SYS ROHDEN MEDICAO - BUILD APK
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYS ROHDEN MEDICAO - BUILD APK" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configurações
$FlutterProjectPath = $PSScriptRoot
$BackendPath = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "SYS_ROHDEN") "SETORES_MODULOS") (Join-Path "GESTAO_DE_OBRAS" "SYS_ROHDEN_MEDICAO")
$ApkFolder = Join-Path $BackendPath "apk"
$PubspecFile = Join-Path $FlutterProjectPath "pubspec.yaml"
$VersionsFile = Join-Path $BackendPath "versions.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

function Get-CurrentVersion {
    try {
        $content = Get-Content $PubspecFile -Raw
        if ($content -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
            $versionName = $matches[1]
            $buildNumber = [int]$matches[2]
            
            # Extrair Major e Minor (ex: 1.0 de 1.0.0)
            if ($versionName -match '(\d+)\.(\d+)\.(\d+)') {
                $major = [int]$matches[1]
                $minor = [int]$matches[2]
                $patch = [int]$matches[3]
                return @($major, $minor, $patch, $buildNumber)
            }
            return @(1, 0, 0, $buildNumber)
        } else {
            Write-Log "Não foi possível encontrar a versão no pubspec.yaml" "ERROR"
            return @(1, 0, 0, 1)
        }
    } catch {
        Write-Log "Erro ao ler versão: $($_.Exception.Message)" "ERROR"
        return @(1, 0, 0, 1)
    }
}

function Update-PubspecVersion {
    param([string]$VersionName, [int]$BuildNumber)
    try {
        $content = Get-Content $PubspecFile -Raw
        $newVersionLine = "version: $VersionName+$BuildNumber"
        $content = $content -replace 'version:\s*\d+\.\d+\.\d+\+\d+', $newVersionLine
        Set-Content $PubspecFile -Value $content -Encoding UTF8
        Write-Log "Versão atualizada no pubspec.yaml: $newVersionLine" "SUCCESS"
        return $true
    } catch {
        Write-Log "Erro ao atualizar pubspec.yaml: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Invoke-FlutterBuild {
    param([string]$VersionName, [int]$BuildNumber)
    try {
        Write-Log "Iniciando build do Flutter..." "INFO"
        
        # Mudar para o diretório do projeto Flutter
        Set-Location $FlutterProjectPath
        
        # Verificar se Flutter está instalado
        try {
            $flutterVersion = flutter --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Flutter não está instalado ou não está no PATH" "ERROR"
                return $false
            }
        } catch {
            Write-Log "Flutter não encontrado. Instale o Flutter e adicione ao PATH" "ERROR"
            return $false
        }
        
        # Executar flutter clean e limpeza manual de cache
        Write-Log "Limpando cache do Flutter e diretórios de build..." "INFO"
        
        if (Test-Path ".dart_tool") { 
            Write-Log "Removendo .dart_tool..." "INFO"
            Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue 
        }
        if (Test-Path "build") { 
            Write-Log "Removendo pasta build..." "INFO"
            Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue 
        }
        
        flutter clean
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Aviso: Erro no flutter clean, continuando mesmo assim..." "WARNING"
        }
        
        # Executar flutter pub get
        Write-Log "Obtendo dependências limpas..." "INFO"
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erro no flutter pub get" "ERROR"
            return $false
        }
        
        # Executar flutter build apk com otimizações de tamanho
        # --split-per-abi: Gera APKs menores por arquitetura
        # --obfuscate --split-debug-info: Reduz tamanho removendo símbolos de debug
        Write-Log "Executando flutter build apk (Otimizado para tamanho)..." "INFO"
        flutter build apk --release `
            --build-name="$VersionName" `
            --build-number="$BuildNumber" `
            --split-per-abi `
            --obfuscate --split-debug-info=build/app/outputs/symbols `
            --tree-shake-icons
            
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Erro no flutter build apk" "ERROR"
            return $false
        }
        
        Write-Log "Build do APK concluído com sucesso!" "SUCCESS"
        return $true
        
    } catch {
        Write-Log "Erro durante o build: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Copy-ApkToBackend {
    param([string]$VersionName, [int]$BuildNumber)
    try {
        # Criar pasta apk se não existir
        if (-not (Test-Path $ApkFolder)) {
            New-Item -ItemType Directory -Path $ApkFolder -Force | Out-Null
            Write-Log "Pasta APK criada: $ApkFolder" "INFO"
        }
        
        # Caminho do APK gerado (com split-per-abi o nome muda)
        # Vamos buscar o armeabi-v7a que é o mais compatível com todos os celulares
        $apkSource = Join-Path (Join-Path (Join-Path (Join-Path $FlutterProjectPath "build") "app") "outputs") (Join-Path "flutter-apk" "app-armeabi-v7a-release.apk")
        
        # Se não encontrar o v7a, tenta o arm64-v8a (celulares mais novos)
        if (-not (Test-Path $apkSource)) {
            $apkSource = Join-Path (Join-Path (Join-Path (Join-Path $FlutterProjectPath "build") "app") "outputs") (Join-Path "flutter-apk" "app-arm64-v8a-release.apk")
        }

        # Se ainda não encontrar, tenta o padrão (caso o split falhe por algum motivo)
        if (-not (Test-Path $apkSource)) {
            $apkSource = Join-Path (Join-Path (Join-Path (Join-Path $FlutterProjectPath "build") "app") "outputs") (Join-Path "flutter-apk" "app-release.apk")
        }
        
        if (-not (Test-Path $apkSource)) {
            Write-Log "APK não encontrado em: $apkSource" "ERROR"
            return $false, $null
        }
        
        # Nome do APK com versão (Simplificado conforme solicitado: v1.0, v1.1)
        if ($VersionName -match '(\d+\.\d+)') {
            $simpleVersion = $matches[1]
            $apkFilename = "sys_rohden_medicao_v$simpleVersion.apk"
        } else {
            $apkFilename = "sys_rohden_medicao_v$VersionName.apk"
        }
        $apkDestination = Join-Path $ApkFolder $apkFilename
        
        # Copiar APK
        Copy-Item $apkSource $apkDestination -Force
        
        # Obter tamanho do arquivo
        $fileSize = (Get-Item $apkDestination).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        
        Write-Log "APK copiado para: $apkDestination" "SUCCESS"
        Write-Log "Tamanho do APK: $fileSizeMB MB" "INFO"
        
        return $true, @{
            filename = $apkFilename
            path = $apkDestination
            size = "$fileSizeMB MB"
            size_bytes = $fileSize
        }
        
    } catch {
        Write-Log "Erro ao copiar APK: $($_.Exception.Message)" "ERROR"
        return $false, $null
    }
}

function Save-VersionInfo {
    param([string]$VersionName, [int]$BuildNumber, $ApkInfo)
    try {
        # Criar nova entrada de versão
        $newVersion = @{
            version = $VersionName
            build_number = $BuildNumber
            full_version = "$VersionName+$BuildNumber"
            build_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            build_date_formatted = (Get-Date).ToString("dd/MM/yyyy 'às' HH:mm")
            apk_info = $ApkInfo
            is_latest = $true
        }
        
        # Ler versões existentes ou criar novo array
        $versions = @()
        if (Test-Path $VersionsFile) {
            try {
                $existingData = Get-Content $VersionsFile -Raw | ConvertFrom-Json
                if ($existingData -is [Array]) {
                    $versions = $existingData
                } else {
                    # Converter versão única para array
                    $versions = @($existingData)
                }
            } catch {
                Write-Log "Erro ao ler versões existentes, criando novo arquivo" "WARNING"
                $versions = @()
            }
        }
        
        # Marcar todas as versões anteriores como não sendo a mais recente
        foreach ($version in $versions) {
            $version.is_latest = $false
        }
        
        # Adicionar nova versão
        $versions += $newVersion
        
        # Ordenar por build_number (mais recente primeiro)
        $versions = $versions | Sort-Object build_number -Descending
        
        # Salvar arquivo (sem BOM)
        $json = $versions | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($VersionsFile, $json, [System.Text.UTF8Encoding]::new($false))
        
        Write-Log "Informações das versões salvas em: $VersionsFile" "SUCCESS"
        Write-Log "Total de versões disponíveis: $($versions.Count)" "INFO"
        return $true
        
    } catch {
        Write-Log "Erro ao salvar informações da versão: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ========================================
# EXECUÇÃO PRINCIPAL
# ========================================

Write-Log "=== INICIANDO BUILD DO APK SYS ROHDEN MEDIÇÃO ===" "INFO"

# Verificar se o projeto Flutter existe
if (-not (Test-Path $PubspecFile)) {
    Write-Log "pubspec.yaml não encontrado em: $PubspecFile" "ERROR"
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Verificar se a pasta do backend existe
if (-not (Test-Path $BackendPath)) {
    Write-Log "Pasta do backend não encontrada em: $BackendPath" "ERROR"
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 1. Obter versão inteligente do Banco de Dados Oracle
Write-Log "Consultando próxima versão no banco de dados..." "INFO"
$ManageVersionPy = Join-Path $BackendPath "manage_version.py"
$VersionJsonRaw = python $ManageVersionPy get
if ($LASTEXITCODE -ne 0) {
    Write-Log "Erro ao consultar versão no banco. Usando fallback do pubspec." "WARNING"
    $currentVersion = Get-CurrentVersion
    $major = $currentVersion[0]
    $minor = $currentVersion[1]
    $patch = $currentVersion[2]
    $buildNumber = $currentVersion[3] + 1
} else {
    $versionData = $VersionJsonRaw | ConvertFrom-Json
    $major = $versionData.major
    $minor = $versionData.minor
    $patch = $versionData.patch
    $buildNumber = $versionData.build
}

$versionName = "$major.$minor.$patch"
$displayVersion = "$major.$minor"
$fullVersion = "$versionName+$buildNumber"

Write-Log "Versão definida pelo banco: $displayVersion (Build: $buildNumber)" "INFO"

# 2. Atualizar pubspec.yaml
if (-not (Update-PubspecVersion $versionName $buildNumber)) {
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 3. Executar build (com limpeza e otimização)
if (-not (Invoke-FlutterBuild $versionName $buildNumber)) {
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 4. Copiar APK para backend
$copyResult = Copy-ApkToBackend $versionName $buildNumber
if (-not $copyResult[0]) {
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

$apkInfo = $copyResult[1]

# 5. Salvar no banco de dados e Versions.json
Write-Log "Salvando nova versão no banco de dados..." "INFO"
python $ManageVersionPy save $major $minor $patch $buildNumber $apkInfo.filename

if (-not (Save-VersionInfo $displayVersion $buildNumber $apkInfo)) {
    Write-Log "Falha ao salvar versions.json, mas o banco foi atualizado." "WARNING"
}

Write-Host ""
Write-Log "=== BUILD CONCLUÍDO COM SUCESSO! ===" "SUCCESS"
Write-Log "Versão: $fullVersion" "INFO"
Write-Log "APK: $($apkInfo.filename)" "INFO"
Write-Log "Tamanho: $($apkInfo.size)" "INFO"
Write-Log "Local: $($apkInfo.path)" "INFO"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   BUILD CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "O APK foi gerado e movido para a pasta do backend!" -ForegroundColor Green
Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")