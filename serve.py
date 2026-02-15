import http.server
import socketserver
import socket
import os

os.chdir('/home/user/flutter_app/build/web')

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()
    def log_message(self, format, *args):
        pass  # suppress logs

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True
    def server_bind(self):
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        super().server_bind()

print("Starting CORS server on port 5060...")
httpd = ReusableTCPServer(('0.0.0.0', 5060), CORSHandler)
print("Server running on http://0.0.0.0:5060")
httpd.serve_forever()
