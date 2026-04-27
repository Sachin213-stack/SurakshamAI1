@echo off
echo ========================================
echo Starting Sentinel Backend...
echo ========================================
start "Sentinel Backend" cmd /k python main.py

timeout /t 3 /nobreak >nul

echo.
echo ========================================
echo Starting ngrok tunnel...
echo ========================================
echo.
echo Copy the ngrok URL and open on your phone:
echo https://YOUR-URL.ngrok-free.app/static/app-preview-instagram.html
echo.
ngrok.exe http 8000
