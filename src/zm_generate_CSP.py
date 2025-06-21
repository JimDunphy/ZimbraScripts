#!/usr/bin/python3
#
# Requirements:
# On Ubuntu: apt install python3-bs4
# On RHEL: pip3 install bs4
#
# Original Author: halfgaar
# Ref: https://forums.zimbra.org/viewtopic.php?t=73809
#
# Modification of generate-zimbra-CSP.py which created apache headers for zimbra nginx headers
# Author: June 21, 2025 - Jim Dunphy
#
# Zimbra has a history of XXS / script injection vulnerabilities. This can be
# quite bad: someone inviting you to an appointment called
# '<script>steal_all_your_stuff()</script>' for instance.
#
# Each fix seems to be another non-structural 'sanitize this input' fix.
# Instead, they should be using a Content-Security-Policy header to approve
# only its own scripts.
#
# A problem here is that they use a lot of inline scripts, so just saying
# 'self', meaning scripts loaded from the main domain, will break it. We need
# to also approve all the in-line stuff.
#
# That can be done by hash. This scripts finds all the relevant script tags,
# and generates a suitable Content-Security-Policy header for the Zimbra installation.
#
# Making sure the web server includes it is another matter. A good place for
# that is the HTTP proxy you should already have anyway [1]. Really. Then, you
# can easily add a line there to add the header.
#
# Example shortened result:
#
#     add_header Content-Security-Policy "script-src 'self' 'sha256-/rKt+JZ...' 'sha256-10cdpK+JyZnxsU..l';";
#
# Call to Zimbra developers: please include something like this in your own builds.
#
# [1] https://blog.bigsmoke.us/2019/06/11/setting-up-a-zimbra-authenticated-proxy

__version__ = "1.0.0"

import os
import hashlib
import base64
import sys
import argparse
from bs4 import BeautifulSoup

def generate_csp_hashes_from_html(directory):
    if not os.path.exists(directory):
        print(f"Warning: Directory {directory} does not exist", file=sys.stderr)
        return set()
    
    csp_hashes = set()
    processed_files = 0
    
    for root, _, files in os.walk(directory):
        for filename in files:
            if filename.lower().endswith(('.html', '.htm', '.jsp')):
                filepath = os.path.join(root, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        soup = BeautifulSoup(f, 'html.parser')
                        scripts = soup.find_all('script')
                        for script in scripts:
                            if script.string and not script.get('src'):
                                script_content = script.string.strip()
                                if script_content:
                                    hash_obj = hashlib.sha256(script_content.encode('utf-8'))
                                    b64_hash = base64.b64encode(hash_obj.digest()).decode('utf-8')
                                    csp_hashes.add(f"'sha256-{b64_hash}'")
                        processed_files += 1
                except Exception as e:
                    print(f"Error reading {filepath}: {e}", file=sys.stderr)
                    continue
    
    print(f"Processed {processed_files} files in {directory}", file=sys.stderr)
    return sorted(csp_hashes)

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
    
    # Check if CSP include is already present (look for both possible formats)
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
    print("=" * 50)
    print(f"1. Edit: /opt/zimbra/conf/nginx/templates/nginx.conf.web.https.template")
    print(f"2. Find this line:")
    print(f"   include                 ${{core.includes}}/${{core.cprefix}}.web.https.mode-${{web.mailmode}};")
    print(f"3. Add this line after it:")
    print(f"   # CSP Security Header")
    print(f"   include /opt/zimbra/conf/nginx/includes/csp-header.conf;")
    print(f"4. Save the file")
    print(f"5. Generate CSP policy: ./zm_generate_CSP.py")
    print(f"6. Restart Zimbra proxy: su - zimbra && zmproxyctl restart")
    print()
    print("Example sed command to do this automatically:")
    print("sed -i '/include.*core\\.includes.*web\\.https\\.mode/a\\    # CSP Security Header\\n    include /opt/zimbra/conf/nginx/includes/csp-header.conf;' \\")
    print("  /opt/zimbra/conf/nginx/templates/nginx.conf.web.https.template")

def write_nginx_csp_config(hashes, output_file, report_uri=None):
    # Ensure output directory exists
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir, exist_ok=True)
        except Exception as e:
            print(f"Error creating directory {output_dir}: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Check write permissions (commented out as requested)
    # if not os.access(output_dir, os.W_OK):
    #     print(f"Error: No write permission to {output_dir}", file=sys.stderr)
    #     sys.exit(1)
    
    # Build the CSP policy
    csp_policy = "script-src 'self'"
    for h in hashes:
        csp_policy += f" {h}"
    
    # Add report-uri if specified
    if report_uri:
        csp_policy += f"; report-uri {report_uri}"
    else:
        csp_policy += ";"
    
    # Calculate policy size
    full_header = f'add_header Content-Security-Policy "{csp_policy}";'
    policy_size = len(full_header)
    
    try:
        with open(output_file, 'w') as f:
            f.write("# Zimbra Content Security Policy Configuration\n")
            f.write(f"# Generated with {len(hashes)} script hashes\n")
            f.write(f"# Policy size: {policy_size} bytes\n")
            if report_uri:
                f.write(f"# CSP reporting enabled: {report_uri}\n")
            f.write("# \n")
            f.write("# To enable this policy:\n")
            f.write("# 1. Include this file in your nginx config:\n")
            f.write("#    include /opt/zimbra/conf/nginx/includes/csp-header.conf;\n")
            f.write("# 2. Restart nginx:\n")
            f.write("#    su - zimbra\n")
            f.write("#    zmproxyctl restart\n")
            if report_uri:
                f.write("# \n")
                f.write("# CSP Violation Reports will be sent to your Flask app\n")
                f.write("# Make sure your Flask app is running on 127.0.0.1:7777\n")
                f.write("# Endpoint: /csp-violation\n")
            f.write("\n")
            f.write(f'add_header Content-Security-Policy "{csp_policy}";\n')
        
        print(f"Successfully wrote nginx CSP config to {output_file}")
        print(f"Policy contains {len(hashes)} script hashes ({policy_size} bytes)")
        if report_uri:
            print(f"CSP reporting enabled: {report_uri}")
        
    except Exception as e:
        print(f"Error writing to {output_file}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Generate CSP policy for Zimbra',
        epilog='''
Workflow:
  Step 1: Setup nginx template (one-time)
    sudo ./zm_generate_CSP.py --init
    OR
    ./zm_generate_CSP.py --manual  # for instructions

  Step 2: Generate CSP policy
    ./zm_generate_CSP.py          # basic policy
    ./zm_generate_CSP.py --report # with violation reporting

  Step 3: Verify generated policy
    cat /opt/zimbra/conf/nginx/includes/csp-header.conf

  Step 4: Restart Zimbra proxy
    su - zimbra && zmproxyctl restart
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('--report-uri', 
                       help='Enable CSP reporting to specified URI (e.g., http://127.0.0.1:7777/csp-violation)', 
                       default=None)
    parser.add_argument('--report', 
                       action='store_true',
                       help='Enable CSP reporting to default Flask app (http://127.0.0.1:7777/csp-violation)')
    parser.add_argument('--init', 
                       action='store_true',
                       help='Initialize Zimbra nginx template to include CSP header')
    parser.add_argument('--manual', 
                       action='store_true',
                       help='Show manual instructions for CSP setup')
    parser.add_argument('--version', 
                       action='version',
                       version=f'%(prog)s {__version__}')
    
    args = parser.parse_args()
    
    # Handle --manual option FIRST (only show instructions)
    if args.manual:
        show_manual_init_instructions()
        sys.exit(0)
    
    # Handle --init option SECOND (only modify nginx template)
    if args.init:
        success = init_zimbra_nginx_template()
        if success:
            print("\nNext steps:")
            print("1. Generate CSP policy: ./zm_generate_CSP.py")
            print("2. Verify the generated policy")
            print("3. Restart Zimbra proxy: su - zimbra && zmproxyctl restart")
        sys.exit(0 if success else 1)
    
    # ONLY run CSP generation if neither --manual nor --init was specified
    print("Scanning Zimbra files for inline scripts...")
    
    # Set report URI
    report_uri = None
    if args.report:
        report_uri = 'http://127.0.0.1:7777/csp-violation'
    elif args.report_uri:
        report_uri = args.report_uri
    
    hashes = generate_csp_hashes_from_html('/opt/zimbra/jetty_base/webapps/zimbra/public')
    
    if not hashes:
        print("Error: No script hashes found", file=sys.stderr)
        sys.exit(2)
    
    output_path = '/opt/zimbra/conf/nginx/includes/csp-header.conf'
    write_nginx_csp_config(hashes, output_path, report_uri)
    
    print("\nNext steps:")
    print("1. Review the generated CSP policy in the config file")
    print("2. Restart Zimbra proxy:")
    print("   su - zimbra")
    print("   zmproxyctl restart")
    
    if report_uri:
        print(f"\nCSP violation reports will be sent to: {report_uri}")
        print("Make sure your Flask app is running and ready to receive reports!")
