<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    HttpSession sess = request.getSession(false);
    String pendingEmail = (sess != null) ? (String) sess.getAttribute("pendingEmail") : null;
    String pendingPhone = (sess != null) ? (String) sess.getAttribute("pendingPhone") : null;

    if (pendingEmail == null) {
        response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
        return;
    }

    String error   = (String) request.getAttribute("error");
    String success = (String) request.getAttribute("success");
    String ctx     = request.getContextPath();

    // Dev OTPs — shown on screen when SMS/Email fails
    String devEmailOtp  = (String) sess.getAttribute("devEmailOtp");
    String devMobileOtp = (String) sess.getAttribute("devMobileOtp");

    // Mask email and phone
    String maskedEmail = "";
    if (pendingEmail != null && pendingEmail.contains("@")) {
        String[] parts = pendingEmail.split("@");
        String name = parts[0];
        maskedEmail = name.substring(0, Math.min(3, name.length())) + "***@" + parts[1];
    }
    String maskedPhone = "";
    if (pendingPhone != null && pendingPhone.length() >= 4) {
        maskedPhone = "******" + pendingPhone.substring(pendingPhone.length() - 4);
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Verify OTP — AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800&family=DM+Sans:wght@400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
    font-family: 'DM Sans', sans-serif;
    min-height: 100vh;
    background: linear-gradient(135deg, #0a6ebd, #00b4a6);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
}
.card {
    background: #fff;
    border-radius: 24px;
    box-shadow: 0 24px 64px rgba(10,110,189,.18);
    width: 100%;
    max-width: 480px;
    overflow: hidden;
}
.card-top {
    background: linear-gradient(135deg, #0a6ebd, #00b4a6);
    padding: 28px 32px;
    text-align: center;
    color: #fff;
}
.card-top .logo { font-family: 'Outfit', sans-serif; font-size: 1.4rem; font-weight: 800; margin-bottom: 4px; }
.card-top .logo span { color: #fff9c4; }
.card-top p { opacity: .85; font-size: .875rem; }
.card-body { padding: 28px 32px; }

/* Step indicator */
.steps { display: flex; align-items: center; margin-bottom: 24px; }
.step { display: flex; flex-direction: column; align-items: center; flex: 1; }
.step-circle { width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: .8rem; font-weight: 700; border: 2px solid #dce3ed; background: #fff; color: #6b7c93; }
.step.done   .step-circle { background: #2e7d32; border-color: #2e7d32; color: #fff; }
.step.active .step-circle { background: linear-gradient(135deg, #0a6ebd, #00b4a6); border-color: transparent; color: #fff; }
.step-label { font-size: .62rem; font-weight: 600; color: #6b7c93; margin-top: 4px; }
.step.active .step-label, .step.done .step-label { color: #0a6ebd; font-weight: 700; }
.step-line { flex: 1; height: 2px; background: #dce3ed; margin-bottom: 18px; }
.step-line.done { background: linear-gradient(to right, #2e7d32, #00b4a6); }

/* DEV OTP boxes — shown on screen */
.dev-otp-box {
    border-radius: 12px;
    padding: 14px 18px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
}
.dev-otp-box.email-box {
    background: #e3f2fd;
    border: 1.5px dashed #1565c0;
}
.dev-otp-box.mobile-box {
    background: #e8f5e9;
    border: 1.5px dashed #2e7d32;
}
.dev-otp-label {
    font-size: .75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: .5px;
}
.email-box  .dev-otp-label { color: #1565c0; }
.mobile-box .dev-otp-label { color: #2e7d32; }
.dev-otp-value {
    font-size: 1.5rem;
    font-weight: 800;
    letter-spacing: 6px;
}
.email-box  .dev-otp-value { color: #0a6ebd; }
.mobile-box .dev-otp-value { color: #2e7d32; }
.dev-badge {
    font-size: .65rem;
    background: #ff6b35;
    color: #fff;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 700;
}

/* OTP section */
.otp-section {
    background: #f8f9fa;
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 14px;
    border: 1.5px solid #dce3ed;
}
.otp-section-title {
    font-size: .75rem;
    font-weight: 700;
    color: #0d1b2a;
    text-transform: uppercase;
    letter-spacing: .5px;
    margin-bottom: 3px;
    display: flex;
    align-items: center;
    gap: 6px;
}
.otp-section-sub { font-size: .76rem; color: #6b7c93; margin-bottom: 12px; }
.otp-boxes { display: flex; gap: 7px; justify-content: center; }
.otp-box {
    width: 44px;
    height: 48px;
    border: 2px solid #dce3ed;
    border-radius: 10px;
    font-size: 1.2rem;
    font-weight: 700;
    text-align: center;
    outline: none;
    transition: all .2s;
    color: #0d1b2a;
    background: #fff;
}
.otp-box:focus { border-color: #0a6ebd; box-shadow: 0 0 0 3px rgba(10,110,189,.1); }
.otp-box.filled { border-color: #2e7d32; background: #f0fff4; }

.timer-wrap { display: flex; align-items: center; justify-content: space-between; margin-top: 8px; }
.timer { font-size: .75rem; color: #6b7c93; }
.timer span { color: #0a6ebd; font-weight: 700; }

.btn-verify {
    width: 100%;
    padding: 13px;
    background: linear-gradient(135deg, #0a6ebd, #00b4a6);
    color: #fff;
    border: none;
    border-radius: 12px;
    font-family: 'Outfit', sans-serif;
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    transition: all .2s;
    margin-top: 6px;
}
.btn-verify:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(10,110,189,.3); }

.alert-e { background: #ffebee; color: #c62828; border: 1px solid #ef9a9a; padding: 10px 14px; border-radius: 10px; margin-bottom: 14px; font-size: .85rem; font-weight: 600; }
.alert-s { background: #e8f5e9; color: #2e7d32; border: 1px solid #a5d6a7; padding: 10px 14px; border-radius: 10px; margin-bottom: 14px; font-size: .85rem; font-weight: 600; }

.back-link { text-align: center; margin-top: 14px; font-size: .8rem; color: #6b7c93; }
.back-link a { color: #0a6ebd; font-weight: 700; text-decoration: none; }
</style>
</head>
<body>

<div class="card">
    <div class="card-top">
        <div class="logo">🚗 Auto<span>Prod</span></div>
        <p>Enter the OTPs below to verify your account</p>
    </div>

    <div class="card-body">

        <!-- Steps -->
        <div class="steps">
            <div class="step done">
                <div class="step-circle">✅</div>
                <div class="step-label">Register</div>
            </div>
            <div class="step-line done"></div>
            <div class="step active">
                <div class="step-circle">2</div>
                <div class="step-label">Verify OTP</div>
            </div>
            <div class="step-line"></div>
            <div class="step">
                <div class="step-circle">3</div>
                <div class="step-label">Done!</div>
            </div>
        </div>

        <% if (error   != null) { %>
        <div class="alert-e"><i class="bi bi-exclamation-circle me-2"></i><%= error %></div>
        <% } %>
        <% if (success != null) { %>
        <div class="alert-s"><i class="bi bi-check-circle me-2"></i><%= success %></div>
        <% } %>

        <!-- ── DEV OTP DISPLAY — shown on screen for testing ── -->
        <% if (devEmailOtp != null) { %>
        <div class="dev-otp-box email-box">
            <div>
                <div class="dev-otp-label">📧 Email OTP</div>
                <div class="dev-otp-value"><%= devEmailOtp %></div>
            </div>
            <span class="dev-badge">TESTING</span>
        </div>
        <% } %>

        <% if (devMobileOtp != null) { %>
        <div class="dev-otp-box mobile-box">
            <div>
                <div class="dev-otp-label">📱 Mobile OTP</div>
                <div class="dev-otp-value"><%= devMobileOtp %></div>
            </div>
            <span class="dev-badge">TESTING</span>
        </div>
        <% } %>

        <form method="post" action="<%= ctx %>/verifyOtp">

            <!-- Email OTP input -->
            <div class="otp-section">
                <div class="otp-section-title">
                    <i class="bi bi-envelope-fill" style="color:#0a6ebd;"></i>
                    Email OTP
                </div>
                <div class="otp-section-sub">
                    OTP sent to <strong><%= maskedEmail %></strong>
                    <% if (devEmailOtp == null) { %> — check your inbox! <% } %>
                </div>
                <div class="otp-boxes">
                    <input type="text" class="otp-box" maxlength="1" id="e1" data-next="e2" data-prev="">
                    <input type="text" class="otp-box" maxlength="1" id="e2" data-next="e3" data-prev="e1">
                    <input type="text" class="otp-box" maxlength="1" id="e3" data-next="e4" data-prev="e2">
                    <input type="text" class="otp-box" maxlength="1" id="e4" data-next="e5" data-prev="e3">
                    <input type="text" class="otp-box" maxlength="1" id="e5" data-next="e6" data-prev="e4">
                    <input type="text" class="otp-box" maxlength="1" id="e6" data-next=""   data-prev="e5">
                </div>
                <input type="hidden" name="emailOtp" id="emailOtpHidden">
                <div class="timer-wrap">
                    <div class="timer">Expires in <span id="emailTimer">10:00</span></div>
                </div>
            </div>

            <!-- Mobile OTP input -->
            <div class="otp-section">
                <div class="otp-section-title">
                    <i class="bi bi-phone-fill" style="color:#00b4a6;"></i>
                    Mobile OTP
                </div>
                <div class="otp-section-sub">
                    OTP for <strong>+91 <%= maskedPhone %></strong>
                    <% if (devMobileOtp != null) { %> — shown above! <% } %>
                </div>
                <div class="otp-boxes">
                    <input type="text" class="otp-box" maxlength="1" id="m1" data-next="m2" data-prev="">
                    <input type="text" class="otp-box" maxlength="1" id="m2" data-next="m3" data-prev="m1">
                    <input type="text" class="otp-box" maxlength="1" id="m3" data-next="m4" data-prev="m2">
                    <input type="text" class="otp-box" maxlength="1" id="m4" data-next="m5" data-prev="m3">
                    <input type="text" class="otp-box" maxlength="1" id="m5" data-next="m6" data-prev="m4">
                    <input type="text" class="otp-box" maxlength="1" id="m6" data-next=""   data-prev="m5">
                </div>
                <input type="hidden" name="mobileOtp" id="mobileOtpHidden">
                <div class="timer-wrap">
                    <div class="timer">Expires in <span id="mobileTimer">10:00</span></div>
                </div>
            </div>

            <button type="submit" class="btn-verify" onclick="collectOtps()">
                <i class="bi bi-shield-check me-2"></i>Verify & Activate Account
            </button>

        </form>

        <div class="back-link">
            Wrong details? <a href="<%= ctx %>/customer_login.jsp">Go back to Register</a>
        </div>

    </div>
</div>

<script>
// ── OTP Box Auto-Jump ──
document.querySelectorAll('.otp-box').forEach(function(box) {
    box.addEventListener('input', function() {
        this.value = this.value.replace(/[^0-9]/g, '');
        if (this.value.length === 1 && this.dataset.next) {
            document.getElementById(this.dataset.next).focus();
        }
        this.classList.toggle('filled', this.value.length === 1);
    });
    box.addEventListener('keydown', function(e) {
        if (e.key === 'Backspace' && this.value === '' && this.dataset.prev) {
            document.getElementById(this.dataset.prev).focus();
        }
    });
    // Paste support
    box.addEventListener('paste', function(e) {
        e.preventDefault();
        const text = (e.clipboardData || window.clipboardData)
                     .getData('text').replace(/[^0-9]/g, '');
        const prefix = this.id.charAt(0);
        for (let i = 0; i < Math.min(text.length, 6); i++) {
            const el = document.getElementById(prefix + (i + 1));
            if (el) { el.value = text[i]; el.classList.add('filled'); }
        }
    });
});

// ── Collect OTPs into hidden fields ──
function collectOtps() {
    let emailOtp = '', mobileOtp = '';
    for (let i = 1; i <= 6; i++) {
        emailOtp  += (document.getElementById('e' + i).value || '');
        mobileOtp += (document.getElementById('m' + i).value || '');
    }
    document.getElementById('emailOtpHidden').value  = emailOtp;
    document.getElementById('mobileOtpHidden').value = mobileOtp;
}

// ── Countdown Timer ──
function startTimer(displayId, seconds) {
    let remaining = seconds;
    const display = document.getElementById(displayId);
    const interval = setInterval(function() {
        remaining--;
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        display.textContent = m + ':' + (s < 10 ? '0' : '') + s;
        if (remaining <= 0) {
            clearInterval(interval);
            display.textContent = 'Expired!';
            display.style.color = '#c62828';
        }
    }, 1000);
}

startTimer('emailTimer',  600);
startTimer('mobileTimer', 600);
</script>
</body>
</html>