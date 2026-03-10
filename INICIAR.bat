@echo off
echo ========================================
echo    WHATSAPP-IA - INICIANDO SERVIDOR
echo ========================================
echo.
cd backend
echo [1/3] Verificando dependencias...
call npm install --silent
echo.
echo [2/3] Iniciando servidor na porta 3000...
echo.
node server.js
