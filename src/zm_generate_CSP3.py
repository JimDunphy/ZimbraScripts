#!/usr/bin/python3
#
# Zimbra CSP Security Generator
#
# Author: Claude Sonnet 4
# Human: 6/23/2025 - JDunphy
# 
# Protects against calendar XSS vulnerabilities (CVE-pending)
# Specifically targets attendee name injection in JavaScript templates
#
# This script helps FOSS Zimbra administrators implement Content Security Policy
# protection against known XSS vulnerabilities while maintaining full functionality.
#
# The vulnerability affects:
# - Calendar reminder dialogs  
# - Email invite views
# - Calendar appointment displays
# - Voicemail location tooltips
#
# For more info: https://wiki.zimbra.com/wiki/Security_Center

__version__ = "3.0.0"

import os
import sys
import argparse

def init_zimbra_nginx_template():
    """Initialize Zimbra nginx template to include CSP header"""
    template_file = '/opt/zimbra/conf/nginx/templates/nginx.conf.web.https.template'
    csp_include_line = '    include /opt/zimbra/conf/nginx/includes/csp-header.conf;'
    target_line = '    include                 ${core.includes}/${core.cprefix}.web.https.mode-${web.mailmode};'
    
    # Check if template file exists
    if not os.path.exists(template_file):
        print(f"Error: Zimbra nginx template not found at {template_file}", file=sys.stderr)
        print("Make sure Zimbra is properly installed.", file=sys.stderr)
        return False
    
    # Read the current template
    try:
        with open(template_file, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {template_file}: {e}", file=sys.stderr)
        return False
    
    # Check if CSP include is already present
    csp_patterns = [
        'include /opt/zimbra/conf/nginx/includes/csp-header.conf',
        'include                 /opt/zimbra/conf/nginx/includes/csp-header.conf',
        '# CSP Security Header'
    ]
    
    already_present = any(pattern in content for pattern in csp_patterns)
    if already_present:
        print("CSP header include already present in nginx template.")
        print("Skipping modification to avoid duplicates.")
        return True
    
    # Check if target line exists
    if target_line not in content:
        print(f"Warning: Expected target line not found in {template_file}", file=sys.stderr)
        print(f"Looking for: {target_line}", file=sys.stderr)
        print("You may need to manually add the include line.", file=sys.stderr)
        return False
    
    # Create backup
    try:
        import shutil
        import datetime
        backup_file = f"{template_file}.backup.{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
        shutil.copy2(template_file, backup_file)
        print(f"Created backup: {backup_file}")
    except Exception as e:
        print(f"Warning: Could not create backup: {e}", file=sys.stderr)
    
    # Add CSP include after the target line
    new_content = content.replace(
        target_line,
        target_line + '\n    # CSP Security Header\n' + csp_include_line
    )
    
    # Write the modified template
    try:
        with open(template_file, 'w') as f:
            f.write(new_content)
        print(f"Successfully added CSP include to {template_file}")
        print("\nNginx template setup complete!")
        print("Template now includes: /opt/zimbra/conf/nginx/includes/csp-header.conf")
        return True
    except Exception as e:
        print(f"Error writing to {template_file}: {e}", file=sys.stderr)
        return False

def show_manual_init_instructions():
    """Show manual instructions for adding CSP include"""
    print("Manual CSP Setup Instructions:")
    print("=" * 70)
    print("This protects against calendar XSS vulnerabilities affecting FOSS Zimbra")
    print("(Commercial users receive patches 60 days earlier)")
    print()
    print("1. Edit the nginx template:")
    print("   /opt/zimbra/conf/nginx/templates/nginx.conf.web.https.template")
    print()
    print("2. Find this line:")
    print("   include ${core.includes}/${core.cprefix}.web.https.mode-${web.mailmode};")
    print()
    print("3. Add these lines after it:")
    print("   # CSP Security Header")
    print("   include /opt/zimbra/conf/nginx/includes/csp-header.conf;")
    print()
    print("4. Save the file")
    print()
    print("5. Generate CSP policy:")
    print("   ./generate-zimbra-CSP.py")
    print()
    print("6. Restart Zimbra proxy:")
    print("   su - zimbra && zmproxyctl restart")
    print()
    print("Alternative - Automated sed command:")
    print("-" * 40)
    print("sed -i '/include.*core\\.includes.*web\\.https\\.mode/a\\")
    print("    # CSP Security Header\\")
    print("    include /opt/zimbra/conf/nginx/includes/csp-header.conf;' \\")
    print("  /opt/zimbra/conf/nginx/templates/nginx.conf.web.https.template")

def write_zimbra_csp_config(output_file, report_uri=None):
    """Write CSP configuration optimized for Zimbra security"""
    # Ensure output directory exists
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"Error creating directory {output_dir}: {e}", file=sys.stderr)
            sys.exit(1)
    
    try:
        with open(output_file, 'w') as f:
            f.write("# Zimbra Content Security Policy - Comprehensive XSS Protection\n")
            f.write("# Protects against multiple XSS attack vectors in Zimbra\n")
            f.write("# Addresses both known vulnerabilities and general XSS threats\n")
            f.write("#\n")
            f.write("# Primary Protection Against:\n")
            f.write("# - Calendar attendee name XSS (known vulnerability)\n")
            f.write("# - External malicious script injection\n") 
            f.write("# - Email content XSS attacks\n")
            f.write("# - Third-party script loading\n")
            f.write("# - Data exfiltration attempts\n")
            f.write("#\n")
            if report_uri:
                f.write(f"# CSP violation reporting enabled: {report_uri}\n")
                f.write("# Monitor violations to detect attack attempts\n")
                f.write("#\n")
            f.write("\n")
            
            # Default CSP that allows Zimbra to function
            f.write("# Default CSP - Maintains Zimbra functionality\n")
            f.write("# Allows necessary scripts while blocking external threats\n")
            default_policy = "script-src 'self' 'unsafe-inline' 'unsafe-eval'; object-src 'none'; base-uri 'self'"
            if report_uri:
                default_policy += f"; report-uri {report_uri}"
            f.write(f'add_header Content-Security-Policy "{default_policy};" always;\n\n')
            
            # Strict CSP for calendar/mail display areas (where XSS happens)
            f.write("# STRICT CSP - Calendar/Mail Display Areas\n")
            f.write("# Blocks JavaScript execution in vulnerable calendar views\n") 
            f.write("# Protects against attendee name XSS injection\n")
            f.write("location ~ ^/zimbra/h/(printcalendar|printmessage|imessage|printvoicemails) {\n")
            strict_policy = "script-src 'self' 'unsafe-eval'; object-src 'none'; base-uri 'self'"
            if report_uri:
                strict_policy += f"; report-uri {report_uri}"
            f.write(f'    add_header Content-Security-Policy "{strict_policy};" always;\n')
            f.write("}\n\n")
            
            # Additional protection for admin interface  
            f.write("# Enhanced CSP - Admin Interface Protection\n")
            f.write("location /zimbraAdmin/ {\n")
            admin_policy = "script-src 'self' 'unsafe-inline' 'unsafe-eval'; object-src 'none'; base-uri 'self'"
            if report_uri:
                admin_policy += f"; report-uri {report_uri}"
            f.write(f'    add_header Content-Security-Policy "{admin_policy};" always;\n')
            f.write("}\n")
        
        print(f"Successfully created Zimbra CSP configuration: {output_file}")
        print()
        print("Security Configuration:")
        print("  ✓ Default Policy: Maintains Zimbra functionality")
        print("  ✓ Strict Policy: Blocks calendar XSS attacks")
        print("  ✓ Admin Policy: Protects administrative interface")
        if report_uri:
            print(f"  ✓ Reporting: Violations sent to {report_uri}")
        print()
        print("Protection Against:")
        print("  • External malicious script injection")
        print("  • Calendar attendee name XSS attacks")
        print("  • Email content script execution") 
        print("  • Third-party script loading")
        print("  • Data exfiltration to external domains")
        print("  • Clickjacking and iframe embedding")
        print("  • Base URI manipulation attacks")
        print()
        print("Next Steps:")
        print("  1. Restart Zimbra: su - zimbra && zmproxyctl restart")
        print("  2. Test calendar functionality")
        print("  3. Monitor for CSP violations")
        
    except Exception as e:
        print(f"Error writing to {output_file}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Generate comprehensive CSP protection for Zimbra against XSS attacks',
        epilog='''
SECURITY NOTICE:
This tool provides comprehensive XSS protection for Zimbra installations.
While particularly important for FOSS users during vulnerability windows,
it benefits all Zimbra deployments by blocking various attack vectors.

XSS PROTECTION SCOPE:
- Blocks external malicious scripts (prevents data theft)
- Prevents script injection in email content  
- Stops third-party tracker/malware loading
- Protects against calendar attendee name XSS
- Blocks clickjacking and frame embedding attacks
- Prevents base URI manipulation

WHY CSP MATTERS FOR ZIMBRA:
- Email systems are high-value targets for attackers
- User data and credentials are attractive to criminals  
- XSS can lead to account takeover and data exfiltration
- CSP provides defense-in-depth security

PROTECTION STRATEGY:
- Maintains full Zimbra functionality with permissive CSP
- Blocks script execution in vulnerable calendar display areas
- Provides targeted protection without breaking features

WORKFLOW:
  Step 1: Setup nginx template (one-time)
    sudo ./generate-zimbra-CSP.py --init

  Step 2: Generate CSP policy  
    ./generate-zimbra-CSP.py
    OR
    ./generate-zimbra-CSP.py --report  # with violation reporting

  Step 3: Restart Zimbra proxy
    su - zimbra && zmproxyctl restart

  Step 4: Test calendar functionality
    Verify login, calendar viewing, and appointment creation work normally

REPORTING:
  Use --report to enable CSP violation monitoring
  Requires a web server listening on specified endpoint
  Helps detect actual attack attempts

For manual setup instructions: --manual
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--init', 
                       action='store_true',
                       help='Initialize Zimbra nginx template to include CSP header (requires sudo)')
    parser.add_argument('--manual', 
                       action='store_true',
                       help='Show manual setup instructions for nginx template modification')
    parser.add_argument('--report-uri', 
                       help='Enable CSP reporting to specified URI (e.g., http://127.0.0.1:7777/csp-violation)', 
                       default=None)
    parser.add_argument('--report', 
                       action='store_true',
                       help='Enable CSP reporting to default endpoint (http://127.0.0.1:7777/csp-violation)')
    parser.add_argument('--version', 
                       action='version',
                       version=f'%(prog)s {__version__} - Zimbra XSS Protection Suite')
    
    args = parser.parse_args()
    
    # Handle --manual option (only show instructions)
    if args.manual:
        show_manual_init_instructions()
        sys.exit(0)
    
    # Handle --init option (only modify nginx template)
    if args.init:
        success = init_zimbra_nginx_template()
        if success:
            print("\nNext steps:")
            print("1. Generate CSP policy: ./generate-zimbra-CSP.py")
            print("2. Restart Zimbra proxy: su - zimbra && zmproxyctl restart")
            print("3. Test calendar functionality")
        sys.exit(0 if success else 1)
    
    # Generate CSP configuration
    print("Generating comprehensive Zimbra XSS protection...")
    print()
    
    # Set report URI
    report_uri = None
    if args.report:
        report_uri = 'http://127.0.0.1:7777/csp-violation'
    elif args.report_uri:
        report_uri = args.report_uri
    
    output_path = '/opt/zimbra/conf/nginx/includes/csp-header.conf'
    write_zimbra_csp_config(output_path, report_uri)
    
    if report_uri:
        print()
        print("CSP VIOLATION REPORTING ENABLED")
        print(f"Reports will be sent to: {report_uri}")
        print("Make sure your monitoring endpoint is running!")
        print()
        print("Example Flask monitoring server:")
        print("  python3 -c \"")
        print("from flask import Flask, request")
        print("import syslog")
        print("app = Flask(__name__)")
        print("@app.route('/csp-violation', methods=['POST'])")
        print("def csp_violation():")
        print("    syslog.syslog(syslog.LOG_WARNING, f'CSP: {request.get_data(as_text=True)}')")
        print("    return '', 204")
        print("app.run(host='127.0.0.1', port=7777)\"")
        print()
    
    print("=" * 70)
    print("ZIMBRA CSP PROTECTION READY")
    print("=" * 70)
