<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,
                 java.time.LocalDateTime,java.time.format.DateTimeFormatter" %>
<%--
  final_report.jsp — FINAL PRODUCTION REPORT
  =============================================
  PATH    : webapp/jsp/final_report.jsp
  REACHED : Direct link from nav.jsp (admin only)

  ALLOWED ROLES : admin only

  WHAT IT SHOWS:
    Complete workflow status for every vehicle in one unified view:
      Vehicle data  →  QC decision  →  Testing results count

  SQL JOIN USED:
    Combines vehicle + approvals using LEFT JOIN so vehicles without
    a QC decision still appear (as NULL). Subqueries count total tests
    and passed tests per vehicle from testing_status.

  PRINT FEATURE:
    CSS @media print (in style.css) hides sidebar + topbar when printing.
    The "Print Report" button calls window.print().
--%>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp");
        return;
    }
    if (!"admin".equals(sess.getAttribute("role"))) {
        response.sendRedirect("../dashboard.jsp");
        return;
    }
    request.setAttribute("currentPage", "report");

    // Summary counts for the stats bar
    int total = 0, approved = 0, rejected = 0, pending = 0;
    int tPass = 0, tFail = 0, tTotal = 0;
    try (Connection conn = DBConnection.getConnection()) {
        ResultSet r1 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle");
        if (r1.next()) total = r1.getInt(1);
        ResultSet r2 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='approved'");
        if (r2.next()) approved = r2.getInt(1);
        ResultSet r3 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='rejected'");
        if (r3.next()) rejected = r3.getInt(1);
        ResultSet r4 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='pending'");
        if (r4.next()) pending = r4.getInt(1);
        ResultSet r5 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='pass'");
        if (r5.next()) tPass = r5.getInt(1);
        ResultSet r6 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='fail'");
        if (r6.next()) tFail = r6.getInt(1);
        ResultSet r7 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status");
        if (r7.next()) tTotal = r7.getInt(1);
    } catch (Exception ignored) {}

    String now = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd MMMM yyyy, HH:mm"));
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Final Report — AutoProd</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="../css/style.css">
    <style>
    :root{--sw:260px;}
    body{font-family:'Plus Jakarta Sans',sans-serif;}
    .sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
    .sb-brand{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
    .sb-brand-row{display:flex;align-items:center;gap:10px;}
    .sb-icon{width:36px;height:36px;background:linear-gradient(135deg,#e53935,#ff8a65);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0;}
    .sb-name{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;}
    .sb-sub{font-size:.64rem;color:rgba(255,255,255,.32);letter-spacing:.5px;margin-top:2px;}
    .sb-user{padding:14px 20px;border-bottom:1px solid rgba(255,255,255,.08);display:flex;align-items:center;gap:12px;}
    .av{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#e53935,#ff8a65);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.9rem;flex-shrink:0;}
    .uname{font-size:.84rem;font-weight:700;}.urole{font-size:.66rem;color:rgba(255,255,255,.38);text-transform:uppercase;letter-spacing:.8px;}
    .dot-g{width:7px;height:7px;background:#22c55e;border-radius:50%;display:inline-block;margin-right:4px;}
    .ns{padding:16px 20px 5px;font-size:.6rem;color:rgba(255,255,255,.26);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
    .nl{display:flex;align-items:center;gap:10px;padding:10px 20px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;font-weight:500;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
    .nl i{font-size:.95rem;flex-shrink:0;}.nl:hover{background:rgba(255,255,255,.07);color:#fff;}
    .nl.active{background:rgba(255,255,255,.12);color:#fff;border-left-color:#e53935;}
    .sf-sb{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
    .sf-sb a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
    .sf-sb a:hover{background:rgba(255,255,255,.07);color:#fff;}
    .main-content{margin-left:var(--sw);}
    .rpt-topbar{background:#fff;border-bottom:1px solid #e5e9f2;padding:14px 28px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;}
    @media print{.sb,.rpt-topbar{display:none!important;}.main-content{margin-left:0!important;}}
    </style>
</head>
<body>

<!-- Admin Sidebar -->
<nav class="sb">
    <div class="sb-brand">
        <div class="sb-brand-row">
            <div class="sb-icon">🏭</div>
            <div><div class="sb-name">AutoProd</div><div class="sb-sub">ADMIN PANEL</div></div>
        </div>
    </div>
    <div class="sb-user">
        <div class="av"><%= sess.getAttribute("fullName")!=null?String.valueOf(((String)sess.getAttribute("fullName")).charAt(0)).toUpperCase():"A" %></div>
        <div>
            <div class="uname"><%= sess.getAttribute("fullName")!=null?sess.getAttribute("fullName"):"Admin" %></div>
            <div class="urole"><span class="dot-g"></span>Administrator</div>
        </div>
    </div>
    <div class="ns">Main</div>
    <a href="admin/admin_dashboard.jsp" class="nl"><i class="bi bi-speedometer2"></i> Dashboard</a>
    <a href="admin/admin_dashboard.jsp?tab=requirements" class="nl"><i class="bi bi-clipboard-check"></i> Requirements</a>
    <div class="ns">Production</div>
    <a href="admin/create_internal_job.jsp" class="nl"><i class="bi bi-hammer"></i> Internal Jobs</a>
    <a href="admin/create_external_order.jsp" class="nl"><i class="bi bi-truck"></i> External Orders</a>
    <a href="admin/admin_dashboard.jsp?tab=workflow" class="nl"><i class="bi bi-diagram-3"></i> Workflow</a>
    <div class="ns">Modules</div>
    <a href="admin/admin_dashboard.jsp?tab=vehicles" class="nl"><i class="bi bi-car-front"></i> Vehicles</a>
    <a href="admin/admin_dashboard.jsp?tab=qc" class="nl"><i class="bi bi-shield-check"></i> QC History</a>
    <a href="admin/admin_dashboard.jsp?tab=testing" class="nl"><i class="bi bi-clipboard2-pulse"></i> Testing</a>
    <a href="admin/admin_dashboard.jsp?tab=customers" class="nl"><i class="bi bi-people"></i> Customers</a>
    <div class="ns">Admin Tools</div>
    <a href="admin/manage_users.jsp" class="nl"><i class="bi bi-person-gear"></i> Manage Users</a>
    <a href="final_report.jsp" class="nl active"><i class="bi bi-file-earmark-bar-graph"></i> Final Report</a>
    <div class="sf-sb">
        <a href="../logout"><i class="bi bi-box-arrow-left"></i> Logout</a>
    </div>
</nav>

<div class="main-content">
    <div class="rpt-topbar">
        <div>
            <div style="font-weight:800;font-size:.95rem;"><i class="bi bi-file-earmark-bar-graph-fill" style="color:#0f1f5c;margin-right:6px;"></i>Final Production Report</div>
            <div style="font-size:.75rem;color:#6b7280;">Complete workflow status for all vehicles</div>
        </div>
        <div style="display:flex;align-items:center;gap:10px;">
            <a href="admin/admin_dashboard.jsp" style="background:#f0f3f9;border:1px solid #e5e9f2;padding:7px 14px;border-radius:8px;color:#1a1f36;text-decoration:none;font-weight:600;font-size:.82rem;display:flex;align-items:center;gap:6px;">
                <i class="bi bi-arrow-left"></i> Dashboard
            </a>
            <button onclick="window.print()" style="background:linear-gradient(135deg,#0a1240,#0f1f5c);color:#fff;border:none;padding:8px 18px;border-radius:8px;font-weight:700;cursor:pointer;font-size:.85rem;display:flex;align-items:center;gap:6px;font-family:inherit;">
                <i class="bi bi-printer"></i> Print Report
            </button>
        </div>
    </div>

        <div class="page-content">

            <!-- ══ REPORT HEADER BLOCK ══ -->
            <div style="background:linear-gradient(135deg,#1a237e,#283593);
                        color:white;border-radius:12px;padding:28px;
                        text-align:center;margin-bottom:24px;">
                <h2 style="font-size:1.45rem;margin-bottom:6px;font-weight:700;">
                    AUTOMOBILE PRODUCTION WORKFLOW REPORT
                </h2>
                <p style="opacity:0.75;font-size:0.9rem;">Generated: <%= now %></p>
                <p style="opacity:0.6;font-size:0.8rem;margin-top:3px;">
                    Automobile Production Data Security &amp; Workflow Optimization System
                </p>
            </div>

            <!-- ══ SUMMARY STATS ══ -->
            <div class="stats-grid" style="margin-bottom:24px;">
                <div class="stat-card">
                    <div class="stat-icon blue">🚗</div>
                    <div class="stat-info"><p><%= total %></p><span>Total Vehicles</span></div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon green">✅</div>
                    <div class="stat-info"><p><%= approved %></p><span>QC Approved</span></div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon red">❌</div>
                    <div class="stat-info"><p><%= rejected %></p><span>QC Rejected</span></div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon orange">⏳</div>
                    <div class="stat-info"><p><%= pending %></p><span>Pending QC</span></div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon purple">🔬</div>
                    <div class="stat-info">
                        <p><%= tPass %>/<%= tTotal %></p>
                        <span>Tests Passed</span>
                    </div>
                </div>
            </div>

            <!-- ══ COMPLETE WORKFLOW TABLE ══ -->
            <%--
                SQL JOIN explanation:
                  vehicle (v)      — core data
                  LEFT JOIN approvals (a) — QC decision (NULL if not reviewed)
                  Subqueries count total tests and passed tests per vehicle
            --%>
            <div class="card" style="margin-bottom:24px;">
                <div class="card-header">
                    <h3>🏭 Complete Vehicle Workflow Status</h3>
                </div>
                <div class="table-wrapper">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Model Name</th>
                                <th>Seating</th>
                                <th>Fuel/Bat Cap</th>
                                <th>Type</th>
                                <th>Design By</th>
                                <th>QC Status</th>
                                <th>QC Officer</th>
                                <th>QC Remarks</th>
                                <th>Tests Run</th>
                                <th>Passed</th>
                                <th>Added Date</th>
                            </tr>
                        </thead>
                        <tbody>
                        <%
                        try (Connection conn = DBConnection.getConnection()) {
                            ResultSet rs = conn.createStatement().executeQuery(
                                "SELECT v.*, " +
                                "  a.action AS qc_action, a.remarks AS qc_remarks, a.qc_user, " +
                                "  (SELECT COUNT(*) FROM testing_status t " +
                                "   WHERE t.vehicle_id = v.id) AS total_tests, " +
                                "  (SELECT COUNT(*) FROM testing_status t " +
                                "   WHERE t.vehicle_id = v.id AND t.status = 'pass') AS pass_tests " +
                                "FROM vehicle v " +
                                "LEFT JOIN approvals a ON v.id = a.vehicle_id " +
                                "ORDER BY v.id"
                            );
                            int i = 1;
                            boolean any = false;
                            while (rs.next()) {
                                any = true;
                                String st       = rs.getString("status");
                                String rowClass = "approved".equals(st) ? "report-row-approved"
                                                : "rejected".equals(st) ? "report-row-rejected" : "";
                                String qcOfficer  = rs.getString("qc_user");
                                String qcRemarks  = rs.getString("qc_remarks");
                        %>
                            <tr class="<%= rowClass %>">
                                <td><%= i++ %></td>
                                <td><strong><%= rs.getString("model_name") %></strong></td>
                                <td><%= rs.getInt("seating_capacity") %></td>
                                <td><%= rs.getDouble("fuel_battery_capacity") %></td>
                                <td><%= rs.getString("fuel_type") %></td>
                                <td><%= rs.getString("added_by") %></td>
                                <td>
                                    <span class="status-badge status-<%= st %>">
                                        <%= st %>
                                    </span>
                                </td>
                                <td><%= qcOfficer != null ? qcOfficer : "—" %></td>
                                <td style="font-size:0.82rem;max-width:140px;">
                                    <%= qcRemarks != null ? qcRemarks : "—" %>
                                </td>
                                <td style="text-align:center;"><%= rs.getInt("total_tests") %></td>
                                <td style="text-align:center;"><%= rs.getInt("pass_tests") %></td>
                                <td style="font-size:0.82rem;">
                                    <%= rs.getTimestamp("created_at").toString().substring(0,10) %>
                                </td>
                            </tr>
                        <%
                            }
                            if (!any) {
                        %>
                            <tr>
                                <td colspan="12"
                                    style="text-align:center;color:#aaa;padding:28px;">
                                    No vehicle data available.
                                </td>
                            </tr>
                        <%  } } catch (Exception e) { %>
                            <tr>
                                <td colspan="12" style="color:red;padding:16px;">
                                    Error: <%= e.getMessage() %>
                                </td>
                            </tr>
                        <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- ══ DETAILED TESTING LOG ══ -->
            <div class="card">
                <div class="card-header">
                    <h3>🔬 Detailed Testing Log</h3>
                </div>
                <div class="table-wrapper">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Vehicle Model</th>
                                <th>Test Type</th>
                                <th>Result</th>
                                <th>Remarks</th>
                                <th>Tested By</th>
                                <th>Test Date</th>
                            </tr>
                        </thead>
                        <tbody>
                        <%
                        try (Connection conn = DBConnection.getConnection()) {
                            ResultSet rs = conn.createStatement().executeQuery(
                                "SELECT t.*, v.model_name " +
                                "FROM testing_status t " +
                                "JOIN vehicle v ON t.vehicle_id = v.id " +
                                "ORDER BY t.id"
                            );
                            int i = 1;
                            boolean any = false;
                            while (rs.next()) {
                                any = true;
                                String st = rs.getString("status");
                        %>
                            <tr>
                                <td><%= i++ %></td>
                                <td><strong><%= rs.getString("model_name") %></strong></td>
                                <td><%= rs.getString("test_type") %></td>
                                <td>
                                    <span class="status-badge status-<%= st %>">
                                        <%= st %>
                                    </span>
                                </td>
                                <td><%= rs.getString("test_remarks") %></td>
                                <td><%= rs.getString("tested_by") %></td>
                                <td><%= rs.getTimestamp("test_date").toString().substring(0,10) %></td>
                            </tr>
                        <%
                            }
                            if (!any) {
                        %>
                            <tr>
                                <td colspan="7"
                                    style="text-align:center;color:#aaa;padding:24px;">
                                    No testing records yet.
                                </td>
                            </tr>
                        <%  } } catch (Exception e) { %>
                            <tr>
                                <td colspan="7" style="color:red;padding:16px;">
                                    Error: <%= e.getMessage() %>
                                </td>
                            </tr>
                        <% } %>
                        </tbody>
                    </table>
                </div>
            </div>

            <p style="text-align:center;color:#bbb;font-size:0.8rem;margin-top:10px;padding-bottom:10px;">
                — End of Report — Automobile Production Data Security &amp; Workflow Optimization System
            </p>

        </div><!-- /page-content -->
    </div><!-- /main-content -->
</body>
</html>
