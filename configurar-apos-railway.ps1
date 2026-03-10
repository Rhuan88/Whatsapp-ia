# ⚡ SCRIPT - CONFIGURAR APÓS RAILWAY DEPLOY

# IMPORTANTE: Execute este script DEPOIS que Railway gerar a URL!

Write-Host "
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     🚀 CONFIGURAÇÃO PÓS-DEPLOY RAILWAY                  ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
" -ForegroundColor Cyan

# Solicitar URL do Railway
Write-Host "`n📋 Cole aqui a URL que o Railway gerou:" -ForegroundColor Yellow
Write-Host "   (Exemplo: https://evolution-api-production-abc.up.railway.app)`n" -ForegroundColor White
$RAILWAY_URL = Read-Host "URL"

if ([string]::IsNullOrWhiteSpace($RAILWAY_URL)) {
    Write-Host "`n❌ URL não pode estar vazia!" -ForegroundColor Red
    exit
}

# Validar URL
if ($RAILWAY_URL -notmatch '^https?://') {
    Write-Host "`n⚠️ URL deve começar com http:// ou https://" -ForegroundColor Yellow
    Write-Host "Adicionando https:// automaticamente..." -ForegroundColor Cyan
    $RAILWAY_URL = "https://$RAILWAY_URL"
}

$API_KEY = "Pmrhuan2013"

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# 1. Testar Evolution API
Write-Host "`n[1/5] 🧪 Testando Evolution API..." -ForegroundColor Yellow
try {
    $headers = @{ "apikey" = $API_KEY }
    $test = Invoke-RestMethod -Uri "$RAILWAY_URL/instance/fetchInstances" -Headers $headers -TimeoutSec 10
    Write-Host "✅ Evolution API está ONLINE e funcionando!" -ForegroundColor Green
} catch {
    Write-Host "❌ Evolution API não está respondendo ainda." -ForegroundColor Red
    Write-Host "`nPossíveis motivos:" -ForegroundColor Yellow
    Write-Host "  • Deploy ainda não terminou (aguarde 2-3 minutos)" -ForegroundColor White
    Write-Host "  • URL incorreta" -ForegroundColor White
    Write-Host "  • API Key diferente da configurada no Railway`n" -ForegroundColor White
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    
    $continuar = Read-Host "`nTentar mesmo assim? (s/N)"
    if ($continuar -ne 's' -and $continuar -ne 'S') {
        exit
    }
}

# 2. Atualizar .env
Write-Host "`n[2/5] 📝 Atualizando arquivo .env..." -ForegroundColor Yellow
$envPath = "backend\.env"

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
    
    if ($envContent -match 'EVOLUTION_API_URL=.*') {
        $envContent = $envContent -replace 'EVOLUTION_API_URL=.*', "EVOLUTION_API_URL=$RAILWAY_URL"
        Set-Content -Path $envPath -Value $envContent -NoNewline
        Write-Host "✅ .env atualizado com URL do Railway!" -ForegroundColor Green
    } else {
        Add-Content -Path $envPath -Value "`nEVOLUTION_API_URL=$RAILWAY_URL"
        Write-Host "✅ EVOLUTION_API_URL adicionada ao .env!" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ Arquivo .env não encontrado!" -ForegroundColor Yellow
}

# 3. Verificar se backend está rodando
Write-Host "`n[3/5] 🔍 Verificando backend..." -ForegroundColor Yellow
try {
    $backend = Invoke-WebRequest -Uri "http://localhost:3000/health" -Method GET -TimeoutSec 3
    Write-Host "✅ Backend já está rodando!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Backend não está rodando." -ForegroundColor Yellow
    Write-Host "Iniciando backend..." -ForegroundColor Cyan
    
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd backend && node server.js" -WindowStyle Minimized
    Start-Sleep -Seconds 5
    
    try {
        $backend = Invoke-WebRequest -Uri "http://localhost:3000/health" -Method GET -TimeoutSec 3
        Write-Host "✅ Backend iniciado com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Não foi possível iniciar o backend automaticamente." -ForegroundColor Red
        Write-Host "Execute manualmente:" -ForegroundColor Yellow
        Write-Host "  .\INICIAR.bat`n" -ForegroundColor Cyan
    }
}

# 4. Criar instância WhatsApp
Write-Host "`n[4/5] 📱 Criando instância WhatsApp..." -ForegroundColor Yellow

$instanceName = "whatsapp-bm-rs"
$headers = @{
    "apikey" = $API_KEY
    "Content-Type" = "application/json"
}

# Verificar se já existe
try {
    $existing = Invoke-RestMethod -Uri "$RAILWAY_URL/instance/connectionState/$instanceName" -Headers $headers -ErrorAction SilentlyContinue
    Write-Host "⚠️ Já existe uma instância '$instanceName'" -ForegroundColor Yellow
    Write-Host "Estado: $($existing.instance.state)" -ForegroundColor Cyan
} catch {
    # Criar nova instância
    try {
        $createBody = @{
            instanceName = $instanceName
            qrcode = $true
            integration = "WHATSAPP-BAILEYS"
        } | ConvertTo-Json

        $instance = Invoke-RestMethod -Uri "$RAILWAY_URL/instance/create" -Method POST -Headers $headers -Body $createBody
        Write-Host "✅ Instância WhatsApp criada!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro ao criar instância: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. Gerar QR Code
Write-Host "`n[5/5] 📲 Gerando QR Code..." -ForegroundColor Yellow

try {
    $qrUrl = "$RAILWAY_URL/instance/qrcode/$instanceName"
    
    Write-Host "✅ QR Code disponível!" -ForegroundColor Green
    Write-Host "`nAbrindo QR Code no navegador..." -ForegroundColor Cyan
    Start-Process $qrUrl
    
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                          ║" -ForegroundColor Green
    Write-Host "║     📱 ESCANEIE O QR CODE PARA CONECTAR WHATSAPP         ║" -ForegroundColor White
    Write-Host "║                                                          ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host "`n🎯 Passo a passo:" -ForegroundColor Cyan
    Write-Host "  1. Abra WhatsApp no celular" -ForegroundColor White
    Write-Host "  2. Toque em ⋮ (3 pontinhos) → Dispositivos vinculados" -ForegroundColor White
    Write-Host "  3. Toque em 'Vincular dispositivo'" -ForegroundColor White
    Write-Host "  4. Escaneie o QR Code que abriu no navegador`n" -ForegroundColor White
    
    Write-Host "Se o QR não abrir, acesse:" -ForegroundColor Yellow
    Write-Host "  $qrUrl`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "⚠️ Erro ao gerar QR Code: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "`nTente acessar manualmente:" -ForegroundColor Cyan
    Write-Host "  $RAILWAY_URL/instance/qrcode/$instanceName`n" -ForegroundColor White
}

# Aguardar conexão
Write-Host "`n⏳ Aguarde escanear o QR Code..." -ForegroundColor Yellow
Write-Host "Pressione ENTER após conectar o WhatsApp..." -ForegroundColor Cyan
Read-Host

# Verificar conexão
Write-Host "`n🔍 Verificando conexão..." -ForegroundColor Yellow
try {
    $state = Invoke-RestMethod -Uri "$RAILWAY_URL/instance/connectionState/$instanceName" -Headers $headers
    
    if ($state.instance.state -eq 'open') {
        Write-Host "✅ WhatsApp conectado com SUCESSO!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Estado atual: $($state.instance.state)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Não foi possível verificar o estado da conexão" -ForegroundColor Yellow
}

# Configurar Webhook
Write-Host "`n🔗 Configurando webhook..." -ForegroundColor Yellow

$webhookBody = @{
    url = "http://localhost:3000/webhook"
    webhook_by_events = $false
    webhook_base64 = $false
    events = @("MESSAGES_UPSERT", "MESSAGES_UPDATE", "CONNECTION_UPDATE")
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$RAILWAY_URL/webhook/set/$instanceName" -Method POST -Headers $headers -Body $webhookBody | Out-Null
    Write-Host "✅ Webhook configurado!" -ForegroundColor Green
    Write-Host "   URL: http://localhost:3000/webhook" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Configure webhook manualmente depois" -ForegroundColor Yellow
}

# Resumo final
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "`n🎉🎉🎉 CONFIGURAÇÃO CONCLUÍDA! 🎉🎉🎉`n" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

Write-Host "`n📋 Informações do sistema:" -ForegroundColor Cyan
Write-Host "  Evolution API: $RAILWAY_URL" -ForegroundColor White
Write-Host "  API Key: $API_KEY" -ForegroundColor White
Write-Host "  Backend: http://localhost:3000" -ForegroundColor White
Write-Host "  Instância: $instanceName" -ForegroundColor White

Write-Host "`n🧪 TESTE AGORA:" -ForegroundColor Cyan
Write-Host "  Envie para o WhatsApp conectado:" -ForegroundColor White
Write-Host "`n  menu" -ForegroundColor Yellow

Write-Host "`n  Você deve receber:" -ForegroundColor White
Write-Host "  '🚔 SISTEMA BM - BOLETINS E ORDENS DE SERVIÇO'" -ForegroundColor Green

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green
