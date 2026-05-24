<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.time.LocalDateTime,java.time.format.DateTimeFormatter" %>
<%
    /* ── Auth Check ── */
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../../index.jsp"); return;
    }
    String role = (String) sess.getAttribute("role");
    if (!"admin".equals(role)) { response.sendRedirect("../../index.jsp"); return; }
    String fullName = (String) sess.getAttribute("fullName");
    String username = (String) sess.getAttribute("username");
    String initial  = (fullName!=null&&!fullName.isEmpty()) ? String.valueOf(fullName.charAt(0)).toUpperCase() : "A";

    /* ── Handle Form POST ── */
    String successMsg = null, errorMsg = null;
    if ("POST".equals(request.getMethod())) {
        String brandName      = request.getParameter("brand_name");
        String vehicleCategory= request.getParameter("vehicle_category");
        String modelName      = request.getParameter("model_name");
        String quantityStr    = request.getParameter("quantity");
        String targetDate     = request.getParameter("target_date");
        String vehicleType    = request.getParameter("vehicle_type_route");
        String adminNotes     = request.getParameter("admin_notes");
        try (Connection conn = DBConnection.getConnection()) {
            // Generate job number: INT-YYYY-NNNNN
            int seq = 1;
            try {
                PreparedStatement ps = conn.prepareStatement(
                    "UPDATE autoprod_counters SET counter_value=counter_value+1 WHERE counter_key='internal_job_seq'");
                ps.executeUpdate();
                ResultSet rs = conn.createStatement().executeQuery(
                    "SELECT counter_value FROM autoprod_counters WHERE counter_key='internal_job_seq'");
                if (rs.next()) seq = rs.getInt(1);
            } catch (Exception ig) {}
            String year = String.valueOf(java.time.Year.now().getValue());
            String jobNumber = "INT-" + year + "-" + String.format("%05d", seq);
            int qty = 1;
            try { qty = Integer.parseInt(quantityStr); } catch (Exception ig) {}

            // ── Round-Robin Designer Assignment (Internal stream) ──
            String assignedUsername = "design";   // fallback
            String assignedName     = "Design Team";
            int    assignedSlot     = 0;
            int    totalInPool      = 0;
            boolean poolEmpty       = false;

            if (vehicleType != null && !vehicleType.trim().isEmpty()) {
                try {
                    PreparedStatement cntQ = conn.prepareStatement(
                        "SELECT COUNT(*) FROM vehicle_designers WHERE vehicle_type=? AND is_active=1");
                    cntQ.setString(1, vehicleType);
                    ResultSet cntRs = cntQ.executeQuery();
                    if (cntRs.next()) totalInPool = cntRs.getInt(1);

                    if (totalInPool > 0) {
                        PreparedStatement rrQ = conn.prepareStatement(
                            "SELECT last_slot_used FROM designer_round_robin WHERE vehicle_type=? AND stream='internal'");
                        rrQ.setString(1, vehicleType);
                        ResultSet rrRs = rrQ.executeQuery();
                        int lastSlot = 0;
                        if (rrRs.next()) lastSlot = rrRs.getInt("last_slot_used");
                        int nextSlot = (lastSlot % totalInPool) + 1;

                        PreparedStatement dsgQ = conn.prepareStatement(
                            "SELECT username, full_name, slot_number FROM vehicle_designers " +
                            "WHERE vehicle_type=? AND is_active=1 ORDER BY slot_number LIMIT 1 OFFSET ?");
                        dsgQ.setString(1, vehicleType);
                        dsgQ.setInt   (2, nextSlot - 1);
                        ResultSet dsgRs = dsgQ.executeQuery();
                        if (dsgRs.next()) {
                            String dUname = dsgRs.getString("username");
                            String dFname = dsgRs.getString("full_name");
                            int    dSlot  = dsgRs.getInt("slot_number");
                            if (dUname != null && !dUname.isEmpty()) {
                                assignedUsername = dUname;
                                assignedName     = dFname != null ? dFname : dUname;
                                assignedSlot     = dSlot;
                            }
                        }
                        // Update INTERNAL stream counter
                        PreparedStatement rrUpd = conn.prepareStatement(
                            "INSERT INTO designer_round_robin (vehicle_type, stream, last_slot_used, total_assigned) " +
                            "VALUES (?, 'internal', ?, 1) " +
                            "ON DUPLICATE KEY UPDATE last_slot_used=VALUES(last_slot_used), total_assigned=total_assigned+1");
                        rrUpd.setString(1, vehicleType);
                        rrUpd.setInt   (2, nextSlot);
                        rrUpd.executeUpdate();
                    } else {
                        poolEmpty = true;
                    }
                } catch (Exception ig) {}
            }

            String slotLabel = assignedSlot > 0 ? " (Slot " + assignedSlot + " of " + totalInPool + ")" : "";
            String vtLabel   = vehicleType != null ? vehicleType.replace("_"," ").toUpperCase() : "";

            String notePrefix = "VEHICLE TYPE: " + vtLabel
                + "\nROUTED TO: " + assignedName + slotLabel
                + " [" + (vehicleType!=null?vehicleType:"") + " / internal stream]"
                + (poolEmpty ? "\nWARNING: No active designers in pool — assigned to fallback." : "");

            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO internal_jobs (job_number,brand_name,vehicle_category,model_name,quantity," +
                "target_date,vehicle_type,admin_notes,status,workflow_stage,current_assignee,created_by) " +
                "VALUES (?,?,?,?,?,?,?,?,'pending','admin_created',?,?)");
            ps.setString(1, jobNumber);
            ps.setString(2, brandName);
            ps.setString(3, vehicleCategory);
            ps.setString(4, modelName);
            ps.setInt(5, qty);
            ps.setString(6, (targetDate!=null&&!targetDate.isEmpty()) ? targetDate : null);
            ps.setString(7, vehicleType);
            ps.setString(8, notePrefix + (adminNotes!=null&&!adminNotes.isEmpty() ? "\n\n" + adminNotes : ""));
            ps.setString(9, assignedUsername);
            ps.setString(10, username);
            ps.executeUpdate();

            // Log to unified_workflow_history
            try {
                ResultSet rs2 = conn.createStatement().executeQuery(
                    "SELECT id FROM internal_jobs WHERE job_number='" + jobNumber + "'");
                if (rs2.next()) {
                    int jobId = rs2.getInt(1);
                    PreparedStatement ps2 = conn.prepareStatement(
                        "INSERT INTO unified_workflow_history (source_type,source_id,stage,action,remarks,actioned_by) VALUES ('internal',?,?,?,?,?)");
                    ps2.setInt(1, jobId);
                    ps2.setString(2, "admin_created");
                    ps2.setString(3, "Job Created");
                    ps2.setString(4, "Internal job created by admin. Assigned to Design team.");
                    ps2.setString(5, username);
                    ps2.executeUpdate();
                }
            } catch (Exception ig2) {}

            successMsg = "Internal Job <strong>" + jobNumber + "</strong> created! "
                + "Assigned to <strong>" + assignedName + "</strong>" + slotLabel
                + " via round-robin."
                + (poolEmpty ? " <span style='color:#b45309'>⚠️ No active designers found for [" + vtLabel + "] — assigned to fallback. Please add designers to the pool.</span>" : "");
        } catch (Exception e) {
            errorMsg = "Error creating job: " + e.getMessage();
        }
    }

    /* ── Load existing internal jobs ── */
    java.util.List<String[]> jobs = new java.util.ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        ResultSet rs = conn.createStatement().executeQuery(
            "SELECT id,job_number,brand_name,vehicle_category,model_name,quantity,target_date,vehicle_type,status,workflow_stage,created_at,current_assignee FROM internal_jobs ORDER BY id DESC");
        while (rs.next()) {
            jobs.add(new String[]{
                rs.getString("id"), rs.getString("job_number"), rs.getString("brand_name"),
                rs.getString("vehicle_category"), rs.getString("model_name"),
                rs.getString("quantity"), rs.getString("target_date")==null?"—":rs.getString("target_date"),
                rs.getString("vehicle_type"), rs.getString("status"), rs.getString("workflow_stage"),
                rs.getString("created_at")==null?"":rs.getString("created_at").substring(0,10),
                rs.getString("current_assignee")==null?"—":rs.getString("current_assignee")
            });
        }
    } catch (Exception ig) {}
    String now = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm"));
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Create Internal Job — AutoProd Admin</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<style>
:root{--sw:260px;--brand:#0f1f5c;--accent:#e53935;--bg:#f0f3f9;--border:#e5e9f2;--muted:#6b7280;--text:#1a1f36;--green:#16a34a;--orange:#ea580c;--purple:#7c3aed;}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:'Plus Jakarta Sans',sans-serif;color:var(--text);}

/* ── SIDEBAR ── */
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

/* ── MAIN ── */
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:#fff;border-bottom:1px solid var(--border);padding:14px 28px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;}
.tb-left{display:flex;align-items:center;gap:12px;}
.tb-tag{background:linear-gradient(135deg,#0a1240,#0f1f5c);color:#fff;border-radius:8px;padding:6px 14px;font-size:.78rem;font-weight:700;letter-spacing:.5px;}
.tb-right{display:flex;align-items:center;gap:14px;font-size:.82rem;color:var(--muted);}
.content{padding:28px;}

/* ── ALERT ── */
.alert{border-radius:12px;padding:14px 18px;margin-bottom:20px;display:flex;align-items:flex-start;gap:12px;font-size:.88rem;font-weight:500;}
.alert-success{background:#f0fdf4;border:1px solid #bbf7d0;color:#15803d;}
.alert-danger{background:#fff1f2;border:1px solid #fecdd3;color:#be123c;}

/* ── FORM CARD ── */
.form-card{background:#fff;border-radius:16px;border:1px solid var(--border);overflow:hidden;margin-bottom:28px;box-shadow:0 2px 12px rgba(0,0,0,.04);}
.form-header{padding:20px 24px;border-bottom:1px solid var(--border);background:linear-gradient(135deg,#0a1240,#0f1f5c);display:flex;align-items:center;gap:14px;}
.form-header-icon{width:44px;height:44px;background:rgba(255,255,255,.12);border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:1.3rem;}
.form-header h2{font-family:'Syne',sans-serif;font-size:1.15rem;color:#fff;}
.form-header p{font-size:.78rem;color:rgba(255,255,255,.5);margin-top:2px;}
.form-body{padding:28px;}
.form-grid{display:grid;grid-template-columns:1fr 1fr;gap:20px;}
.form-grid-3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:20px;}
.form-group{display:flex;flex-direction:column;gap:6px;}
.form-group.full{grid-column:1/-1;}
.form-label{font-size:.8rem;font-weight:700;color:var(--text);letter-spacing:.3px;}
.form-label span{color:var(--accent);}
.form-control{padding:10px 14px;border:1.5px solid var(--border);border-radius:10px;font-size:.88rem;font-family:inherit;color:var(--text);transition:.2s;background:#fafbfc;outline:none;}
.form-control:focus{border-color:#0f1f5c;background:#fff;box-shadow:0 0 0 3px rgba(15,31,92,.08);}
select.form-control{cursor:pointer;}
textarea.form-control{resize:vertical;min-height:90px;}
.form-hint{font-size:.72rem;color:var(--muted);margin-top:2px;}
.vtype-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:4px;}
.vtype-btn{padding:12px 8px;border:2px solid var(--border);border-radius:10px;cursor:pointer;text-align:center;transition:.2s;background:#fafbfc;position:relative;}
.vtype-btn input[type=radio]{display:none;}
.vtype-btn:has(input:checked){border-color:#0f1f5c;background:#eff6ff;}
.vtype-icon{font-size:1.4rem;display:block;margin-bottom:4px;}
.vtype-label{font-size:.68rem;font-weight:700;color:#0d1b2a;display:block;line-height:1.3;}
.vtype-pill{display:inline-block;padding:3px 10px;border-radius:20px;font-size:.7rem;font-weight:700;background:#e0f2fe;color:#0369a1;}.brand-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:4px;}
.brand-btn{padding:12px 8px;border:2px solid var(--border);border-radius:10px;cursor:pointer;text-align:center;transition:.2s;background:#fafbfc;position:relative;}
.brand-btn input[type=radio]{display:none;}
.brand-btn:has(input:checked){border-color:#0f1f5c;background:#eff6ff;}
.brand-name{font-size:.72rem;font-weight:700;margin-top:4px;}
.btn-submit{padding:13px 32px;background:linear-gradient(135deg,#0a1240,#0f1f5c);color:#fff;border:none;border-radius:12px;font-size:.9rem;font-weight:700;cursor:pointer;display:flex;align-items:center;gap:8px;transition:.2s;font-family:inherit;}
.btn-submit:hover{transform:translateY(-1px);box-shadow:0 6px 20px rgba(15,31,92,.3);}
.btn-reset{padding:13px 24px;background:#f0f3f9;color:var(--muted);border:1.5px solid var(--border);border-radius:12px;font-size:.9rem;font-weight:600;cursor:pointer;font-family:inherit;transition:.2s;}
.btn-reset:hover{background:#e5e9f2;}
.form-actions{display:flex;gap:12px;align-items:center;margin-top:24px;padding-top:20px;border-top:1px solid var(--border);}

/* ── JOBS TABLE ── */
.table-card{background:#fff;border-radius:16px;border:1px solid var(--border);overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.04);}
.table-header{padding:18px 24px;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;}
.table-title{font-family:'Syne',sans-serif;font-size:1rem;font-weight:800;display:flex;align-items:center;gap:10px;}
.badge-count{background:#0f1f5c;color:#fff;border-radius:20px;padding:3px 10px;font-size:.72rem;font-weight:700;}
.tbl{width:100%;border-collapse:collapse;}
.tbl th{padding:11px 16px;background:#f8fafc;border-bottom:1px solid var(--border);font-size:.74rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;text-align:left;white-space:nowrap;}
.tbl td{padding:13px 16px;border-bottom:1px solid var(--border);font-size:.84rem;vertical-align:middle;}
.tbl tr:last-child td{border-bottom:none;}
.tbl tr:hover td{background:#f8fafc;}
.job-num{font-weight:800;color:#0f1f5c;font-size:.8rem;}
.brand-pill{display:inline-flex;align-items:center;gap:6px;background:#eff6ff;color:#1d4ed8;border-radius:20px;padding:3px 10px;font-size:.74rem;font-weight:700;}
.stage-pill{display:inline-block;padding:3px 10px;border-radius:20px;font-size:.72rem;font-weight:700;}
.stage-admin_created{background:#fef9c3;color:#854d0e;}
.stage-in_design{background:#dbeafe;color:#1d4ed8;}
.stage-in_qc{background:#fce7f3;color:#9d174d;}
.stage-in_testing{background:#dcfce7;color:#166534;}
.stage-in_analytics{background:#ede9fe;color:#5b21b6;}
.stage-completed{background:#dcfce7;color:#166534;}
.stage-rejected{background:#fee2e2;color:#991b1b;}
.prio-pill{display:inline-block;padding:2px 8px;border-radius:20px;font-size:.7rem;font-weight:700;}
.prio-Low{background:#dcfce7;color:#166534;}
.prio-Medium{background:#dbeafe;color:#1d4ed8;}
.prio-High{background:#ffedd5;color:#9a3412;}
.prio-Critical{background:#fee2e2;color:#991b1b;}
.cat-pill{background:#f3f4f6;color:#374151;border-radius:6px;padding:3px 8px;font-size:.72rem;font-weight:600;}
.empty-row td{text-align:center;padding:40px;color:var(--muted);font-size:.88rem;}
</style>
</head>
<body>

<!-- ═══════════════ SIDEBAR ═══════════════ -->
<nav class="sb">
  <div class="sb-brand">
    <div class="sb-brand-row">
      <div class="sb-icon">🏭</div>
      <div>
        <div class="sb-name">AutoProd</div>
        <div class="sb-sub">ADMIN PANEL</div>
      </div>
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
  <a href="admin_dashboard.jsp?tab=requirements" class="nl"><i class="bi bi-inbox"></i> Requirements</a>
  <div class="ns">Production</div>
  <a href="create_internal_job.jsp" class="nl active"><i class="bi bi-hammer"></i> Internal Jobs</a>
  <a href="create_external_order.jsp" class="nl"><i class="bi bi-truck"></i> External Orders</a>
  <a href="admin_dashboard.jsp?tab=workflow" class="nl"><i class="bi bi-diagram-3"></i> Workflow</a>
  <div class="ns">Modules</div>
  <a href="admin_dashboard.jsp?tab=vehicles" class="nl"><i class="bi bi-car-front"></i> Vehicles</a>
  <a href="admin_dashboard.jsp?tab=qc" class="nl"><i class="bi bi-shield-check"></i> QC History</a>
  <a href="admin_dashboard.jsp?tab=testing" class="nl"><i class="bi bi-clipboard2-pulse"></i> Testing</a>
  <a href="admin_dashboard.jsp?tab=customers" class="nl"><i class="bi bi-people"></i> Customers</a>
  <div class="sf">
    <a href="manage_users.jsp"><i class="bi bi-person-gear"></i> Manage Users</a>
    <a href="../../logout"><i class="bi bi-box-arrow-left"></i> Logout</a>
  </div>
</nav>

<!-- ═══════════════ MAIN ═══════════════ -->
<div class="main">

  <!-- Top Bar -->
  <div class="topbar">
    <div class="tb-left">
      <div class="tb-tag">🏭 INTERNAL</div>
      <div>
        <div style="font-weight:800;font-size:.95rem;">Create Internal Job</div>
        <div style="font-size:.75rem;color:var(--muted);">Admin → Design → QC → Testing → Analytics</div>
      </div>
    </div>
    <div class="tb-right">
      <i class="bi bi-clock"></i> <%= now %>
      <a href="admin_dashboard.jsp" style="background:var(--bg);border:1px solid var(--border);padding:7px 14px;border-radius:8px;color:var(--text);text-decoration:none;font-weight:600;font-size:.8rem;display:flex;align-items:center;gap:6px;">
        <i class="bi bi-arrow-left"></i> Back
      </a>
    </div>
  </div>

  <div class="content">

    <!-- Success / Error -->
    <% if (successMsg != null) { %>
    <div class="alert alert-success">
      <i class="bi bi-check-circle-fill" style="font-size:1.1rem;flex-shrink:0;margin-top:1px;"></i>
      <div><%= successMsg %></div>
    </div>
    <% } %>
    <% if (errorMsg != null) { %>
    <div class="alert alert-danger">
      <i class="bi bi-exclamation-triangle-fill" style="font-size:1.1rem;flex-shrink:0;margin-top:1px;"></i>
      <div><%= errorMsg %></div>
    </div>
    <% } %>

    <!-- ═══ FORM ═══ -->
    <div class="form-card">
      <div class="form-header">
        <div class="form-header-icon">🏭</div>
        <div>
          <h2>New Internal Manufacturing Job</h2>
          <p>Create a new job and assign it directly to the Design team</p>
        </div>
      </div>
      <div class="form-body">
        <form method="POST" action="create_internal_job.jsp">

          <!-- Brand Selection -->
          <div class="form-group full" style="margin-bottom:20px;">
            <label class="form-label">Brand Name <span>*</span></label>
            <div class="brand-grid">
              <% String[] brands = {"KTM","Bajaj","BMW","Hero","TVS","Tata","Mahindra","Royal Enfield"}; %>
              <% String[] brandIcons = {"🟠","🔵","⚪","🔴","🟢","💙","🟤","🟡"}; %>
              <% for (int b=0; b<brands.length; b++) { %>
              <label class="brand-btn">
                <input type="radio" name="brand_name" value="<%= brands[b] %>" <%= b==0?"checked":"" %>>
                <div style="font-size:1.4rem;"><%= brandIcons[b] %></div>
                <div class="brand-name"><%= brands[b] %></div>
              </label>
              <% } %>
            </div>
          </div>

          <div class="form-grid">
            <!-- Vehicle Category -->
            <div class="form-group">
              <label class="form-label">Vehicle Category <span>*</span></label>
              <select name="vehicle_category" class="form-control" required>
                <option value="">— Select Category —</option>
                <option value="Bike">🏍️ Bike / Motorcycle</option>
                <option value="Scooter">🛵 Scooter</option>
                <option value="Car">🚗 Car (Sedan)</option>
                <option value="SUV">🚙 SUV / Crossover</option>
                <option value="Hatchback">🚗 Hatchback</option>
                <option value="Bus">🚌 Bus</option>
                <option value="Truck">🚛 Truck</option>
                <option value="Van">🚐 Van</option>
                <option value="Electric">⚡ Electric Vehicle</option>
              </select>
            </div>

            <!-- Model Name -->
            <div class="form-group">
              <label class="form-label">Model Name <span>*</span></label>
              <input type="text" name="model_name" class="form-control" placeholder="e.g. Duke 390 V3, Pulsar NS200" required>
              <div class="form-hint">Enter the exact model name or code</div>
            </div>

            <!-- Quantity -->
            <div class="form-group">
              <label class="form-label">Production Quantity <span>*</span></label>
              <input type="number" name="quantity" class="form-control" min="1" value="1" required>
              <div class="form-hint">Number of units to manufacture</div>
            </div>

            <!-- Target Date -->
            <div class="form-group">
              <label class="form-label">Target Completion Date</label>
              <input type="date" name="target_date" class="form-control">
              <div class="form-hint">Expected production completion date</div>
            </div>
          </div>

          <!-- Vehicle Type Routing -->
          <div class="form-group full" style="margin-top:20px;">
            <label class="form-label">Vehicle Type <span>*</span> <span style="font-size:.72rem;font-weight:400;color:#6b7280;">— routes job to the specialist designer</span></label>
            <div class="vtype-grid">
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="two_wheeler" required>
                <span class="vtype-icon">🏍️</span>
                <span class="vtype-label">Two Wheeler</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="three_wheeler">
                <span class="vtype-icon">🛺</span>
                <span class="vtype-label">Three Wheeler</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="car">
                <span class="vtype-icon">🚗</span>
                <span class="vtype-label">Car</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="van">
                <span class="vtype-icon">🚐</span>
                <span class="vtype-label">Van</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="bus">
                <span class="vtype-icon">🚌</span>
                <span class="vtype-label">Bus</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="lorry">
                <span class="vtype-icon">🚛</span>
                <span class="vtype-label">Lorry / Truck</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="heavy_vehicle">
                <span class="vtype-icon">🚜</span>
                <span class="vtype-label">Heavy Vehicle</span>
              </label>
              <label class="vtype-btn">
                <input type="radio" name="vehicle_type_route" value="special">
                <span class="vtype-icon">🚑</span>
                <span class="vtype-label">Special Purpose</span>
              </label>
            </div>
          </div>

          <!-- Admin Notes -->
          <div class="form-group full" style="margin-top:20px;">
            <label class="form-label">Admin Instructions / Notes</label>
            <textarea name="admin_notes" class="form-control" rows="4"
              placeholder="Describe design requirements, special features, engineering notes, or any specific instructions for the design team..."></textarea>
            <div class="form-hint">These notes will be visible to the Design, QC, Testing, and Analytics teams</div>
          </div>

          <!-- Actions -->
          <div class="form-actions">
            <button type="submit" class="btn-submit">
              <i class="bi bi-plus-circle-fill"></i> Create Internal Job
            </button>
            <button type="reset" class="btn-reset">
              <i class="bi bi-arrow-counterclockwise"></i> Reset
            </button>
            <div style="margin-left:auto;font-size:.78rem;color:var(--muted);">
              <i class="bi bi-info-circle"></i>
              Job will be assigned to Design Team immediately
            </div>
          </div>

        </form>
      </div>
    </div>

    <!-- ═══ EXISTING JOBS TABLE ═══ -->
    <div class="table-card">
      <div class="table-header">
        <div class="table-title">
          <i class="bi bi-list-ul" style="color:#0f1f5c;"></i>
          All Internal Jobs
          <span class="badge-count"><%= jobs.size() %></span>
        </div>
        <div style="font-size:.78rem;color:var(--muted);">
          <i class="bi bi-arrow-clockwise"></i> Live from DB
        </div>
      </div>
      <div style="overflow-x:auto;">
        <table class="tbl">
          <thead>
            <tr>
              <th>#</th>
              <th>Job Number</th>
              <th>Brand</th>
              <th>Category</th>
              <th>Model</th>
              <th>Qty</th>
              <th>Vehicle Type</th>
              <th>Assigned To</th>
              <th>Stage</th>
              <th>Target Date</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            <% if (jobs.isEmpty()) { %>
            <tr class="empty-row"><td colspan="11">
              <i class="bi bi-inbox" style="font-size:2rem;display:block;margin-bottom:8px;color:#d1d5db;"></i>
              No internal jobs yet. Create your first job above!
            </td></tr>
            <% } else { %>
            <% for (int i=0; i<jobs.size(); i++) {
                String[] j = jobs.get(i);
                String stageClass = "stage-" + (j[9]!=null?j[9].replace(" ","_"):"admin_created");
            %>
            <tr>
              <td style="color:var(--muted);font-size:.78rem;"><%= (i+1) %></td>
              <td><span class="job-num"><%= j[1] %></span></td>
              <td><span class="brand-pill">🏭 <%= j[2] %></span></td>
              <td><span class="cat-pill"><%= j[3] %></span></td>
              <td style="font-weight:600;"><%= j[4] %></td>
              <td style="font-weight:700;color:#0f1f5c;"><%= j[5] %></td>
              <td><span class="prio-pill prio-<%= j[7] %>"><%= j[7]!=null?j[7]:"—" %></span></td>
              <td style="font-size:.82rem;font-weight:600;color:#0f1f5c;">
                <% if(j[11]!=null && !j[11].equals("design") && !j[11].equals("—")){ %>
                  <i class="bi bi-person-fill" style="color:#1d4ed8;"></i> <%= j[11] %>
                <% } else { %>
                  <span style="color:var(--muted);font-size:.78rem;">Design Team</span>
                <% } %>
              </td>
              <td><span class="stage-pill <%= stageClass %>"><%= j[9]!=null?j[9].replace("_"," "):"—" %></span></td>
              <td style="color:var(--muted);font-size:.8rem;"><%= j[6] %></td>
              <td style="color:var(--muted);font-size:.8rem;"><%= j[10] %></td>
            </tr>
            <% } %>
            <% } %>
          </tbody>
        </table>
      </div>
    </div>

  </div><!-- /content -->
</div><!-- /main -->

</body>
</html>
