# Sentinel + ngrok Auto-start Script (PowerShell)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting Sentinel Backend..." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Start backend in new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "python main.py"

# Wait for backend to start
Start-Sleep -Seconds 3

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting ngrok tunnel..." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Copy the ngrok URL and open on your phone:" -ForegroundColor Yellow
Write-Host "https://YOUR-URL.ngrok-free.app/static/app-preview-instagram.html`n" -ForegroundColor White

# Start ngrok
.\ngrok.exe http 8000
