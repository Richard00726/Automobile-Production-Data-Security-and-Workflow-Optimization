<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,
                 com.automobile.util.PasswordUtil,
                 java.util.*" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../../index.jsp"); return;
    }
    if (!"admin".equals(sess.getAttribute("role"))) {
        response.sendRedirect("../../dashboard.jsp"); return;
    }
    String fullName = (String) sess.getAttribute("fullName");
    String initial  = (fullName != null && !fullName.isEmpty()) ? String.valueOf(fullName.charAt(0)).toUpperCase() : "A";

    String msg = "", msgType = "";
    String action = request.getParameter("action");

    // ADD
    if ("add".equals(action)) {
        String vtype = request.getParameter("vehicle_type");
        String fname = request.getParameter("full_name");
        String uname = request.getParameter("username");
        String pwd   = request.getParameter("password");
        if (vtype!=null && fname!=null && uname!=null && pwd!=null
                && !vtype.trim().isEmpty() && !fname.trim().isEmpty()
                && !uname.trim().isEmpty() && !pwd.trim().isEmpty()) {
            try (Connection conn = DBConnection.getConnection()) {
                PreparedStatement chk = conn.prepareStatement("SELECT COUNT(*) FROM users WHERE CONVERT(username USING utf8mb4) COLLATE utf8mb4_general_ci = CONVERT(? USING utf8mb4) COLLATE utf8mb4_general_ci");
                chk.setString(1, uname.trim().toLowerCase());
                ResultSet cr = chk.executeQuery();
                int exists = cr.next() ? cr.getInt(1) : 0;
                if (exists > 0) {
                    msg = "Username already taken."; msgType = "error";
                } else {
                    int nextSlot = 1;
                    PreparedStatement slotQ = conn.prepareStatement(
                        "SELECT COALESCE(MAX(slot_number),0)+1 AS ns FROM vehicle_designers WHERE vehicle_type=?");
                    slotQ.setString(1, vtype.trim());
                    ResultSet sr = slotQ.executeQuery();
                    if (sr.next()) nextSlot = sr.getInt("ns");
                    String hp = PasswordUtil.hashPassword(pwd.trim());
                    PreparedStatement pu = conn.prepareStatement(
                        "INSERT INTO users (full_name,username,password,role,is_active) VALUES (?,?,?,'design',1)");
                    pu.setString(1, fname.trim()); pu.setString(2, uname.trim().toLowerCase()); pu.setString(3, hp);
                    pu.executeUpdate();
                    PreparedStatement pd = conn.prepareStatement(
                        "INSERT INTO vehicle_designers (vehicle_type,slot_number,full_name,username,is_active) VALUES (?,?,?,?,1)");
                    pd.setString(1, vtype.trim()); pd.setInt(2, nextSlot);
                    pd.setString(3, fname.trim()); pd.setString(4, uname.trim().toLowerCase());
                    pd.executeUpdate();
                    PreparedStatement pr = conn.prepareStatement(
                        "INSERT IGNORE INTO designer_round_robin (vehicle_type,stream,last_slot_used,total_assigned) VALUES (?,?,0,0)");
                    pr.setString(1, vtype.trim()); pr.setString(2, "internal"); pr.executeUpdate();
                    pr.setString(1, vtype.trim()); pr.setString(2, "external"); pr.executeUpdate();
                    msg = fname.trim() + " added as Slot " + nextSlot + " for " + vtype.trim().replace("_"," ").toUpperCase();
                    msgType = "success";
                }
            } catch (Exception e) { msg = "Error: " + e.getMessage(); msgType = "error"; }
        } else { msg = "All fields are required."; msgType = "error"; }
    }

    // TOGGLE
    if ("toggle".equals(action)) {
        String didStr = request.getParameter("did");
        String curStr = request.getParameter("cur");
        if (didStr != null && curStr != null) {
            try (Connection conn = DBConnection.getConnection()) {
                int did = Integer.parseInt(didStr.trim());
                int nv  = "1".equals(curStr.trim()) ? 0 : 1;
                PreparedStatement gu = conn.prepareStatement("SELECT username FROM vehicle_designers WHERE id=?");
                gu.setInt(1, did); ResultSet ur = gu.executeQuery();
                if (ur.next()) {
                    String un2 = ur.getString("username");
                    PreparedStatement u1 = conn.prepareStatement("UPDATE vehicle_designers SET is_active=? WHERE id=?");
                    u1.setInt(1,nv); u1.setInt(2,did); u1.executeUpdate();
                    PreparedStatement u2 = conn.prepareStatement("UPDATE users SET is_active=? WHERE username=?");
                    u2.setInt(1,nv); u2.setString(2,un2); u2.executeUpdate();
                }
                msg = nv==1 ? "Designer activated." : "Designer deactivated."; msgType = "success";
            } catch (Exception e) { msg = "Error: " + e.getMessage(); msgType = "error"; }
        }
    }

    // DELETE
    if ("delete".equals(action)) {
        String didStr = request.getParameter("did");
        if (didStr != null) {
            try (Connection conn = DBConnection.getConnection()) {
                int did = Integer.parseInt(didStr.trim());
                PreparedStatement gu = conn.prepareStatement("SELECT username,vehicle_type FROM vehicle_designers WHERE id=?");
                gu.setInt(1, did); ResultSet dr = gu.executeQuery();
                if (dr.next()) {
                    String un2 = dr.getString("username");
                    String vt2 = dr.getString("vehicle_type");
                    conn.prepareStatement("DELETE FROM vehicle_designers WHERE id="+did).executeUpdate();
                    ResultSet rem = conn.createStatement().executeQuery(
                        "SELECT id FROM vehicle_designers WHERE vehicle_type='"+vt2.replace("'","''")+"' ORDER BY slot_number");
                    int sn=1;
                    while (rem.next()) {
                        PreparedStatement rn = conn.prepareStatement("UPDATE vehicle_designers SET slot_number=? WHERE id=?");
                        rn.setInt(1,sn++); rn.setInt(2,rem.getInt("id")); rn.executeUpdate();
                    }
                    PreparedStatement rs = conn.prepareStatement(
                        "UPDATE designer_round_robin SET last_slot_used=0 WHERE vehicle_type=?");
                    rs.setString(1,vt2); rs.executeUpdate();
                    PreparedStatement du = conn.prepareStatement("UPDATE users SET is_active=0 WHERE username=?");
                    du.setString(1,un2); du.executeUpdate();
                }
                msg = "Designer removed from pool."; msgType = "success";
            } catch (Exception e) { msg = "Error: " + e.getMessage(); msgType = "error"; }
        }
    }

    String[][] vtypes = {
        {"two_wheeler",   "Two Wheeler",    "Bike, Scooter, Electric 2W",          "\uD83C\uDFCD\uFE0F"},
        {"three_wheeler", "Three Wheeler",  "Auto, Electric Auto, Cargo 3W",        "\uD83D\uDEFA"},
        {"car",           "Car",            "Hatchback, Sedan, SUV, EV",            "\uD83D\uDE97"},
        {"van",           "Van",            "Minivan, Cargo Van, Staff Van",         "\uD83D\uDE90"},
        {"bus",           "Bus",            "Mini, Standard, Luxury, Electric Bus", "\uD83D\uDE8C"},
        {"lorry",         "Lorry / Truck",  "Light/Heavy Truck, Tipper, Tanker",    "\uD83D\uDE9B"},
        {"heavy_vehicle", "Heavy Vehicle",  "Tractor, JCB, Excavator, Crane",       "\uD83D\uDE9C"},
        {"special",       "Special Purpose","Ambulance, Fire Engine, Defence",       "\uD83D\uDE91"}
    };
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Manage Design Team — AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<style>
:root{--sw:260px;--brand:#0f1f5c;--blue:#1d4ed8;--bg:#f0f3f9;--border:#e5e9f2;--muted:#6b7280;}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:'Plus Jakarta Sans',sans-serif;color:#1a1f36;}
.sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
.sb-top{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
.sb-brand{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;}
.sb-sub{font-size:.64rem;color:rgba(255,255,255,.32);letter-spacing:.5px;margin-top:2px;}
.sb-user{padding:14px 20px;border-bottom:1px solid rgba(255,255,255,.08);display:flex;align-items:center;gap:12px;}
.sb-av{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#e53935,#ff8a65);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.9rem;flex-shrink:0;}
.sb-uname{font-size:.84rem;font-weight:700;}
.sb-urole{font-size:.66rem;color:rgba(255,255,255,.38);text-transform:uppercase;letter-spacing:.8px;}
.sb-dot{width:7px;height:7px;background:#22c55e;border-radius:50%;display:inline-block;margin-right:4px;}
.sb-sec{padding:16px 20px 5px;font-size:.6rem;color:rgba(255,255,255,.26);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
.sb-a{display:flex;align-items:center;gap:10px;padding:10px 20px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;font-weight:500;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
.sb-a:hover{background:rgba(255,255,255,.07);color:#fff;}
.sb-a.on{background:rgba(255,255,255,.12);color:#fff;border-left-color:#1d4ed8;}
.sb-a i{font-size:.95rem;flex-shrink:0;}
.sb-foot{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
.sb-foot a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
.sb-foot a:hover{background:rgba(255,255,255,.07);color:#fff;}
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:#fff;padding:14px 30px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100;box-shadow:0 2px 10px rgba(0,0,0,.04);}
.pb{padding:28px 30px;}
.btn-back{background:#1d4ed8;color:#fff;padding:9px 18px;border-radius:9px;font-size:.82rem;font-weight:700;text-decoration:none;display:inline-flex;align-items:center;gap:6px;transition:.2s;}
.btn-back:hover{background:#1e40af;color:#fff;}
.alert{border-radius:10px;padding:12px 18px;margin-bottom:20px;font-weight:700;font-size:.875rem;}
.alert-s{background:#eff6ff;border:1px solid #93c5fd;color:#1d4ed8;}
.alert-e{background:#ffebee;border:1px solid #ef9a9a;color:#c62828;}
.banner{background:linear-gradient(135deg,#eff6ff,#dbeafe);border:2px solid #93c5fd;border-radius:14px;padding:22px 26px;margin-bottom:24px;display:flex;align-items:flex-start;gap:14px;}
.vcard{background:#fff;border-radius:14px;border:1px solid var(--border);margin-bottom:18px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.04);}
.vcard-head{padding:14px 20px;background:#f8f9ff;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;}
.vcard-title{font-weight:700;font-size:.95rem;color:#1a1f36;display:flex;align-items:center;gap:8px;}
.badge-count{background:#dbeafe;color:#1d4ed8;border:1px solid #93c5fd;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;}
.badge-next{background:#eff6ff;color:#1d4ed8;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;}
.vcard-table{width:100%;border-collapse:collapse;font-size:.85rem;}
.vcard-table th{padding:9px 16px;background:#f8f9ff;font-size:.7rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:1px solid var(--border);text-align:left;}
.vcard-table td{padding:11px 16px;border-bottom:1px solid #f0f3f9;vertical-align:middle;}
.vcard-table tr:last-child td{border-bottom:none;}
.vcard-table tr:hover td{background:#f8fafc;}
.slot-circle{width:28px;height:28px;border-radius:50%;background:#1d4ed8;color:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:.75rem;font-weight:800;}
.next-label{font-size:.62rem;color:#1d4ed8;font-weight:800;margin-left:6px;background:#dbeafe;padding:1px 6px;border-radius:8px;}
.status-active{background:#dcfce7;color:#15803d;padding:3px 10px;border-radius:20px;font-size:.72rem;font-weight:700;}
.status-inactive{background:#fee2e2;color:#b91c1c;padding:3px 10px;border-radius:20px;font-size:.72rem;font-weight:700;}
.next-row{background:#eff6ff !important;}
.empty-row{padding:14px 20px;font-size:.82rem;color:#9ca3af;font-style:italic;border-top:1px dashed var(--border);}
.empty-row a{color:#1d4ed8;font-weight:700;text-decoration:none;}
.add-form{background:#f8faff;padding:16px 20px;border-top:2px dashed #dbeafe;}
.add-form-title{font-size:.75rem;font-weight:800;color:#1d4ed8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;}
.add-grid{display:grid;grid-template-columns:1.5fr 1.2fr 1.2fr 1fr auto;gap:10px;align-items:end;}
.fg-lbl{font-size:.7rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:5px;}
.fg-in{width:100%;padding:9px 11px;border:1.5px solid var(--border);border-radius:8px;font-size:.875rem;outline:none;font-family:inherit;transition:border .2s;}
.fg-in:focus{border-color:#1d4ed8;box-shadow:0 0 0 3px rgba(29,78,216,.08);}
.fg-in:disabled{background:#f5f5f5;color:var(--muted);cursor:not-allowed;}
.btn-add{background:linear-gradient(135deg,#1d4ed8,#1e40af);color:#fff;border:none;border-radius:9px;padding:10px 18px;font-weight:700;font-size:.85rem;cursor:pointer;display:inline-flex;align-items:center;gap:6px;font-family:inherit;}
.btn-sm{border:none;border-radius:8px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;transition:.2s;}
.btn-view{background:linear-gradient(135deg,#1d4ed8,#3b82f6);color:#fff;}
.btn-deactivate{background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;}
.btn-activate{background:linear-gradient(135deg,#22c55e,#16a34a);color:#fff;}
.btn-remove{background:linear-gradient(135deg,#e53935,#c62828);color:#fff;}
.modal-bg{display:none;position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:9999;align-items:center;justify-content:center;}
.modal-bg.open{display:flex;}
.modal-box{background:#fff;border-radius:16px;width:420px;max-width:95vw;overflow:hidden;box-shadow:0 20px 60px rgba(0,0,0,.25);}
.modal-head{background:linear-gradient(135deg,#1d4ed8,#1e40af);padding:20px 24px;display:flex;align-items:center;justify-content:space-between;}
.modal-close{background:rgba(255,255,255,.2);border:none;color:#fff;width:28px;height:28px;border-radius:50%;font-size:1rem;cursor:pointer;}
.modal-body{padding:22px 26px;}
.modal-av{width:52px;height:52px;border-radius:50%;background:#1d4ed8;display:flex;align-items:center;justify-content:center;font-size:1.1rem;font-weight:800;color:#fff;flex-shrink:0;}
.modal-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:18px;}
.modal-cell{background:#f8faff;border-radius:10px;padding:12px 14px;}
.modal-cell-lbl{font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;}
.modal-cell-val{font-size:.88rem;font-weight:700;color:#1a1f36;}
@media(max-width:900px){.add-grid{grid-template-columns:1fr 1fr;}.add-grid>div:last-child{grid-column:1/-1;}}
</style>
</head>
<body>

<!-- SIDEBAR -->
<div class="sb">
    <div class="sb-top">
        <div style="display:flex;align-items:center;gap:10px;">
            <div style="width:36px;height:36px;background:linear-gradient(135deg,#e53935,#ff8a65);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0;">&#127981;</div>
            <div><div class="sb-brand">AutoProd</div><div class="sb-sub">ADMIN PANEL</div></div>
        </div>
    </div>
    <div class="sb-user">
        <div class="sb-av"><%= initial %></div>
        <div>
            <div class="sb-uname"><%= fullName != null ? fullName : "Admin" %></div>
            <div class="sb-urole"><span class="sb-dot"></span>Administrator</div>
        </div>
    </div>
    <div class="sb-sec">Main</div>
    <a class="sb-a" href="admin_dashboard.jsp"><i class="bi bi-speedometer2"></i> Dashboard</a>
    <a class="sb-a" href="admin_dashboard.jsp?tab=internal"><i class="bi bi-hammer"></i> Internal Jobs</a>
    <a class="sb-a" href="admin_dashboard.jsp?tab=external"><i class="bi bi-people-fill"></i> Customer Orders</a>
    <div class="sb-sec">Team Management</div>
    <a class="sb-a on" href="manage_designers.jsp"><i class="bi bi-pencil-ruler"></i> Design Team</a>
    <a class="sb-a" href="manage_qc_team.jsp"><i class="bi bi-shield-check"></i> QC Team</a>
    <a class="sb-a" href="manage_testing_team.jsp"><i class="bi bi-flask-fill"></i> Testing Team</a>
    <a class="sb-a" href="manage_analytics_team.jsp"><i class="bi bi-graph-up-arrow"></i> Analytics Team</a>
    <a class="sb-a" href="manage_users.jsp"><i class="bi bi-people"></i> All Users</a>
    <div class="sb-foot">
        <a href="../../logout"><i class="bi bi-box-arrow-left"></i> Logout</a>
    </div>
</div>

<!-- MAIN -->
<div class="main">
    <div class="topbar">
        <div>
            <div style="font-family:'Syne',sans-serif;font-size:1.05rem;font-weight:800;color:#1d4ed8;">
                <i class="bi bi-pencil-ruler"></i> Manage Design Team
            </div>
            <div style="font-size:.72rem;color:var(--muted);margin-top:1px;">
                Add designers per vehicle category &mdash; round-robin auto-assignment
            </div>
        </div>
        <a href="admin_dashboard.jsp?tab=designer_assign" class="btn-back">
            <i class="bi bi-arrow-left"></i> Back to Dashboard
        </a>
    </div>

    <div class="pb">

        <% if (!msg.isEmpty()) { %>
        <div class='alert <%= "success".equals(msgType)?"alert-s":"alert-e" %>'>
            <%= "success".equals(msgType)?"&#10003; ":"&#10007; " %><%= msg %>
        </div>
        <% } %>

        <!-- Banner -->
        <div class="banner">
            <i class="bi bi-pencil-ruler" style="font-size:1.8rem;color:#1d4ed8;flex-shrink:0;margin-top:2px;"></i>
            <div>
                <div style="font-family:'Syne',sans-serif;font-size:1.15rem;font-weight:800;color:#1e3a8a;">Design Team Routing</div>
                <div style="font-size:.82rem;color:#1d4ed8;margin-top:4px;line-height:1.6;">
                    Each vehicle category has its own specialist designer pool. Orders are auto-assigned via
                    <strong>round-robin</strong> &mdash; Job 1 &rarr; Slot 1, Job 2 &rarr; Slot 2, Job 3 &rarr; Slot 1 again.
                    Separate counters exist for <strong>internal</strong> (admin-created) and <strong>external</strong> (customer) streams.
                </div>
            </div>
        </div>

        <%
        try (Connection conn = DBConnection.getConnection()) {
            int vi = 0;
            for (String[] vt : vtypes) {
                String vtKey   = vt[0];
                String vtLabel = vt[1];
                String vtSub   = vt[2];
                String vtEmoji = vt[3];

                List<Object[]> designers = new ArrayList<>();
                try {
                    PreparedStatement dq = conn.prepareStatement(
                        "SELECT vd.id, vd.slot_number, vd.full_name, vd.username, vd.is_active, u.last_active " +
                        "FROM vehicle_designers vd LEFT JOIN users u ON vd.username = u.username " +
                        "WHERE vd.vehicle_type=? ORDER BY vd.slot_number");
                    dq.setString(1, vtKey);
                    ResultSet dr = dq.executeQuery();
                    while (dr.next()) {
                        designers.add(new Object[]{
                            dr.getInt("id"), dr.getInt("slot_number"),
                            dr.getString("full_name") != null ? dr.getString("full_name") : "",
                            dr.getString("username")  != null ? dr.getString("username")  : "",
                            dr.getInt("is_active"), dr.getTimestamp("last_active")
                        });
                    }
                } catch (Exception ig) {}

                int lastSlot = 0, totalAssigned = 0;
                try {
                    PreparedStatement rq = conn.prepareStatement(
                        "SELECT last_slot_used, total_assigned FROM designer_round_robin WHERE vehicle_type=? AND stream='internal'");
                    rq.setString(1, vtKey);
                    ResultSet rr = rq.executeQuery();
                    if (rr.next()) { lastSlot = rr.getInt("last_slot_used"); totalAssigned = rr.getInt("total_assigned"); }
                } catch (Exception ig) {}

                int total    = designers.size();
                int nextSlot = total > 0 ? (lastSlot % total) + 1 : 1;
                vi++;
        %>

        <div class="vcard">
            <!-- Header -->
            <div class="vcard-head">
                <div class="vcard-title">
                    <span style="font-size:1.3rem;"><%= vtEmoji %></span>
                    <%= vtLabel %>
                    <span style="font-size:.75rem;color:var(--muted);font-weight:400;">&mdash; <%= vtSub %></span>
                </div>
                <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
                    <span class="badge-count"><%= total %> member<%= total!=1?"s":"" %></span>
                    <% if (total > 0) { %>
                    <span class="badge-next">Next &rarr; Slot <%= nextSlot %></span>
                    <span style="background:#f0fdf4;color:#15803d;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;border:1px solid #86efac;"><%= totalAssigned %> routed</span>
                    <% } %>
                </div>
            </div>

            <!-- Empty state -->
            <% if (designers.isEmpty()) { %>
            <div class="empty-row">
                No designers for <%= vtLabel %> yet &mdash;
                <a href="#" onclick="document.getElementById('addf-<%=vtKey%>').scrollIntoView({behavior:'smooth',block:'center'});return false;">Add member</a>
            </div>
            <% } else { %>
            <!-- Table -->
            <table class="vcard-table">
                <thead>
                    <tr>
                        <th style="width:100px;">Slot</th>
                        <th>Name</th>
                        <th>Username</th>
                        <th style="width:130px;">Online</th>
                        <th style="width:100px;">Status</th>
                        <th style="width:200px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <% for (Object[] d : designers) {
                    int    did     = (Integer)   d[0];
                    int    dslot   = (Integer)   d[1];
                    String dname   = (String)    d[2];
                    String duname  = (String)    d[3];
                    int    dactive = (Integer)   d[4];
                    java.sql.Timestamp dlast = (java.sql.Timestamp) d[5];
                    String odot = "#9ca3af", otxt = "Offline";
                    if (dlast != null) {
                        long dm = (System.currentTimeMillis()-dlast.getTime())/60000L;
                        if (dm<=5) { odot="#22c55e"; otxt="Online"; }
                        else if (dm<=30) { odot="#f59e0b"; otxt="Away "+dm+"m"; }
                    }
                    boolean isNext = (total>0 && dslot==nextSlot);
                    String dn = dname.replace("'","\\'");
                    String du = duname.replace("'","\\'");
                %>
                <tr<%= isNext?" class=\"next-row\"":"" %>>
                    <td>
                        <span class="slot-circle"><%= dslot %></span>
                        <% if (isNext) { %><span class="next-label">NEXT</span><% } %>
                    </td>
                    <td style="font-weight:600;"><%= dname %></td>
                    <td><code style="background:#f1f5f9;padding:2px 8px;border-radius:5px;font-size:.8rem;">@<%= duname %></code></td>
                    <td>
                        <span style="width:8px;height:8px;border-radius:50%;background:<%= odot %>;display:inline-block;margin-right:5px;vertical-align:middle;"></span>
                        <span style="font-size:.78rem;color:var(--muted);"><%= otxt %></span>
                    </td>
                    <td>
                        <span class='<%= dactive==1?"status-active":"status-inactive" %>'>
                            <%= dactive==1?"&#9679; Active":"&#9675; Inactive" %>
                        </span>
                    </td>
                    <td>
                        <div style="display:flex;gap:5px;flex-wrap:wrap;">
                            <button class="btn-sm btn-view"
                                onclick='showModal("<%= dn %>","<%= du %>","<%= vtLabel %>",<%= dslot %>,"<%= dactive==1?"Active":"Inactive" %>","<%= otxt %>")'>
                                <i class="bi bi-eye"></i> View
                            </button>
                            <form method="post" action="manage_designers.jsp" style="display:inline;">
                                <input type="hidden" name="action" value="toggle">
                                <input type="hidden" name="did"    value="<%= did %>">
                                <input type="hidden" name="cur"    value="<%= dactive %>">
                                <button type="submit" class='btn-sm <%= dactive==1?"btn-deactivate":"btn-activate" %>'>
                                    <%= dactive==1?"Deactivate":"Activate" %>
                                </button>
                            </form>
                            <form method="post" action="manage_designers.jsp" style="display:inline;"
                                  onsubmit="return confirm('Remove this designer? Their account will be deactivated.');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="did"    value="<%= did %>">
                                <button type="submit" class="btn-sm btn-remove">Remove</button>
                            </form>
                        </div>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
            <% } %>

            <!-- Add Form -->
            <div class="add-form" id="addf-<%= vtKey %>">
                <div class="add-form-title">
                    <i class="bi bi-person-plus-fill"></i>
                    Add new <%= vtLabel %> designer &mdash; will be Slot <%= total+1 %>
                </div>
                <form method="post" action="manage_designers.jsp">
                    <input type="hidden" name="action"       value="add">
                    <input type="hidden" name="vehicle_type" value="<%= vtKey %>">
                    <div class="add-grid">
                        <div>
                            <div class="fg-lbl">Full Name</div>
                            <input type="text" name="full_name" class="fg-in" placeholder="e.g. Arun Kumar" required maxlength="150">
                        </div>
                        <div>
                            <div class="fg-lbl">Username</div>
                            <input type="text" name="username" class="fg-in" placeholder="e.g. arun_design" required maxlength="50" pattern="[a-zA-Z0-9_]+" title="Letters, numbers, underscore only">
                        </div>
                        <div>
                            <div class="fg-lbl">Password</div>
                            <input type="password" name="password" class="fg-in" placeholder="Login password" required minlength="4">
                        </div>
                        <div>
                            <div class="fg-lbl">Auto Slot</div>
                            <input type="text" class="fg-in" value="Slot <%= total+1 %> (auto)" disabled>
                        </div>
                        <div style="display:flex;align-items:flex-end;">
                            <button type="submit" class="btn-add">
                                <i class="bi bi-plus-circle"></i> Add
                            </button>
                        </div>
                    </div>
                </form>
            </div>
        </div>

        <%
            } // vtypes loop
        } catch (Exception ex) { %>
        <div style="background:#ffebee;padding:14px 18px;border-radius:10px;color:#c62828;font-weight:700;">
            Error: <%= ex.getMessage() %>
        </div>
        <% } %>

    </div>
</div>

<!-- MODAL -->
<div id="viewModal" class="modal-bg">
    <div class="modal-box">
        <div class="modal-head">
            <div style="font-weight:800;font-size:1rem;color:#fff;" id="m-title">Designer Details</div>
            <button class="modal-close" onclick="closeModal()">&times;</button>
        </div>
        <div class="modal-body">
            <div style="display:flex;align-items:center;gap:14px;">
                <div class="modal-av" id="m-av"></div>
                <div>
                    <div style="font-weight:800;font-size:1rem;color:#1a1f36;" id="m-name"></div>
                    <div style="font-size:.78rem;color:var(--muted);margin-top:2px;">Design Engineer</div>
                </div>
            </div>
            <div class="modal-grid">
                <div class="modal-cell">
                    <div class="modal-cell-lbl">Username</div>
                    <div class="modal-cell-val" id="m-uname"></div>
                </div>
                <div class="modal-cell">
                    <div class="modal-cell-lbl">Slot</div>
                    <div class="modal-cell-val" style="color:#1d4ed8;" id="m-slot"></div>
                </div>
                <div class="modal-cell">
                    <div class="modal-cell-lbl">Category</div>
                    <div class="modal-cell-val" id="m-cat"></div>
                </div>
                <div class="modal-cell">
                    <div class="modal-cell-lbl">Account</div>
                    <div class="modal-cell-val" id="m-status"></div>
                </div>
                <div class="modal-cell" style="grid-column:1/-1;">
                    <div class="modal-cell-lbl">Online Status</div>
                    <div class="modal-cell-val" id="m-online"></div>
                </div>
            </div>
            <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:11px 14px;margin-top:14px;font-size:.8rem;color:#1d4ed8;">
                <i class="bi bi-info-circle"></i> Orders are auto-assigned via round-robin based on slot number. Separate counters for internal and external streams.
            </div>
        </div>
    </div>
</div>

<script>
function showModal(name, uname, cat, slot, status, online) {
    var ini = name.split(' ').map(function(w){return w[0]||'';}).join('').substring(0,2).toUpperCase();
    document.getElementById('m-av').textContent    = ini;
    document.getElementById('m-title').textContent = name;
    document.getElementById('m-name').textContent  = name;
    document.getElementById('m-uname').textContent = '@' + uname;
    document.getElementById('m-slot').textContent  = 'Slot ' + slot;
    document.getElementById('m-cat').textContent   = cat;
    var st = document.getElementById('m-status');
    st.textContent = status;
    st.style.color = status === 'Active' ? '#16a34a' : '#b91c1c';
    document.getElementById('m-online').textContent = online;
    document.getElementById('viewModal').classList.add('open');
}
function closeModal() {
    document.getElementById('viewModal').classList.remove('open');
}
document.getElementById('viewModal').addEventListener('click', function(e){
    if (e.target === this) closeModal();
});
</script>
</body>
</html>
