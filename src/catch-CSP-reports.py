#!/usr/bin/python3
#
# csp_report_logger.py
#
# companion script to catch CSP reports generated from zm_generate_CSP.py
# output is via syslog
#
# install flask: pip3 install flask
#

from flask import Flask, request
import json
import syslog

app = Flask(__name__)

@app.route('/csp-violation', methods=['POST'])
def csp_violation():
    try:
        report_data = request.get_json()
        if report_data and 'csp-report' in report_data:
            csp_report = report_data['csp-report']
            violated_directive = csp_report.get('violated-directive', 'unknown')
            blocked_uri = csp_report.get('blocked-uri', 'unknown')
            document_uri = csp_report.get('document-uri', 'unknown')
            syslog.syslog(syslog.LOG_WARNING,
                         f'CSP violation - directive: {violated_directive}, '
                         f'blocked: {blocked_uri}, page: {document_uri}')
        else:
            # Fallback to raw data
            raw_data = request.get_data(as_text=True)
            syslog.syslog(syslog.LOG_WARNING, f'CSP violation (raw): {raw_data}')
    except Exception as e:
        syslog.syslog(syslog.LOG_ERR, f'Error processing CSP report: {e}')
    return '', 204

if __name__ == '__main__':
    print("Starting CSP violation report logger on port 7777...")
    print("Violation reports will be logged to syslog")
    app.run(host='127.0.0.1', port=7777, debug=False)
