# ============================================================================
# TRIVY - SCAN COMPLET PROJET321
# ============================================================================

param(
    [switch]$SkipBuild = $false
)

Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║         TRIVY - SCAN PROJET321 (TaskManager)             ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue

# Vérifier les prérequis
Write-Host "`n🔍 Vérification des prérequis..." -ForegroundColor Yellow

$trivyInstalled = Get-Command trivy -ErrorAction SilentlyContinue
if (-not $trivyInstalled) {
    Write-Host "❌ Trivy n'est pas installé" -ForegroundColor Red
    Write-Host "   Installez-le avec: choco install trivy" -ForegroundColor Yellow
    exit 1
}

$dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerInstalled) {
    Write-Host "❌ Docker n'est pas installé" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Trivy installé" -ForegroundColor Green
Write-Host "✅ Docker installé" -ForegroundColor Green

# Créer le dossier reports
New-Item -ItemType Directory -Force -Path "reports" | Out-Null

# ============================================================================
# 1. SCAN DES DÉPENDANCES
# ============================================================================
Write-Host "`n[1/5] 📦 Scan des dépendances Maven..." -ForegroundColor Yellow
trivy fs --scanners vuln --severity HIGH,CRITICAL pom.xml --format table --output reports/dependencies.txt
trivy fs --scanners vuln pom.xml --format json --output reports/dependencies.json
Write-Host "   ✓ Rapport: reports/dependencies.txt" -ForegroundColor Green

# ============================================================================
# 2. SCAN DU CODE SOURCE
# ============================================================================
Write-Host "`n[2/5] 🔍 Scan du code source..." -ForegroundColor Yellow
trivy fs --scanners secret,misconfig src --format table --output reports/code-source.txt
trivy fs --scanners secret,misconfig src --format json --output reports/code-source.json
Write-Host "   ✓ Rapport: reports/code-source.txt" -ForegroundColor Green

# ============================================================================
# 3. SCAN DOCKERFILE.DES
# ============================================================================
Write-Host "`n[3/5] 🐳 Scan de Dockerfile.des..." -ForegroundColor Yellow
if (Test-Path "Dockerfile.des") {
    trivy config Dockerfile.des --format table --output reports/dockerfile-des.txt
    trivy config Dockerfile.des --format json --output reports/dockerfile-des.json
    Write-Host "   ✓ Rapport: reports/dockerfile-des.txt" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Dockerfile.des introuvable, skip..." -ForegroundColor Yellow
}

# ============================================================================
# 4. SCAN DOCKERFILE.MULTI
# ============================================================================
Write-Host "`n[4/5] 🐳 Scan de Dockerfile.multi..." -ForegroundColor Yellow
if (Test-Path "Dockerfile.multi") {
    trivy config Dockerfile.multi --format table --output reports/dockerfile-multi.txt
    trivy config Dockerfile.multi --format json --output reports/dockerfile-multi.json
    Write-Host "   ✓ Rapport: reports/dockerfile-multi.txt" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Dockerfile.multi introuvable, skip..." -ForegroundColor Yellow
}

# ============================================================================
# 5. BUILD ET SCAN DES IMAGES
# ============================================================================
if (-not $SkipBuild) {
    Write-Host "`n[5/5] 🏗️  Build des images Docker..." -ForegroundColor Yellow

    # Build Image 1 (Dockerfile.des)
    if (Test-Path "Dockerfile.des") {
        Write-Host "   → Build projet321:des..." -ForegroundColor Cyan
        docker build -f Dockerfile.des -t projet321:des . 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ projet321:des créée" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Erreur build projet321:des" -ForegroundColor Red
        }
    }

    # Build Image 2 (Dockerfile.multi)
    if (Test-Path "Dockerfile.multi") {
        Write-Host "   → Build projet321:multi..." -ForegroundColor Cyan
        docker build -f Dockerfile.multi -t projet321:multi . 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ projet321:multi créée" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Erreur build projet321:multi" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n[5/5] ⏭️  Skip du build (option -SkipBuild)" -ForegroundColor Yellow
}

# Scan des images
Write-Host "`n   🔍 Scan des images Docker..." -ForegroundColor Cyan

# Scan Image 1
$imageDesExists = docker images -q projet321:des 2>&1
if ($imageDesExists) {
    Write-Host "      → Scan projet321:des..." -ForegroundColor Cyan
    trivy image --severity HIGH,CRITICAL projet321:des --format table --output reports/image-des.txt 2>&1 | Out-Null
    trivy image projet321:des --format json --output reports/image-des.json 2>&1 | Out-Null
    Write-Host "         ✓ Rapport: reports/image-des.txt" -ForegroundColor Green
} else {
    Write-Host "      ⚠️  Image projet321:des introuvable, skip..." -ForegroundColor Yellow
}

# Scan Image 2
$imageMultiExists = docker images -q projet321:multi 2>&1
if ($imageMultiExists) {
    Write-Host "      → Scan projet321:multi..." -ForegroundColor Cyan
    trivy image --severity HIGH,CRITICAL projet321:multi --format table --output reports/image-multi.txt 2>&1 | Out-Null
    trivy image projet321:multi --format json --output reports/image-multi.json 2>&1 | Out-Null
    Write-Host "         ✓ Rapport: reports/image-multi.txt" -ForegroundColor Green
} else {
    Write-Host "      ⚠️  Image projet321:multi introuvable, skip..." -ForegroundColor Yellow
}

# ============================================================================
# RÉSUMÉ
# ============================================================================
Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    RÉSUMÉ DU SCAN                         ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Blue

Write-Host "`n📁 Rapports générés dans: reports\" -ForegroundColor Cyan
Get-ChildItem -Path reports -Filter *.txt | ForEach-Object {
    Write-Host "   ├─ $($_.Name)" -ForegroundColor White
}

# Compter les vulnérabilités
$depCritical = 0
$secrets = 0
$imgDesCritical = 0
$imgMultiCritical = 0

if (Test-Path "reports/dependencies.txt") {
    $depCritical = (Select-String -Path "reports/dependencies.txt" -Pattern "CRITICAL" -AllMatches -ErrorAction SilentlyContinue).Matches.Count
}

if (Test-Path "reports/code-source.txt") {
    $secrets = (Select-String -Path "reports/code-source.txt" -Pattern "SECRET" -AllMatches -ErrorAction SilentlyContinue).Matches.Count
}

if (Test-Path "reports/image-des.txt") {
    $imgDesCritical = (Select-String -Path "reports/image-des.txt" -Pattern "CRITICAL" -AllMatches -ErrorAction SilentlyContinue).Matches.Count
}

if (Test-Path "reports/image-multi.txt") {
    $imgMultiCritical = (Select-String -Path "reports/image-multi.txt" -Pattern "CRITICAL" -AllMatches -ErrorAction SilentlyContinue).Matches.Count
}

Write-Host "`n📊 STATISTIQUES:" -ForegroundColor Cyan
Write-Host "   🔴 Dépendances CRITICAL: $depCritical" -ForegroundColor $(if ($depCritical -gt 0) { "Red" } else { "Green" })
Write-Host "   🔑 Secrets trouvés: $secrets" -ForegroundColor $(if ($secrets -gt 0) { "Red" } else { "Green" })
Write-Host "   🖼️  Image des CRITICAL: $imgDesCritical" -ForegroundColor $(if ($imgDesCritical -gt 0) { "Red" } else { "Green" })
Write-Host "   🖼️  Image multi CRITICAL: $imgMultiCritical" -ForegroundColor $(if ($imgMultiCritical -gt 0) { "Red" } else { "Green" })

Write-Host "`n✅ Scan terminé avec succès !" -ForegroundColor Green

# Verdict final
$totalCritical = $depCritical + $imgDesCritical + $imgMultiCritical
if ($totalCritical -gt 0) {
    Write-Host "`n⚠️  ATTENTION: $totalCritical vulnérabilités CRITICAL détectées" -ForegroundColor Yellow
    Write-Host "   → Consulter les rapports dans reports\" -ForegroundColor Yellow
}

if ($secrets -gt 0) {
    Write-Host "`n⚠️  ATTENTION: $secrets secrets détectés dans le code" -ForegroundColor Yellow
    Write-Host "   → Retirer les secrets avant le déploiement" -ForegroundColor Yellow
}
