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

    String msg     = "";
    String msgType = "";
    String action  = request.getParameter("action");

    // ── ADD designer ──
    if ("add".equals(action)) {
        String vtype = request.getParameter("vehicle_type");
        String fname = request.getParameter("full_name");
        String uname = request.getParameter("username");
        String pwd   = request.getParameter("password");
        if (vtype != null && fname != null && uname != null && pwd != null
                && !vtype.trim().isEmpty() && !fname.trim().isEmpty()
                && !uname.trim().isEmpty() && !pwd.trim().isEmpty()) {
            try (Connection conn = DBConnection.getConnection()) {
                // Check username not already taken
                PreparedStatement chk = conn.prepareStatement(
                    "SELECT COUNT(*) FROM users WHERE CONVERT(username USING utf8mb4) COLLATE utf8mb4_general_ci = CONVERT(? USING utf8mb4) COLLATE utf8mb4_general_ci");
                chk.setString(1, uname.trim().toLowerCase());
                ResultSet chkRs = chk.executeQuery();
                int exists = 0;
                if (chkRs.next()) exists = chkRs.getInt(1);
                if (exists > 0) {
                    msg = "Username already taken. Choose a different one.";
                    msgType = "error";
                } else {
                    // Get next slot for this vehicle type
                    int nextSlot = 1;
                    PreparedStatement slotQ = conn.prepareStatement(
                        "SELECT COALESCE(MAX(slot_number),0)+1 AS ns FROM module_team_members WHERE module_role='testing' AND vehicle_type=?");
                    slotQ.setString(1, vtype.trim());
                    ResultSet slotRs = slotQ.executeQuery();
                    if (slotRs.next()) nextSlot = slotRs.getInt("ns");

                    // Hash password using PasswordUtil (salt:hash format)
                    String hashedPwd = PasswordUtil.hashPassword(pwd.trim());

                    // Insert into users table
                    PreparedStatement pu = conn.prepareStatement(
                        "INSERT INTO users (full_name, username, password, role, is_active) VALUES (?,?,?,'testing',1)");
                    pu.setString(1, fname.trim());
                    pu.setString(2, uname.trim().toLowerCase());
                    pu.setString(3, hashedPwd);
                    pu.executeUpdate();

                    // Insert into module_team_members
                    PreparedStatement pd = conn.prepareStatement(
                        "INSERT INTO module_team_members (module_role, vehicle_type, slot_number, full_name, username, is_active) VALUES (?,?,?,?,?,1)");
                    pd.setString(1, "testing");
                    pd.setString(2, vtype.trim());
                    pd.setInt   (3, nextSlot);
                    pd.setString(4, fname.trim());
                    pd.setString(5, uname.trim().toLowerCase());
                    pd.executeUpdate();

                    // Ensure round-robin row exists
                    PreparedStatement pr = conn.prepareStatement(
                        "INSERT IGNORE INTO module_round_robin (module_role, vehicle_type, last_slot_used, total_assigned) VALUES (?,?,0,0)");
                    pr.setString(1, "testing");
                    pr.setString(2, vtype.trim());
                    pr.executeUpdate();

                    String vtLabel = vtype.trim().replace("_"," ").toUpperCase();
                    msg = "Testing Team member " + fname.trim() + " added as Slot " + nextSlot + " for " + vtLabel;
                    msgType = "success";
                }
            } catch (Exception e) {
                msg = "Error: " + e.getMessage();
                msgType = "error";
            }
        } else {
            msg = "All fields are required.";
            msgType = "error";
        }
    }

    // ── TOGGLE active ──
    if ("toggle".equals(action)) {
        String didStr = request.getParameter("did");
        String curStr = request.getParameter("cur");
        if (didStr != null && curStr != null) {
            try (Connection conn = DBConnection.getConnection()) {
                int did    = Integer.parseInt(didStr.trim());
                int newVal = "1".equals(curStr.trim()) ? 0 : 1;
                // Get username first
                PreparedStatement getu = conn.prepareStatement(
                    "SELECT username FROM module_team_members WHERE id=?");
                getu.setInt(1, did);
                ResultSet urs = getu.executeQuery();
                if (urs.next()) {
                    String uname2 = urs.getString("username");
                    PreparedStatement upd = conn.prepareStatement(
                        "UPDATE module_team_members SET is_active=? WHERE id=?");
                    upd.setInt(1, newVal);
                    upd.setInt(2, did);
                    upd.executeUpdate();
                    PreparedStatement upu = conn.prepareStatement(
                        "UPDATE users SET is_active=? WHERE username=?");
                    upu.setInt(1, newVal);
                    upu.setString(2, uname2);
                    upu.executeUpdate();
                }
                msg = newVal == 1 ? "Testing Team member activated." : "Testing Team member deactivated.";
                msgType = "success";
            } catch (Exception e) {
                msg = "Error: " + e.getMessage();
                msgType = "error";
            }
        }
    }

    // ── DELETE (remove from pool, deactivate user) ──
    if ("delete".equals(action)) {
        String didStr = request.getParameter("did");
        if (didStr != null) {
            try (Connection conn = DBConnection.getConnection()) {
                int did = Integer.parseInt(didStr.trim());
                PreparedStatement getu = conn.prepareStatement(
                    "SELECT username, vehicle_type FROM module_team_members WHERE id=?");
                getu.setInt(1, did);
                ResultSet dr = getu.executeQuery();
                if (dr.next()) {
                    String uname2 = dr.getString("username");
                    String vt2    = dr.getString("vehicle_type");
                    // Delete from vehicle_designers
                    PreparedStatement del = conn.prepareStatement(
                        "DELETE FROM module_team_members WHERE id=?");
                    del.setInt(1, did);
                    del.executeUpdate();
                    // Re-number slots to keep them sequential
                    ResultSet rem = conn.createStatement().executeQuery(
                        "SELECT id FROM module_team_members WHERE module_role='testing' AND vehicle_type='"
                        + vt2.replace("'","''") + "' ORDER BY slot_number");
                    int slotNum = 1;
                    while (rem.next()) {
                        PreparedStatement rnu = conn.prepareStatement(
                            "UPDATE module_team_members SET slot_number=? WHERE id=?");
                        rnu.setInt(1, slotNum++);
                        rnu.setInt(2, rem.getInt("id"));
                        rnu.executeUpdate();
                    }
                    // Reset round-robin counter for this type
                    PreparedStatement rreset = conn.prepareStatement(
                        "UPDATE module_round_robin SET last_slot_used=0 WHERE module_role='testing' AND vehicle_type=?");
                    rreset.setString(1, vt2);
                    rreset.executeUpdate();
                    // Deactivate user account (preserve history)
                    PreparedStatement deu = conn.prepareStatement(
                        "UPDATE users SET is_active=0 WHERE username=?");
                    deu.setString(1, uname2);
                    deu.executeUpdate();
                }
                msg = "Testing Team member removed from pool.";
                msgType = "success";
            } catch (Exception e) {
                msg = "Error: " + e.getMessage();
                msgType = "error";
            }
        }
    }

    // Vehicle type metadata
    String[][] vtypes = {
        {"two_wheeler",   "two_wheeler",   "Two Wheeler",    "Bike, Scooter, Electric 2W"},
        {"three_wheeler", "three_wheeler", "Three Wheeler",  "Auto, Electric Auto, Cargo 3W"},
        {"car",           "car",           "Car",            "Hatchback, Sedan, SUV, EV"},
        {"van",           "van",           "Van",            "Minivan, Cargo Van, Staff Van"},
        {"bus",           "bus",           "Bus",            "Mini, Standard, Luxury, Electric"},
        {"lorry",         "lorry",         "Lorry / Truck",  "Light/Heavy Truck, Tipper, Tanker"},
        {"heavy_vehicle", "heavy_vehicle", "Heavy Vehicle",  "Tractor, JCB, Excavator, Crane"},
        {"special",       "special",       "Special Purpose","Ambulance, Fire Engine, Defence"}
    };
    String[] vtIcons = {"two_wh","three_wh","car","van","bus","lorry","heavy","spec"};
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Manage Testing Team — AutoProd</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
<style>
:root{--sw:260px;--brand:#0f1f5c;--accent:#e53935;--bg:#f0f3f9;--border:#e5e9f2;--muted:#6b7280;}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:'Plus Jakarta Sans',sans-serif;color:#1a1f36;}
.sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
.sb-brand{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
.sb-name{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;}
.nl{display:flex;align-items:center;gap:10px;padding:10px 16px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
.nl:hover{background:rgba(255,255,255,.07);color:#fff;}
.nl.active{background:rgba(255,255,255,.12);color:#fff;border-left-color:var(--accent);}
.ns{padding:14px 20px 4px;font-size:.6rem;color:rgba(255,255,255,.28);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
.sf{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
.sf a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
.sf a:hover{background:rgba(255,255,255,.07);color:#fff;}
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:#fff;padding:14px 30px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100;box-shadow:0 2px 10px rgba(0,0,0,.04);}
.pb{padding:28px 30px;}
.card{background:#fff;border-radius:16px;border:1px solid var(--border);margin-bottom:22px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.04);}
.ch{padding:16px 22px;border-bottom:2px solid var(--border);display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;}
.ct{font-weight:800;font-size:.95rem;color:var(--brand);display:flex;align-items:center;gap:8px;}
.sbtn{background:linear-gradient(135deg,var(--brand),#1a3a8f);color:#fff;border:none;border-radius:10px;padding:10px 20px;font-weight:700;font-size:.85rem;cursor:pointer;transition:.2s;display:inline-flex;align-items:center;gap:6px;text-decoration:none;}
.sbtn:hover{opacity:.9;transform:translateY(-1px);}
.dt{width:100%;border-collapse:collapse;font-size:.85rem;}
.dt th{background:#f8f9ff;padding:10px 14px;text-align:left;font-weight:700;font-size:.75rem;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid var(--border);}
.dt td{padding:11px 14px;border-bottom:1px solid #f0f3f9;vertical-align:middle;}
.dt tr:last-child td{border-bottom:none;}
.dt tr:hover td{background:#fafbff;}
.p{display:inline-flex;align-items:center;padding:3px 10px;border-radius:20px;font-size:.72rem;font-weight:700;}
.pg{background:#e8f5e9;color:#2e7d32;}
.pgy{background:#f5f5f5;color:#757575;}
.ifield{width:100%;padding:9px 11px;border:1.5px solid var(--border);border-radius:8px;font-size:.875rem;outline:none;font-family:inherit;transition:border .2s;}
.ifield:focus{border-color:#d97706;}
.msg-s{background:#e8f5e9;border:1px solid #a5d6a7;color:#2e7d32;border-radius:10px;padding:12px 18px;margin-bottom:18px;font-weight:600;font-size:.875rem;}
.msg-e{background:#ffebee;border:1px solid #ef9a9a;color:#c62828;border-radius:10px;padding:12px 18px;margin-bottom:18px;font-weight:600;font-size:.875rem;}
.add-form{background:#f8faff;padding:18px 22px;border-top:2px dashed #e5e9f2;}
.add-grid{display:grid;grid-template-columns:1.5fr 1.2fr 1.2fr 1fr auto;gap:10px;align-items:end;}
.lbl{font-size:.71rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:5px;}
.dot{width:9px;height:9px;border-radius:50%;display:inline-block;margin-right:4px;vertical-align:middle;}
.dot-g{background:#22c55e;box-shadow:0 0 5px #22c55e60;}
.dot-y{background:#f59e0b;box-shadow:0 0 5px #f59e0b60;}
.dot-gr{background:#9ca3af;}
.next-badge{background:#fef3c7;color:#92400e;font-size:.65rem;font-weight:800;padding:2px 7px;border-radius:10px;margin-left:6px;}
.slot-num{background:#f59e0b;color:#fff;border-radius:50%;width:26px;height:26px;display:inline-flex;align-items:center;justify-content:center;font-size:.72rem;font-weight:800;}
</style>
</head>
<body>

<!-- SIDEBAR -->
<div class="sb">
    <div class="sb-brand">
        <div style="font-size:1.4rem;">&#127981;</div>
        <div class="sb-name" style="margin-top:4px;">AutoProd</div>
        <div style="font-size:.68rem;color:rgba(255,255,255,.35);margin-top:2px;">ADMIN PANEL</div>
    </div>
    <div class="ns">Navigation</div>
    <a class="nl" href="admin_dashboard.jsp"><i class="bi bi-grid-1x2-fill"></i> Dashboard</a>
    <a class="nl" href="admin_dashboard.jsp?tab=external"><i class="bi bi-people-fill"></i> Customer Orders</a>
    <a class="nl" href="admin_dashboard.jsp?tab=internal"><i class="bi bi-hammer"></i> Internal Jobs</a>
    <a class="nl active" href="manage_designers.jsp"><i class="bi bi-flask-fill"></i> Manage Testing Team</a>
    <a class="nl" href="manage_users.jsp"><i class="bi bi-people"></i> Manage Users</a>
    <div class="sf">
        <a href="../../index.jsp"><i class="bi bi-box-arrow-left"></i> Logout</a>
    </div>
</div>

<!-- MAIN CONTENT -->
<div class="main">
    <div class="topbar">
        <div>
            <div style="font-family:'Syne',sans-serif;font-size:1.05rem;font-weight:800;color:var(--brand);">
                <i class="bi bi-flask-fill"></i> Manage Testing Team
            </div>
            <div style="font-size:.72rem;color:var(--muted);margin-top:1px;">
                Add Testing Team members per vehicle category &mdash; Round-robin auto-assignment
            </div>
        </div>
        <a href="admin_dashboard.jsp?tab=testing_assign" class="sbtn" style="font-size:.8rem;padding:8px 16px;">
            <i class="bi bi-arrow-left"></i> Back to Dashboard
        </a>
    </div>

    <div class="pb">

        <% if (!msg.isEmpty()) { %>
        <div class='msg-<%= "success".equals(msgType) ? "s" : "e" %>'>
            <%= "success".equals(msgType) ? "&#10003; " : "&#10007; " %><%= msg %>
        </div>
        <% } %>

        <!-- How It Works -->
        <div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1.5px solid #b45309;border-radius:14px;padding:16px 20px;margin-bottom:24px;display:flex;align-items:flex-start;gap:14px;">
            <span style="font-size:2rem;">&#128260;</span>
            <div>
                <div style="font-weight:800;color:#d97706;font-size:.95rem;margin-bottom:4px;">Round-Robin Auto Assignment — Testing Team</div>
                <div style="font-size:.82rem;color:#374151;line-height:1.6;">
                    Each vehicle category has its own designer pool. When admin approves an order, the system picks the next designer in rotation automatically.
                    <strong>Car order 1 goes to Slot 1, order 2 to Slot 2, order 3 to Slot 3, order 4 back to Slot 1 and so on.</strong>
                    Add or remove designers anytime &mdash; the cycle adjusts automatically.
                </div>
            </div>
        </div>

        <%
        try (Connection conn = DBConnection.getConnection()) {
            int vtIdx = 0;
            for (String[] vt : vtypes) {
                vtIdx++;
                String vtKey   = vt[0];
                String vtLabel = vt[2];
                String vtSub   = vt[3];

                // Load designers for this type
                List<Object[]> designers = new ArrayList<>();
                try {
                    PreparedStatement dq = conn.prepareStatement(
                        "SELECT vd.id, vd.slot_number, vd.full_name, vd.username, vd.is_active, " +
                        "       u.last_active " +
                        "FROM module_team_members vd " +
                        "LEFT JOIN users u ON vd.username = u.username " +
                        "WHERE vd.module_role='testing' AND vd.vehicle_type = ? ORDER BY vd.slot_number");
                    dq.setString(1, vtKey);
                    ResultSet dr = dq.executeQuery();
                    while (dr.next()) {
                        Object[] row = new Object[6];
                        row[0] = dr.getInt("id");
                        row[1] = dr.getInt("slot_number");
                        row[2] = dr.getString("full_name") != null ? dr.getString("full_name") : "";
                        row[3] = dr.getString("username")  != null ? dr.getString("username")  : "";
                        row[4] = dr.getInt("is_active");
                        row[5] = dr.getTimestamp("last_active");
                        designers.add(row);
                    }
                } catch (Exception ig) {}

                // Load round-robin counter
                int lastSlotUsed  = 0;
                int totalAssigned = 0;
                try {
                    PreparedStatement rq = conn.prepareStatement(
                        "SELECT last_slot_used, total_assigned FROM module_round_robin WHERE module_role='testing' AND vehicle_type=?");
                    rq.setString(1, vtKey);
                    ResultSet rr = rq.executeQuery();
                    if (rr.next()) {
                        lastSlotUsed  = rr.getInt("last_slot_used");
                        totalAssigned = rr.getInt("total_assigned");
                    }
                } catch (Exception ig) {}

                int totalDesigners = designers.size();
                int nextSlotToGet  = totalDesigners > 0 ? (lastSlotUsed % totalDesigners) + 1 : 1;
        %>

        <div class="card">
            <!-- Category Header -->
            <div class="ch">
                <div class="ct">
                    <span style="font-size:1.5rem;"><%= vtIdx==1?"&#128693;":vtIdx==2?"&#128666;":vtIdx==3?"&#128664;":vtIdx==4?"&#128656;":vtIdx==5?"&#128652;":vtIdx==6?"&#128667;":vtIdx==7?"&#128668;":"&#128657;" %></span>
                    <%= vtLabel %> Testing Team
                    <span style="background:#f59e0b;color:#fff;border-radius:20px;padding:2px 10px;font-size:.68rem;font-weight:800;margin-left:4px;">
                        <%= totalDesigners %> in pool
                    </span>
                </div>
                <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
                    <span style="font-size:.75rem;color:var(--muted);">
                        <%= vtSub %>
                    </span>
                    <% if (totalDesigners > 0) { %>
                    <span style="background:#e8f5e9;color:#2e7d32;padding:3px 12px;border-radius:20px;font-size:.72rem;font-weight:700;">
                        <%= totalAssigned %> orders routed
                    </span>
                    <span style="background:#eff6ff;color:#1d4ed8;padding:3px 12px;border-radius:20px;font-size:.72rem;font-weight:700;">
                        Next &rarr; Slot <%= nextSlotToGet %>
                    </span>
                    <% } %>
                </div>
            </div>

            <!-- Designer Table -->
            <% if (designers.isEmpty()) { %>
            <div style="padding:18px 22px;display:flex;align-items:center;gap:12px;background:#fffde7;">
                <span style="font-size:1.4rem;">&#9888;</span>
                <div>
                    <div style="font-weight:700;color:#b45309;font-size:.88rem;">No Testing Team members added yet</div>
                    <div style="font-size:.77rem;color:#92400e;margin-top:2px;">
                        Use the form below to add the first <%= vtLabel %> Testing Team member
                    </div>
                </div>
            </div>
            <% } else { %>
            <table class="dt">
                <thead>
                    <tr>
                        <th style="width:80px;">Slot</th>
                        <th>Full Name</th>
                        <th>Username</th>
                        <th style="width:100px;">Account</th>
                        <th style="width:140px;">Online Status</th>
                        <th style="width:160px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <%
                for (Object[] d : designers) {
                    int      did      = (Integer)   d[0];
                    int      slot     = (Integer)   d[1];
                    String   dname    = (String)    d[2];
                    String   duname   = (String)    d[3];
                    int      dactive  = (Integer)   d[4];
                    java.sql.Timestamp lastAct = (java.sql.Timestamp) d[5];

                    // Online status from last_active
                    String dotClass   = "dot-gr";
                    String onlineText = "Offline";
                    if (lastAct != null) {
                        long diffMin = (System.currentTimeMillis() - lastAct.getTime()) / 60000L;
                        if      (diffMin <= 5)  { dotClass = "dot-g";  onlineText = "Online"; }
                        else if (diffMin <= 30) { dotClass = "dot-y";  onlineText = "Away (" + diffMin + "m ago)"; }
                        else                    { dotClass = "dot-gr"; onlineText = "Offline"; }
                    }

                    boolean isNext = (totalDesigners > 0 && slot == nextSlotToGet);
                %>
                <tr style='<%= isNext ? "background:#fffbeb;" : "" %>'>
                    <td>
                        <span class="slot-num"><%= slot %></span>
                        <% if (isNext) { %>
                        <span class="next-badge">NEXT</span>
                        <% } %>
                    </td>
                    <td style="font-weight:700;font-size:.88rem;"><%= dname %></td>
                    <td>
                        <code style="background:#f5f5f5;padding:2px 8px;border-radius:6px;font-size:.8rem;">@<%= duname %></code>
                    </td>
                    <td>
                        <span class='p <%= dactive==1 ? "pg" : "pgy" %>'>
                            <%= dactive==1 ? "Active" : "Inactive" %>
                        </span>
                    </td>
                    <td>
                        <span class="dot <%= dotClass %>"></span>
                        <span style="font-size:.78rem;color:var(--muted);"><%= onlineText %></span>
                    </td>
                    <td>
                        <div style="display:flex;gap:6px;">
                            <button type="button" onclick='showView("<%= did %>","<%= dname %>","<%= duname %>","<%= slot %>","<%= dactive==1?"Active":"Inactive" %>","<%= onlineText %>")' style="background:linear-gradient(135deg,#1d4ed8,#3b82f6);color:#fff;border:none;border-radius:8px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;">View</button>
                            <form method="post" action="manage_testing_team.jsp" style="display:inline;">
                                <input type="hidden" name="action" value="toggle">
                                <input type="hidden" name="did"    value="<%= did %>">
                                <input type="hidden" name="cur"    value="<%= dactive %>">
                                <button type="submit" style='background:<%= dactive==1 ? "linear-gradient(135deg,#f59e0b,#d97706)" : "linear-gradient(135deg,#22c55e,#16a34a)" %>;color:#fff;border:none;border-radius:8px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;'>
                                    <%= dactive==1 ? "Deactivate" : "Activate" %>
                                </button>
                            </form>
                            <form method="post" style="display:inline;"
                                onsubmit="return confirm('Remove this designer from the pool? Their account will be deactivated.');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="did"    value="<%= did %>">
                                <button type="submit" style="background:linear-gradient(135deg,#e53935,#c62828);color:#fff;border:none;border-radius:8px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;">
                                    Remove
                                </button>
                            </form>
                        </div>
                    </td>
                </tr>
                <% } // end for designers %>
                </tbody>
            </table>
            <% } // end if designers empty %>

            <!-- Add Designer Form -->
            <div class="add-form">
                <div style="font-size:.77rem;font-weight:800;color:#d97706;text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;">
                    <i class="bi bi-person-plus-fill"></i> Add New <%= vtLabel %> Testing Team Member &mdash; Will be Slot <%= totalDesigners + 1 %>
                </div>
                <form method="post" action="manage_testing_team.jsp">
                    <input type="hidden" name="action"       value="add">
                    <input type="hidden" name="vehicle_type" value="<%= vtKey %>">
                    <div class="add-grid">
                        <div>
                            <div class="lbl">Full Name</div>
                            <input type="text" name="full_name" class="ifield"
                                placeholder="e.g. Arun Kumar" required maxlength="150">
                        </div>
                        <div>
                            <div class="lbl">Username (login ID)</div>
                            <input type="text" name="username" class="ifield"
                                placeholder="e.g. arun_design" required maxlength="50"
                                pattern="[a-zA-Z0-9_]+" title="Letters, numbers, underscore only">
                        </div>
                        <div>
                            <div class="lbl">Password</div>
                            <input type="password" name="password" class="ifield"
                                placeholder="Set login password" required minlength="4">
                        </div>
                        <div>
                            <div class="lbl">Auto Slot</div>
                            <input type="text" class="ifield"
                                value="Slot <%= totalDesigners + 1 %> (auto)" disabled
                                style="background:#f5f5f5;color:var(--muted);cursor:not-allowed;">
                        </div>
                        <div>
                            <button type="submit" class="sbtn"
                                style="background:linear-gradient(135deg,#d97706,#b45309);white-space:nowrap;padding:10px 16px;">
                                <i class="bi bi-plus-circle"></i> Add
                            </button>
                        </div>
                    </div>
                </form>
            </div>
        </div>

        <%
            } // end for vtypes
        } catch (Exception pageEx) { %>
        <div style="background:#ffebee;padding:14px 18px;border-radius:10px;color:#c62828;font-weight:700;">
            Page Error: <%= pageEx.getMessage() %>
        </div>
        <% } %>

    </div><!-- /pb -->
</div><!-- /main -->

<div id="view-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:9999;align-items:center;justify-content:center;">
  <div style="background:#fff;border-radius:16px;padding:28px 32px;min-width:340px;max-width:420px;position:relative;">
    <button onclick="closeView()" style="position:absolute;top:12px;right:14px;background:none;border:none;font-size:1.3rem;cursor:pointer;color:#9ca3af;">&#x2715;</button>
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:20px;">
      <div id="vm-av" style="width:52px;height:52px;border-radius:50%;background:#f59e0b;display:flex;align-items:center;justify-content:center;font-size:1.1rem;font-weight:800;color:#fff;"></div>
      <div><div id="vm-name" style="font-weight:800;font-size:1rem;"></div><div style="font-size:.78rem;color:#6b7280;margin-top:2px;">Testing Engineer</div></div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
      <div style="background:#f8faff;border-radius:10px;padding:12px;"><div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;margin-bottom:4px;">Username</div><div id="vm-un" style="font-weight:700;"></div></div>
      <div style="background:#f8faff;border-radius:10px;padding:12px;"><div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;margin-bottom:4px;">Slot</div><div id="vm-sl" style="font-weight:700;color:#f59e0b;"></div></div>
      <div style="background:#f8faff;border-radius:10px;padding:12px;"><div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;margin-bottom:4px;">Account</div><div id="vm-st" style="font-weight:700;"></div></div>
      <div style="background:#f8faff;border-radius:10px;padding:12px;"><div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;margin-bottom:4px;">Online</div><div id="vm-on" style="font-weight:700;color:#6b7280;"></div></div>
    </div>
  </div>
</div>
<script>
function showView(id,name,uname,slot,status,online){
  document.getElementById('vm-av').textContent=name.length>=2?name.substring(0,2).toUpperCase():name;
  document.getElementById('vm-name').textContent=name;
  document.getElementById('vm-un').textContent='@'+uname;
  document.getElementById('vm-sl').textContent='Slot '+slot;
  var s=document.getElementById('vm-st'); s.textContent=status; s.style.color=status==='Active'?'#16a34a':'#b91c1c';
  document.getElementById('vm-on').textContent=online;
  document.getElementById('view-modal').style.display='flex';
}
function closeView(){ document.getElementById('view-modal').style.display='none'; }
document.addEventListener('click',function(e){ if(e.target.id==='view-modal') closeView(); });
</script>

</body>
</html>
