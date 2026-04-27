#!/usr/bin/env python3
"""
Run Sentinel backend accessible from phone (same WiFi)
"""
import socket
import uvicorn
from main import app

def get_local_ip():
    """Get local IP address"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "localhost"

if __name__ == "__main__":
    ip = get_local_ip()
    port = 8000
    
    print("\n" + "="*60)
    print("🛡️  SENTINEL BACKEND STARTED")
    print("="*60)
    print(f"\n📱 Phone se kholo (Same WiFi):")
    print(f"   http://{ip}:{port}/static/app-preview-instagram.html")
    print(f"\n💻 Computer se kholo:")
    print(f"   http://localhost:{port}/static/app-preview-instagram.html")
    print(f"\n🔗 API Docs:")
    print(f"   http://{ip}:{port}/docs")
    print("\n" + "="*60 + "\n")
    
    uvicorn.run(app, host="0.0.0.0", port=port)
