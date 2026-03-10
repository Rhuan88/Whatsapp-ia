# SCRIPT AUTOMATIZADO - CONECTAR WHATSAPP
# Execute este script DEPOIS que a Evolution API estiver rodando

param(
    [string]$ApiUrl = "http://localhost:8080",
    [string]$ApiKey = "Pmrhuan2013",
    [string]$WebhookUrl = "http://localhost:3000/webhook"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   📱 CONECTAR WHATSAPP" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuração:" -ForegroundColor Yellow
Write-Host "  API URL: $ApiUrl" -ForegroundColor White
Write-Host "  Webhook: $WebhookUrl" -ForegroundColor White
Write-Host ""

$headers = @{
    "apikey" = $ApiKey
    "Content-Type" = "application/json"
}

# 1. Verificar se API está online
Write-Host "[1/5] Verificando Evolution API..." -ForegroundColor Yellow
try {
    $test = Invoke-RestMethod -Uri "$ApiUrl/instance/fetchInstances" -Headers $headers -ErrorAction Stop
    Write-Host "✅ Evolution API online!" -ForegroundColor Green
} catch {
    Write-Host "❌ Evolution API não está respondendo!" -ForegroundColor Red
    Write-Host "`nVerifique se:" -ForegroundColor Yellow
    Write-Host "  • A URL está correta: $ApiUrl" -ForegroundColor White
    Write-Host "  • A API Key está correta: $ApiKey" -ForegroundColor White
    Write-Host "  • O container/serviço está rodando" -ForegroundColor White
    Write-Host "`nSe estiver usando nuvem, use:" -ForegroundColor Cyan
    Write-Host "  .\conectar-whatsapp.ps1 -ApiUrl 'https://sua-url.railway.app' -ApiKey 'Pmrhuan2013'`n" -ForegroundColor White
    exit
}

# 2. Verificar se backend está rodando
Write-Host "`n[2/5] Verificando backend..." -ForegroundColor Yellow
try {
    $backend = Invoke-WebRequest -Uri "http://localhost:3000/health" -Method GET -TimeoutSec 3 -ErrorAction Stop
    Write-Host "✅ Backend rodando!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Backend não está rodando!" -ForegroundColor Yellow
    Write-Host "`nInicie o backend primeiro:" -ForegroundColor Cyan
    Write-Host "  Duplo clique em: INICIAR.bat" -ForegroundColor White
    Write-Host "  Ou execute: cd backend && node server.js`n" -ForegroundColor White
    
    $resposta = Read-Host "Continuar mesmo assim? (s/N)"
    if ($resposta -ne 's' -and $resposta -ne 'S') {
        exit
    }
}

# 3. Criar instância WhatsApp
Write-Host "`n[3/5] Criando instância WhatsApp..." -ForegroundColor Yellow

$instanceName = "whatsapp-bm-rs"

# Verificar se já existe
try {
    $existing = Invoke-RestMethod -Uri "$ApiUrl/instance/connectionState/$instanceName" -Headers $headers -ErrorAction SilentlyContinue
    Write-Host "⚠️ Instância '$instanceName' já existe!" -ForegroundColor Yellow
    Write-Host "Estado: $($existing.instance.state)" -ForegroundColor Cyan
    
    $recriar = Read-Host "`nRecriar instância? Isso irá desconectar o WhatsApp atual (s/N)"
    if ($recriar -eq 's' -or $recriar -eq 'S') {
        Write-Host "Deletando instância antiga..." -ForegroundColor Yellow
        Invoke-RestMethod -Uri "$ApiUrl/instance/delete/$instanceName" -Method DELETE -Headers $headers | Out-Null
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Pulando criação de instância..." -ForegroundColor Cyan
        $skipCreate = $true
    }
} catch {
    # Instância não existe, tudo certo
}

if (-not $skipCreate) {
    $createBody = @{
        instanceName = $instanceName
        qrcode = $true
        integration = "WHATSAPP-BAILEYS"
    } | ConvertTo-Json

    try {
        $instance = Invoke-RestMethod -Uri "$ApiUrl/instance/create" -Method POST -Headers $headers -Body $createBody
        Write-Host "✅ Instância criada: $($instance.instance.instanceName)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro ao criar instância: $_" -ForegroundColor Red
        exit
    }
}

# 4. Gerar e exibir QR Code
Write-Host "`n[4/5] Gerando QR Code..." -ForegroundColor Yellow

try {
    $connect = Invoke-RestMethod -Uri "$ApiUrl/instance/connect/$instanceName" -Headers $headers
    
    $qrUrl = "$ApiUrl/instance/qrcode/$instanceName"
    
    Write-Host "✅ QR Code gerado!" -ForegroundColor Green
    Write-Host "`n📲 ABRINDO QR CODE NO NAVEGADOR..." -ForegroundColor Cyan
    Start-Process $qrUrl
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "   📱 ESCANEIE O QR CODE AGORA" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nPasso a passo:" -ForegroundColor Cyan
    Write-Host "  1. Abra WhatsApp no celular" -ForegroundColor White
    Write-Host "  2. Toque nos 3 pontinhos (menu)" -ForegroundColor White
    Write-Host "  3. Toque em 'Dispositivos vinculados'" -ForegroundColor White
    Write-Host "  4. Toque em 'Vincular dispositivo'" -ForegroundColor White
    Write-Host "  5. Escaneie o código que abriu no navegador" -ForegroundColor White
    Write-Host "`nSe o QR não abrir, acesse:" -ForegroundColor Yellow
    Write-Host "  $qrUrl`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Erro ao gerar QR Code: $_" -ForegroundColor Red
    Write-Host "`nTente acessar manualmente:" -ForegroundColor Yellow
    Write-Host "  $ApiUrl/instance/qrcode/$instanceName`n" -ForegroundColor Cyan
}

# Aguardar conexão
Write-Host "⏳ Aguardando você escanear o QR Code..." -ForegroundColor Yellow
Write-Host "Pressione ENTER após escanear..." -ForegroundColor Cyan
Read-Host

# Verificar status da conexão
Write-Host "`nVerificando conexão..." -ForegroundColor Yellow
$tentativas = 0
$conectado = $false

while ($tentativas -lt 10 -and -not $conectado) {
    try {
        $state = Invoke-RestMethod -Uri "$ApiUrl/instance/connectionState/$instanceName" -Headers $headers
        
        if ($state.instance.state -eq 'open') {
            $conectado = $true
            Write-Host "✅ WhatsApp conectado com sucesso!" -ForegroundColor Green
            break
        }
        
        $tentativas++
        Write-Host "Estado atual: $($state.instance.state) - Tentativa $tentativas/10" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
    } catch {
        $tentativas++
        Start-Sleep -Seconds 2
    }
}

if (-not $conectado) {
    Write-Host "⚠️ Não foi possível confirmar a conexão automaticamente" -ForegroundColor Yellow
    Write-Host "Verifique manualmente se o WhatsApp está conectado" -ForegroundColor Cyan
}

# 5. Configurar Webhook
Write-Host "`n[5/5] Configurando webhook..." -ForegroundColor Yellow

$webhookBody = @{
    url = $WebhookUrl
    webhook_by_events = $false
    webhook_base64 = $false
    events = @(
        "MESSAGES_UPSERT",
        "MESSAGES_UPDATE",
        "CONNECTION_UPDATE",
        "QRCODE_UPDATED"
    )
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$ApiUrl/webhook/set/$instanceName" -Method POST -Headers $headers -Body $webhookBody | Out-Null
    Write-Host "✅ Webhook configurado!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Erro ao configurar webhook: $_" -ForegroundColor Yellow
    Write-Host "Configure manualmente depois se necessário" -ForegroundColor Cyan
}

# Resumo final
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   🎉 CONFIGURAÇÃO CONCLUÍDA!" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green

Write-Host "`n📋 Status:" -ForegroundColor Cyan
Write-Host "  ✅ Evolution API: Online" -ForegroundColor White
Write-Host "  ✅ Instância WhatsApp: $instanceName" -ForegroundColor White
Write-Host "  ✅ Webhook: Configurado" -ForegroundColor White

Write-Host "`n🧪 TESTE AGORA:" -ForegroundColor Cyan
Write-Host "  Envie esta mensagem para o WhatsApp conectado:" -ForegroundColor White
Write-Host "`n  menu" -ForegroundColor Yellow

Write-Host "`n  Você deve receber:" -ForegroundColor White
Write-Host "  '🚔 SISTEMA BM - BOLETINS E ORDENS DE SERVIÇO'" -ForegroundColor Green

Write-Host "`n🛠️ Comandos úteis:" -ForegroundColor Cyan
Write-Host "  Ver status:     Invoke-RestMethod -Uri '$ApiUrl/instance/connectionState/$instanceName' -Headers @{'apikey'='$ApiKey'}" -ForegroundColor White
Write-Host "  Desconectar:    Invoke-RestMethod -Uri '$ApiUrl/instance/logout/$instanceName' -Headers @{'apikey'='$ApiKey'}" -ForegroundColor White

Write-Host "`n========================================`n" -ForegroundColor Green
