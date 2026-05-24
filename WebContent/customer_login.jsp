<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess != null && sess.getAttribute("customerName") != null) {
        response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp");
        return;
    }
    String error   = (String) request.getAttribute("error");
    String success = (String) request.getAttribute("success");
    String ctx     = request.getContextPath();
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Customer Portal — AutoProd</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&family=DM+Sans:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.2/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <style>
        :root {
            --primary: #0a6ebd; --primary-dark: #054d8a;
            --secondary: #00b4a6; --bg: #f0f4f8;
            --text: #1a2b4a; --text-light: #5a6a7e; --border: #dce3ed;
        }
        body { font-family: 'DM Sans', sans-serif; background: linear-gradient(135deg, #0a6ebd 0%, #054d8a 45%, #00b4a6 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 40px 20px; }
        .auth-container { width: 100%; max-width: 960px; background: #fff; border-radius: 24px; box-shadow: 0 20px 60px rgba(0,0,0,.2); overflow: hidden; display: grid; grid-template-columns: 1fr 1fr; animation: fadeUp .6s ease; }
        @keyframes fadeUp { from { transform: translateY(40px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }

        /* Left panel */
        .auth-left { background: linear-gradient(160deg, #0a6ebd, #00b4a6); padding: 48px 40px; display: flex; flex-direction: column; justify-content: center; color: #fff; }
        .auth-left .brand { font-family: 'Outfit', sans-serif; font-size: 2rem; font-weight: 800; margin-bottom: 8px; }
        .auth-left .brand span { color: #ffdb4d; }
        .auth-left p { opacity: .85; font-size: .95rem; line-height: 1.7; margin-bottom: 32px; }
        .feature-list { list-style: none; padding: 0; }
        .feature-list li { display: flex; align-items: center; gap: 10px; padding: 8px 0; font-size: .875rem; opacity: .9; }
        .feature-list li .icon { width: 28px; height: 28px; background: rgba(255,255,255,.2); border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }

        /* Right panel */
        .auth-right { padding: 40px; overflow-y: auto; max-height: 100vh; }
        .auth-tabs { display: flex; background: var(--bg); border-radius: 10px; padding: 4px; margin-bottom: 24px; }
        .auth-tab { flex: 1; padding: 10px; border: none; background: none; border-radius: 8px; font-family: 'DM Sans', sans-serif; font-size: .875rem; font-weight: 600; color: var(--text-light); cursor: pointer; transition: all .2s; }
        .auth-tab.active { background: #fff; color: var(--primary); box-shadow: 0 2px 8px rgba(0,0,0,.08); }

        .auth-form { display: none; }
        .auth-form.active { display: block; animation: fadeIn .3s ease; }
        @keyframes fadeIn { from { opacity: 0; transform: translateX(10px); } to { opacity: 1; transform: translateX(0); } }

        .auth-form h2 { font-family: 'Outfit', sans-serif; font-size: 1.4rem; font-weight: 700; color: var(--text); margin-bottom: 4px; }
        .auth-form .subtitle { color: var(--text-light); font-size: .875rem; margin-bottom: 20px; }

        .form-group { margin-bottom: 14px; }
        .form-group label { display: block; font-size: .72rem; font-weight: 700; color: var(--text); margin-bottom: 5px; text-transform: uppercase; letter-spacing: .5px; }
        .input-wrap { position: relative; }
        .input-wrap i { position: absolute; left: 14px; top: 50%; transform: translateY(-50%); color: var(--text-light); font-size: .9rem; }
        .input-wrap input { width: 100%; padding: 10px 14px 10px 38px; border: 1.5px solid var(--border); border-radius: 10px; font-family: 'DM Sans', sans-serif; font-size: .875rem; color: var(--text); outline: none; transition: all .2s; }
        .input-wrap input:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(10,110,189,.1); }

        .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }

        /* Phone input with +91 prefix */
        .phone-wrap { display: flex; gap: 8px; }
        .phone-code { padding: 10px 12px; border: 1.5px solid var(--border); border-radius: 10px; font-size: .875rem; font-weight: 700; color: var(--primary); background: #f0f7ff; white-space: nowrap; display: flex; align-items: center; gap: 4px; flex-shrink: 0; }
        .phone-input { flex: 1; padding: 10px 14px; border: 1.5px solid var(--border); border-radius: 10px; font-family: 'DM Sans', sans-serif; font-size: .875rem; outline: none; transition: all .2s; color: var(--text); }
        .phone-input:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(10,110,189,.1); }

        .btn-primary { width: 100%; padding: 12px; background: linear-gradient(135deg, var(--primary), var(--primary-dark)); color: #fff; border: none; border-radius: 10px; font-family: 'Outfit', sans-serif; font-size: .95rem; font-weight: 700; cursor: pointer; transition: all .2s; margin-top: 6px; }
        .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(10,110,189,.3); }

        .alert-error   { background: #ffebee; color: #c62828; border: 1px solid #ef9a9a; padding: 10px 14px; border-radius: 8px; font-size: .85rem; margin-bottom: 16px; }
        .alert-success { background: #e8f5e9; color: #2e7d32; border: 1px solid #a5d6a7; padding: 10px 14px; border-radius: 8px; font-size: .85rem; margin-bottom: 16px; }

        .switch-link { text-align: center; margin-top: 14px; font-size: .8rem; color: var(--text-light); }
        .switch-link a { color: var(--primary); font-weight: 600; text-decoration: none; cursor: pointer; }

        /* OTP step info box */
        .otp-info { background: #f0f7ff; border: 1.5px solid #b3d9f7; border-radius: 10px; padding: 10px 14px; font-size: .8rem; color: #1565c0; margin-bottom: 16px; display: flex; align-items: flex-start; gap: 8px; }
        .otp-info i { font-size: 1rem; margin-top: 1px; flex-shrink: 0; }

        /* Password rules */
        .pwd-rules { background: #f8f9fa; border-radius: 8px; padding: 8px 12px; font-size: .72rem; color: #6b7c93; margin-top: 4px; }
        .pwd-rules span { display: block; margin-bottom: 1px; }

        @media (max-width: 768px) {
            .auth-container { grid-template-columns: 1fr; }
            .auth-left { display: none; }
            .auth-right { padding: 28px 20px; }
            .form-row { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>

<div class="auth-container">

    <!-- LEFT PANEL -->
    <div class="auth-left">
        <div class="brand">Auto<span>Prod</span> 🚗</div>
        <p>Automobile Manufacturing Management System — Customer Portal for seamless project requirement submissions.</p>
        <ul class="feature-list">
            <li><div class="icon"><i class="bi bi-shield-check"></i></div> Secure verified accounts</li>
            <li><div class="icon"><i class="bi bi-phone"></i></div> Mobile OTP verification</li>
            <li><div class="icon"><i class="bi bi-envelope-check"></i></div> Email OTP verification</li>
            <li><div class="icon"><i class="bi bi-graph-up"></i></div> Real-time status tracking</li>
            <li><div class="icon"><i class="bi bi-people"></i></div> Multi-team collaboration</li>
        </ul>
    </div>

    <!-- RIGHT PANEL -->
    <div class="auth-right">

        <!-- Tabs -->
        <div class="auth-tabs">
            <button class="auth-tab active" id="loginTab" onclick="switchTab('login')">
                <i class="bi bi-box-arrow-in-right me-1"></i>Sign In
            </button>
            <button class="auth-tab" id="registerTab" onclick="switchTab('register')">
                <i class="bi bi-person-plus me-1"></i>Create Account
            </button>
        </div>

        <!-- Alerts -->
        <% if (error   != null) { %><div class="alert-error"><i class="bi bi-exclamation-circle me-2"></i><%= error %></div><% } %>
        <% if (success != null) { %><div class="alert-success"><i class="bi bi-check-circle me-2"></i><%= success %></div><% } %>

        <!-- ── LOGIN FORM ── -->
        <div class="auth-form active" id="loginForm">
            <h2>Welcome Back! 👋</h2>
            <p class="subtitle">Sign in to access your customer portal</p>

            <form method="post" action="<%= ctx %>/customerLogin">
                <div class="form-group">
                    <label>Email Address</label>
                    <div class="input-wrap">
                        <i class="bi bi-envelope"></i>
                        <input type="email" name="email" placeholder="your@email.com" required>
                    </div>
                </div>
                <div class="form-group">
                    <label>Password</label>
                    <div class="input-wrap">
                        <i class="bi bi-lock"></i>
                        <input type="password" name="password" placeholder="Enter your password" required>
                    </div>
                </div>
                <button type="submit" class="btn-primary">
                    <i class="bi bi-box-arrow-in-right me-2"></i>Sign In
                </button>
            </form>
            <div class="switch-link">
                Don't have an account?
                <a onclick="switchTab('register')">Register here</a>
            </div>
        </div>

        <!-- ── REGISTER FORM ── -->
        <div class="auth-form" id="registerForm">
            <h2>Create Account 🚀</h2>
            <p class="subtitle">Join AutoProd Customer Portal today</p>

            <!-- OTP info box -->
            <div class="otp-info">
                <i class="bi bi-info-circle-fill"></i>
                <span>After registration you will receive a <strong>6-digit OTP</strong> on your
                email and mobile number to verify your account!</span>
            </div>

            <form method="post" action="<%= ctx %>/customerRegister" onsubmit="return validateRegister()">

                <!-- Row 1: Full Name + City/Location -->
                <div class="form-row">
                    <div class="form-group">
                        <label>Full Name *</label>
                        <div class="input-wrap">
                            <i class="bi bi-person"></i>
                            <input type="text" name="fullName" placeholder="Your full name" required>
                        </div>
                    </div>
                    <div class="form-group">
                        <label>City / Location *</label>
                        <div class="input-wrap">
                            <i class="bi bi-geo-alt"></i>
                            <input type="text" name="city" placeholder="e.g. Chennai, Mumbai" required>
                        </div>
                    </div>
                </div>

                <!-- Email -->
                <div class="form-group">
                    <label>Email Address *</label>
                    <div class="input-wrap">
                        <i class="bi bi-envelope"></i>
                        <input type="email" name="email" id="regEmail"
                               placeholder="your@email.com" required>
                    </div>
                </div>

                <!-- Mobile -->
                <div class="form-group">
                    <label>Mobile Number *</label>
                    <div class="phone-wrap">
                        <div class="phone-code">🇮🇳 +91</div>
                        <input type="tel" name="phone" class="phone-input"
                               placeholder="10-digit mobile number"
                               maxlength="10" id="regPhone" required>
                    </div>
                </div>

                <!-- Row 2: Password + Confirm -->
                <div class="form-row">
                    <div class="form-group">
                        <label>Password *</label>
                        <div class="input-wrap">
                            <i class="bi bi-lock"></i>
                            <input type="password" name="password" id="regPassword"
                                   placeholder="Min 8 characters" required minlength="8">
                        </div>
                    </div>
                    <div class="form-group">
                        <label>Confirm Password *</label>
                        <div class="input-wrap">
                            <i class="bi bi-lock-fill"></i>
                            <input type="password" name="confirmPassword" id="regConfirm"
                                   placeholder="Repeat password" required>
                        </div>
                    </div>
                </div>

                <div class="pwd-rules">
                    <span id="r-len">⬜ At least 8 characters</span>
                    <span id="r-num">⬜ Contains a number</span>
                    <span id="r-upp">⬜ Contains uppercase letter</span>
                </div>

                <button type="submit" class="btn-primary" style="margin-top:14px;">
                    <i class="bi bi-send me-2"></i>Register & Send OTP
                </button>
            </form>

            <div class="switch-link">
                Already have an account?
                <a onclick="switchTab('login')">Sign in</a>
            </div>
        </div>

    </div>
</div>

<script>
    // ── Tab switch ──
    function switchTab(tab) {
        document.getElementById('loginTab').classList.toggle('active',    tab === 'login');
        document.getElementById('registerTab').classList.toggle('active', tab === 'register');
        document.getElementById('loginForm').classList.toggle('active',   tab === 'login');
        document.getElementById('registerForm').classList.toggle('active',tab === 'register');
    }

    // ── Password strength ──
    document.getElementById('regPassword').addEventListener('input', function() {
        const v = this.value;
        document.getElementById('r-len').textContent = (v.length >= 8   ? '✅' : '⬜') + ' At least 8 characters';
        document.getElementById('r-num').textContent = (/\d/.test(v)    ? '✅' : '⬜') + ' Contains a number';
        document.getElementById('r-upp').textContent = (/[A-Z]/.test(v) ? '✅' : '⬜') + ' Contains uppercase letter';
    });

    // ── Confirm password match ──
    document.getElementById('regConfirm').addEventListener('input', function() {
        const match = this.value === document.getElementById('regPassword').value;
        this.style.borderColor = this.value ? (match ? '#2e7d32' : '#c62828') : '#dce3ed';
    });

    // ── Only numbers in phone ──
    document.getElementById('regPhone').addEventListener('input', function() {
        this.value = this.value.replace(/[^0-9]/g, '');
    });

    // ── Validate register before submit ──
    function validateRegister() {
        const pass    = document.getElementById('regPassword').value;
        const confirm = document.getElementById('regConfirm').value;
        const phone   = document.getElementById('regPhone').value;
        if (pass.length < 8) {
            alert('Password must be at least 8 characters!'); return false;
        }
        if (pass !== confirm) {
            alert('Passwords do not match!'); return false;
        }
        if (phone.length !== 10) {
            alert('Please enter a valid 10-digit mobile number!'); return false;
        }
        return true;
    }

    // ── Auto switch to register tab if redirected ──
    <% if ("register".equals(request.getParameter("tab"))) { %>
    switchTab('register');
    <% } %>
</script>
</body>
</html>
