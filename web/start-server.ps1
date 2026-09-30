# ==============================================================================
# SERVIDOR WEB LOCAL NATIVO (POWERSHELL / .NET HTTPLISTENER)
# PROJETO: TRVSEG - CONFERÊNCIA DE PASSAGENS E AUDITORIA DE VIAGENS
# Executa a interface APEX em http://localhost:8080 sem dependências externas.
# ==============================================================================

$port = 8080
$baseDir = $PSScriptRoot

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  TRVSEG - CONFERÊNCIA DE PASSAGENS E AUDITORIA DE VIAGENS" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " Servidor rodando em: http://localhost:$port/" -ForegroundColor Yellow
    Write-Host " Pressione Ctrl+C para encerrar o servidor.`n" -ForegroundColor Gray

    # Abre automaticamente no navegador padrao
    Start-Process "http://localhost:$port/"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = "index.html"
        }

        $filePath = Join-Path $baseDir $path

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mimeType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".json" { "application/json; charset=utf-8" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".svg"  { "image/svg+xml" }
                ".pdf"  { "application/pdf" }
                ".xlsx" { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
                ".csv"  { "text/csv; charset=utf-8" }
                Default { "application/octet-stream" }
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentType = $mimeType
            $response.ContentLength64 = $bytes.Length
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $errBytes = [System.Text.Encoding]::UTF8.GetBytes("404 - Arquivo nao encontrado: $path")
            $response.OutputStream.Write($errBytes, 0, $errBytes.Length)
        }

        $response.Close()
    }
} catch {
    Write-Host "Erro ao executar o servidor: $_" -ForegroundColor Red
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}

