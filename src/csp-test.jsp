<!-- CSP Test script - place this file at: /opt/zimbra/jetty_base/webapps/zimbra/public/csp-test.jsp -->
<!-- # Verify CSP header is being sent: curl -I https://your-zimbra-server/zimbra/public/csp-test.jsp -->
<!-- # Visit in browser: https://your-zimbra-server/zimbra/public/csp-test.jsp -->
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
    <title>CSP Test Page</title>
</head>
<body>
    <h1>CSP Test Page</h1>
    <p>This page tests Content Security Policy enforcement.</p>
    
    <!-- This script should be BLOCKED by CSP (not in your hash list) -->
    <script>
        console.log("ALERT: This unauthorized script executed! CSP is NOT working!");
        alert("CSP FAILED - Unauthorized script executed!");
    </script>
    
    <!-- This should also be BLOCKED -->
    <button onclick="alert('Inline event handler executed - CSP failed!')">Click me (should be blocked)</button>
    
    <div id="result">
        <p><strong>Expected behavior with working CSP:</strong></p>
        <ul>
            <li>No alert popup should appear</li>
            <li>Console should show CSP violation errors</li>
            <li>Button click should do nothing</li>
            <li>Your Flask app should receive violation reports</li>
        </ul>
    </div>
</body>
</html>
