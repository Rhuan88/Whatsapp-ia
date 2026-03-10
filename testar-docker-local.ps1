# SCRIPT AUTOMATIZADO - TESTAR DOCKER LOCAL
# Execute este script para verificar se consegue rodar Evolution API localmente

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   🐳 TESTANDO DOCKER LOCAL" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. Verificar se Docker está instalado
Write-Host "[1/5] Verificando Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker encontrado: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker não encontrado!" -ForegroundColor Red
    Write-Host "`n📥 Instale Docker Desktop:" -ForegroundColor Yellow
    Write-Host "   https://www.docker.com/products/docker-desktop/`n" -ForegroundColor Cyan
    Write-Host "Ou use Railway/Render (mais fácil):" -ForegroundColor Yellow
    Write-Host "   Veja: GUIA_COMPLETO_EVOLUTION_API.md`n" -ForegroundColor Cyan
    exit
}

# 2. Verificar se Docker está rodando
Write-Host "`n[2/5] Verificando se Docker está rodando..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "✅ Docker está rodando!" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker não está rodando!" -ForegroundColor Red
    Write-Host "`n🔧 Solução:" -ForegroundColor Yellow
    Write-Host "   1. Abra o Docker Desktop" -ForegroundColor White
    Write-Host "   2. Aguarde inicializar" -ForegroundColor White
    Write-Host "   3. Execute este script novamente`n" -ForegroundColor White
    exit
}

# 3. Parar container antigo se existir
Write-Host "`n[3/5] Limpando containers antigos..." -ForegroundColor Yellow
docker stop evolution-api 2>$null | Out-Null
docker rm evolution-api 2>$null | Out-Null
Write-Host "✅ Limpeza concluída" -ForegroundColor Green

# 4. Baixar e iniciar Evolution API
Write-Host "`n[4/5] Baixando e iniciando Evolution API..." -ForegroundColor Yellow
Write-Host "⏳ Isso pode demorar alguns minutos (194 MB)..." -ForegroundColor Cyan

docker run -d `
  --name evolution-api `
  --restart always `
  -p 8080:8080 `
    -e AUTHENTICATION_API_KEY="Pmrhuan2013" `
  -e SERVER_URL="http://localhost:8080" `
  -e WEBSOCKET_ENABLED=true `
    -e CONFIG_SESSION_PHONE_CLIENT="Bot Atendimento" `
  -e DEL_INSTANCE=false `
  -e STORE_MESSAGES=true `
  -e STORE_MESSAGE_UP=true `
  -e STORE_CONTACTS=true `
  -e STORE_CHATS=true `
  atendai/evolution-api:latest

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Container iniciado!" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao iniciar container" -ForegroundColor Red
    exit
}

# 5. Aguardar API inicializar
Write-Host "`n[5/5] Aguardando Evolution API inicializar..." -ForegroundColor Yellow
$tentativas = 0
$maxTentativas = 30

while ($tentativas -lt $maxTentativas) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -Method GET -TimeoutSec 2 -ErrorAction Stop
        Write-Host "✅ Evolution API está online!" -ForegroundColor Green
        break
    } catch {
        $tentativas++
        Write-Host "⏳ Tentativa $tentativas/$maxTentativas..." -ForegroundColor Cyan
        Start-Sleep -Seconds 2
    }
}

if ($tentativas -eq $maxTentativas) {
    Write-Host "❌ Timeout - API não respondeu em 60 segundos" -ForegroundColor Red
    Write-Host "`nVerifique os logs:" -ForegroundColor Yellow
    Write-Host "docker logs evolution-api" -ForegroundColor Cyan
    exit
}

# Testar API
Write-Host "`n🧪 Testando API..." -ForegroundColor Cyan
$headers = @{ "apikey" = "Pmrhuan2013" }

try {
    $instancias = Invoke-RestMethod -Uri "http://localhost:8080/instance/fetchInstances" -Headers $headers
    Write-Host "✅ API funcionando perfeitamente!" -ForegroundColor Green
    Write-Host "`nInstâncias encontradas: $($instancias.Count)" -ForegroundColor Yellow
} catch {
    Write-Host "⚠️ API online mas com erro: $_" -ForegroundColor Yellow
}

# Atualizar .env
Write-Host "`n📝 Atualizando arquivo .env..." -ForegroundColor Cyan
$envPath = "backend\.env"

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
    
    if ($envContent -match 'EVOLUTION_API_URL=.*') {
        $envContent = $envContent -replace 'EVOLUTION_API_URL=.*', 'EVOLUTION_API_URL=http://localhost:8080'
        Set-Content -Path $envPath -Value $envContent -NoNewline
        Write-Host "✅ .env atualizado!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Adicione manualmente ao .env:" -ForegroundColor Yellow
        Write-Host "EVOLUTION_API_URL=http://localhost:8080" -ForegroundColor Cyan
    }
}

# Resumo
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   🎉 EVOLUTION API RODANDO!" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n📋 Informações:" -ForegroundColor Cyan
Write-Host "   URL: http://localhost:8080" -ForegroundColor White
Write-Host "   API Key: Pmrhuan2013" -ForegroundColor White
Write-Host "   Container: evolution-api" -ForegroundColor White

Write-Host "`n🔗 Próximos passos:" -ForegroundColor Cyan
Write-Host "   1. Execute: .\INICIAR.bat" -ForegroundColor White
Write-Host "   2. Execute: .\conectar-whatsapp.ps1" -ForegroundColor White
Write-Host "   3. Escaneie o QR Code" -ForegroundColor White
Write-Host "   4. Envie 'menu' no WhatsApp" -ForegroundColor White

Write-Host "`n🛠️ Comandos úteis:" -ForegroundColor Cyan
Write-Host "   Ver logs:    docker logs evolution-api -f" -ForegroundColor White
Write-Host "   Parar:       docker stop evolution-api" -ForegroundColor White
Write-Host "   Reiniciar:   docker restart evolution-api" -ForegroundColor White
Write-Host "   Remover:     docker stop evolution-api && docker rm evolution-api" -ForegroundColor White

Write-Host "`n========================================`n" -ForegroundColor Green
