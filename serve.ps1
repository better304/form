$port = 8000
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Local Test Server" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Root: $root"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
try {
    $listener.Start()
} catch {
    Write-Host "[X] Port $port is busy. Close other servers and retry." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "  URL:  http://localhost:$port/" -ForegroundColor Green
Write-Host "  Stop: Ctrl+C" -ForegroundColor Yellow
Write-Host "================================================`n" -ForegroundColor Cyan
Start-Sleep -Milliseconds 200
Start-Process "http://localhost:$port/"

$mimes = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.pem'  = 'text/plain; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.pdf'  = 'application/pdf'
    '.txt'  = 'text/plain; charset=utf-8'
}

while ($listener.IsListening) {
    $ctx = $null
    try {
        $ctx = $listener.GetContext()
    } catch {
        Write-Host "[!] GetContext failed: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    try {
        $absPath = $ctx.Request.Url.AbsolutePath
        $relPath = [Uri]::UnescapeDataString($absPath).TrimStart('/')
        if ([string]::IsNullOrEmpty($relPath)) { $relPath = 'index.html' }
        $file = Join-Path $root $relPath

        $logTime = Get-Date -Format 'HH:mm:ss'

        if (Test-Path -LiteralPath $file -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $mime = if ($mimes.ContainsKey($ext)) { $mimes[$ext] } else { 'application/octet-stream' }
            $ctx.Response.ContentType = $mime
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "$logTime  200  $relPath  ($($bytes.Length) bytes)"
        } else {
            $ctx.Response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $relPath")
            $ctx.Response.ContentType = 'text/plain; charset=utf-8'
            $ctx.Response.ContentLength64 = $msg.Length
            $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
            Write-Host "$logTime  404  $relPath" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[!] Handler error: $($_.Exception.Message)" -ForegroundColor Red
        try {
            $ctx.Response.StatusCode = 500
            $msg = [System.Text.Encoding]::UTF8.GetBytes("500 Internal Server Error`n$($_.Exception.Message)")
            $ctx.Response.ContentType = 'text/plain; charset=utf-8'
            $ctx.Response.ContentLength64 = $msg.Length
            $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
        } catch {}
    } finally {
        try { $ctx.Response.Close() } catch {}
    }
}
