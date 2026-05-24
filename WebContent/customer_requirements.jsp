<%@ page contentType="text/html;charset=UTF-8" language="java" import="java.sql.*,com.automobile.db.DBConnection"%>
<%
HttpSession sess = request.getSession(false);
if (sess == null || sess.getAttribute("customerName") == null) {
    response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
    return;
}
String customerName = (String) sess.getAttribute("customerName");
int customerId = (int) sess.getAttribute("customerId");
String success = (String) request.getAttribute("success");
String error = (String) request.getAttribute("error");
String activeTab = (String) request.getAttribute("activeTab");
if (activeTab == null) activeTab = "submit";
if ("bulk".equals(activeTab)) activeTab = "bulk";

String welcomeMsg = (String) sess.getAttribute("welcomeMsg");
if (welcomeMsg != null) {
    success = welcomeMsg;
    sess.removeAttribute("welcomeMsg");
}
String ctx = request.getContextPath();
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
    --primary: #0a6ebd;
    --teal: #00b4a6;
    --dark: #0d1b2a;
    --bg: #f0f4f8;
    --border: #dce3ed;
    --light: #6b7c93;
}
* { box-sizing: border-box; }
body { font-family: 'DM Sans', sans-serif; background: var(--bg); margin: 0; }

.navbar { background: #fff; box-shadow: 0 2px 16px rgba(10,110,189,.08); padding: 0 32px; height: 64px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 1000; }
.nav-brand { font-family: 'Outfit', sans-serif; font-weight: 800; font-size: 1.2rem; color: var(--primary); text-decoration: none; }
.nav-brand span { color: var(--teal); }
.nav-links { display: flex; gap: 4px; list-style: none; margin: 0; padding: 0; }
.nav-links a { padding: 8px 14px; border-radius: 8px; color: var(--light); text-decoration: none; font-size: .875rem; font-weight: 500; transition: all .2s; }
.nav-links a:hover, .nav-links a.active { background: #e8f4fd; color: var(--primary); }
.btn-logout { padding: 8px 18px; background: #fff0eb; color: #ff6b35; border: none; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: all .2s; }
.btn-logout:hover { background: #ff6b35; color: #fff; }
.uavatar { width: 34px; height: 34px; border-radius: 50%; background: var(--primary); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: .9rem; }

.main { max-width: 1100px; margin: 0 auto; padding: 28px 24px; }

.portal-tabs { display: flex; background: #fff; border-radius: 12px; padding: 4px; margin-bottom: 24px; box-shadow: 0 2px 12px rgba(0,0,0,.06); width: fit-content; }
.portal-tab { padding: 10px 24px; border: none; background: none; border-radius: 10px; font-family: 'DM Sans', sans-serif; font-size: .875rem; font-weight: 600; color: var(--light); cursor: pointer; transition: all .2s; }
.portal-tab.active { background: linear-gradient(135deg, var(--primary), var(--teal)); color: #fff; box-shadow: 0 4px 12px rgba(10,110,189,.25); }

.tab-pane { display: none; }
.tab-pane.active { display: block; animation: fadeIn .3s ease; }
@keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }

.welcome-banner { background: linear-gradient(135deg, var(--primary), var(--teal)); border-radius: 14px; padding: 20px 26px; color: #fff; margin-bottom: 22px; display: flex; align-items: center; justify-content: space-between; }
.welcome-banner h4 { font-family: 'Outfit', sans-serif; font-weight: 700; margin-bottom: 4px; }
.welcome-banner p { opacity: .85; font-size: .875rem; margin: 0; }

.req-card { background: #fff; border-radius: 16px; box-shadow: 0 4px 24px rgba(10,110,189,.07); overflow: hidden; }
.req-card-header { background: linear-gradient(135deg, var(--primary), var(--teal)); padding: 22px 28px; color: #fff; }
.req-card-header h2 { font-family: 'Outfit', sans-serif; font-size: 1.2rem; font-weight: 700; margin-bottom: 4px; }
.req-card-header p { opacity: .85; font-size: .85rem; margin: 0; }

.req-form { padding: 28px; display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
.req-form .full-width { grid-column: 1 / -1; }
.form-group label { display: block; font-size: .75rem; font-weight: 700; color: var(--dark); margin-bottom: 6px; text-transform: uppercase; letter-spacing: .5px; }
.form-group input, .form-group select, .form-group textarea { width: 100%; padding: 10px 14px; border: 1.5px solid var(--border); border-radius: 10px; font-family: 'DM Sans', sans-serif; font-size: .875rem; outline: none; transition: all .2s; background: #fff; color: var(--dark); }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(10,110,189,.1); }
.form-group input[readonly] { background: #f8f9fa; color: var(--light); }
.form-group textarea { min-height: 110px; resize: vertical; }

/* Vehicle count input with +/- buttons */
.count-wrap { display: flex; align-items: center; border: 1.5px solid var(--border); border-radius: 10px; overflow: hidden; }
.count-btn { width: 40px; height: 40px; border: none; background: #f0f4f8; font-size: 1.1rem; font-weight: 700; cursor: pointer; color: var(--primary); transition: all .2s; flex-shrink: 0; }
.count-btn:hover { background: var(--primary); color: #fff; }
.count-input { flex: 1; border: none; text-align: center; font-size: 1rem; font-weight: 700; color: var(--dark); outline: none; padding: 8px 0; font-family: 'DM Sans', sans-serif; }

.file-wrap { border: 2px dashed var(--border); border-radius: 10px; padding: 20px; text-align: center; cursor: pointer; transition: all .2s; position: relative; overflow: hidden; }
.file-wrap:hover { border-color: var(--primary); background: #f0f7ff; }
.file-wrap input[type=file] { position: absolute; inset: 0; opacity: 0; cursor: pointer; }

.form-actions { grid-column: 1 / -1; display: flex; gap: 10px; justify-content: flex-end; padding-top: 14px; border-top: 1px solid var(--border); }
.btn-submit { padding: 11px 28px; background: linear-gradient(135deg, var(--primary), var(--teal)); color: #fff; border: none; border-radius: 10px; font-family: 'Outfit', sans-serif; font-size: .95rem; font-weight: 700; cursor: pointer; transition: all .2s; }
.btn-submit:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(10,110,189,.3); }
.btn-reset { padding: 11px 20px; background: var(--bg); color: var(--light); border: 1.5px solid var(--border); border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; }

/* Status cards */
.status-card { background: #fff; border-radius: 14px; box-shadow: 0 2px 12px rgba(0,0,0,.06); margin-bottom: 18px; overflow: hidden; }
.sc-header { padding: 16px 22px; border-bottom: 1px solid #f0f0f0; display: flex; align-items: center; justify-content: space-between; }
.sc-body { padding: 18px 22px; }
.sc-title { font-weight: 700; font-size: .95rem; color: var(--dark); }
.sc-meta { font-size: .78rem; color: var(--light); margin-top: 4px; display: flex; flex-wrap: wrap; gap: 8px; }
.sc-meta span { display: flex; align-items: center; gap: 3px; }

/* Status badge */
.sbadge { padding: 5px 12px; border-radius: 20px; font-size: .72rem; font-weight: 700; text-transform: uppercase; white-space: nowrap; }
.s-pending   { background: #fff3e0; color: #e65100; }
.s-in_review { background: #e3f2fd; color: #1565c0; }
.s-completed { background: #e8f5e9; color: #2e7d32; }
.s-rejected  { background: #ffebee; color: #c62828; }

/* Workflow tracker */
.wf-track { display: flex; align-items: center; margin: 14px 0 8px; }
.wf-step { display: flex; flex-direction: column; align-items: center; flex: 1; }
.wf-dot { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: .85rem; border: 2px solid #e0e0e0; background: #fff; transition: all .3s; }
.wf-step.done .wf-dot { background: #2e7d32; border-color: #2e7d32; color: #fff; }
.wf-step.act  .wf-dot { background: linear-gradient(135deg, var(--primary), var(--teal)); border-color: transparent; color: #fff; animation: pulse 1.5s infinite; }
.wf-step.fail .wf-dot { background: #c62828; border-color: #c62828; color: #fff; }
@keyframes pulse { 0%,100%{ box-shadow:0 0 0 0 rgba(10,110,189,.4); } 50%{ box-shadow:0 0 0 8px rgba(10,110,189,0); } }
.wf-lbl { font-size: .62rem; font-weight: 600; color: var(--light); margin-top: 5px; text-align: center; line-height: 1.3; }
.wf-step.done .wf-lbl, .wf-step.act .wf-lbl { color: var(--primary); font-weight: 700; }
.wf-line { flex: 1; height: 2px; background: #e0e0e0; margin-bottom: 22px; }
.wf-line.done { background: linear-gradient(to right, #2e7d32, var(--teal)); }

.stage-box { background: #f8f9fa; border-radius: 10px; padding: 12px 16px; font-size: .84rem; margin-top: 8px; border-left: 3px solid var(--primary); }

.alert-s { background: #e8f5e9; color: #2e7d32; border: 1px solid #a5d6a7; padding: 14px 18px; border-radius: 12px; margin-bottom: 18px; font-weight: 600; }
.alert-e { background: #ffebee; color: #c62828; border: 1px solid #ef9a9a; padding: 14px 18px; border-radius: 12px; margin-bottom: 18px; font-weight: 600; }

.empty-box { text-align: center; padding: 48px 20px; color: var(--light); }
.empty-box i { font-size: 3rem; display: block; margin-bottom: 12px; color: #dce3ed; }

footer { background: var(--dark); color: rgba(255,255,255,.6); text-align: center; padding: 18px; font-size: .8rem; margin-top: 48px; }
footer span { color: var(--teal); font-weight: 600; }

@media (max-width: 768px) {
    .req-form { grid-template-columns: 1fr; }
    .req-form .full-width { grid-column: 1; }
    .main { padding: 16px; }
    .nav-links { display: none; }
    .wf-line { display: none; }
    .wf-track { flex-wrap: wrap; gap: 8px; }
}
</style>
</head>
<body>

<!-- NAVBAR -->
<nav class="navbar">
    <a href="<%= ctx %>/home.jsp" class="nav-brand">🚗 Auto<span>Prod</span></a>
    <ul class="nav-links">
        <li><a href="#" class="active"><i class="bi bi-upload me-1"></i>Upload</a></li>
        <li><a href="#"><i class="bi bi-person-check me-1"></i>Client Request</a></li>
        <li><a href="#"><i class="bi bi-search me-1"></i>Status Check</a></li>
        <li><a href="#"><i class="bi bi-people me-1"></i>Employee Request</a></li>
        <li><a href="#"><i class="bi bi-check2-circle me-1"></i>Data Approval</a></li>
    </ul>
    <div class="d-flex align-items-center gap-2">
        <div class="uavatar"><%= customerName.charAt(0) %></div>
        <span style="font-size:.85rem;font-weight:600;color:var(--dark);"><%= customerName %></span>
        <a href="<%= ctx %>/customerLogout" class="btn-logout">
            <i class="bi bi-box-arrow-right me-1"></i>Logout
        </a>
    </div>
</nav>

<div class="main">

    <!-- Alerts -->
    <% if (success != null) { %>
    <div class="alert-s"><i class="bi bi-check-circle-fill me-2"></i><%= success %></div>
    <% } %>
    <% if (error != null) { %>
    <div class="alert-e"><i class="bi bi-exclamation-circle-fill me-2"></i><%= error %></div>
    <% } %>

    <!-- Welcome Banner -->
    <div class="welcome-banner">
        <div>
            <h4>Welcome, <%= customerName %>! 👋</h4>
            <p>Submit your vehicle requirements or track the status of your existing requests.</p>
        </div>
        <div style="background:rgba(255,255,255,.2);padding:8px 16px;border-radius:20px;font-size:.8rem;font-weight:600;">
            🚗 Customer Portal
        </div>
    </div>

    <!-- Tabs -->
    <div class="portal-tabs">
        <button class="portal-tab <%= "submit".equals(activeTab) ? "active" : "" %>"
                id="btn-submit" onclick="switchTab('submit')">
            <i class="bi bi-plus-circle me-1"></i> Submit Requirement
        </button>
        <button class="portal-tab <%= "bulk".equals(activeTab) ? "active" : "" %>"
                id="btn-bulk" onclick="switchTab('bulk')"
                style="background:<%= "bulk".equals(activeTab) ? "linear-gradient(135deg,#0d9488,#00b4a6)" : "" %>;">
            <i class="bi bi-building me-1"></i> Bulk / Company Order
        </button>
        <button class="portal-tab <%= "track".equals(activeTab) ? "active" : "" %>"
                id="btn-track" onclick="switchTab('track')">
            <i class="bi bi-search me-1"></i> Track Status
        </button>
    </div>

    <!-- ══ TAB 1: SUBMIT ══ -->
    <div class="tab-pane <%= "submit".equals(activeTab) ? "active" : "" %>" id="tab-submit">
        <div class="req-card">
            <div class="req-card-header">
                <h2><i class="bi bi-file-earmark-plus me-2"></i>Submit New Requirement</h2>
                <p>Fill in all required fields. Admin will review and approve within 24 hours.</p>
            </div>
            <form method="post" action="<%= ctx %>/submitRequirement" enctype="multipart/form-data" onsubmit="return validateForm()">
                <div class="req-form">

                    <!-- Row 1: Client Name + Vehicle Category -->
                    <div class="form-group">
                        <label>Client Name *</label>
                        <input type="text" name="clientName" value="<%= customerName %>" readonly>
                    </div>

                    <div class="form-group">
                        <label>Vehicle Type *</label>
                        <select name="moduleName" id="vehicleCategory" required onchange="setVehicleType(this)">
                            <option value="">— Select Vehicle Type —</option>
                            <optgroup label="🏍️ Two Wheelers">
                                <option value="Motorcycle"       data-type="two_wheeler">🏍️ Motorcycle</option>
                                <option value="Scooter"          data-type="two_wheeler">🛵 Scooter</option>
                                <option value="Electric Bike"    data-type="two_wheeler">⚡ Electric Bike</option>
                            </optgroup>
                            <optgroup label="🛺 Three Wheelers">
                                <option value="Auto Rickshaw"    data-type="three_wheeler">🛺 Auto Rickshaw</option>
                                <option value="Electric Auto"    data-type="three_wheeler">⚡ Electric Auto</option>
                                <option value="Cargo Three Wheeler" data-type="three_wheeler">📦 Cargo Three Wheeler</option>
                            </optgroup>
                            <optgroup label="🚗 Cars">
                                <option value="Hatchback"        data-type="car">🚗 Hatchback</option>
                                <option value="Sedan"            data-type="car">🚙 Sedan</option>
                                <option value="SUV"              data-type="car">🚐 SUV / MUV</option>
                                <option value="Electric Car"     data-type="car">⚡ Electric Car</option>
                            </optgroup>
                            <optgroup label="🚐 Vans">
                                <option value="Van"              data-type="van">🚐 Van / Minivan</option>
                                <option value="Cargo Van"        data-type="van">📦 Cargo Van</option>
                                <option value="Staff Van"        data-type="van">👔 Staff Van</option>
                            </optgroup>
                            <optgroup label="🚌 Buses">
                                <option value="Mini Bus"         data-type="bus">🚐 Mini Bus (15-30 seats)</option>
                                <option value="Standard Bus"     data-type="bus">🚌 Standard Bus (30-50 seats)</option>
                                <option value="Large Bus"        data-type="bus">🚌 Large Bus (50+ seats)</option>
                                <option value="Electric Bus"     data-type="bus">⚡ Electric Bus</option>
                                <option value="School Bus"       data-type="bus">🏫 School Bus</option>
                                <option value="Luxury Bus"       data-type="bus">💺 Luxury / Sleeper Bus</option>
                            </optgroup>
                            <optgroup label="🚛 Lorry / Truck">
                                <option value="Light Truck"      data-type="lorry">🚚 Light Commercial Truck</option>
                                <option value="Medium Truck"     data-type="lorry">🚛 Medium Truck</option>
                                <option value="Heavy Truck"      data-type="lorry">🚛 Heavy Truck / Trailer</option>
                                <option value="Tipper"           data-type="lorry">🏗️ Tipper / Dumper</option>
                                <option value="Tanker"           data-type="lorry">🛢️ Tanker</option>
                            </optgroup>
                            <optgroup label="🚜 Heavy Vehicles">
                                <option value="Tractor"          data-type="heavy_vehicle">🚜 Agricultural Tractor</option>
                                <option value="Excavator"        data-type="heavy_vehicle">🏗️ Excavator / JCB</option>
                                <option value="Crane"            data-type="heavy_vehicle">🏗️ Crane</option>
                            </optgroup>
                            <optgroup label="🚑 Special Purpose">
                                <option value="Ambulance"        data-type="special">🚑 Ambulance</option>
                                <option value="Fire Engine"      data-type="special">🚒 Fire Engine</option>
                                <option value="Refrigerated Vehicle" data-type="special">❄️ Refrigerated Vehicle</option>
                                <option value="Defence Vehicle"  data-type="special">🛡️ Defence / Armoured</option>
                            </optgroup>
                            <optgroup label="🔧 Other">
                                <option value="Other"            data-type="special">🔧 Other (describe below)</option>
                            </optgroup>
                        </select>
                        <input type="hidden" name="vehicleType" id="vehicleTypeHidden" value="">
                        <!-- Badge shown after selection -->
                        <div id="vtBadge" style="display:none;margin-top:6px;"></div>
                    </div>

                    <!-- Row 2: Requirement Title -->
                    <div class="form-group full-width">
                        <label>Requirement Title *</label>
                        <input type="text" name="reqTitle"
                               placeholder="Brief title of your requirement" required>
                    </div>

                    <!-- Row 3: Description -->
                    <div class="form-group full-width">
                        <label>Detailed Description *</label>
                        <textarea name="reqDesc"
                                  placeholder="Describe your requirement in detail..." required></textarea>
                    </div>

                    <!-- Row 4: Fuel Type + Budget -->
                    <div class="form-group">
                        <label>Fuel Type *</label>
                        <select name="deadline" required>
                            <option value="">— Select Fuel Type —</option>
                            <option value="Petrol">⛽ Petrol</option>
                            <option value="Diesel">🛢️ Diesel</option>
                            <option value="Electric">⚡ Electric</option>
                            <option value="Hybrid">🔋 Hybrid (Petrol + Electric)</option>
                            <option value="CNG">💨 CNG</option>
                            <option value="LPG">🔵 LPG</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Budget Range *</label>
                        <select name="budget" required>
                            <option value="">— Select Budget —</option>
                            <option value="Under Rs.50,000">Under Rs.50,000</option>
                            <option value="₹50,000 &ndash; ₹1,00,000">₹50,000 &ndash; ₹1,00,000</option>
                            <option value="₹1,00,000 &ndash; ₹5,00,000">₹1,00,000 &ndash; ₹5,00,000</option>
                            <option value="₹5,00,000 &ndash; ₹10,00,000">₹5,00,000 &ndash; ₹10,00,000</option>
                            <option value="Above Rs.10,00,000">Above Rs.10,00,000</option>
                            <option value="To be discussed">To be discussed</option>
                        </select>
                    </div>

                    <!-- Row 5: Vehicle Count ← NEW! -->
                    <div class="form-group">
                        <label>🚗 How Many Vehicles? *</label>
                        <div class="count-wrap">
                            <button type="button" class="count-btn" onclick="changeCount(-1)">−</button>
                            <input type="number" name="vehicleCount" id="vehicleCount"
                                   class="count-input" value="1" min="1" max="10000" required readonly>
                            <button type="button" class="count-btn" onclick="changeCount(1)">+</button>
                        </div>
                        <p style="font-size:.72rem;color:var(--light);margin-top:5px;">
                            Use + / − buttons or type directly
                        </p>
                    </div>

                    <!-- Row 5b: Document Type + Mandatory Upload -->
                    <div class="form-group full-width" style="background:#fff8e1;border:2px solid #ffb300;border-radius:14px;padding:18px 20px;">
                        <div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;">
                            <i class="bi bi-person-badge-fill" style="color:#e65100;font-size:1.1rem;"></i>
                            <label style="margin:0;color:#e65100;font-size:.8rem;font-weight:800;text-transform:uppercase;letter-spacing:.5px;">
                                Identity Verification Document <span style="color:#c62828;">*</span>
                            </label>
                            <span style="background:#c62828;color:#fff;font-size:.65rem;font-weight:700;padding:2px 8px;border-radius:10px;">MANDATORY</span>
                        </div>
                        <p style="font-size:.8rem;color:#6b7c93;margin:0 0 12px;line-height:1.6;">
                            ⚠️ Admin will verify your identity document before approving your requirement.
                            <strong style="color:#e65100;">Fake or invalid documents will be rejected immediately.</strong>
                        </p>
                        <!-- Document Type Selector -->
                        <div class="form-group" style="margin-bottom:12px;">
                            <label style="color:#0d1b2a;">Document Type *</label>
                            <select name="docType" id="docType" required
                                    style="width:100%;padding:10px 14px;border:1.5px solid #ffb300;border-radius:10px;font-size:.875rem;outline:none;background:#fff;">
                                <option value="">— Select Document Type —</option>
                                <option value="Aadhaar Card">🪪 Aadhaar Card</option>
                                <option value="PAN Card">💳 PAN Card</option>
                                <option value="Passport">🛂 Passport</option>
                                <option value="Voter ID">🗳️ Voter ID (Election Card)</option>
                                <option value="Driving Licence">🚗 Driving Licence</option>
                                <option value="Ration Card">📋 Ration Card</option>
                                <option value="Other Government ID">📎 Other Government ID</option>
                            </select>
                        </div>
                        <!-- File Upload -->
                        <div class="file-wrap" id="fileWrap" style="border-color:#ffb300;background:#fffde7;">
                            <input type="file" name="attachment" id="attachmentFile"
                                   accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.xlsx"
                                   onchange="onFileSelected(this)">
                            <i class="bi bi-cloud-upload" style="font-size:1.8rem;color:#e65100;display:block;margin-bottom:6px;"></i>
                            <p style="color:#6b7c93;font-size:.85rem;margin:0;">
                                <span style="color:#e65100;font-weight:700;">Click to upload document</span>
                                — PDF, DOC, JPG, PNG
                            </p>
                        </div>
                        <div id="fn" style="display:none;background:#e8f5e9;border:1.5px solid #a5d6a7;border-radius:8px;padding:8px 14px;margin-top:8px;display:flex;align-items:center;gap:8px;">
                            <i class="bi bi-check-circle-fill" style="color:#2e7d32;"></i>
                            <span id="fnText" style="font-size:.82rem;color:#2e7d32;font-weight:600;"></span>
                        </div>
                    </div>

                    <!-- Actions -->
                    <div class="form-actions">
                        <button type="reset" class="btn-reset"
                                onclick="resetForm()">
                            <i class="bi bi-arrow-counterclockwise me-1"></i>Reset
                        </button>
                        <button type="submit" class="btn-submit" id="submitBtn">
                            <i class="bi bi-send me-1"></i>Submit Requirement
                        </button>
                    </div>

                </div>
            </form>
        </div>
    </div>


    <!-- ══ TAB 2: BULK ORDER ══ -->
    <div class="tab-pane <%= "bulk".equals(activeTab) ? "active" : "" %>" id="tab-bulk">
        <div class="req-card">
            <div class="req-card-header" style="background:linear-gradient(135deg,#042f2e,#0d9488);">
                <h2><i class="bi bi-building me-2"></i>Submit Bulk / Company Order</h2>
                <p>For government, fleet, corporate, or large-quantity orders. Admin will process and assign a project manager.</p>
            </div>
            <form method="post" action="<%= ctx %>/submitBulkOrder" enctype="multipart/form-data" onsubmit="return validateBulkForm()">
                <input type="hidden" name="portal_type" value="bulk">
                <div class="req-form">

                    <!-- Row 1: Company Name + Contact Person -->
                    <div class="form-group">
                        <label>Company / Organisation Name *</label>
                        <input type="text" name="companyName"
                               placeholder="e.g. Tamil Nadu State Transport Corp"
                               required>
                    </div>
                    <div class="form-group">
                        <label>Contact Person Name *</label>
                        <input type="text" name="contactPerson"
                               value="<%= customerName %>" required>
                    </div>

                    <!-- Row 2: Order Title + Vehicle Type -->
                    <div class="form-group">
                        <label>Order Title *</label>
                        <input type="text" name="orderTitle"
                               placeholder="e.g. Fleet of 50 Electric Buses"
                               required>
                    </div>
                    <div class="form-group">
                        <label>Vehicle Type *</label>
                        <select name="moduleName" id="bulkVehicleCategory" required onchange="setBulkVehicleType(this)">
                            <option value="">— Select Vehicle Type —</option>
                            <optgroup label="🏍️ Two Wheelers">
                                <option value="Motorcycle"       data-type="two_wheeler">🏍️ Motorcycle</option>
                                <option value="Scooter"          data-type="two_wheeler">🛵 Scooter</option>
                                <option value="Electric Bike"    data-type="two_wheeler">⚡ Electric Bike</option>
                            </optgroup>
                            <optgroup label="🛺 Three Wheelers">
                                <option value="Auto Rickshaw"    data-type="three_wheeler">🛺 Auto Rickshaw</option>
                                <option value="Electric Auto"    data-type="three_wheeler">⚡ Electric Auto</option>
                                <option value="Cargo Three Wheeler" data-type="three_wheeler">📦 Cargo Three Wheeler</option>
                            </optgroup>
                            <optgroup label="🚗 Cars">
                                <option value="Hatchback"        data-type="car">🚗 Hatchback</option>
                                <option value="Sedan"            data-type="car">🚙 Sedan</option>
                                <option value="SUV"              data-type="car">🚐 SUV / MUV</option>
                                <option value="Electric Car"     data-type="car">⚡ Electric Car</option>
                            </optgroup>
                            <optgroup label="🚐 Vans">
                                <option value="Van"              data-type="van">🚐 Van / Minivan</option>
                                <option value="Cargo Van"        data-type="van">📦 Cargo Van</option>
                                <option value="Staff Van"        data-type="van">👔 Staff Van</option>
                            </optgroup>
                            <optgroup label="🚌 Buses">
                                <option value="Mini Bus"         data-type="bus">🚐 Mini Bus</option>
                                <option value="Standard Bus"     data-type="bus">🚌 Standard Bus</option>
                                <option value="Large Bus"        data-type="bus">🚌 Large Bus (50+ seats)</option>
                                <option value="Electric Bus"     data-type="bus">⚡ Electric Bus</option>
                                <option value="School Bus"       data-type="bus">🏫 School Bus</option>
                                <option value="Luxury Bus"       data-type="bus">💺 Luxury / Sleeper Bus</option>
                            </optgroup>
                            <optgroup label="🚛 Lorry / Truck">
                                <option value="Light Truck"      data-type="lorry">🚚 Light Truck</option>
                                <option value="Medium Truck"     data-type="lorry">🚛 Medium Truck</option>
                                <option value="Heavy Truck"      data-type="lorry">🚛 Heavy Truck / Trailer</option>
                                <option value="Tipper"           data-type="lorry">🏗️ Tipper / Dumper</option>
                                <option value="Tanker"           data-type="lorry">🛢️ Tanker</option>
                            </optgroup>
                            <optgroup label="🚜 Heavy Vehicles">
                                <option value="Tractor"          data-type="heavy_vehicle">🚜 Agricultural Tractor</option>
                                <option value="Excavator"        data-type="heavy_vehicle">🏗️ Excavator / JCB</option>
                                <option value="Crane"            data-type="heavy_vehicle">🏗️ Crane</option>
                            </optgroup>
                            <optgroup label="🚑 Special Purpose">
                                <option value="Ambulance"        data-type="special">🚑 Ambulance</option>
                                <option value="Fire Engine"      data-type="special">🚒 Fire Engine</option>
                                <option value="Refrigerated Vehicle" data-type="special">❄️ Refrigerated Vehicle</option>
                                <option value="Defence Vehicle"  data-type="special">🛡️ Defence / Armoured</option>
                            </optgroup>
                            <optgroup label="🔧 Other">
                                <option value="Other"            data-type="special">🔧 Other</option>
                            </optgroup>
                        </select>
                        <input type="hidden" name="vehicleType" id="bulkVehicleTypeHidden" value="">
                        <div id="bulkVtBadge" style="display:none;margin-top:6px;"></div>
                    </div>

                    <!-- Row 3: Quantity + Budget -->
                    <div class="form-group">
                        <label>🚗 Number of Vehicles Required *</label>
                        <div class="count-wrap">
                            <button type="button" class="count-btn" onclick="changeBulkCount(-10)">−</button>
                            <input type="number" name="vehicleCount" id="bulkVehicleCount"
                                   class="count-input" value="10" min="1" max="100000" required>
                            <button type="button" class="count-btn" onclick="changeBulkCount(10)">+</button>
                        </div>
                        <p style="font-size:.72rem;color:var(--light);margin-top:5px;">Use +/− or type directly. Minimum 1 vehicle.</p>
                    </div>

                    <div class="form-group">
                        <label>Estimated Budget *</label>
                        <select name="budget" required>
                            <option value="">— Select Budget Range —</option>
                            <option value="Under Rs.10 Lakh">Under ₹10 Lakh</option>
                            <option value="Rs.10L - Rs.50L">₹10 Lakh – ₹50 Lakh</option>
                            <option value="Rs.50L - Rs.1 Cr">₹50 Lakh – ₹1 Crore</option>
                            <option value="Rs.1Cr - Rs.5Cr">₹1 Crore – ₹5 Crore</option>
                            <option value="Rs.5Cr - Rs.25Cr">₹5 Crore – ₹25 Crore</option>
                            <option value="Above Rs.25Cr">Above ₹25 Crore</option>
                            <option value="To be negotiated">To be negotiated</option>
                        </select>
                    </div>

                    <!-- Row 4: Fuel Type + Delivery Timeline -->
                    <div class="form-group">
                        <label>Fuel Type *</label>
                        <select name="deadline" required>
                            <option value="">— Select Fuel Type —</option>
                            <option value="Petrol">⛽ Petrol</option>
                            <option value="Diesel">🛢️ Diesel</option>
                            <option value="Electric">⚡ Electric</option>
                            <option value="Hybrid">🔋 Hybrid</option>
                            <option value="CNG">💨 CNG</option>
                            <option value="LPG">🔵 LPG</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label>Delivery Timeline *</label>
                        <select name="deliveryTimeline" required>
                            <option value="">— Select Timeline —</option>
                            <option value="Within 1 month">Within 1 Month</option>
                            <option value="1-3 months">1 – 3 Months</option>
                            <option value="3-6 months">3 – 6 Months</option>
                            <option value="6-12 months">6 – 12 Months</option>
                            <option value="Above 1 year">Above 1 Year</option>
                            <option value="Flexible">Flexible / Open</option>
                        </select>
                    </div>

                    <!-- Row 5: Full Description -->
                    <div class="form-group full-width">
                        <label>Order Description / Special Requirements *</label>
                        <textarea name="reqDesc"
                                  placeholder="Describe your order in detail — specifications, features, colours, modifications, usage purpose, delivery location, etc."
                                  required style="min-height:130px;"></textarea>
                    </div>

                    <!-- Row 6: Mandatory Document Upload -->
                    <div class="form-group full-width" style="background:#fff8e1;border:2px solid #ffb300;border-radius:14px;padding:18px 20px;">
                        <div style="display:flex;align-items:center;gap:8px;margin-bottom:14px;">
                            <i class="bi bi-shield-lock-fill" style="color:#e65100;font-size:1.1rem;"></i>
                            <label style="margin:0;color:#e65100;font-size:.8rem;font-weight:800;text-transform:uppercase;letter-spacing:.5px;">
                                Company Verification Document <span style="color:#c62828;">*</span>
                            </label>
                            <span style="background:#c62828;color:#fff;font-size:.65rem;font-weight:700;padding:2px 8px;border-radius:10px;">MANDATORY</span>
                        </div>
                        <p style="font-size:.8rem;color:#6b7c93;margin:0 0 12px;line-height:1.6;">
                            ⚠️ Bulk orders require company verification. Upload an official document.
                            <strong style="color:#e65100;">Fake documents will be rejected and reported.</strong>
                        </p>
                        <div class="form-group" style="margin-bottom:12px;">
                            <label style="color:#0d1b2a;">Document Type *</label>
                            <select name="docType" required
                                    style="width:100%;padding:10px 14px;border:1.5px solid #ffb300;border-radius:10px;font-size:.875rem;outline:none;background:#fff;">
                                <option value="">— Select Document Type —</option>
                                <option value="GST Certificate">🏢 GST Certificate</option>
                                <option value="Company Registration Certificate">📋 Company Registration Certificate</option>
                                <option value="Purchase Order">📄 Purchase Order (PO)</option>
                                <option value="Letter of Intent">✉️ Letter of Intent (LOI)</option>
                                <option value="Government Tender Document">🏛️ Government Tender Document</option>
                                <option value="Company Letterhead with Stamp">🖊️ Company Letterhead with Stamp</option>
                                <option value="Other Official Document">📎 Other Official Document</option>
                            </select>
                        </div>
                        <div class="file-wrap" id="bulkFileWrap" style="border-color:#ffb300;background:#fffde7;">
                            <input type="file" name="attachment" id="bulkAttachmentFile"
                                   accept=".pdf,.doc,.docx,.jpg,.jpeg,.png,.xlsx"
                                   onchange="onBulkFileSelected(this)">
                            <i class="bi bi-cloud-upload" style="font-size:1.8rem;color:#e65100;display:block;margin-bottom:6px;"></i>
                            <p style="color:#6b7c93;font-size:.85rem;margin:0;">
                                <span style="color:#e65100;font-weight:700;">Click to upload document</span>
                                — PDF, DOC, JPG, PNG
                            </p>
                        </div>
                        <p id="bulkFileNameDisplay" style="display:none;margin-top:8px;font-size:.8rem;color:#2e7d32;font-weight:600;"></p>
                    </div>

                    <!-- Submit Actions -->
                    <div class="form-actions">
                        <button type="reset" class="btn-reset" onclick="resetBulkForm()">
                            <i class="bi bi-arrow-counterclockwise me-1"></i>Reset
                        </button>
                        <button type="submit" class="btn-submit" id="bulkSubmitBtn"
                                style="background:linear-gradient(135deg,#0d9488,#00b4a6);">
                            <i class="bi bi-send me-1"></i>Submit Bulk Order
                        </button>
                    </div>

                </div>
            </form>
        </div>
    </div>

    <!-- ══ TAB 3: TRACK ══ -->
    <div class="tab-pane <%= "track".equals(activeTab) ? "active" : "" %>" id="tab-track">
        <%
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement ps2 = conn.prepareStatement(
                "SELECT * FROM customer_requirements WHERE customer_id=? ORDER BY submitted_at DESC");
            ps2.setInt(1, customerId);
            ResultSet rs = ps2.executeQuery();
            int cnt = 0;

            while (rs.next()) {
                cnt++;
                String stage  = rs.getString("workflow_stage"); if (stage  == null) stage  = "submitted";
                String status = rs.getString("status");         if (status == null) status = "pending";
                int    reqNum = rs.getInt("req_number");
                int    vCount = rs.getInt("vehicle_count");

                // ── Stage booleans ──
                boolean adminApproved = !stage.equals("submitted") &&
                    !stage.equals("admin_initial_review") &&
                    !stage.equals("admin_initial_rejected");
                boolean designDone = stage.equals("design_completed") || stage.equals("qc_review") ||
                    stage.equals("qc_approved") || stage.equals("testing_review") ||
                    stage.equals("testing_completed") || stage.equals("analytics_review") ||
                    stage.equals("analytics_completed") || stage.equals("completed");
                boolean qcDone = stage.equals("qc_approved") || stage.equals("testing_review") ||
                    stage.equals("testing_completed") || stage.equals("analytics_review") ||
                    stage.equals("analytics_completed") || stage.equals("completed");
                boolean testingDone = stage.equals("testing_completed") || stage.equals("analytics_review") ||
                    stage.equals("analytics_completed") || stage.equals("completed");
                boolean analyticsDone = stage.equals("analytics_completed") || stage.equals("completed");
                boolean finalDone = stage.equals("completed");

                boolean adminActive    = stage.equals("admin_initial_review");
                boolean designActive   = stage.equals("admin_initial_approved") || stage.equals("design_review") || stage.equals("qc_rejected");
                boolean qcActive       = stage.equals("qc_review");
                boolean testingActive  = stage.equals("testing_review");
                boolean analyticsActive= stage.equals("analytics_review");
                boolean finalActive    = stage.equals("analytics_completed");
                boolean isRejected     = stage.equals("admin_initial_rejected") || stage.equals("rejected");

                // ── Status message ──
                String msg; String msgColor;
                if      (finalDone)        { msg = "🎉 COMPLETED! Our team will contact you shortly.";               msgColor = "#2e7d32"; }
                else if (isRejected)       { msg = "❌ Requirement was rejected. Please contact our team.";         msgColor = "#c62828"; }
                else if (adminActive)      { msg = "⏳ Awaiting Admin review. You will be notified once approved.";  msgColor = "#e65100"; }
                else if (designActive)     { msg = "🎨 Admin approved! Design team is now working on your requirement."; msgColor = "#1565c0"; }
                else if (qcActive)         { msg = "✅ Under QC review.";                                           msgColor = "#2e7d32"; }
                else if (testingActive)    { msg = "🔬 Testing team is validating your requirement.";               msgColor = "#e65100"; }
                else if (analyticsActive)  { msg = "📊 Analytics team is generating the report.";                   msgColor = "#6a1b9a"; }
                else if (finalActive)      { msg = "👑 Awaiting final Admin approval.";                             msgColor = "#0d1b2a"; }
                else                       { msg = "📋 Submitted. Awaiting Admin review.";                          msgColor = "#6b7c93"; }

                String subDate = rs.getTimestamp("submitted_at") != null
                               ? rs.getTimestamp("submitted_at").toString().substring(0,10) : "";
        %>
        <div class="status-card">
            <div class="sc-header">
                <div>
                    <!-- ✅ Shows req_number per customer -->
                    <div class="sc-title">
                        Requirement #<%= reqNum %> — <%= rs.getString("req_title") %>
                    </div>
                    <div class="sc-meta">
                        <span><i class="bi bi-grid"></i> <%= rs.getString("module_name") %></span>
                        <span><i class="bi bi-currency-rupee"></i> <%= rs.getString("budget") %></span>
                        <span><i class="bi bi-fuel-pump"></i> <%= rs.getString("deadline") %></span>
                        <!-- ✅ Shows vehicle count -->
                        <span><i class="bi bi-truck"></i> <%= vCount %> Vehicle<%= vCount > 1 ? "s" : "" %></span>
                        <span><i class="bi bi-calendar"></i> Submitted: <%= subDate %></span>
                    </div>
                </div>
                <!-- ✅ Status badge -->
                <span class="sbadge s-<%= status %>">
                    <%
                    if      ("pending".equals(status))   out.print("⏳ Pending");
                    else if ("in_review".equals(status)) out.print("🔄 In Review");
                    else if ("completed".equals(status)) out.print("✅ Completed");
                    else if ("rejected".equals(status))  out.print("❌ Rejected");
                    else                                  out.print(status.replace("_"," "));
                    %>
                </span>
            </div>
            <div class="sc-body">
                <!-- Workflow Progress Tracker -->
                <div class="wf-track">

                    <div class="wf-step done">
                        <div class="wf-dot">✅</div>
                        <div class="wf-lbl">Submitted</div>
                    </div>
                    <div class="wf-line <%= adminApproved ? "done" : "" %>"></div>

                    <div class="wf-step <%= isRejected && stage.equals("admin_initial_rejected") ? "fail" : adminApproved ? "done" : adminActive ? "act" : "" %>">
                        <div class="wf-dot">
                            <%= isRejected && stage.equals("admin_initial_rejected") ? "❌" : adminApproved ? "✅" : "👑" %>
                        </div>
                        <div class="wf-lbl">Admin Review</div>
                    </div>
                    <div class="wf-line <%= designDone ? "done" : "" %>"></div>

                    <div class="wf-step <%= designDone ? "done" : designActive ? "act" : "" %>">
                        <div class="wf-dot"><%= designDone ? "✅" : "🎨" %></div>
                        <div class="wf-lbl">Design</div>
                    </div>
                    <div class="wf-line <%= qcDone ? "done" : "" %>"></div>

                    <div class="wf-step <%= qcDone ? "done" : isRejected && stage.equals("qc_rejected") ? "fail" : qcActive ? "act" : "" %>">
                        <div class="wf-dot"><%= qcDone ? "✅" : isRejected && stage.equals("qc_rejected") ? "❌" : "✅" %></div>
                        <div class="wf-lbl">QC Review</div>
                    </div>
                    <div class="wf-line <%= testingDone ? "done" : "" %>"></div>

                    <div class="wf-step <%= testingDone ? "done" : testingActive ? "act" : "" %>">
                        <div class="wf-dot"><%= testingDone ? "✅" : "🔬" %></div>
                        <div class="wf-lbl">Testing</div>
                    </div>
                    <div class="wf-line <%= analyticsDone ? "done" : "" %>"></div>

                    <div class="wf-step <%= analyticsDone ? "done" : analyticsActive ? "act" : "" %>">
                        <div class="wf-dot"><%= analyticsDone ? "✅" : "📊" %></div>
                        <div class="wf-lbl">Analytics</div>
                    </div>
                    <div class="wf-line <%= finalDone ? "done" : "" %>"></div>

                    <div class="wf-step <%= finalDone ? "done" : finalActive ? "act" : "" %>">
                        <div class="wf-dot"><%= finalDone ? "✅" : "🚗" %></div>
                        <div class="wf-lbl">Completed</div>
                    </div>

                </div>

                <div class="stage-box">
                    <strong>Current Status:</strong>
                    <span style="color:<%= msgColor %>;font-weight:600;margin-left:4px;"><%= msg %></span>
                </div>
            </div>
        </div>
        <%
            }
            if (cnt == 0) {
        %>
        <div class="empty-box">
            <i class="bi bi-inbox"></i>
            <h5>No Requirements Yet</h5>
            <p>Submit your first requirement using the Submit Requirement tab!</p>
            <button class="btn-submit" onclick="switchTab('submit')" style="margin-top:8px;">
                <i class="bi bi-plus-circle me-1"></i> Submit First Requirement
            </button>
        </div>
        <%
            }
        } catch (Exception ex) {
        %>
        <div class="alert-e"><i class="bi bi-exclamation-circle me-2"></i>Error: <%= ex.getMessage() %></div>
        <% } %>
    </div>

</div>

<footer><p>© 2026 <span>AutoProd</span> Manufacturing Systems. All rights reserved.</p></footer>

<script>
    // Tab switch
    function switchTab(t) {
        ['submit','bulk','track'].forEach(function(id) {
            document.getElementById('tab-' + id).classList.toggle('active', id === t);
            document.getElementById('btn-' + id).classList.toggle('active', id === t);
        });
    }

    // Vehicle count +/- buttons
    function changeCount(delta) {
        var input = document.getElementById('vehicleCount');
        var val = parseInt(input.value) + delta;
        if (val < 1)     val = 1;
        if (val > 10000) val = 10000;
        input.value = val;
    }

    // Allow direct typing in count input
    var vcInput = document.getElementById('vehicleCount');
    if (vcInput) vcInput.removeAttribute('readonly');

    // File selected handler
    function onFileSelected(input) {
        var fnDiv  = document.getElementById('fn');
        var fnText = document.getElementById('fnText');
        var wrap   = document.getElementById('fileWrap');
        if (input.files && input.files[0]) {
            fnText.textContent = '✅ ' + input.files[0].name;
            fnDiv.style.display = 'flex';
            wrap.style.borderColor = '#2e7d32';
            wrap.style.background  = '#f1f8f1';
        } else {
            fnDiv.style.display = 'none';
            wrap.style.borderColor = '#ffb300';
            wrap.style.background  = '#fffde7';
        }
    }

    // Reset form
    function resetForm() {
        document.querySelector('form').reset();
        document.getElementById('fn').style.display = 'none';
        document.getElementById('vehicleCount').value = 1;
        var wrap = document.getElementById('fileWrap');
        wrap.style.borderColor = '#ffb300';
        wrap.style.background  = '#fffde7';
    }

    // Validate form — document + docType are MANDATORY
    function validateForm() {
        var count   = parseInt(document.getElementById('vehicleCount').value);
        var docType = document.getElementById('docType').value;
        var file    = document.getElementById('attachmentFile').files.length;

        if (isNaN(count) || count < 1) {
            showError('Please enter at least 1 vehicle!');
            return false;
        }
        if (!docType) {
            showError('Please select the Document Type!');
            document.getElementById('docType').focus();
            return false;
        }
        if (file === 0) {
            showError('Identity Verification Document is MANDATORY! Please upload your Aadhaar, PAN, or other ID document to proceed.');
            document.getElementById('fileWrap').style.borderColor = '#c62828';
            document.getElementById('fileWrap').style.background  = '#ffebee';
            return false;
        }
        return true;
    }

    function showError(msg) {
        var existing = document.getElementById('validErr');
        if (existing) existing.remove();
        var div = document.createElement('div');
        div.id = 'validErr';
        div.style.cssText = 'background:#ffebee;border:1.5px solid #ef9a9a;border-radius:10px;padding:12px 18px;margin-bottom:14px;color:#c62828;font-weight:600;font-size:.875rem;';
        div.innerHTML = '<i class="bi bi-exclamation-circle-fill me-2"></i>' + msg;
        document.querySelector('.main').insertBefore(div, document.querySelector('.portal-tabs'));
        window.scrollTo({top:0, behavior:'smooth'});
    }

// ── Vehicle Type auto-routing ──
var vtLabels = {
    'two_wheeler':   '🏍️ Two Wheeler',
    'three_wheeler': '🛺 Three Wheeler',
    'car':           '🚗 Car',
    'van':           '🚐 Van',
    'bus':           '🚌 Bus',
    'lorry':         '🚛 Lorry / Truck',
    'heavy_vehicle': '🚜 Heavy Vehicle',
    'special':       '🚑 Special Purpose'
};
function setVehicleType(sel) {
    var opt = sel.options[sel.selectedIndex];
    var vt  = opt.getAttribute('data-type') || '';
    document.getElementById('vehicleTypeHidden').value = vt;
    var badge = document.getElementById('vtBadge');
    if(vt) {
        badge.style.display = 'block';
        badge.innerHTML = '<span style="background:#e0f7f5;color:#0f766e;padding:4px 12px;border-radius:20px;font-size:.75rem;font-weight:700;">' +
            (vtLabels[vt]||vt) + ' — will be routed to specialist designer</span>';
    } else {
        badge.style.display = 'none';
    }
}

    // ── Bulk Order helpers ──
    var bulkVtLabels = {
        'two_wheeler':'🏍️ Two Wheeler','three_wheeler':'🛺 Three Wheeler',
        'car':'🚗 Car','van':'🚐 Van','bus':'🚌 Bus',
        'lorry':'🚛 Lorry / Truck','heavy_vehicle':'🚜 Heavy Vehicle','special':'🚑 Special Purpose'
    };
    function setBulkVehicleType(sel) {
        var opt = sel.options[sel.selectedIndex];
        var vt  = opt.getAttribute('data-type') || '';
        document.getElementById('bulkVehicleTypeHidden').value = vt;
        var badge = document.getElementById('bulkVtBadge');
        if (vt) {
            badge.style.display = 'block';
            badge.innerHTML = '<span style="background:#e0f7f5;color:#0f766e;padding:4px 12px;border-radius:20px;font-size:.75rem;font-weight:700;">' +
                (bulkVtLabels[vt]||vt) + ' — specialist team will handle this order</span>';
        } else { badge.style.display = 'none'; }
    }
    function changeBulkCount(delta) {
        var input = document.getElementById('bulkVehicleCount');
        var val = parseInt(input.value) + delta;
        if (val < 1) val = 1;
        if (val > 100000) val = 100000;
        input.value = val;
    }
    function onBulkFileSelected(input) {
        var disp = document.getElementById('bulkFileNameDisplay');
        if (input.files && input.files[0]) {
            disp.style.display = 'block';
            disp.textContent = '✅ ' + input.files[0].name;
            document.getElementById('bulkFileWrap').style.borderColor = '#4caf50';
        }
    }
    function resetBulkForm() {
        document.getElementById('bulkVehicleTypeHidden').value = '';
        document.getElementById('bulkVtBadge').style.display = 'none';
        document.getElementById('bulkVehicleCount').value = 10;
        document.getElementById('bulkFileNameDisplay').style.display = 'none';
        document.getElementById('bulkFileWrap').style.borderColor = '#ffb300';
    }
    function validateBulkForm() {
        var sm = document.getElementById('bulkSubmitBtn');
        if (!document.getElementById('bulkVehicleTypeHidden').value) {
            alert('Please select a Vehicle Type.');
            return false;
        }
        if (!document.getElementById('bulkAttachmentFile').files.length) {
            alert('Company verification document is mandatory for bulk orders.');
            return false;
        }
        sm.disabled = true;
        sm.innerHTML = '<i class="bi bi-hourglass-split me-1"></i>Submitting...';
        return true;
    }
</script>
</body>
</html>


