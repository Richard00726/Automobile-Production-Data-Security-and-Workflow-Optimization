<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    HttpSession existingSession = request.getSession(false);
    if (existingSession != null && existingSession.getAttribute("username") != null) {
        String r = (String) existingSession.getAttribute("role");
        if ("admin".equals(r)) { response.sendRedirect("jsp/admin/admin_dashboard.jsp"); }
        else                   { response.sendRedirect("dashboard.jsp"); }
        return;
    }
    String error = (String) request.getAttribute("error");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login — Automobile Production System</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.2/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <style>
        body { background: linear-gradient(135deg,#0d1b6e 0%,#1a237e 50%,#283593 100%); min-height:100vh; display:flex; align-items:center; justify-content:center; font-family:'Segoe UI',sans-serif; }
        .login-card { background:#fff; border-radius:20px; box-shadow:0 20px 60px rgba(0,0,0,0.35); overflow:hidden; width:100%; max-width:900px; display:flex; min-height:520px; }
        .login-left { background:linear-gradient(160deg,#0d1b6e,#1a237e,#e53935); color:#fff; padding:50px 40px; flex:1; display:flex; flex-direction:column; justify-content:center; align-items:center; text-align:center; }
        .login-left .car-icon { font-size:5rem; margin-bottom:20px; animation:float 3s ease-in-out infinite; }
        @keyframes float { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-12px)} }
        .login-left h2 { font-weight:800; font-size:1.6rem; line-height:1.3; margin-bottom:10px; }
        .login-left p { opacity:.8; font-size:.9rem; margin-bottom:24px; }
        .badge-pill { background:rgba(255,255,255,.18); color:#fff; border:1px solid rgba(255,255,255,.25); padding:5px 14px; border-radius:30px; font-size:.76rem; display:inline-block; margin:3px; }
        .login-right { padding:50px 44px; flex:1; display:flex; flex-direction:column; justify-content:center; }
        .login-right h3 { font-weight:800; color:#1a237e; margin-bottom:6px; }
        .login-right .sub { color:#888; font-size:.875rem; margin-bottom:28px; }
        .form-label { font-weight:600; font-size:.85rem; color:#444; }
        .form-control { border-radius:10px; padding:12px 16px; border:1.5px solid #e0e0e0; font-size:.9rem; transition:.2s; }
        .form-control:focus { border-color:#1a237e; box-shadow:0 0 0 3px rgba(26,35,126,.12); }
        .form-control.is-invalid { border-color:#c62828; }
        .btn-login { background:linear-gradient(135deg,#1a237e,#283593); color:#fff; border:none; border-radius:10px; padding:13px; font-size:1rem; font-weight:700; width:100%; transition:.2s; }
        .btn-login:hover { background:linear-gradient(135deg,#0d1b6e,#1a237e); color:#fff; transform:translateY(-1px); box-shadow:0 4px 16px rgba(26,35,126,.3); }
        .demo-hint { margin-top:20px; font-size:.76rem; color:#aaa; text-align:center; line-height:1.9; }
        .invalid-feedback-custom { color:#c62828; font-size:.8rem; margin-top:4px; }
        @media(max-width:700px) { .login-left{ display:none; } .login-right{ padding:40px 30px; } }
    </style>
</head>
<body>
<div class="login-card">
    <div class="login-left">
        <div class="car-icon">🚗</div>
        <h2>Automobile Production<br>Security &amp; Workflow</h2>
        <p>Secure multi-stage production workflow system with role-based access control</p>
        <div>
            <span class="badge-pill">⚙️ Design</span>
            <span class="badge-pill">📊 Analytics</span>
            <span class="badge-pill">✅ QC</span>
            <span class="badge-pill">🔬 Testing</span>
        </div>
    </div>

    <div class="login-right">
        <div style="font-size:2.5rem; margin-bottom:12px;">🔐</div>
        <h3>Welcome Back</h3>
        <p class="sub">Sign in to access your dashboard</p>

        <% if (error != null && !error.isEmpty()) { %>
        <div class="alert alert-danger d-flex align-items-center py-2 mb-3" style="border-radius:10px; font-size:.85rem;">
            <i class="bi bi-exclamation-triangle-fill me-2"></i> <%= error %>
        </div>
        <% } %>

        <form method="post" action="login" id="loginForm" novalidate>
            <div class="mb-3">
                <label class="form-label" for="username"><i class="bi bi-person me-1"></i>Username</label>
                <input type="text" class="form-control" id="username" name="username"
                       placeholder="Enter your username" autocomplete="username" autofocus>
                <div class="invalid-feedback-custom" id="usernameErr"></div>
            </div>
            <div class="mb-4">
                <label class="form-label" for="password"><i class="bi bi-lock me-1"></i>Password</label>
                <div class="input-group">
                    <input type="password" class="form-control" id="password" name="password"
                           placeholder="Enter your password" autocomplete="current-password" style="border-right:none;">
                    <button class="btn btn-outline-secondary" type="button" id="togglePwd"
                            style="border-left:none; border-radius:0 10px 10px 0;">
                        <i class="bi bi-eye" id="eyeIcon"></i>
                    </button>
                </div>
                <div class="invalid-feedback-custom" id="passwordErr"></div>
            </div>
            <button type="submit" class="btn-login">Sign In &nbsp;<i class="bi bi-arrow-right"></i></button>
        </form>

        <div class="demo-hint">
            Demo logins: <strong>admin</strong>/admin123 &nbsp;|&nbsp; <strong>designer1</strong>/design123<br>
            <strong>analyst1</strong>/analytics123 &nbsp;|&nbsp; <strong>qc1</strong>/qc123 &nbsp;|&nbsp; <strong>tester1</strong>/test123
        </div>
    </div>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.2/js/bootstrap.bundle.min.js"></script>
<script>
// Client-side validation
document.getElementById('loginForm').addEventListener('submit', function(e) {
    let valid = true;
    const u = document.getElementById('username');
    const p = document.getElementById('password');
    const uErr = document.getElementById('usernameErr');
    const pErr = document.getElementById('passwordErr');

    uErr.textContent = ''; pErr.textContent = '';
    u.classList.remove('is-invalid'); p.classList.remove('is-invalid');

    if (!u.value.trim()) {
        u.classList.add('is-invalid');
        uErr.textContent = 'Username is required.';
        valid = false;
    } else if (!/^[a-zA-Z0-9_]{3,30}$/.test(u.value.trim())) {
        u.classList.add('is-invalid');
        uErr.textContent = 'Username: 3-30 characters, letters/digits/underscore only.';
        valid = false;
    }
    if (!p.value) {
        p.classList.add('is-invalid');
        pErr.textContent = 'Password is required.';
        valid = false;
    } else if (p.value.length < 4) {
        p.classList.add('is-invalid');
        pErr.textContent = 'Password must be at least 4 characters.';
        valid = false;
    }
    if (!valid) e.preventDefault();
});

// Toggle password visibility
document.getElementById('togglePwd').addEventListener('click', function() {
    const p = document.getElementById('password');
    const icon = document.getElementById('eyeIcon');
    if (p.type === 'password') { p.type = 'text'; icon.className = 'bi bi-eye-slash'; }
    else                       { p.type = 'password'; icon.className = 'bi bi-eye'; }
});
</script>
</body>
</html>
