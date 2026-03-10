param(
    [string]$ApiUrl = "https://evolution-api-production-5d52.up.railway.app",
    [string]$InstanceName = "whatsapp-bot",
    [string]$ApiKey = "Pmrhuan2013",
    [string]$OutputPath = "$env:TEMP\whatsapp-qr-code.html"
)

$ErrorActionPreference = "Stop"

Write-Host "\n[1/4] Solicitando QR Code da instância '$InstanceName'..." -ForegroundColor Cyan
$headers = @{ apikey = $ApiKey }
$resp = Invoke-RestMethod -Uri "$ApiUrl/instance/connect/$InstanceName" -Headers $headers -Method GET

$qrBase64 = $null
if ($resp.base64) { $qrBase64 = $resp.base64 }
elseif ($resp.qrcode -and $resp.qrcode.base64) { $qrBase64 = $resp.qrcode.base64 }

if (-not $qrBase64) {
    throw "Não foi possível obter QR Code no retorno da API."
}

Write-Host "[2/4] Gerando página HTML do QR..." -ForegroundColor Cyan
$html = @"
<!DOCTYPE html>
<html lang='pt-BR'>
<head>
<meta charset='utf-8'>
<title>QR Code WhatsApp</title>
<style>
body{display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#0f172a;font-family:Arial,sans-serif;color:#fff}
.card{background:#111827;padding:28px;border-radius:16px;text-align:center;max-width:420px;box-shadow:0 12px 30px rgba(0,0,0,.35)}
img{width:320px;height:320px;background:#fff;padding:10px;border-radius:10px}
small{display:block;margin-top:12px;color:#cbd5e1}
code{color:#93c5fd}
</style>
</head>
<body>
<div class='card'>
  <h2>Conectar WhatsApp</h2>
  <p>Escaneie com o número desejado.</p>
  <img src='$qrBase64' alt='QR Code'/>
  <small>Instância: <code>$InstanceName</code></small>
</div>
</body>
</html>
"@

$html | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "[3/4] Abrindo QR no navegador..." -ForegroundColor Cyan
Start-Process $OutputPath

Write-Host "[4/4] Verificando estado de conexão..." -ForegroundColor Cyan
$state = Invoke-RestMethod -Uri "$ApiUrl/instance/connectionState/$InstanceName" -Headers $headers -Method GET
$state | ConvertTo-Json -Depth 10

Write-Host "\nQR aberto com sucesso: $OutputPath\n" -ForegroundColor Green
