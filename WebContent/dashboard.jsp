<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,
                 java.time.LocalDateTime,java.time.format.DateTimeFormatter" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("index.jsp"); return;
    }
    String role     = (String) sess.getAttribute("role");
    String fullName = (String) sess.getAttribute("fullName");
    String username = (String) sess.getAttribute("username");

    int internalTotal=0,internalInProgress=0,internalCompleted=0;
    int externalTotal=0,externalPending=0,externalInProgress=0,externalCompleted=0;
    int qcApproved=0,testPassed=0,myTasks=0;
    String designerVehicleType=null;
    int designerSlot=0,myIntJobs=0,myExtReqs=0;

    try(Connection conn=DBConnection.getConnection()){
        ResultSet r;
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs");if(r.next())internalTotal=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE workflow_stage NOT IN ('completed','cancelled')");if(r.next())internalInProgress=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE workflow_stage='completed'");if(r.next())internalCompleted=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage NOT IN ('submitted','admin_initial_rejected')");if(r.next())externalTotal=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage='submitted'");if(r.next())externalPending=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage IN ('admin_initial_approved','design_completed','qc_approved','testing_completed','analytics_completed')");if(r.next())externalInProgress=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage='completed'");if(r.next())externalCompleted=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='approved'");if(r.next())qcApproved=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='pass'");if(r.next())testPassed=r.getInt(1);}catch(Exception ig){}
        if("design".equals(role)){
            try{PreparedStatement ps=conn.prepareStatement("SELECT vehicle_type,slot_number FROM vehicle_designers WHERE username=? AND is_active=1");ps.setString(1,username);ResultSet vd=ps.executeQuery();if(vd.next()){designerVehicleType=vd.getString("vehicle_type");designerSlot=vd.getInt("slot_number");}}catch(Exception ig){}
            try{PreparedStatement ps=conn.prepareStatement("SELECT COUNT(*) FROM internal_jobs WHERE current_assignee=? AND workflow_stage NOT IN ('design_completed','completed','cancelled')");ps.setString(1,username);ResultSet ri=ps.executeQuery();if(ri.next())myIntJobs=ri.getInt(1);}catch(Exception ig){}
            try{PreparedStatement ps=conn.prepareStatement("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee=? AND workflow_stage='admin_initial_approved'");ps.setString(1,username);ResultSet re=ps.executeQuery();if(re.next())myExtReqs=re.getInt(1);}catch(Exception ig){}
            try{PreparedStatement ps=conn.prepareStatement("SELECT COUNT(*) FROM external_orders WHERE current_assignee=? AND workflow_stage='admin_initial_approved'");ps.setString(1,username);ResultSet rex=ps.executeQuery();if(rex.next())myExtReqs+=rex.getInt(1);}catch(Exception ig){}
            myTasks=myIntJobs+myExtReqs;
        } else {
            try{
                if("qc".equals(role)){r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='qc' AND workflow_stage='design_completed'");if(r.next())myTasks=r.getInt(1);}
                else if("testing".equals(role)){r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='testing' AND workflow_stage='qc_approved'");if(r.next())myTasks=r.getInt(1);}
                else if("analytics".equals(role)){
                    PreparedStatement psA=conn.prepareStatement("SELECT COUNT(*) FROM internal_jobs WHERE current_assignee=? AND workflow_stage='testing_completed'");psA.setString(1,username);ResultSet rA=psA.executeQuery();if(rA.next())myTasks+=rA.getInt(1);
                    PreparedStatement psA2=conn.prepareStatement("SELECT COUNT(*) FROM external_orders WHERE current_assignee=? AND workflow_stage='testing_completed'");psA2.setString(1,username);ResultSet rA2=psA2.executeQuery();if(rA2.next())myTasks+=rA2.getInt(1);
                    PreparedStatement psA3=conn.prepareStatement("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee=? AND workflow_stage='testing_completed'");psA3.setString(1,username);ResultSet rA3=psA3.executeQuery();if(rA3.next())myTasks+=rA3.getInt(1);
                }
                else if("admin".equals(role)){r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage='submitted'");if(r.next())myTasks=r.getInt(1);}
            }catch(Exception ig){}
        }
    }catch(Exception ignored){}

    String searchQ=request.getParameter("search");if(searchQ==null)searchQ="";
    String activeTab=request.getParameter("tab");if(activeTab==null)activeTab="internal";
    String now=LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm"));
    String initial=(fullName!=null&&!fullName.isEmpty())?String.valueOf(fullName.charAt(0)).toUpperCase():"U";
    int totalJobs=internalTotal+externalTotal;
    String taskLink="#";
    if("design".equals(role))taskLink=request.getContextPath()+"/vehicle";
    else if("qc".equals(role))taskLink=request.getContextPath()+"/qc";
    else if("testing".equals(role))taskLink=request.getContextPath()+"/testing";
    else if("analytics".equals(role))taskLink="jsp/analytics_module.jsp";
    else if("admin".equals(role))taskLink="jsp/admin/admin_dashboard.jsp";
    String vtLabel=designerVehicleType!=null?designerVehicleType.replace("_"," ").toUpperCase():"";
    String roleColor="design".equals(role)?"#6366f1":"qc".equals(role)?"#10b981":"testing".equals(role)?"#f59e0b":"analytics".equals(role)?"#06b6d4":"admin".equals(role)?"#ef4444":"#64748b";
    String roleBg="design".equals(role)?"#eef2ff":"qc".equals(role)?"#ecfdf5":"testing".equals(role)?"#fffbeb":"analytics".equals(role)?"#ecfeff":"admin".equals(role)?"#fef2f2":"#f8fafc";
    int hour=LocalDateTime.now().getHour();
    String greeting=hour<12?"Good Morning":hour<17?"Good Afternoon":"Good Evening";
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Dashboard — AutoProd</title>
<link href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css" rel="stylesheet">
<style>
:root{--sw:252px;--bg:#f1f5f9;--surf:#fff;--brand:#0f172a;--int:#4f46e5;--int-bg:#eef2ff;--int-bd:#c7d2fe;--ext:#059669;--ext-bg:#ecfdf5;--ext-bd:#a7f3d0;--text:#0f172a;--muted:#64748b;--bdr:#e2e8f0;--r:12px;--sh:0 1px 3px rgba(0,0,0,.08),0 1px 2px rgba(0,0,0,.06);}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:var(--text);font-size:14px;line-height:1.5;}
.sidebar{position:fixed;top:0;left:0;width:var(--sw);height:100vh;background:var(--brand);display:flex;flex-direction:column;z-index:200;overflow-y:auto;}
.sb-logo{padding:20px 18px 16px;border-bottom:1px solid rgba(255,255,255,.06);display:flex;align-items:center;gap:10px;}
.sb-logo-icon{width:34px;height:34px;background:#4f46e5;border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:16px;flex-shrink:0;}
.sb-logo-text{font-size:15px;font-weight:700;color:#fff;letter-spacing:-.3px;}
.sb-logo-sub{font-size:9px;color:rgba(255,255,255,.25);letter-spacing:1.2px;margin-top:1px;}
.sb-profile{padding:14px 18px;border-bottom:1px solid rgba(255,255,255,.06);display:flex;align-items:center;gap:10px;}
.sb-av{width:36px;height:36px;border-radius:10px;background:#4f46e5;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:14px;color:#fff;flex-shrink:0;}
.sb-pname{font-size:13px;font-weight:600;color:#fff;}
.sb-prole{font-size:10px;color:rgba(255,255,255,.35);margin-top:1px;display:flex;align-items:center;gap:4px;}
.sb-online{width:6px;height:6px;background:#22c55e;border-radius:50%;}
.sb-sect{padding:16px 18px 5px;font-size:9px;color:rgba(255,255,255,.2);letter-spacing:2px;text-transform:uppercase;font-weight:700;}
.sb-link{display:flex;align-items:center;gap:9px;padding:8px 18px;color:rgba(255,255,255,.45);text-decoration:none;font-size:12.5px;font-weight:500;transition:.15s;margin:1px 8px;border-radius:8px;}
.sb-link i{font-size:13px;flex-shrink:0;width:16px;}
.sb-link:hover{background:rgba(255,255,255,.07);color:#fff;}
.sb-link.active{background:rgba(79,70,229,.35);color:#fff;}
.sb-link .badge{margin-left:auto;background:#ef4444;color:#fff;border-radius:20px;padding:1px 7px;font-size:9px;font-weight:700;}
.sb-footer{margin-top:auto;padding:14px 18px;border-top:1px solid rgba(255,255,255,.06);}
.sb-footer a{color:rgba(255,255,255,.3);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:12px;padding:7px 10px;border-radius:8px;transition:.15s;}
.sb-footer a:hover{background:rgba(255,255,255,.07);color:#fff;}
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:var(--surf);border-bottom:1px solid var(--bdr);padding:13px 24px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;}
.topbar h1{font-size:15px;font-weight:700;color:var(--brand);}
.topbar p{font-size:11px;color:var(--muted);margin-top:1px;}
.topbar-right{display:flex;align-items:center;gap:8px;}
.chip{display:inline-flex;align-items:center;gap:5px;padding:5px 12px;border-radius:20px;font-size:11px;font-weight:600;border:1px solid var(--bdr);background:var(--bg);color:var(--muted);}
.content{padding:22px 24px;}
.hero{background:var(--brand);border-radius:16px;padding:24px 28px;margin-bottom:22px;display:flex;align-items:center;justify-content:space-between;gap:20px;position:relative;overflow:hidden;}
.hero-bg{position:absolute;right:-30px;top:-30px;width:220px;height:220px;border-radius:50%;background:rgba(79,70,229,.12);pointer-events:none;}
.hero-bg2{position:absolute;right:60px;bottom:-60px;width:160px;height:160px;border-radius:50%;background:rgba(79,70,229,.08);pointer-events:none;}
.hero-left{position:relative;z-index:1;}
.hero-greet{font-size:11px;color:rgba(255,255,255,.35);letter-spacing:1px;text-transform:uppercase;margin-bottom:5px;}
.hero-name{font-size:22px;font-weight:800;color:#fff;letter-spacing:-.4px;margin-bottom:4px;}
.hero-sub{font-size:12px;color:rgba(255,255,255,.4);}
.hero-task{background:rgba(79,70,229,.35);border:1px solid rgba(79,70,229,.5);border-radius:10px;padding:10px 16px;display:flex;align-items:center;gap:12px;margin-top:14px;}
.hero-task-n{font-size:20px;font-weight:800;color:#a5b4fc;line-height:1;}
.hero-task-l{font-size:11px;color:rgba(255,255,255,.45);margin-top:1px;}
.hero-task-btn{background:#4f46e5;color:#fff;text-decoration:none;padding:6px 14px;border-radius:7px;font-size:11px;font-weight:700;white-space:nowrap;}
.hero-right{display:flex;gap:20px;position:relative;z-index:1;flex-shrink:0;}
.hstat{text-align:center;}
.hstat-n{font-size:24px;font-weight:800;color:#fff;line-height:1;}
.hstat-l{font-size:10px;color:rgba(255,255,255,.35);margin-top:3px;letter-spacing:.5px;}
.hdiv{width:1px;background:rgba(255,255,255,.08);align-self:stretch;}
.kpi-grid{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin-bottom:22px;}
.kpi{background:var(--surf);border-radius:var(--r);padding:16px;border:1px solid var(--bdr);box-shadow:var(--sh);position:relative;overflow:hidden;}
.kpi-bar{position:absolute;bottom:0;left:0;right:0;height:3px;}
.kpi-ico{width:36px;height:36px;border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:16px;margin-bottom:10px;}
.kpi-n{font-size:22px;font-weight:800;line-height:1;margin-bottom:3px;}
.kpi-l{font-size:11px;color:var(--muted);}
.dband{background:var(--surf);border:1px solid var(--bdr);border-radius:var(--r);padding:14px 18px;margin-bottom:22px;display:flex;align-items:center;justify-content:space-between;gap:16px;box-shadow:var(--sh);}
.vtype-badge{background:var(--int-bg);border:1px solid var(--int-bd);color:var(--int);padding:6px 14px;border-radius:8px;font-size:12px;font-weight:700;}
.dc{text-align:center;background:var(--bg);border-radius:8px;padding:10px 16px;}
.dc-n{font-size:18px;font-weight:800;line-height:1;}
.dc-l{font-size:10px;color:var(--muted);margin-top:2px;}
.wf-card{background:var(--surf);border:1px solid var(--bdr);border-radius:var(--r);padding:18px 20px;margin-bottom:22px;box-shadow:var(--sh);}
.wf-title{font-size:12px;font-weight:700;color:var(--brand);margin-bottom:16px;display:flex;align-items:center;gap:6px;}
.wf-track{display:flex;align-items:center;}
.wf-node{flex:1;display:flex;flex-direction:column;align-items:center;position:relative;}
.wf-node:not(:last-child)::after{content:'';position:absolute;top:14px;left:calc(50% + 16px);right:calc(-50% + 16px);height:1.5px;background:var(--bdr);}
.wf-node.done:not(:last-child)::after{background:var(--int);}
.wf-circle{width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:11px;border:1.5px solid var(--bdr);background:var(--bg);color:var(--muted);position:relative;z-index:1;margin-bottom:6px;}
.wf-node.done .wf-circle{background:var(--int);border-color:var(--int);color:#fff;}
.wf-node.cur .wf-circle{background:var(--int);border-color:var(--int);color:#fff;box-shadow:0 0 0 4px rgba(79,70,229,.15);}
.wf-lbl{font-size:9px;color:var(--muted);font-weight:600;text-align:center;}
.wf-node.cur .wf-lbl{color:var(--int);font-weight:700;}
.wf-hint{background:var(--int-bg);border-radius:8px;padding:8px 12px;font-size:11px;color:var(--int);font-weight:600;margin-top:12px;display:flex;align-items:center;gap:6px;}
.prod-card{background:var(--surf);border:1px solid var(--bdr);border-radius:var(--r);margin-bottom:22px;box-shadow:var(--sh);overflow:hidden;}
.card-head{padding:14px 18px;border-bottom:1px solid var(--bdr);display:flex;align-items:center;justify-content:space-between;gap:12px;}
.card-title{font-size:13px;font-weight:700;display:flex;align-items:center;gap:6px;}
.card-body{padding:18px;}
.tab-bar{display:flex;background:var(--bg);border-radius:8px;padding:3px;gap:2px;}
.tab-btn{padding:5px 16px;border-radius:6px;font-size:11px;font-weight:600;cursor:pointer;border:none;background:transparent;color:var(--muted);transition:.15s;display:flex;align-items:center;gap:5px;}
.tab-btn.int.on{background:var(--int);color:#fff;}
.tab-btn.ext.on{background:var(--ext);color:#fff;}
.tab-panel{display:none;}
.tab-panel.show{display:block;}
.sinfo{border-radius:10px;padding:12px 15px;margin-bottom:16px;display:flex;align-items:center;gap:12px;}
.si-int{background:var(--int-bg);border:1px solid var(--int-bd);}
.si-ext{background:var(--ext-bg);border:1px solid var(--ext-bd);}
.si-int .sit{color:var(--int);font-weight:700;font-size:12px;}
.si-ext .sit{color:var(--ext);font-weight:700;font-size:12px;}
.si-sub{font-size:10px;color:var(--muted);margin-top:2px;}
.mstats{display:flex;gap:8px;margin-bottom:16px;}
.msbox{flex:1;border-radius:8px;padding:10px 12px;border:1px solid var(--bdr);}
.msbox-n{font-size:17px;font-weight:800;line-height:1;}
.msbox-l{font-size:10px;color:var(--muted);margin-top:2px;}
.bgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:8px;margin-bottom:18px;}
.bcard{background:var(--bg);border:1px solid var(--bdr);border-radius:10px;padding:13px 10px;text-align:center;text-decoration:none;color:var(--text);transition:.15s;position:relative;}
.bcard:hover{border-color:var(--int-bd);background:#fff;transform:translateY(-2px);}
.bcard-icon{width:40px;height:40px;border-radius:9px;background:var(--int-bg);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:12px;color:var(--int);margin:0 auto 7px;}
.bcard-name{font-weight:700;font-size:11px;}
.bcard-sub{font-size:9px;color:var(--muted);margin-top:2px;}
.bcard-tag{position:absolute;top:6px;right:6px;background:var(--int-bg);color:var(--int);border-radius:20px;padding:1px 6px;font-size:8px;font-weight:700;}
.bcard-add .bcard-icon{background:transparent;border:1.5px dashed var(--int);}
.bcard-add .bcard-name{color:var(--int);}
.dt{width:100%;border-collapse:collapse;font-size:12px;}
.dt th{padding:8px 12px;background:var(--bg);font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.6px;border-bottom:1px solid var(--bdr);}
.dt td{padding:9px 12px;border-bottom:1px solid var(--bdr);}
.dt tr:last-child td{border-bottom:none;}
.dt tr:hover td{background:#fafbff;}
.sp{display:inline-block;padding:2px 9px;border-radius:20px;font-size:9px;font-weight:700;}
.sp-ok{background:#dcfce7;color:#166534;}
.sp-wip{background:#fef9c3;color:#854d0e;}
.sp-dsn{background:#ede9fe;color:#5b21b6;}
.sp-qc{background:#cffafe;color:#155e75;}
.sp-tst{background:#fce7f3;color:#9d174d;}
.sp-pnd{background:#f1f5f9;color:#475569;}
.vtag{background:var(--bg);border:1px solid var(--bdr);padding:2px 8px;border-radius:20px;font-size:9px;font-weight:600;}
.reqlist{display:flex;flex-direction:column;gap:8px;}
.rcard{background:var(--bg);border:1px solid var(--bdr);border-radius:10px;padding:13px 15px;transition:.15s;}
.rcard:hover{border-color:#a5b4fc;background:#fff;}
.rc-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:7px;}
.rc-id{font-size:10px;font-weight:700;color:var(--int);}
.rc-title{font-weight:700;font-size:13px;margin-bottom:6px;}
.rc-meta{display:flex;gap:10px;flex-wrap:wrap;}
.rc-m{display:flex;align-items:center;gap:4px;font-size:10px;color:var(--muted);}
.rc-btn{margin-top:9px;display:inline-flex;align-items:center;gap:4px;padding:5px 13px;border-radius:7px;font-size:10px;font-weight:700;text-decoration:none;}
.rb-d{background:var(--int);color:#fff;}
.rb-r{background:#f97316;color:#fff;}
.srow{display:flex;gap:8px;margin-bottom:14px;}
.sinput{flex:1;border:1px solid var(--bdr);border-radius:8px;padding:9px 14px;font-size:12px;outline:none;background:var(--bg);transition:.15s;font-family:inherit;}
.sinput:focus{border-color:var(--int);background:#fff;}
.sbtn2{padding:9px 20px;background:var(--brand);color:#fff;border:none;border-radius:8px;font-weight:700;font-size:12px;cursor:pointer;display:flex;align-items:center;gap:5px;}
.clrbtn{padding:9px 13px;border:1px solid var(--bdr);border-radius:8px;color:var(--muted);text-decoration:none;font-size:12px;display:flex;align-items:center;gap:3px;}
.qagrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(130px,1fr));gap:10px;}
.qabtn{border-radius:12px;padding:18px 12px;text-align:center;text-decoration:none;font-weight:700;font-size:12px;display:flex;flex-direction:column;align-items:center;gap:8px;transition:transform .15s;border:none;cursor:pointer;position:relative;}
.qabtn i{font-size:22px;}
.qabtn:hover{transform:translateY(-3px);}
.qa-d{background:linear-gradient(135deg,#4f46e5,#818cf8);color:#fff;}
.qa-q{background:linear-gradient(135deg,#059669,#34d399);color:#fff;}
.qa-t{background:linear-gradient(135deg,#dc2626,#f87171);color:#fff;}
.qa-a{background:linear-gradient(135deg,#0891b2,#22d3ee);color:#fff;}
.qa-adm{background:linear-gradient(135deg,#0f172a,#334155);color:#fff;}
.qa-rpt{background:linear-gradient(135deg,#7c3aed,#a78bfa);color:#fff;}
.qabadge{position:absolute;top:7px;right:7px;background:rgba(255,255,255,.9);color:#dc2626;border-radius:20px;padding:1px 7px;font-size:9px;font-weight:800;}
.empty{text-align:center;padding:28px 20px;color:var(--muted);}
.empty i{font-size:28px;opacity:.2;display:block;margin-bottom:8px;}
.empty p{font-size:12px;}
</style>
</head>
<body>
<div class="sidebar">
  <div class="sb-logo">
    <div class="sb-logo-icon">🚗</div>
    <div><div class="sb-logo-text">AutoProd</div><div class="sb-logo-sub">Production System</div></div>
  </div>
  <div class="sb-profile">
    <div class="sb-av"><%= initial %></div>
    <div><div class="sb-pname"><%= fullName %></div><div class="sb-prole"><span class="sb-online"></span><%= role.toUpperCase() %></div></div>
  </div>
  <div class="sb-sect">Main</div>
  <a class="sb-link active" href="dashboard.jsp"><i class="bi bi-grid-1x2-fill"></i> Dashboard<%if(myTasks>0){%><span class="badge"><%= myTasks %></span><%}%></a>
  <div class="sb-sect">Modules</div>
  <%if("admin".equals(role)||"design".equals(role)){%><a class="sb-link" href="${pageContext.request.contextPath}/vehicle"><i class="bi bi-truck-front-fill"></i> Vehicle Design</a><%}%>
  <%if("admin".equals(role)||"qc".equals(role)){%><a class="sb-link" href="${pageContext.request.contextPath}/qc"><i class="bi bi-shield-check"></i> QC Module</a><%}%>
  <%if("admin".equals(role)||"testing".equals(role)){%><a class="sb-link" href="${pageContext.request.contextPath}/testing"><i class="bi bi-flask-fill"></i> Testing</a><%}%>
  <%if("admin".equals(role)||"analytics".equals(role)){%><a class="sb-link" href="jsp/analytics_module.jsp"><i class="bi bi-bar-chart-fill"></i> Analytics</a><%}%>
  <%if("admin".equals(role)){%>
  <div class="sb-sect">Admin</div>
  <a class="sb-link" href="jsp/admin/admin_dashboard.jsp"><i class="bi bi-speedometer2"></i> Admin Panel<%if(myTasks>0){%><span class="badge"><%= myTasks %></span><%}%></a>
  <a class="sb-link" href="jsp/final_report.jsp"><i class="bi bi-file-earmark-bar-graph-fill"></i> Final Report</a>
  <%}%>
  <div class="sb-footer"><a href="${pageContext.request.contextPath}/logout"><i class="bi bi-box-arrow-left"></i> Logout</a></div>
</div>

<div class="main">
  <div class="topbar">
    <div><h1>Dashboard</h1><p>AutoProd &rsaquo; Production Overview</p></div>
    <div class="topbar-right">
      <div class="chip"><i class="bi bi-clock" style="font-size:10px;"></i> <%= now %></div>
      <div class="chip" style="background:<%= roleBg %>;color:<%= roleColor %>;border-color:transparent;font-weight:700;"><%= role.toUpperCase() %></div>
    </div>
  </div>
  <div class="content">

    <div class="hero">
      <div class="hero-bg"></div><div class="hero-bg2"></div>
      <div class="hero-left">
        <div class="hero-greet"><%= greeting %></div>
        <div class="hero-name"><%= fullName %></div>
        <div class="hero-sub">Production pipeline snapshot · <%= now.split(",")[0] %></div>
        <%if(myTasks>0){%>
        <div class="hero-task">
          <div><div class="hero-task-n"><%= myTasks %></div><div class="hero-task-l">task<%= myTasks>1?"s":"" %> pending</div></div>
          <a href="<%= taskLink %>" class="hero-task-btn"><i class="bi bi-arrow-right-circle-fill"></i> Go to my module</a>
        </div>
        <%}%>
      </div>
      <div class="hero-right">
        <div class="hstat"><div class="hstat-n"><%= totalJobs %></div><div class="hstat-l">Total Jobs</div></div>
        <div class="hdiv"></div>
        <div class="hstat"><div class="hstat-n"><%= internalTotal %></div><div class="hstat-l">Internal</div></div>
        <div class="hdiv"></div>
        <div class="hstat"><div class="hstat-n"><%= externalTotal %></div><div class="hstat-l">External</div></div>
        <div class="hdiv"></div>
        <div class="hstat"><div class="hstat-n" style="color:#4ade80;"><%= internalCompleted+externalCompleted %></div><div class="hstat-l">Completed</div></div>
      </div>
    </div>

    <div class="kpi-grid">
      <div class="kpi"><div class="kpi-bar" style="background:#4f46e5;"></div><div class="kpi-ico" style="background:#eef2ff;">🏭</div><div class="kpi-n" style="color:#4f46e5;"><%= internalTotal %></div><div class="kpi-l">Internal Jobs</div></div>
      <div class="kpi"><div class="kpi-bar" style="background:#059669;"></div><div class="kpi-ico" style="background:#ecfdf5;">🤝</div><div class="kpi-n" style="color:#059669;"><%= externalTotal %></div><div class="kpi-l">External Orders</div></div>
      <div class="kpi"><div class="kpi-bar" style="background:#f97316;"></div><div class="kpi-ico" style="background:#fff7ed;">⏳</div><div class="kpi-n" style="color:#f97316;"><%= externalPending %></div><div class="kpi-l">Awaiting Admin</div></div>
      <div class="kpi"><div class="kpi-bar" style="background:#3b82f6;"></div><div class="kpi-ico" style="background:#eff6ff;">🔄</div><div class="kpi-n" style="color:#3b82f6;"><%= internalInProgress+externalInProgress %></div><div class="kpi-l">In Progress</div></div>
      <div class="kpi"><div class="kpi-bar" style="background:#22c55e;"></div><div class="kpi-ico" style="background:#f0fdf4;">✅</div><div class="kpi-n" style="color:#22c55e;"><%= qcApproved %></div><div class="kpi-l">QC Approved</div></div>
      <div class="kpi"><div class="kpi-bar" style="background:#a855f7;"></div><div class="kpi-ico" style="background:#faf5ff;">🔬</div><div class="kpi-n" style="color:#a855f7;"><%= testPassed %></div><div class="kpi-l">Tests Passed</div></div>
    </div>

    <%if("design".equals(role)){%>
    <div class="dband">
      <div style="display:flex;align-items:center;gap:12px;">
        <%if(!vtLabel.isEmpty()){%><div class="vtype-badge"><i class="bi bi-tag-fill" style="font-size:10px;margin-right:4px;"></i><%= vtLabel %></div><%}%>
        <div><div style="font-weight:700;font-size:13px;"><%= fullName %></div><div style="font-size:11px;color:var(--muted);margin-top:2px;">@<%= username %><%if(designerSlot>0){%> &nbsp;·&nbsp; Slot <%= designerSlot %><%}%></div></div>
      </div>
      <div style="display:flex;gap:10px;">
        <div class="dc"><div class="dc-n" style="color:#4f46e5;"><%= myIntJobs %></div><div class="dc-l">Internal Jobs</div></div>
        <div class="dc"><div class="dc-n" style="color:#059669;"><%= myExtReqs %></div><div class="dc-l">External Reqs</div></div>
      </div>
    </div>
    <div class="wf-card">
      <div class="wf-title"><i class="bi bi-diagram-2-fill" style="color:#4f46e5;"></i> Your Stage in the Production Workflow</div>
      <div class="wf-track">
        <div class="wf-node done"><div class="wf-circle"><i class="bi bi-check2" style="font-size:10px;"></i></div><div class="wf-lbl">Request</div></div>
        <div class="wf-node done"><div class="wf-circle"><i class="bi bi-check2" style="font-size:10px;"></i></div><div class="wf-lbl">Admin</div></div>
        <div class="wf-node cur"><div class="wf-circle"><i class="bi bi-pencil-fill" style="font-size:9px;"></i></div><div class="wf-lbl">Design</div></div>
        <div class="wf-node"><div class="wf-circle"><i class="bi bi-shield-check" style="font-size:9px;"></i></div><div class="wf-lbl">QC</div></div>
        <div class="wf-node"><div class="wf-circle"><i class="bi bi-flask" style="font-size:9px;"></i></div><div class="wf-lbl">Testing</div></div>
        <div class="wf-node"><div class="wf-circle"><i class="bi bi-bar-chart" style="font-size:9px;"></i></div><div class="wf-lbl">Analytics</div></div>
        <div class="wf-node"><div class="wf-circle"><i class="bi bi-flag" style="font-size:9px;"></i></div><div class="wf-lbl">Final</div></div>
      </div>
      <div class="wf-hint"><i class="bi bi-info-circle-fill"></i> Stage 3 — Design. Submit your assigned jobs to advance orders to QC.</div>
    </div>
    <%}%>

    <div class="prod-card">
      <div class="card-head">
        <div class="card-title"><i class="bi bi-diagram-3-fill" style="color:#4f46e5;font-size:13px;"></i> Production Overview</div>
        <div class="tab-bar">
          <button class="tab-btn int on" id="btn-int" onclick="switchTab('internal')"><i class="bi bi-building"></i> Internal (<%= internalTotal %>)</button>
          <button class="tab-btn ext" id="btn-ext" onclick="switchTab('external')"><i class="bi bi-person-lines-fill"></i> External (<%= externalTotal %>)</button>
        </div>
      </div>
      <div class="card-body">
        <div id="pan-int" class="tab-panel show">
          <div class="sinfo si-int"><i class="bi bi-building" style="font-size:22px;color:#4f46e5;"></i><div><div class="sit">Company Manufacturing</div><div class="si-sub">Vehicles designed and manufactured by AutoProd — KTM, Bajaj, BMW, Hero, TVS, Tata, Mahindra and more</div></div></div>
          <div class="mstats">
            <div class="msbox" style="background:#eef2ff;border-color:#c7d2fe;"><div class="msbox-n" style="color:#4f46e5;"><%= internalTotal %></div><div class="msbox-l">Total Internal Jobs</div></div>
            <div class="msbox" style="background:#fffbeb;border-color:#fde68a;"><div class="msbox-n" style="color:#92400e;"><%= internalInProgress %></div><div class="msbox-l">In Progress</div></div>
            <div class="msbox" style="background:#f0fdf4;border-color:#bbf7d0;"><div class="msbox-n" style="color:#166534;"><%= internalCompleted %></div><div class="msbox-l">Completed</div></div>
          </div>
          <div style="font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:10px;">Manufacturer Partners</div>
          <div class="bgrid">
            <a href="${pageContext.request.contextPath}/vehicle?brand=KTM" class="bcard"><div class="bcard-icon">K</div><div class="bcard-name">KTM</div><div class="bcard-sub">Sport / Adventure</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=Bajaj" class="bcard"><div class="bcard-icon">B</div><div class="bcard-name">Bajaj</div><div class="bcard-sub">Bikes / 3-Wheeler</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=BMW" class="bcard"><div class="bcard-icon">BM</div><div class="bcard-name">BMW</div><div class="bcard-sub">Luxury / Performance</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=Hero" class="bcard"><div class="bcard-icon">H</div><div class="bcard-name">Hero</div><div class="bcard-sub">Commuter Bikes</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=TVS" class="bcard"><div class="bcard-icon">T</div><div class="bcard-name">TVS</div><div class="bcard-sub">Scooters / Bikes</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=Tata" class="bcard"><div class="bcard-icon">TA</div><div class="bcard-name">Tata Motors</div><div class="bcard-sub">Cars / Trucks / EVs</div><span class="bcard-tag">INT</span></a>
            <a href="${pageContext.request.contextPath}/vehicle?brand=Mahindra" class="bcard"><div class="bcard-icon">M</div><div class="bcard-name">Mahindra</div><div class="bcard-sub">SUVs / Off-Road</div><span class="bcard-tag">INT</span></a>
            <%if("admin".equals(role)||"design".equals(role)){%><a href="${pageContext.request.contextPath}/vehicle" class="bcard bcard-add"><div class="bcard-icon">+</div><div class="bcard-name">New Job</div><div class="bcard-sub">Start Design</div></a><%}%>
          </div>
          <div style="font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:10px;">Recent Internal Jobs</div>
          <div style="overflow-x:auto;">
            <table class="dt">
              <thead><tr><th>#</th><th>Job No.</th><th>Brand</th><th>Vehicle Type</th><th>Stage</th><th>Assigned To</th></tr></thead>
              <tbody>
              <%try(Connection c2=DBConnection.getConnection()){ResultSet ij=c2.createStatement().executeQuery("SELECT * FROM internal_jobs ORDER BY created_at DESC LIMIT 8");int ir=0;boolean hr=false;
              while(ij.next()){hr=true;ir++;String ws=ij.getString("workflow_stage");if(ws==null)ws="";String sc=ws.contains("completed")?"sp-ok":ws.contains("design")?"sp-dsn":ws.contains("qc")?"sp-qc":ws.contains("testing")?"sp-tst":ws.contains("analytic")?"sp-tst":"sp-wip";%>
              <tr><td style="color:var(--muted);font-weight:600;"><%= ir %></td><td style="font-weight:700;color:#4f46e5;"><%= ij.getString("job_number")!=null?ij.getString("job_number"):"INT-"+ij.getInt("id") %></td><td style="font-weight:600;"><%= ij.getString("brand_name")!=null?ij.getString("brand_name"):"—" %></td><td><span class="vtag"><%= ij.getString("vehicle_type")!=null?ij.getString("vehicle_type").replace("_"," "):"—" %></span></td><td><span class="sp <%= sc %>"><%= ws.replace("_"," ") %></span></td><td style="color:var(--muted);"><%= ij.getString("current_assignee")!=null?ij.getString("current_assignee"):"—" %></td></tr>
              <%}if(!hr){%><tr><td colspan="6"><div class="empty"><i class="bi bi-building"></i><p>No internal jobs yet.</p></div></td></tr><%}}catch(Exception ed){%><tr><td colspan="6" style="color:#ef4444;padding:10px;font-size:11px;">DB Error: <%= ed.getMessage() %></td></tr><%}%>
              </tbody>
            </table>
          </div>
        </div>

        <div id="pan-ext" class="tab-panel">
          <div class="sinfo si-ext"><i class="bi bi-people-fill" style="font-size:22px;color:#059669;"></i><div><div class="sit">Customer-Requested Designs</div><div class="si-sub">Requirements submitted by customers, approved by Admin, routed through the production workflow</div></div></div>
          <div class="mstats">
            <div class="msbox" style="background:#fff7ed;border-color:#fde68a;"><div class="msbox-n" style="color:#92400e;"><%= externalPending %></div><div class="msbox-l">Awaiting Admin</div></div>
            <div class="msbox" style="background:#eff6ff;border-color:#bfdbfe;"><div class="msbox-n" style="color:#1e40af;"><%= externalInProgress %></div><div class="msbox-l">In Progress</div></div>
            <div class="msbox" style="background:#f0fdf4;border-color:#bbf7d0;"><div class="msbox-n" style="color:#166534;"><%= externalCompleted %></div><div class="msbox-l">Completed</div></div>
          </div>
          <div class="reqlist">
          <%boolean anyExt=false;
          try(Connection c3=DBConnection.getConnection()){ResultSet er=c3.createStatement().executeQuery("SELECT cr.*,c.full_name AS cname FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id WHERE cr.workflow_stage != 'admin_initial_rejected' ORDER BY cr.submitted_at DESC LIMIT 10");
          while(er.next()){anyExt=true;String wS=er.getString("workflow_stage");if(wS==null)wS="";String sl,sc2;
          if("completed".equals(wS)){sl="Completed";sc2="sp-ok";}else if("submitted".equals(wS)){sl="Awaiting Admin";sc2="sp-pnd";}else if("admin_initial_review".equals(wS)){sl="Under Review";sc2="sp-pnd";}else if("admin_initial_approved".equals(wS)){sl="In Design";sc2="sp-dsn";}else if("design_completed".equals(wS)){sl="In QC";sc2="sp-qc";}else if("qc_approved".equals(wS)){sl="In Testing";sc2="sp-tst";}else if("testing_completed".equals(wS)){sl="In Analytics";sc2="sp-tst";}else if("analytics_completed".equals(wS)){sl="Final Review";sc2="sp-wip";}else{sl="In Progress";sc2="sp-wip";}
          String cn=er.getString("cname")!=null?er.getString("cname"):er.getString("client_name");String reqN="REQ-"+String.format("%04d",er.getInt("id"));String reqT=er.getString("req_title")!=null?er.getString("req_title"):er.getString("module_name");
          String rawB=er.getString("budget")!=null?er.getString("budget"):"—";String budget=rawB;try{budget=new String(rawB.getBytes("ISO-8859-1"),"UTF-8");}catch(Exception ig){budget=rawB;}
          String vcat=er.getString("vehicle_type")!=null?er.getString("vehicle_type").replace("_"," ").toUpperCase():er.getString("module_name")!=null?er.getString("module_name"):"—";int qty=0;try{qty=er.getInt("vehicle_count");}catch(Exception ig){}%>
          <div class="rcard"><div class="rc-head"><div class="rc-id"><i class="bi bi-hash" style="font-size:9px;"></i> <%= reqN %></div><span class="sp <%= sc2 %>"><%= sl %></span></div>
          <div class="rc-title"><%= reqT!=null?reqT:"Requirement" %></div>
          <div class="rc-meta"><div class="rc-m"><i class="bi bi-person-fill" style="color:#059669;font-size:9px;"></i> <%= cn %></div><div class="rc-m"><i class="bi bi-tag-fill" style="color:#059669;font-size:9px;"></i> <%= vcat %></div><%if(qty>0){%><div class="rc-m"><i class="bi bi-truck-front" style="color:#059669;font-size:9px;"></i> <%= qty %> unit<%= qty>1?"s":"" %></div><%}%><div class="rc-m"><i class="bi bi-currency-rupee" style="color:#059669;font-size:9px;"></i> <%= budget %></div></div>
          <%if("admin_initial_approved".equals(wS)&&("design".equals(role)||"admin".equals(role))){%><a href="${pageContext.request.contextPath}/vehicle?reqId=<%= er.getInt("id") %>" class="rc-btn rb-d"><i class="bi bi-pencil-fill"></i> Start Design</a><%}else if("submitted".equals(wS)&&"admin".equals(role)){%><a href="jsp/admin/admin_dashboard.jsp" class="rc-btn rb-r"><i class="bi bi-eye-fill"></i> Review</a><%}%>
          </div>
          <%}if(!anyExt){%><div class="empty"><i class="bi bi-clipboard-x"></i><p>No customer requirements yet.</p></div><%}}catch(Exception e4){%><div style="color:#ef4444;padding:10px;font-size:11px;">DB Error: <%= e4.getMessage() %></div><%}%>
          </div>
        </div>
      </div>
    </div>

    <div class="prod-card">
      <div class="card-head"><div class="card-title"><i class="bi bi-search" style="color:#4f46e5;font-size:13px;"></i> Search Vehicles</div></div>
      <div class="card-body">
        <form method="get"><div class="srow">
          <input type="text" name="search" class="sinput" placeholder="Search by model name or fuel type..." value="<%= searchQ %>">
          <button type="submit" class="sbtn2"><i class="bi bi-search"></i> Search</button>
          <%if(!searchQ.isEmpty()){%><a href="dashboard.jsp" class="clrbtn"><i class="bi bi-x"></i> Clear</a><%}%>
        </div></form>
        <%if(!searchQ.isEmpty()){%>
        <div style="overflow-x:auto;"><table class="dt">
          <thead><tr><th>#</th><th>Model Name</th><th>Seats</th><th>Fuel Type</th><th>Status</th></tr></thead>
          <tbody>
          <%try(Connection cS=DBConnection.getConnection()){String sq=searchQ.replace("'","''");ResultSet sv=cS.createStatement().executeQuery("SELECT * FROM vehicle WHERE model_name LIKE '%"+sq+"%' OR fuel_type LIKE '%"+sq+"%' ORDER BY created_at DESC");int sn=0;
          while(sv.next()){sn++;String vs=sv.getString("status");String pc="approved".equals(vs)?"sp-ok":"rejected".equals(vs)?"sp-tst":"sp-wip";%>
          <tr><td style="color:var(--muted);"><%= sn %></td><td style="font-weight:600;"><%= sv.getString("model_name") %></td><td><%= sv.getInt("seating_capacity") %></td><td><span class="vtag"><%= sv.getString("fuel_type") %></span></td><td><span class="sp <%= pc %>"><%= vs %></span></td></tr>
          <%}if(sn==0){%><tr><td colspan="5"><div class="empty"><i class="bi bi-search"></i><p>No results for "<%= searchQ %>"</p></div></td></tr><%}}catch(Exception eS){%><tr><td colspan="5" style="color:#ef4444;padding:10px;">DB Error</td></tr><%}%>
          </tbody>
        </table></div>
        <%}%>
      </div>
    </div>

    <div class="prod-card">
      <div class="card-head"><div class="card-title"><i class="bi bi-lightning-charge-fill" style="color:#f97316;font-size:13px;"></i> Quick Access</div></div>
      <div class="card-body"><div class="qagrid">
        <%if("admin".equals(role)||"design".equals(role)){%><a href="${pageContext.request.contextPath}/vehicle" class="qabtn qa-d"><i class="bi bi-truck-front-fill"></i> Vehicle Design<%if("design".equals(role)&&myTasks>0){%><span class="qabadge"><%= myTasks %></span><%}%></a><%}%>
        <%if("admin".equals(role)||"qc".equals(role)){%><a href="${pageContext.request.contextPath}/qc" class="qabtn qa-q"><i class="bi bi-shield-check"></i> QC Module<%if("qc".equals(role)&&myTasks>0){%><span class="qabadge"><%= myTasks %></span><%}%></a><%}%>
        <%if("admin".equals(role)||"testing".equals(role)){%><a href="${pageContext.request.contextPath}/testing" class="qabtn qa-t"><i class="bi bi-flask-fill"></i> Testing<%if("testing".equals(role)&&myTasks>0){%><span class="qabadge"><%= myTasks %></span><%}%></a><%}%>
        <%if("admin".equals(role)||"analytics".equals(role)){%><a href="jsp/analytics_module.jsp" class="qabtn qa-a"><i class="bi bi-bar-chart-fill"></i> Analytics<%if("analytics".equals(role)&&myTasks>0){%><span class="qabadge"><%= myTasks %></span><%}%></a><%}%>
        <%if("admin".equals(role)){%><a href="jsp/admin/admin_dashboard.jsp" class="qabtn qa-adm"><i class="bi bi-speedometer2"></i> Admin Panel<%if(myTasks>0){%><span class="qabadge"><%= myTasks %></span><%}%></a><a href="jsp/final_report.jsp" class="qabtn qa-rpt"><i class="bi bi-file-earmark-bar-graph-fill"></i> Final Report</a><%}%>
      </div></div>
    </div>

  </div>
</div>
<script>
function switchTab(t){
  var bi=document.getElementById('btn-int'),be=document.getElementById('btn-ext');
  var pi=document.getElementById('pan-int'),pe=document.getElementById('pan-ext');
  if(t==='internal'){bi.className='tab-btn int on';be.className='tab-btn ext';pi.classList.add('show');pe.classList.remove('show');}
  else{be.className='tab-btn ext on';bi.className='tab-btn int';pe.classList.add('show');pi.classList.remove('show');}
  var u=new URL(window.location.href);u.searchParams.set('tab',t);window.history.replaceState({},'',u);
}
if('<%= activeTab %>'==='external')switchTab('external');
document.querySelectorAll('.kpi').forEach(function(c,i){c.style.opacity='0';c.style.transform='translateY(12px)';setTimeout(function(){c.style.transition='opacity .3s ease,transform .3s ease';c.style.opacity='1';c.style.transform='translateY(0)';},40+i*50);});
</script>
</body>
</html>
