# Compila a versão web local. O rodapé do login e o menu mostram
# "v1.0.0+425 · local · <data e hora da compilação>", para conferir
# se o navegador está rodando a compilação mais recente.
#
# Uso:  .\build_local.ps1            (só compila)
#       .\build_local.ps1 -Servir    (compila e abre em http://localhost:8765)

param([switch]$Servir)

$hora = Get-Date -Format 'dd/MM HH:mm'
flutter build web --release --dart-define=APP_ENV=dev --dart-define=BUILD_HASH=local "--dart-define=BUILD_TIME=$hora"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Compilado em $hora. Com o servidor local (-Servir), um F5 comum já carrega a versão nova."

if ($Servir) {
    # Servidor sem cache: um F5 comum já carrega a compilação nova
    & "$PSScriptRoot\.venv\Scripts\python.exe" "$PSScriptRoot\tool\servidor_local.py" 8765
}
