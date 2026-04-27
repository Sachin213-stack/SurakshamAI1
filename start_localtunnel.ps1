# Sentinel + localtunnel (No account needed!)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting Sentinel Backend..." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Start backend in new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "python main.py"

# Wait for backend to start
Start-Sleep -Seconds 3

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Starting localtunnel..." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Copy the URL and open on your phone!" -ForegroundColor Yellow
Write-Host "Add: /static/app-preview-instagram.html`n" -ForegroundColor White

# Start localtunnel
npx localtunnel --port 8000
