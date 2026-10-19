#!/usr/bin/env python3
import http.server
import socketserver
import os
from urllib.parse import unquote
import json
from datetime import datetime

# Change to the accountant portal directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Define the port
PORT = 3003

# Create a simple HTTP server for accountant portal
class AccountantPortalHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Get the file path
        path = self.translate_path(self.path)
        
        # Handle root path
        if self.path == '/':
            path = 'index.html'
        
        # Handle API routes
        elif self.path.startswith('/api/'):
            self.handle_api_request(self.path)
            return
        
        # Handle common accounting tool routes
        elif self.path in ['/invoice-management', '/bill-payment', '/financial-reports', 
                          '/tax-management', '/bank-reconciliation', '/expense-tracking']:
            path = f'{self.path}.html'
        
        try:
            # Try to open the file
            with open(path, 'rb') as f:
                # Read the file content
                content = f.read()
                
                # Determine content type
                if path.endswith('.html'):
                    content_type = 'text/html'
                elif path.endswith('.css'):
                    content_type = 'text/css'
                elif path.endswith('.js'):
                    content_type = 'application/javascript'
                elif path.endswith('.json'):
                    content_type = 'application/json'
                elif path.endswith('.png'):
                    content_type = 'image/png'
                elif path.endswith('.jpg') or path.endswith('.jpeg'):
                    content_type = 'image/jpeg'
                elif path.endswith('.gif'):
                    content_type = 'image/gif'
                elif path.endswith('.svg'):
                    content_type = 'image/svg+xml'
                else:
                    content_type = 'application/octet-stream'
                
                # Send response
                self.send_response(200)
                self.send_header('Content-type', content_type)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type')
                self.end_headers()
                self.wfile.write(content)
                
        except FileNotFoundError:
            # File not found - send 404
            self.send_response(404)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>404 Not Found</h1><p>The file was not found on this server.</p>')

    def do_POST(self):
        if self.path.startswith('/api/'):
            self.handle_api_request(self.path)
        else:
            self.send_response(404)
            self.end_headers()

    def handle_api_request(self, path):
        """Handle API requests for accounting operations"""
        try:
            content_length = self.headers.get('Content-Length')
            if content_length:
                post_data = self.rfile.read(int(content_length))
            else:
                post_data = b''
            
            try:
                data = json.loads(post_data.decode('utf-8')) if post_data else {}
            except:
                data = {}
        except Exception as e:
            data = {}
        
        # API endpoints
        if path == '/api/invoices':
            response = self.handle_invoices(data)
        elif path == '/api/bills':
            response = self.handle_bills(data)
        elif path == '/api/reports':
            response = self.handle_reports(data)
        elif path == '/api/expenses':
            response = self.handle_expenses(data)
        elif path == '/api/tax':
            response = self.handle_tax(data)
        elif path == '/api/bank-reconciliation':
            response = self.handle_bank_reconciliation(data)
        else:
            response = {'error': 'API endpoint not found'}
        
        # Send JSON response
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode('utf-8'))

    def handle_invoices(self, data):
        """Handle invoice operations"""
        operation = data.get('operation', 'list')
        
        if operation == 'list':
            return {
                'invoices': [
                    {'id': 1, 'number': 'INV-001', 'client': 'ABC Corp', 'amount': 1500, 'status': 'pending', 'due_date': '2024-02-15'},
                    {'id': 2, 'number': 'INV-002', 'client': 'XYZ Ltd', 'amount': 2300, 'status': 'paid', 'due_date': '2024-02-10'},
                    {'id': 3, 'number': 'INV-003', 'client': 'DEF Inc', 'amount': 800, 'status': 'overdue', 'due_date': '2024-02-05'}
                ]
            }
        elif operation == 'create':
            return {'success': False, 'error': 'Invoice creation is not connected to persistent storage. No invoice was created.'}
        else:
            return {'error': 'Invalid operation'}

    def handle_bills(self, data):
        """Handle bill operations"""
        operation = data.get('operation', 'list')
        
        if operation == 'list':
            return {
                'bills': [
                    {'id': 1, 'vendor': 'Office Supplies Co', 'amount': 450, 'due_date': '2024-02-20', 'status': 'pending'},
                    {'id': 2, 'vendor': 'Utilities Inc', 'amount': 320, 'due_date': '2024-02-18', 'status': 'urgent'},
                    {'id': 3, 'vendor': 'Internet Provider', 'amount': 150, 'due_date': '2024-02-25', 'status': 'scheduled'}
                ]
            }
        elif operation == 'pay':
            return {'success': False, 'error': 'Payment processing is not configured. No payment was made.'}
        else:
            return {'error': 'Invalid operation'}

    def handle_reports(self, data):
        """Handle financial report operations"""
        report_type = data.get('type', 'summary')
        
        if report_type == 'summary':
            return {
                'report': {
                    'total_revenue': 45678,
                    'total_expenses': 23456,
                    'net_profit': 22222,
                    'pending_invoices': 12,
                    'unpaid_bills': 8,
                    'period': 'February 2024'
                }
            }
        elif report_type == 'detailed':
            return {
                'report': {
                    'revenue_by_client': [
                        {'client': 'ABC Corp', 'amount': 15000},
                        {'client': 'XYZ Ltd', 'amount': 12000},
                        {'client': 'DEF Inc', 'amount': 85678}
                    ],
                    'expenses_by_category': [
                        {'category': 'Office Supplies', 'amount': 2340},
                        {'category': 'Utilities', 'amount': 1890},
                        {'category': 'Software', 'amount': 4500}
                    ]
                }
            }
        else:
            return {'error': 'Invalid report type'}

    def handle_expenses(self, data):
        """Handle expense tracking operations"""
        operation = data.get('operation', 'list')
        
        if operation == 'list':
            return {
                'expenses': [
                    {'id': 1, 'description': 'Office supplies', 'amount': 150, 'category': 'Supplies', 'date': '2024-02-14'},
                    {'id': 2, 'description': 'Client lunch', 'amount': 85, 'category': 'Meals', 'date': '2024-02-13'},
                    {'id': 3, 'description': 'Software subscription', 'amount': 99, 'category': 'Software', 'date': '2024-02-12'}
                ]
            }
        elif operation == 'add':
            return {'success': False, 'error': 'Expense creation is not connected to persistent storage. No expense was saved.'}
        else:
            return {'error': 'Invalid operation'}

    def handle_tax(self, data):
        """Handle tax management operations"""
        return {
            'tax_info': {
                'next_deadline': '2024-03-15',
                'days_remaining': 15,
                'estimated_tax': 5678,
                'payments_made': 2340,
                'remaining': 3338
            }
        }

    def handle_bank_reconciliation(self, data):
        """Handle bank reconciliation operations"""
        return {
            'reconciliation': {
                'bank_balance': 25678,
                'book_balance': 25456,
                'difference': 222,
                'unmatched_transactions': [
                    {'id': 1, 'description': 'Deposit from client', 'amount': 1500, 'date': '2024-02-14'},
                    {'id': 2, 'description': 'Bank fee', 'amount': -25, 'date': '2024-02-13'}
                ]
            }
        }

def run_server():
    try:
        # Create and run the server
        with socketserver.TCPServer(("", PORT), AccountantPortalHandler) as httpd:
            print(f"Accountant Portal running at http://localhost:{PORT}")
            print("Accounting tools available:")
            print("  - Invoice Management")
            print("  - Bill Payment")
            print("  - Financial Reports")
            print("  - Tax Management")
            print("  - Bank Reconciliation")
            print("  - Expense Tracking")
            print("API endpoints available at /api/")
            print("Press Ctrl+C to stop the server")
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nAccountant Portal stopped.")
    except Exception as e:
        print(f"Error starting server: {e}")

if __name__ == "__main__":
    run_server()
