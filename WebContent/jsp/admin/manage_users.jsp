<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) { response.sendRedirect("../../index.jsp"); return; }
    if (!"admin".equals(sess.getAttribute("role"))) { response.sendRedirect("../../index.jsp"); return; }
    String fullName = (String) sess.getAttribute("fullName");
    String initial  = (fullName != null && !fullName.isEmpty()) ? String.valueOf(fullName.charAt(0)).toUpperCase() : "A";
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Manage Users — AutoProd Admin</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <style>
    :root{--sw:260px;--brand:#0f1f5c;--accent:#e53935;--bg:#f0f3f9;--border:#e5e9f2;--muted:#6b7280;--text:#1a1f36;}
    *{margin:0;padding:0;box-sizing:border-box;}
    body{background:var(--bg);font-family:'Plus Jakarta Sans',sans-serif;color:var(--text);}
    .sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
    .sb-brand{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
    .sb-brand-row{display:flex;align-items:center;gap:10px;}
    .sb-icon{width:36px;height:36px;background:linear-gradient(135deg,var(--accent),#ff8a65);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0;}
    .sb-name{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;}
    .sb-sub{font-size:.64rem;color:rgba(255,255,255,.32);letter-spacing:.5px;margin-top:2px;}
    .sb-user{padding:14px 20px;border-bottom:1px solid rgba(255,255,255,.08);display:flex;align-items:center;gap:12px;}
    .av{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,var(--accent),#ff8a65);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.9rem;flex-shrink:0;}
    .uname{font-size:.84rem;font-weight:700;}.urole{font-size:.66rem;color:rgba(255,255,255,.38);text-transform:uppercase;letter-spacing:.8px;}
    .dot{width:7px;height:7px;background:#22c55e;border-radius:50%;display:inline-block;margin-right:4px;}
    .ns{padding:16px 20px 5px;font-size:.6rem;color:rgba(255,255,255,.26);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
    .nl{display:flex;align-items:center;gap:10px;padding:10px 20px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;font-weight:500;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
    .nl i{font-size:.95rem;flex-shrink:0;}.nl:hover{background:rgba(255,255,255,.07);color:#fff;}
    .nl.active{background:rgba(255,255,255,.12);color:#fff;border-left-color:var(--accent);}
    .sf{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
    .sf a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
    .sf a:hover{background:rgba(255,255,255,.07);color:#fff;}
    .main{margin-left:var(--sw);min-height:100vh;}
    .topbar{background:#fff;border-bottom:1px solid var(--border);padding:14px 28px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;}
    .content{padding:28px;}
    .card{background:#fff;border-radius:16px;border:1px solid var(--border);overflow:hidden;margin-bottom:24px;box-shadow:0 2px 12px rgba(0,0,0,.04);}
    .card-header{padding:16px 22px;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;background:#fafbfc;}
    .card-title{font-family:'Syne',sans-serif;font-size:.95rem;font-weight:800;display:flex;align-items:center;gap:8px;}
    .tbl{width:100%;border-collapse:collapse;}
    .tbl th{padding:11px 16px;background:#f8fafc;border-bottom:1px solid var(--border);font-size:.74rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;text-align:left;}
    .tbl td{padding:13px 16px;border-bottom:1px solid var(--border);font-size:.84rem;vertical-align:middle;}
    .tbl tr:last-child td{border-bottom:none;}
    .tbl tr:hover td{background:#f8fafc;}
    .badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:.72rem;font-weight:700;}
    .badge-admin{background:#fce4ec;color:#ad1457;} .badge-design{background:#e3f2fd;color:#1565c0;}
    .badge-analytics{background:#f3e5f5;color:#6a1b9a;} .badge-qc{background:#e8f5e9;color:#2e7d32;}
    .badge-testing{background:#fff3e0;color:#e65100;} .badge-active{background:#dcfce7;color:#166534;}
    .badge-inactive{background:#f3f4f6;color:#6b7280;}
    .sec-list{list-style:none;padding:0;}
    .sec-list li{padding:12px 0;border-bottom:1px solid var(--border);font-size:.875rem;display:flex;align-items:flex-start;gap:10px;line-height:1.6;}
    .sec-list li:last-child{border-bottom:none;}
    .sec-list li::before{content:'🔒';flex-shrink:0;}
    code{background:#f0f3f9;padding:2px 7px;border-radius:5px;font-size:.82rem;color:var(--brand);}
    </style>
</head>
<body>
<nav class="sb">
    <div class="sb-brand">
        <div class="sb-brand-row">
            <div class="sb-icon">🏭</div>
            <div><div class="sb-name">AutoProd</div><div class="sb-sub">ADMIN PANEL</div></div>
        </div>
    </div>
    <div class="sb-user">
        <div class="av"><%= initial %></div>
        <div>
            <div class="uname"><%= fullName!=null?fullName:"Admin" %></div>
            <div class="urole"><span class="dot"></span>Administrator</div>
        </div>
    </div>
    <div class="ns">Main</div>
    <a href="admin_dashboard.jsp" class="nl"><i class="bi bi-speedometer2"></i> Dashboard</a>
    <a href="admin_dashboard.jsp?tab=requirements" class="nl"><i class="bi bi-clipboard-check"></i> Requirements</a>
    <div class="ns">Production</div>
    <a href="create_internal_job.jsp" class="nl"><i class="bi bi-hammer"></i> Internal Jobs</a>
    <a href="create_external_order.jsp" class="nl"><i class="bi bi-truck"></i> External Orders</a>
    <a href="admin_dashboard.jsp?tab=workflow" class="nl"><i class="bi bi-diagram-3"></i> Workflow</a>
    <div class="ns">Modules</div>
    <a href="admin_dashboard.jsp?tab=vehicles" class="nl"><i class="bi bi-car-front"></i> Vehicles</a>
    <a href="admin_dashboard.jsp?tab=qc" class="nl"><i class="bi bi-shield-check"></i> QC History</a>
    <a href="admin_dashboard.jsp?tab=testing" class="nl"><i class="bi bi-clipboard2-pulse"></i> Testing</a>
    <a href="admin_dashboard.jsp?tab=customers" class="nl"><i class="bi bi-people"></i> Customers</a>
    <div class="ns">Admin Tools</div>
    <a href="manage_users.jsp" class="nl active"><i class="bi bi-person-gear"></i> Manage Users</a>
    <a href="../final_report.jsp" class="nl"><i class="bi bi-file-earmark-bar-graph"></i> Final Report</a>
    <div class="sf">
        <a href="../../logout"><i class="bi bi-box-arrow-left"></i> Logout</a>
    </div>
</nav>
<div class="main">
    <div class="topbar">
        <div>
            <div style="font-weight:800;font-size:.95rem;"><i class="bi bi-person-gear" style="color:var(--accent);margin-right:6px;"></i>Manage Users</div>
            <div style="font-size:.75rem;color:var(--muted);">View all system users and their roles</div>
        </div>
        <a href="admin_dashboard.jsp" style="background:var(--bg);border:1px solid var(--border);padding:7px 16px;border-radius:8px;color:var(--text);text-decoration:none;font-weight:600;font-size:.82rem;display:flex;align-items:center;gap:6px;">
            <i class="bi bi-arrow-left"></i> Back to Dashboard
        </a>
    </div>
    <div class="content">
        <div class="card">
            <div class="card-header">
                <div class="card-title"><i class="bi bi-people-fill" style="color:var(--brand);"></i> All Registered Users</div>
            </div>
            <div style="overflow-x:auto;">
                <table class="tbl">
                    <thead><tr><th>#</th><th>Full Name</th><th>Username</th><th>Role</th><th>Status</th><th>Created</th></tr></thead>
                    <tbody>
                    <%
                    try (Connection conn = DBConnection.getConnection()) {
                        ResultSet ru = conn.createStatement().executeQuery("SELECT * FROM users ORDER BY role, id");
                        int n = 0;
                        while (ru.next()) { n++;
                            String uRole = ru.getString("role");
                            int active   = ru.getInt("is_active");
                    %>
                        <tr>
                            <td style="color:var(--muted);font-size:.78rem;"><%= n %></td>
                            <td style="font-weight:700;"><%= ru.getString("full_name") %></td>
                            <td><code><%= ru.getString("username") %></code></td>
                            <td><span class="badge badge-<%= uRole %>"><%= uRole.toUpperCase() %></span></td>
                            <td><span class="badge <%= active==1?"badge-active":"badge-inactive" %>"><%= active==1?"● Active":"○ Inactive" %></span></td>
                            <td style="font-size:.78rem;color:var(--muted);"><%= ru.getTimestamp("created_at")!=null?ru.getTimestamp("created_at").toString().substring(0,10):"—" %></td>
                        </tr>
                    <% } if(n==0){%><tr><td colspan="6" style="text-align:center;padding:40px;color:var(--muted);">No users found.</td></tr>
                    <%} } catch(Exception e){%><tr><td colspan="6" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
</body>
</html>
