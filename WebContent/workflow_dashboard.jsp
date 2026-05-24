<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect(request.getContextPath() + "/index.jsp");
        return;
    }
    String role     = (String) sess.getAttribute("role");
    String fullName = (String) sess.getAttribute("fullName");
    String ctx      = request.getContextPath();

    // ── Role-based filter ──
    String stageFilter  = "1=0";
    String pageTitle    = "";
    String roleColor    = "#0a6ebd";

    // Admin sees TWO queues — initial review AND final approval
    String stageFilter2 = ""; // second queue for admin

    if ("admin".equals(role)) {
        stageFilter  = "current_assignee='admin' AND workflow_stage IN ('admin_initial_review','submitted','in_review')";
        stageFilter2 = "current_assignee='admin' AND workflow_stage='analytics_completed'";
        pageTitle    = "👑 Admin — Workflow Dashboard";
        roleColor    = "#0d1b2a";
    } else if ("design".equals(role)) {
        stageFilter  = "workflow_stage='admin_initial_approved' AND current_assignee NOT IN ('admin','qc','testing','analytics')";
        pageTitle    = "🎨 Design Team — Workflow";
        roleColor    = "#1565c0";
    } else if ("qc".equals(role)) {
        stageFilter  = "current_assignee='qc' AND workflow_stage='design_completed'";
        pageTitle    = "✅ QC Team — Workflow";
        roleColor    = "#2e7d32";
    } else if ("testing".equals(role)) {
        stageFilter  = "current_assignee='testing' AND workflow_stage='qc_approved'";
        pageTitle    = "🔬 Testing Team — Workflow";
        roleColor    = "#e65100";
    } else if ("analytics".equals(role)) {
        stageFilter  = "current_assignee='analytics' AND workflow_stage='testing_completed'";
        pageTitle    = "📊 Analytics Team — Workflow";
        roleColor    = "#6a1b9a";
    }

    int pendingCount    = 0;
    int internalJobCount = 0;  // internal jobs for design role
    int finalCount      = 0;
    int totalCustomers  = 0;
    int totalSubmitted  = 0;
    int totalPending    = 0;
    int totalInProgress = 0;
    int totalCompleted  = 0;
    int totalRejected   = 0;
    try (Connection conn = DBConnection.getConnection()) {
        ResultSet cr = conn.createStatement().executeQuery(
            "SELECT COUNT(*) FROM customer_requirements WHERE " + stageFilter);
        if (cr.next()) pendingCount = cr.getInt(1);

        // Count internal jobs for design team
        if ("design".equals(role)) {
            String loggedUser = (String) sess.getAttribute("username");
            try {
                PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM internal_jobs " +
                    "WHERE current_assignee=? " +
                    "  AND workflow_stage NOT IN ('completed','cancelled','design_completed')");
                ps.setString(1, loggedUser != null ? loggedUser : "");
                ResultSet ij = ps.executeQuery();
                if (ij.next()) internalJobCount = ij.getInt(1);
            } catch (Exception ig) {}
        }

        if (!stageFilter2.isEmpty()) {
            ResultSet cr2 = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements WHERE " + stageFilter2);
            if (cr2.next()) finalCount = cr2.getInt(1);
        }
        if ("admin".equals(role)) {
            ResultSet s1 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customers WHERE is_verified=1");
            if (s1.next()) totalCustomers = s1.getInt(1);
            ResultSet s2 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements");
            if (s2.next()) totalSubmitted = s2.getInt(1);
            ResultSet s3 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE status='pending'");
            if (s3.next()) totalPending = s3.getInt(1);
            ResultSet s4 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE status='in_review'");
            if (s4.next()) totalInProgress = s4.getInt(1);
            ResultSet s5 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE status='completed'");
            if (s5.next()) totalCompleted = s5.getInt(1);
            ResultSet s6 = conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE status='rejected'");
            if (s6.next()) totalRejected = s6.getInt(1);
        }
    } catch (Exception ignored) {}
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= pageTitle %> — AutoProd</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.2/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <style>
        :root { --primary:#0a6ebd; --teal:#00b4a6; --dark:#0d1b2a; }
        body { background:#f0f4f8; font-family:'Segoe UI',sans-serif; }

        .topbar { background:#fff; padding:14px 28px; display:flex; align-items:center; justify-content:space-between; border-bottom:1px solid #e0e0e0; position:sticky; top:0; z-index:100; box-shadow:0 2px 8px rgba(0,0,0,.05); }
        .topbar h5 { margin:0; font-weight:700; color:<%= roleColor %>; }

        .page-body { padding:24px 28px; max-width:1200px; margin:0 auto; }

        /* Pipeline */
        .pipeline { background:#fff; border-radius:14px; padding:20px 28px; margin-bottom:24px; box-shadow:0 2px 12px rgba(0,0,0,.06); }
        .pipeline-title { font-size:.72rem; font-weight:700; color:#6b7c93; text-transform:uppercase; letter-spacing:1px; margin-bottom:14px; }
        .pipeline-steps { display:flex; align-items:center; }
        .p-step { display:flex; flex-direction:column; align-items:center; flex:1; }
        .p-circle { width:40px; height:40px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:.9rem; border:2px solid #e0e0e0; background:#fff; }
        .p-step.done   .p-circle { background:#2e7d32; border-color:#2e7d32; color:#fff; }
        .p-step.active .p-circle { border-color:transparent; color:#fff; }
        .p-label { font-size:.62rem; font-weight:600; color:#6b7c93; margin-top:5px; text-align:center; }
        .p-step.done .p-label, .p-step.active .p-label { font-weight:700; }
        .p-line { flex:1; height:2px; background:#e0e0e0; margin-bottom:22px; }
        .p-line.done { background:linear-gradient(to right,#2e7d32,var(--teal)); }

        /* Section heading */
        .section-heading { font-size:.8rem; font-weight:800; text-transform:uppercase; letter-spacing:1px; padding:8px 16px; border-radius:8px; margin-bottom:14px; display:inline-flex; align-items:center; gap:8px; }
        .sh-initial { background:#fff3e0; color:#e65100; }
        .sh-final   { background:#e8f5e9; color:#2e7d32; }
        .sh-work    { background:#e3f2fd; color:#1565c0; }

        /* Banner */
        .wf-banner { border-radius:14px; padding:18px 24px; color:#fff; margin-bottom:20px; display:flex; align-items:center; justify-content:space-between; }
        .wf-banner h4 { font-weight:700; margin:0 0 3px; font-size:1rem; }
        .wf-banner p  { margin:0; opacity:.85; font-size:.8rem; }
        .pending-pill { background:rgba(255,255,255,.25); padding:6px 16px; border-radius:16px; font-weight:700; font-size:.8rem; border:2px solid rgba(255,255,255,.4); }

        /* Requirement card */
        .req-card { background:#fff; border-radius:14px; box-shadow:0 2px 12px rgba(0,0,0,.06); margin-bottom:18px; overflow:hidden; border-left:4px solid; }
        .req-card-head { padding:14px 20px; border-bottom:1px solid #f5f5f5; display:flex; align-items:flex-start; justify-content:space-between; gap:12px; }
        .req-card-body { padding:14px 20px; }
        .req-card-foot { padding:12px 20px; background:#fafafa; border-top:1px solid #f0f0f0; }

        .req-title { font-weight:700; font-size:.95rem; color:var(--dark); margin:0 0 6px; }
        .req-meta  { display:flex; gap:12px; flex-wrap:wrap; }
        .req-meta span { font-size:.76rem; color:#6b7c93; display:flex; align-items:center; gap:4px; }

        /* Stage pills */
        .stage-pill { padding:4px 12px; border-radius:20px; font-size:.7rem; font-weight:700; text-transform:uppercase; letter-spacing:.5px; white-space:nowrap; }
        .sp-admin_initial_review    { background:#fff3e0; color:#e65100; }
        .sp-admin_initial_approved  { background:#e8f5e9; color:#2e7d32; }
        .sp-admin_initial_rejected  { background:#ffebee; color:#c62828; }
        .sp-design_review           { background:#e3f2fd; color:#1565c0; }
        .sp-design_completed        { background:#e1f5fe; color:#0277bd; }
        .sp-qc_approved             { background:#c8e6c9; color:#1b5e20; }
        .sp-qc_rejected             { background:#ffebee; color:#c62828; }
        .sp-testing_completed       { background:#fce4ec; color:#ad1457; }
        .sp-analytics_completed     { background:#ede7f6; color:#4527a0; }
        .sp-completed               { background:#e8f5e9; color:#1b5e20; }
        .sp-rejected                { background:#ffebee; color:#b71c1c; }

        /* Uploaded file */
        .file-preview { display:inline-flex; align-items:center; gap:6px; background:#f0f7ff; border:1px solid #b3d9f7; border-radius:8px; padding:6px 12px; font-size:.8rem; color:#1565c0; font-weight:600; text-decoration:none; margin-top:8px; }
        .file-preview:hover { background:#e3f2fd; }

        /* History */
        .history-wrap { background:#f8f9fb; border-radius:10px; padding:12px 16px; margin-top:10px; }
        .history-title { font-size:.68rem; font-weight:700; color:#6b7c93; text-transform:uppercase; letter-spacing:1px; margin-bottom:8px; }
        .hist-item { display:flex; gap:10px; padding:6px 0; border-bottom:1px solid #eee; }
        .hist-item:last-child { border-bottom:none; }
        .hist-dot { width:8px; height:8px; border-radius:50%; background:var(--teal); margin-top:5px; flex-shrink:0; }
        .hist-action { font-size:.8rem; font-weight:600; color:var(--dark); }
        .hist-meta   { font-size:.73rem; color:#6b7c93; margin-top:2px; }
        .hist-remark { font-size:.73rem; color:var(--primary); margin-top:2px; }

        /* Action form */
        .action-form { display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
        .remarks-input { flex:1; min-width:180px; padding:8px 12px; border:1.5px solid #dce3ed; border-radius:8px; font-size:.82rem; outline:none; }
        .remarks-input:focus { border-color:var(--primary); }
        .btn-approve { padding:8px 18px; background:linear-gradient(135deg,#2e7d32,#1b5e20); color:#fff; border:none; border-radius:8px; font-weight:700; font-size:.82rem; cursor:pointer; display:flex; align-items:center; gap:5px; transition:all .2s; }
        .btn-approve:hover { transform:translateY(-1px); box-shadow:0 4px 12px rgba(46,125,50,.3); }
        .btn-reject  { padding:8px 18px; background:linear-gradient(135deg,#c62828,#b71c1c); color:#fff; border:none; border-radius:8px; font-weight:700; font-size:.82rem; cursor:pointer; display:flex; align-items:center; gap:5px; transition:all .2s; }
        .btn-reject:hover  { transform:translateY(-1px); box-shadow:0 4px 12px rgba(198,40,40,.3); }

        /* Empty */
        .empty-state { text-align:center; padding:48px 20px; color:#6b7c93; }
        .empty-state i { font-size:3rem; display:block; margin-bottom:12px; color:#dce3ed; }

        .back-btn { display:inline-flex; align-items:center; gap:6px; padding:7px 14px; background:#fff; color:#6b7c93; border:1.5px solid #dce3ed; border-radius:8px; font-size:.85rem; font-weight:600; cursor:pointer; text-decoration:none; transition:all .2s; margin-bottom:18px; }
        .back-btn:hover { background:var(--primary); color:#fff; border-color:var(--primary); }

        /* Stats cards */
        .stats-grid { display:grid; grid-template-columns:repeat(6,1fr); gap:14px; margin-bottom:24px; }
        .stat-card { background:#fff; border-radius:14px; padding:16px 18px; box-shadow:0 2px 12px rgba(0,0,0,.06); display:flex; flex-direction:column; gap:6px; border-top:4px solid; }
        .stat-card .s-val { font-size:2rem; font-weight:800; line-height:1; }
        .stat-card .s-lbl { font-size:.72rem; font-weight:700; text-transform:uppercase; letter-spacing:.5px; color:#6b7c93; }
        .stat-card .s-icon { font-size:1.4rem; }
        .sc-customers  { border-color:#0a6ebd; } .sc-customers  .s-val { color:#0a6ebd; }
        .sc-total      { border-color:#00b4a6; } .sc-total      .s-val { color:#00b4a6; }
        .sc-pending    { border-color:#e65100; } .sc-pending    .s-val { color:#e65100; }
        .sc-inprogress { border-color:#1565c0; } .sc-inprogress .s-val { color:#1565c0; }
        .sc-completed  { border-color:#2e7d32; } .sc-completed  .s-val { color:#2e7d32; }
        .sc-rejected   { border-color:#c62828; } .sc-rejected   .s-val { color:#c62828; }
        @media(max-width:1100px) { .stats-grid { grid-template-columns:repeat(3,1fr); } }
        @media(max-width:768px) { .page-body{padding:16px;} .req-meta{flex-direction:column;gap:4px;} .stats-grid{grid-template-columns:repeat(2,1fr);} }
    </style>
</head>
<body>

<!-- TOPBAR -->
<div class="topbar">
    <h5><i class="bi bi-arrow-repeat me-2"></i><%= pageTitle %></h5>
    <div class="d-flex align-items-center gap-2">
        <span class="badge" style="background:<%= roleColor %>;font-size:.72rem;padding:5px 12px;text-transform:capitalize;">
            <%= role %>
        </span>
        <a href="<%= ctx %>/dashboard.jsp" class="btn btn-sm btn-outline-secondary">
            <i class="bi bi-house me-1"></i>Dashboard
        </a>
        <a href="<%= ctx %>/logout" class="btn btn-sm btn-outline-danger">
            <i class="bi bi-box-arrow-right me-1"></i>Logout
        </a>
    </div>
</div>

<div class="page-body">

    <a href="<%= ctx %>/dashboard.jsp" class="back-btn">
        <i class="bi bi-arrow-left"></i> Back to Dashboard
    </a>

    <% if ("admin".equals(role)) { %>
    <!-- Stats Cards -->
    <div class="stats-grid">
        <div class="stat-card sc-customers">
            <div class="s-icon">👥</div>
            <div class="s-val"><%= totalCustomers %></div>
            <div class="s-lbl">Total Customers</div>
        </div>
        <div class="stat-card sc-total">
            <div class="s-icon">📋</div>
            <div class="s-val"><%= totalSubmitted %></div>
            <div class="s-lbl">Total Submissions</div>
        </div>
        <div class="stat-card sc-pending">
            <div class="s-icon">⏳</div>
            <div class="s-val"><%= totalPending %></div>
            <div class="s-lbl">Pending Review</div>
        </div>
        <div class="stat-card sc-inprogress">
            <div class="s-icon">🔄</div>
            <div class="s-val"><%= totalInProgress %></div>
            <div class="s-lbl">In Progress</div>
        </div>
        <div class="stat-card sc-completed">
            <div class="s-icon">✅</div>
            <div class="s-val"><%= totalCompleted %></div>
            <div class="s-lbl">Completed</div>
        </div>
        <div class="stat-card sc-rejected">
            <div class="s-icon">❌</div>
            <div class="s-val"><%= totalRejected %></div>
            <div class="s-lbl">Rejected</div>
        </div>
    </div>
    <% } %>

    <!-- Pipeline -->
    <div class="pipeline">
        <div class="pipeline-title">Complete Workflow Pipeline</div>
        <div class="pipeline-steps">

            <div class="p-step <%= "admin".equals(role) ? "active" : "done" %>">
                <div class="p-circle" style="<%= "admin".equals(role) ? "background:linear-gradient(135deg,#0d1b2a,#1a2b3c)" : "" %>">
                    <%= "admin".equals(role) ? "👑" : "✅" %>
                </div>
                <div class="p-label" style="<%= "admin".equals(role) ? "color:#0d1b2a" : "" %>">Admin Review</div>
            </div>
            <div class="p-line <%= (!("admin".equals(role))) ? "done" : "" %>"></div>

            <div class="p-step <%= "design".equals(role) ? "active" : ("qc".equals(role)||"testing".equals(role)||"analytics".equals(role)) ? "done" : "" %>">
                <div class="p-circle" style="<%= "design".equals(role) ? "background:linear-gradient(135deg,#1565c0,#0d47a1)" : "" %>">
                    <%= "design".equals(role) ? "🎨" : ("qc".equals(role)||"testing".equals(role)||"analytics".equals(role)) ? "✅" : "🎨" %>
                </div>
                <div class="p-label" style="<%= "design".equals(role) ? "color:#1565c0" : "" %>">Design</div>
            </div>
            <div class="p-line <%= ("qc".equals(role)||"testing".equals(role)||"analytics".equals(role)) ? "done" : "" %>"></div>

            <div class="p-step <%= "qc".equals(role) ? "active" : ("testing".equals(role)||"analytics".equals(role)) ? "done" : "" %>">
                <div class="p-circle" style="<%= "qc".equals(role) ? "background:linear-gradient(135deg,#2e7d32,#1b5e20)" : "" %>">
                    <%= "qc".equals(role) ? "✅" : ("testing".equals(role)||"analytics".equals(role)) ? "✅" : "✅" %>
                </div>
                <div class="p-label" style="<%= "qc".equals(role) ? "color:#2e7d32" : "" %>">QC</div>
            </div>
            <div class="p-line <%= ("testing".equals(role)||"analytics".equals(role)) ? "done" : "" %>"></div>

            <div class="p-step <%= "testing".equals(role) ? "active" : "analytics".equals(role) ? "done" : "" %>">
                <div class="p-circle" style="<%= "testing".equals(role) ? "background:linear-gradient(135deg,#e65100,#bf360c)" : "" %>">
                    <%= "testing".equals(role) ? "🔬" : "analytics".equals(role) ? "✅" : "🔬" %>
                </div>
                <div class="p-label" style="<%= "testing".equals(role) ? "color:#e65100" : "" %>">Testing</div>
            </div>
            <div class="p-line <%= "analytics".equals(role) ? "done" : "" %>"></div>

            <div class="p-step <%= "analytics".equals(role) ? "active" : "" %>">
                <div class="p-circle" style="<%= "analytics".equals(role) ? "background:linear-gradient(135deg,#6a1b9a,#4a148c)" : "" %>">
                    <%= "analytics".equals(role) ? "📊" : "📊" %>
                </div>
                <div class="p-label" style="<%= "analytics".equals(role) ? "color:#6a1b9a" : "" %>">Analytics</div>
            </div>
            <div class="p-line"></div>

            <div class="p-step">
                <div class="p-circle">👑</div>
                <div class="p-label">Final Approval</div>
            </div>
            <div class="p-line"></div>

            <div class="p-step">
                <div class="p-circle">🚗</div>
                <div class="p-label">Done!</div>
            </div>

        </div>
    </div>

    <%-- ══════════════════════════════════════════════════
         ADMIN — SECTION 1: INITIAL REVIEW
    ══════════════════════════════════════════════════ --%>
    <% if ("admin".equals(role)) { %>

    <!-- Banner 1 -->
    <div class="wf-banner" style="background:linear-gradient(135deg,#e65100,#bf360c);">
        <div>
            <h4><i class="bi bi-inbox-fill me-2"></i>New Customer Requirements</h4>
            <p>Review customer submissions — approve to forward to Design team or reject</p>
        </div>
        <div class="pending-pill"><%= pendingCount %> Pending</div>
    </div>

    <div class="section-heading sh-initial">
        <i class="bi bi-inbox"></i> Step 1 — Initial Review (New Submissions)
    </div>

    <%
    try (Connection conn = DBConnection.getConnection()) {
        ResultSet rs = conn.createStatement().executeQuery(
            "SELECT cr.*, c.email, c.phone " +
            "FROM customer_requirements cr " +
            "LEFT JOIN customers c ON cr.customer_id = c.id " +
            "WHERE " + stageFilter + " ORDER BY cr.submitted_at DESC");
        int count = 0;
        while (rs.next()) {
            count++;
            String stage = rs.getString("workflow_stage");
            if (stage == null) stage = "submitted";
    %>
    <div class="req-card" style="border-left-color:#e65100;">
        <div class="req-card-head">
            <div style="flex:1;">
                <p class="req-title">#<%= rs.getInt("id") %> — <%= rs.getString("req_title") %></p>
                <div class="req-meta">
                    <span><i class="bi bi-person-fill"></i> <%= rs.getString("client_name") %></span>
                    <span><i class="bi bi-envelope"></i> <%= rs.getString("email") != null ? rs.getString("email") : "N/A" %></span>
                    <span><i class="bi bi-telephone"></i> <%= rs.getString("phone") != null ? rs.getString("phone") : "N/A" %></span>
                    <span><i class="bi bi-grid"></i> <%= rs.getString("module_name") %></span>
                    <span><i class="bi bi-fuel-pump"></i> <%= rs.getString("deadline") %></span>
                    <span><i class="bi bi-currency-rupee"></i> <%= rs.getString("budget") %></span>
                    <span><i class="bi bi-clock"></i> <%= rs.getTimestamp("submitted_at") != null ? rs.getTimestamp("submitted_at").toString().substring(0,16) : "N/A" %></span>
                </div>
            </div>
            <span class="stage-pill sp-admin_initial_review">New Submission</span>
        </div>
        <div class="req-card-body">
            <p style="font-size:.875rem;color:#444;margin:0 0 14px;">
                <strong style="color:var(--dark);">Description:</strong> <%= rs.getString("req_desc") %>
            </p>
            <!-- ── Document Section ── -->
            <% String attachment = rs.getString("attachment");
               if (attachment != null && !attachment.trim().isEmpty()) {
                   String ext = attachment.contains(".") ?
                       attachment.substring(attachment.lastIndexOf(".")+1).toLowerCase() : "file";
                   String fileIcon = "bi-file-earmark";
                   String fileColor = "#1565c0";
                   if (ext.equals("pdf"))  { fileIcon = "bi-file-earmark-pdf";   fileColor = "#c62828"; }
                   else if (ext.equals("doc") || ext.equals("docx")) { fileIcon = "bi-file-earmark-word"; fileColor = "#1565c0"; }
                   else if (ext.equals("jpg") || ext.equals("jpeg") || ext.equals("png")) { fileIcon = "bi-file-earmark-image"; fileColor = "#2e7d32"; }
                   else if (ext.equals("xlsx") || ext.equals("xls")) { fileIcon = "bi-file-earmark-excel"; fileColor = "#1b5e20"; }
            %>
            <div style="background:#f0f7ff;border:2px solid #b3d9f7;border-radius:12px;padding:14px 18px;margin-bottom:10px;">
                <div style="font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:.5px;color:#1565c0;margin-bottom:10px;">
                    <i class="bi bi-paperclip me-1"></i> Customer Uploaded Document
                </div>
                <div style="display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;">
                    <div style="display:flex;align-items:center;gap:10px;">
                        <div style="width:42px;height:42px;background:#fff;border-radius:10px;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,.08);">
                            <i class="bi <%= fileIcon %>" style="font-size:1.4rem;color:<%= fileColor %>;"></i>
                        </div>
                        <div>
                            <div style="font-weight:700;font-size:.85rem;color:#0d1b2a;"><%= attachment %></div>
                            <div style="font-size:.72rem;color:#6b7c93;text-transform:uppercase;"><%= ext %> File</div>
                        </div>
                    </div>
                    <div style="display:flex;gap:8px;">
                        <a href="<%= ctx %>/uploads/<%= attachment %>" target="_blank"
                           style="display:inline-flex;align-items:center;gap:6px;padding:8px 16px;background:linear-gradient(135deg,#1565c0,#0d47a1);color:#fff;border-radius:8px;font-size:.82rem;font-weight:700;text-decoration:none;">
                            <i class="bi bi-eye"></i> View
                        </a>
                        <a href="<%= ctx %>/uploads/<%= attachment %>" download
                           style="display:inline-flex;align-items:center;gap:6px;padding:8px 16px;background:linear-gradient(135deg,#2e7d32,#1b5e20);color:#fff;border-radius:8px;font-size:.82rem;font-weight:700;text-decoration:none;">
                            <i class="bi bi-download"></i> Download
                        </a>
                    </div>
                </div>
            </div>
            <% } else { %>
            <div style="background:#fff8e1;border:2px dashed #ffb300;border-radius:12px;padding:12px 18px;margin-bottom:10px;display:flex;align-items:center;gap:10px;">
                <i class="bi bi-exclamation-triangle-fill" style="color:#ff6f00;font-size:1.2rem;flex-shrink:0;"></i>
                <div>
                    <div style="font-size:.82rem;font-weight:700;color:#e65100;">No Document Uploaded</div>
                    <div style="font-size:.75rem;color:#6b7c93;">Customer did not attach any document with this requirement.</div>
                </div>
            </div>
            <% } %>
        </div>
        <div class="req-card-foot">
            <form method="post" action="<%= ctx %>/workflow" class="action-form"
                  onsubmit="return checkVerified(this, 'admin_initial_approve')">
                <input type="hidden" name="requirementId" value="<%= rs.getInt("id") %>">
                <!-- ── Level 3: Admin Verification Checkbox ── -->
                <% String docType2 = rs.getString("doc_type");
                   if (docType2 == null) docType2 = "Company Document"; %>
                <div style="background:#fff8e1;border:1.5px solid #ffb300;border-radius:10px;padding:12px 16px;margin-bottom:12px;grid-column:1/-1;">
                    <label style="display:flex;align-items:flex-start;gap:10px;cursor:pointer;margin:0;">
                        <input type="checkbox" class="verify-chk" id="chk_<%= rs.getInt("id") %>"
                               onchange="toggleApprove(this, 'approve_<%= rs.getInt("id") %>')"
                               style="width:18px;height:18px;margin-top:2px;accent-color:#2e7d32;flex-shrink:0;">
                        <span style="font-size:.82rem;color:#0d1b2a;line-height:1.5;">
                            <strong style="color:#e65100;">⚠️ Verification Required:</strong>
                            I have reviewed and verified the customer's
                            <strong><%= docType2 %></strong> document.
                            It is genuine and belongs to a valid company.
                            I take full responsibility for this approval.
                        </span>
                    </label>
                </div>
                <input type="text" name="remarks" class="remarks-input" placeholder="Add remarks (optional)...">
                <button type="submit" name="action" value="admin_initial_approve"
                        id="approve_<%= rs.getInt("id") %>"
                        class="btn-approve" disabled
                        style="opacity:.4;cursor:not-allowed;"
                        title="Tick the verification checkbox first!">
                    ✅ Approve & Send to Design
                </button>
                <button type="submit" name="action" value="admin_initial_reject" class="btn-reject">
                    ❌ Reject
                </button>
            </form>
        </div>
    </div>
    <%
        }
        if (count == 0) {
    %>
    <div class="empty-state">
        <i class="bi bi-inbox"></i>
        <h6>No New Submissions</h6>
        <p>No customer requirements pending initial review!</p>
    </div>
    <% } } catch (Exception e) { %>
    <div class="alert alert-danger">Error: <%= e.getMessage() %></div>
    <% } %>

    <!-- ══ ADMIN SECTION 2: FINAL APPROVAL ══ -->
    <div style="margin-top:32px;">
        <div class="wf-banner" style="background:linear-gradient(135deg,#2e7d32,#1b5e20);">
            <div>
                <h4><i class="bi bi-check2-all me-2"></i>Final Approval Queue</h4>
                <p>Requirements completed by all teams — give final approval to customer</p>
            </div>
            <div class="pending-pill"><%= finalCount %> Pending</div>
        </div>

        <div class="section-heading sh-final">
            <i class="bi bi-patch-check"></i> Step 2 — Final Approval (All Teams Done)
        </div>

        <%
        try (Connection conn2 = DBConnection.getConnection()) {
            ResultSet rs2 = conn2.createStatement().executeQuery(
                "SELECT cr.*, c.email, c.phone " +
                "FROM customer_requirements cr " +
                "LEFT JOIN customers c ON cr.customer_id = c.id " +
                "WHERE " + stageFilter2 + " ORDER BY cr.submitted_at DESC");
            int count2 = 0;
            while (rs2.next()) {
                count2++;
                String stage2 = rs2.getString("workflow_stage");
        %>
        <div class="req-card" style="border-left-color:#2e7d32;">
            <div class="req-card-head">
                <div style="flex:1;">
                    <p class="req-title">#<%= rs2.getInt("id") %> — <%= rs2.getString("req_title") %></p>
                    <div class="req-meta">
                        <span><i class="bi bi-person-fill"></i> <%= rs2.getString("client_name") %></span>
                        <span><i class="bi bi-envelope"></i> <%= rs2.getString("email") != null ? rs2.getString("email") : "N/A" %></span>
                        <span><i class="bi bi-grid"></i> <%= rs2.getString("module_name") %></span>
                        <span><i class="bi bi-fuel-pump"></i> <%= rs2.getString("deadline") %></span>
                        <span><i class="bi bi-currency-rupee"></i> <%= rs2.getString("budget") %></span>
                    </div>
                </div>
                <span class="stage-pill" style="background:#e8f5e9;color:#1b5e20;">All Teams Done ✅</span>
            </div>
            <div class="req-card-body">
                <p style="font-size:.875rem;color:#444;margin:0;">
                    <strong style="color:var(--dark);">Description:</strong> <%= rs2.getString("req_desc") %>
                </p>
                <!-- Workflow history -->
                <%
                try (Connection conn3 = DBConnection.getConnection()) {
                    ResultSet hist = conn3.createStatement().executeQuery(
                        "SELECT * FROM workflow_history WHERE requirement_id=" + rs2.getInt("id") +
                        " ORDER BY actioned_at DESC LIMIT 6");
                    boolean hasHist = false;
                    StringBuilder hb = new StringBuilder();
                    while (hist.next()) {
                        hasHist = true;
                        hb.append("<div class='hist-item'>")
                          .append("<div class='hist-dot'></div><div>")
                          .append("<div class='hist-action'>").append(hist.getString("action")).append("</div>")
                          .append("<div class='hist-meta'>By <strong>").append(hist.getString("actioned_by"))
                          .append("</strong> · ").append(hist.getString("actioned_at")).append("</div>");
                        String rem = hist.getString("remarks");
                        if (rem != null && !rem.trim().isEmpty())
                            hb.append("<div class='hist-remark'>💬 ").append(rem).append("</div>");
                        hb.append("</div></div>");
                    }
                    if (hasHist) {
                        out.print("<div class='history-wrap'><div class='history-title'>📋 Workflow History</div>");
                        out.print(hb.toString());
                        out.print("</div>");
                    }
                } catch (Exception ignored) {}
                %>
            </div>
            <div class="req-card-foot">
                <form method="post" action="<%= ctx %>/workflow" class="action-form">
                    <input type="hidden" name="requirementId" value="<%= rs2.getInt("id") %>">
                    <input type="text" name="remarks" class="remarks-input" placeholder="Final remarks...">
                    <button type="submit" name="action" value="admin_final_approve" class="btn-approve">
                        🎉 Final Approve & Notify Customer
                    </button>
                    <button type="submit" name="action" value="admin_final_reject" class="btn-reject">
                        ❌ Reject
                    </button>
                </form>
            </div>
        </div>
        <%
            }
            if (count2 == 0) {
        %>
        <div class="empty-state">
            <i class="bi bi-hourglass-split"></i>
            <h6>Nothing for Final Approval Yet</h6>
            <p>Requirements will appear here after all teams complete their work!</p>
        </div>
        <% } } catch (Exception e) { %>
        <div class="alert alert-danger">Error: <%= e.getMessage() %></div>
        <% } %>
    </div>

    <%-- ══ ADMIN STATUS TRACKER ══ --%>
    <div style="margin-top:32px;">
        <div class="wf-banner" style="background:linear-gradient(135deg,#0d1b2a,#1a2b3c);">
            <div>
                <h4><i class="bi bi-activity me-2"></i>All Requirements — Status Tracker</h4>
                <p>Track progress of all submitted requirements across all teams</p>
            </div>
        </div>
        <div class="section-heading" style="color:#0d1b2a;border-color:#0d1b2a;">
            <i class="bi bi-kanban"></i> Live Pipeline Status
        </div>
        <%
        try (Connection connT = DBConnection.getConnection()) {
            ResultSet rsT = connT.createStatement().executeQuery(
                "SELECT cr.*, c.email, c.phone FROM customer_requirements cr " +
                "LEFT JOIN customers c ON cr.customer_id = c.id " +
                "ORDER BY cr.submitted_at DESC");
            int tCnt = 0;
            while (rsT.next()) {
                tCnt++;
                String tStage  = rsT.getString("workflow_stage"); if (tStage == null) tStage = "admin_initial_review";
                String tStatus = rsT.getString("status");         if (tStatus == null) tStatus = "pending";
                int    tReqNum = rsT.getInt("req_number");

                boolean t_adminApproved  = !tStage.equals("admin_initial_review") && !tStage.equals("admin_initial_rejected");
                boolean t_designDone     = tStage.equals("design_completed") || tStage.equals("qc_review") || tStage.equals("qc_approved") || tStage.equals("testing_review") || tStage.equals("testing_completed") || tStage.equals("analytics_review") || tStage.equals("analytics_completed") || tStage.equals("completed");
                boolean t_qcDone         = tStage.equals("qc_approved") || tStage.equals("testing_review") || tStage.equals("testing_completed") || tStage.equals("analytics_review") || tStage.equals("analytics_completed") || tStage.equals("completed");
                boolean t_testingDone    = tStage.equals("testing_completed") || tStage.equals("analytics_review") || tStage.equals("analytics_completed") || tStage.equals("completed");
                boolean t_analyticsDone  = tStage.equals("analytics_completed") || tStage.equals("completed");
                boolean t_finalDone      = tStage.equals("completed");
                boolean t_rejected       = tStage.equals("admin_initial_rejected") || tStage.equals("rejected");

                boolean t_adminActive    = tStage.equals("admin_initial_review");
                boolean t_designActive   = tStage.equals("admin_initial_approved") || tStage.equals("design_review");
                boolean t_qcActive       = tStage.equals("qc_review");
                boolean t_testingActive  = tStage.equals("testing_review");
                boolean t_analyticsActive= tStage.equals("analytics_review");
                boolean t_finalActive    = tStage.equals("analytics_completed");

                String tDate = rsT.getTimestamp("submitted_at") != null ?
                    rsT.getTimestamp("submitted_at").toString().substring(0,10) : "";

                // Stage label + color
                String stageLabel; String stageColor;
                if      (t_finalDone)       { stageLabel = "✅ Completed";          stageColor = "#2e7d32"; }
                else if (t_rejected)        { stageLabel = "❌ Rejected";            stageColor = "#c62828"; }
                else if (t_adminActive)     { stageLabel = "⏳ Admin Review";        stageColor = "#e65100"; }
                else if (t_designActive)    { stageLabel = "🎨 Design In Progress";  stageColor = "#1565c0"; }
                else if (t_qcActive)        { stageLabel = "✅ QC Review";           stageColor = "#2e7d32"; }
                else if (t_testingActive)   { stageLabel = "🔬 Testing";             stageColor = "#e65100"; }
                else if (t_analyticsActive) { stageLabel = "📊 Analytics";           stageColor = "#6a1b9a"; }
                else if (t_finalActive)     { stageLabel = "👑 Final Approval";       stageColor = "#0d1b2a"; }
                else                        { stageLabel = "📋 Pending";             stageColor = "#6b7c93"; }
        %>
        <div class="status-card" style="background:#fff;border-radius:14px;box-shadow:0 2px 12px rgba(0,0,0,.06);margin-bottom:16px;overflow:hidden;">
            <div style="padding:14px 20px;border-bottom:1px solid #f0f0f0;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;">
                <div>
                    <div style="font-weight:700;font-size:.95rem;color:#0d1b2a;">
                        Req #<%= tReqNum %> — <%= rsT.getString("req_title") %>
                    </div>
                    <div style="font-size:.75rem;color:#6b7c93;margin-top:3px;display:flex;flex-wrap:wrap;gap:10px;">
                        <span><i class="bi bi-person"></i> <%= rsT.getString("client_name") %></span>
                        <span><i class="bi bi-grid"></i> <%= rsT.getString("module_name") %></span>
                        <span><i class="bi bi-currency-rupee"></i> <%= rsT.getString("budget") %></span>
                        <span><i class="bi bi-calendar"></i> <%= tDate %></span>
                    </div>
                </div>
                <span style="padding:5px 14px;border-radius:20px;font-size:.72rem;font-weight:700;background:#f0f4f8;color:<%= stageColor %>;border:1.5px solid <%= stageColor %>;">
                    <%= stageLabel %>
                </span>
            </div>
            <div style="padding:16px 20px;">
                <!-- 7-step tracker -->
                <div style="display:flex;align-items:center;">

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;background:#2e7d32;color:#fff;">✅</div>
                        <div style="font-size:.6rem;font-weight:600;color:#2e7d32;margin-top:4px;text-align:center;">Submitted</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_adminApproved ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_rejected && tStage.equals("admin_initial_rejected") ? "#c62828" : t_adminApproved ? "#2e7d32" : t_adminActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_adminApproved || t_adminActive || t_rejected) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_rejected && tStage.equals("admin_initial_rejected") ? "#c62828" : t_adminApproved ? "#2e7d32" : t_adminActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_rejected && tStage.equals("admin_initial_rejected") ? "❌" : t_adminApproved ? "✅" : "👑" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_adminApproved || t_adminActive ? "#0a6ebd" : "#aaa" %>;">Admin</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_designDone ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_designDone ? "#2e7d32" : t_designActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_designDone || t_designActive) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_designDone ? "#2e7d32" : t_designActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_designDone ? "✅" : "🎨" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_designDone || t_designActive ? "#0a6ebd" : "#aaa" %>;">Design</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_qcDone ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_qcDone ? "#2e7d32" : t_qcActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_qcDone || t_qcActive) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_qcDone ? "#2e7d32" : t_qcActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_qcDone ? "✅" : "🔍" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_qcDone || t_qcActive ? "#0a6ebd" : "#aaa" %>;">QC</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_testingDone ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_testingDone ? "#2e7d32" : t_testingActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_testingDone || t_testingActive) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_testingDone ? "#2e7d32" : t_testingActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_testingDone ? "✅" : "🔬" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_testingDone || t_testingActive ? "#0a6ebd" : "#aaa" %>;">Testing</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_analyticsDone ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_analyticsDone ? "#2e7d32" : t_analyticsActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_analyticsDone || t_analyticsActive) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_analyticsDone ? "#2e7d32" : t_analyticsActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_analyticsDone ? "✅" : "📊" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_analyticsDone || t_analyticsActive ? "#0a6ebd" : "#aaa" %>;">Analytics</div>
                    </div>
                    <div style="flex:1;height:2px;margin-bottom:18px;background:<%= t_finalDone ? "linear-gradient(to right,#2e7d32,#00b4a6)" : "#e0e0e0" %>;"></div>

                    <div style="display:flex;flex-direction:column;align-items:center;flex:1;">
                        <div style="width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:.8rem;
                            background:<%= t_finalDone ? "#2e7d32" : t_finalActive ? "linear-gradient(135deg,#0a6ebd,#00b4a6)" : "#fff" %>;
                            color:<%= (t_finalDone || t_finalActive) ? "#fff" : "#aaa" %>;
                            border:2px solid <%= t_finalDone ? "#2e7d32" : t_finalActive ? "transparent" : "#e0e0e0" %>;">
                            <%= t_finalDone ? "✅" : "🚗" %>
                        </div>
                        <div style="font-size:.6rem;font-weight:600;margin-top:4px;text-align:center;color:<%= t_finalDone || t_finalActive ? "#0a6ebd" : "#aaa" %>;">Done</div>
                    </div>

                </div>
            </div>
        </div>
        <%
            }
            if (tCnt == 0) {
        %>
        <div class="empty-state">
            <i class="bi bi-bar-chart"></i>
            <h6>No Requirements Yet</h6>
            <p>Submitted requirements will appear here for tracking!</p>
        </div>
        <% } } catch (Exception eT) { %>
        <div class="alert alert-danger">Tracker Error: <%= eT.getMessage() %></div>
        <% } %>
    </div>

    <% } else { %>

    <%-- ══ NON-ADMIN ROLES ══ --%>
    <div class="wf-banner" style="background:linear-gradient(135deg,<%= roleColor %>,var(--teal));">
        <div>
            <h4><i class="bi bi-inbox me-2"></i>My Pending Tasks</h4>
            <p>Requirements assigned to your team</p>
        </div>
        <div class="pending-pill">
            <%= pendingCount + internalJobCount %> Pending
            <% if (internalJobCount > 0) { %>
            &nbsp;(<%= internalJobCount %> Internal)
            <% } %>
        </div>
    </div>

    <%-- ══ INTERNAL JOBS SECTION (design team only) ══ --%>
    <% if ("design".equals(role) && internalJobCount > 0) { %>
    <div class="section-heading" style="background:#f0eeff;color:#6c63ff;">
        <i class="bi bi-hammer"></i> 🏭 Internal Manufacturing Jobs
    </div>
    <%
    String loggedDesigner = (String) sess.getAttribute("username");
    try (Connection connIJ = DBConnection.getConnection()) {
        PreparedStatement psIJ = connIJ.prepareStatement(
            "SELECT * FROM internal_jobs WHERE current_assignee=? " +
            "  AND workflow_stage NOT IN ('completed','cancelled','design_completed') " +
            "ORDER BY id DESC");
        psIJ.setString(1, loggedDesigner != null ? loggedDesigner : "");
        ResultSet ijRs = psIJ.executeQuery();
        boolean anyIJ = false;
        while (ijRs.next()) {
            anyIJ = true;
            String ijStage = ijRs.getString("workflow_stage");
            if (ijStage == null) ijStage = "";
    %>
    <div class="req-card" style="border-left-color:#6c63ff;">
        <div class="req-card-head">
            <div style="flex:1;">
                <p class="req-title" style="display:flex;align-items:center;gap:8px;">
                    <span style="background:#f0eeff;color:#6c63ff;padding:2px 10px;border-radius:20px;font-size:.72rem;font-weight:700;">🏭 Internal</span>
                    <%= ijRs.getString("job_number") != null ? ijRs.getString("job_number") : "INT-"+ijRs.getInt("id") %>
                    — <%= ijRs.getString("model_name") != null ? ijRs.getString("model_name") : "Manufacturing Job" %>
                </p>
                <div class="req-meta">
                    <span><i class="bi bi-building"></i>
                        Brand: <strong><%= ijRs.getString("brand_name") != null ? ijRs.getString("brand_name") : "—" %></strong>
                    </span>
                    <span><i class="bi bi-truck"></i>
                        Type: <%= ijRs.getString("vehicle_type") != null ? ijRs.getString("vehicle_type").replace("_"," ").toUpperCase() : "—" %>
                    </span>
                    <span><i class="bi bi-123"></i>
                        Qty: <%= ijRs.getString("quantity") != null ? ijRs.getString("quantity") : "1" %>
                    </span>
                    <span><i class="bi bi-calendar3"></i>
                        Target: <%= ijRs.getString("target_date") != null ? ijRs.getString("target_date") : "—" %>
                    </span>
                </div>
            </div>
            <span class="stage-pill" style="background:#f0eeff;color:#6c63ff;">
                <%= ijStage.replace("_"," ") %>
            </span>
        </div>
        <% String adminNoteIJ = ijRs.getString("admin_notes");
           if (adminNoteIJ != null && !adminNoteIJ.trim().isEmpty()) { %>
        <div class="req-card-body">
            <p style="font-size:.875rem;color:#444;margin:0;background:#fffde7;border-left:3px solid #ffc107;padding:10px 14px;border-radius:6px;">
                <strong>📌 Admin Notes:</strong> <%= adminNoteIJ %>
            </p>
        </div>
        <% } %>
        <div class="req-card-foot">
            <a href="<%= ctx %>/vehicle?reqId=<%= ijRs.getInt("id") %>&surface=internal&source=internal_job"
               class="btn btn-primary btn-sm" style="border-radius:8px;font-weight:700;">
                🏭 Open Design Form →
            </a>
        </div>
    </div>
    <%  }
        if (!anyIJ) { %>
    <div class="empty-state">
        <i class="bi bi-hammer"></i>
        <h5>No Internal Jobs</h5>
        <p>No internal manufacturing jobs assigned to you right now.</p>
    </div>
    <%  }
    } catch (Exception eIJ) { %>
    <div class="alert alert-warning">Internal jobs error: <%= eIJ.getMessage() %></div>
    <% } %>

    <div class="section-heading sh-work" style="margin-top:24px;">
        <i class="bi bi-list-task"></i> 🤝 External — Customer Requirements
    </div>
    <% } else { %>

    <div class="section-heading sh-work">
        <i class="bi bi-list-task"></i> Assigned to Your Team
    </div>

    <% } %>

    <%
    try (Connection conn = DBConnection.getConnection()) {
        ResultSet rs = conn.createStatement().executeQuery(
            "SELECT cr.*, c.email, c.phone " +
            "FROM customer_requirements cr " +
            "LEFT JOIN customers c ON cr.customer_id = c.id " +
            "WHERE " + stageFilter + " ORDER BY cr.submitted_at DESC");

        String nextAction = "", nextLabel = "", rejectAction = "", rejectLabel = "";
        if ("design".equals(role))    { nextAction="design_complete";   nextLabel="✅ Mark Design Complete"; }
        if ("qc".equals(role))        { nextAction="qc_approve";        nextLabel="✅ Approve"; rejectAction="qc_reject"; rejectLabel="❌ Reject"; }
        if ("testing".equals(role))   { nextAction="testing_complete";  nextLabel="✅ Mark Testing Complete"; }
        if ("analytics".equals(role)) { nextAction="analytics_complete";nextLabel="✅ Mark Analytics Complete"; }

        int count = 0;
        while (rs.next()) {
            count++;
            String stage = rs.getString("workflow_stage");
            if (stage == null) stage = "";
    %>
    <div class="req-card" style="border-left-color:<%= roleColor %>;">
        <div class="req-card-head">
            <div style="flex:1;">
                <p class="req-title">#<%= rs.getInt("id") %> — <%= rs.getString("req_title") %></p>
                <div class="req-meta">
                    <span><i class="bi bi-person-fill"></i> <%= rs.getString("client_name") %></span>
                    <span><i class="bi bi-envelope"></i> <%= rs.getString("email") != null ? rs.getString("email") : "N/A" %></span>
                    <span><i class="bi bi-grid"></i> <%= rs.getString("module_name") %></span>
                    <span><i class="bi bi-fuel-pump"></i> <%= rs.getString("deadline") %></span>
                    <span><i class="bi bi-currency-rupee"></i> <%= rs.getString("budget") %></span>
                    <span><i class="bi bi-clock"></i> <%= rs.getTimestamp("submitted_at") != null ? rs.getTimestamp("submitted_at").toString().substring(0,10) : "N/A" %></span>
                </div>
            </div>
            <span class="stage-pill sp-<%= stage %>"><%= stage.replace("_"," ") %></span>
        </div>
        <div class="req-card-body">
            <p style="font-size:.875rem;color:#444;margin:0 0 10px;">
                <strong>Description:</strong> <%= rs.getString("req_desc") %>
            </p>
            <!-- History -->
            <%
            try (Connection connH = DBConnection.getConnection()) {
                ResultSet hist = connH.createStatement().executeQuery(
                    "SELECT * FROM workflow_history WHERE requirement_id=" + rs.getInt("id") +
                    " ORDER BY actioned_at DESC LIMIT 5");
                boolean hasHist = false;
                StringBuilder hb = new StringBuilder();
                while (hist.next()) {
                    hasHist = true;
                    hb.append("<div class='hist-item'><div class='hist-dot'></div><div>")
                      .append("<div class='hist-action'>").append(hist.getString("action")).append("</div>")
                      .append("<div class='hist-meta'>By <strong>").append(hist.getString("actioned_by"))
                      .append("</strong> · ").append(hist.getString("actioned_at")).append("</div>");
                    String rem = hist.getString("remarks");
                    if (rem != null && !rem.trim().isEmpty())
                        hb.append("<div class='hist-remark'>💬 ").append(rem).append("</div>");
                    hb.append("</div></div>");
                }
                if (hasHist) {
                    out.print("<div class='history-wrap'><div class='history-title'>📋 Workflow History</div>");
                    out.print(hb.toString());
                    out.print("</div>");
                }
            } catch (Exception ignored) {}
            %>
        </div>
        <div class="req-card-foot">
            <form method="post" action="<%= ctx %>/workflow" class="action-form">
                <input type="hidden" name="requirementId" value="<%= rs.getInt("id") %>">
                <input type="text" name="remarks" class="remarks-input" placeholder="Add remarks (optional)...">
                <% if (!nextAction.isEmpty()) { %>
                <button type="submit" name="action" value="<%= nextAction %>" class="btn-approve">
                    <%= nextLabel %>
                </button>
                <% } %>
                <% if (!rejectAction.isEmpty()) { %>
                <button type="submit" name="action" value="<%= rejectAction %>" class="btn-reject">
                    <%= rejectLabel %>
                </button>
                <% } %>
            </form>
        </div>
    </div>
    <%
        }
        if (count == 0) {
    %>
    <div class="empty-state">
        <i class="bi bi-inbox"></i>
        <h5>No Pending Tasks</h5>
        <p>All requirements assigned to your team have been processed! 🎉</p>
    </div>
    <% } } catch (Exception e) { %>
    <div class="alert alert-danger">Error: <%= e.getMessage() %></div>
    <% } %>

    <% } %>

</div>

<script>
    function toggleApprove(chk, btnId) {
        var btn = document.getElementById(btnId);
        if (!btn) return;
        if (chk.checked) {
            btn.disabled = false;
            btn.style.opacity = '1';
            btn.style.cursor  = 'pointer';
            btn.title = '';
        } else {
            btn.disabled = true;
            btn.style.opacity = '0.4';
            btn.style.cursor  = 'not-allowed';
            btn.title = 'Tick the verification checkbox first!';
        }
    }
    function checkVerified(form, action) {
        var chks = form.querySelectorAll('.verify-chk');
        if (chks.length > 0 && !chks[0].checked) {
            alert('⚠️ You must verify the company document first!\nPlease tick the verification checkbox before approving.');
            return false;
        }
        return true;
    }
</script>
</body>
</html>