<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.util.*" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp"); return;
    }
    String role    = (String) sess.getAttribute("role");
    String anaUser = (String) sess.getAttribute("username");
    String anaName = (String) sess.getAttribute("fullName");
    if (anaName == null) anaName = anaUser;
    if (!"analytics".equals(role) && !"admin".equals(role)) {
        response.sendRedirect("../dashboard.jsp"); return;
    }
    String ctx = request.getContextPath();

    /* Ensure analytics_submissions table */
    try (Connection c = DBConnection.getConnection()) {
        c.createStatement().executeUpdate(
            "CREATE TABLE IF NOT EXISTS analytics_submissions(" +
            "id INT AUTO_INCREMENT PRIMARY KEY," +
            "job_ref_id INT NOT NULL,source_type VARCHAR(30),analyst_user VARCHAR(100)," +
            "market_segment VARCHAR(100),cost_estimate DECIMAL(15,2) DEFAULT 0," +
            "projected_units INT DEFAULT 0,roi_pct DECIMAL(5,2) DEFAULT 0," +
            "risk_level VARCHAR(20),recommendation VARCHAR(50),analyst_notes TEXT," +
            "submitted_at DATETIME DEFAULT NOW())ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    } catch (Exception ig) {}

    /* Determine analyst stream: internal or external based on module_team_members */
    String anaStream = "both"; // default for admin
    if (!"admin".equals(role)) {
        try (Connection c = DBConnection.getConnection()) {
            PreparedStatement ps = c.prepareStatement(
                "SELECT vehicle_type FROM module_team_members WHERE module_role='analytics' AND username=? AND is_active=1 LIMIT 1");
            ps.setString(1, anaUser);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                String vt = rs.getString("vehicle_type");
                if ("internal".equals(vt) || "external".equals(vt)) anaStream = vt;
            }
        } catch (Exception ig) {}
    }
    boolean canSeeInternal = "admin".equals(role) || "internal".equals(anaStream);
    boolean canSeeExternal = "admin".equals(role) || "external".equals(anaStream);

    /* URL params */
    String surface  = request.getParameter("surface");
    String reqIdStr = request.getParameter("reqId");
    String srcParam = request.getParameter("src");

    /* LOAD INTERNAL JOBS (only if analyst has internal stream) */
    List<Object[]> myIntJobs = new ArrayList<>();
    if (canSeeInternal) {
        try (Connection conn = DBConnection.getConnection()) {
            String sql = "admin".equals(role)
                ? "SELECT ij.id,'internal' AS st,COALESCE(ij.job_number,CONCAT('INT-',ij.id)) AS ref," +
                  "COALESCE(ij.model_name,'—') AS title,COALESCE(ij.vehicle_type,'—') AS vtype," +
                  "COALESCE(ij.brand_name,'—') AS client,COALESCE(ij.target_date,'—') AS dl," +
                  "COALESCE(ij.quantity,'1') AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM internal_jobs ij " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=ij.id AND tr.source_type='internal' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=ij.id AND source_type='internal' ORDER BY id DESC LIMIT 1) " +
                  "WHERE ij.workflow_stage IN ('testing_completed','analytics_failed') ORDER BY ij.id DESC"
                : "SELECT ij.id,'internal' AS st,COALESCE(ij.job_number,CONCAT('INT-',ij.id)) AS ref," +
                  "COALESCE(ij.model_name,'—') AS title,COALESCE(ij.vehicle_type,'—') AS vtype," +
                  "COALESCE(ij.brand_name,'—') AS client,COALESCE(ij.target_date,'—') AS dl," +
                  "COALESCE(ij.quantity,'1') AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM internal_jobs ij " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=ij.id AND tr.source_type='internal' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=ij.id AND source_type='internal' ORDER BY id DESC LIMIT 1) " +
                  "WHERE ij.workflow_stage IN ('testing_completed','analytics_failed') AND ij.current_assignee=? ORDER BY ij.id DESC";
            PreparedStatement ps = conn.prepareStatement(sql);
            if (!"admin".equals(role)) ps.setString(1, anaUser);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) myIntJobs.add(new Object[]{
                rs.getInt("id"), rs.getString("st"), rs.getString("ref"), rs.getString("title"),
                rs.getString("vtype"), rs.getString("client"), rs.getString("dl"), rs.getString("qty"),
                rs.getInt("tscore"), rs.getString("tres")
            });
        } catch (Exception e) {}
    }

    /* LOAD EXTERNAL JOBS (only if analyst has external stream) */
    List<Object[]> myExtJobs = new ArrayList<>();
    if (canSeeExternal) {
        try (Connection conn = DBConnection.getConnection()) {
            String eoSql = "admin".equals(role)
                ? "SELECT eo.id,'external' AS st,COALESCE(eo.order_number,CONCAT('EXT-',eo.id)) AS ref," +
                  "CONCAT(eo.client_name,' — Bulk') AS title,COALESCE(eo.vehicle_type,'—') AS vtype," +
                  "COALESCE(eo.client_name,'—') AS client,COALESCE(eo.deadline,'—') AS dl,'1' AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM external_orders eo " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=eo.id AND tr.source_type='external' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=eo.id AND source_type='external' ORDER BY id DESC LIMIT 1) " +
                  "WHERE eo.workflow_stage IN ('testing_completed','analytics_failed') ORDER BY eo.id DESC"
                : "SELECT eo.id,'external' AS st,COALESCE(eo.order_number,CONCAT('EXT-',eo.id)) AS ref," +
                  "CONCAT(eo.client_name,' — Bulk') AS title,COALESCE(eo.vehicle_type,'—') AS vtype," +
                  "COALESCE(eo.client_name,'—') AS client,COALESCE(eo.deadline,'—') AS dl,'1' AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM external_orders eo " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=eo.id AND tr.source_type='external' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=eo.id AND source_type='external' ORDER BY id DESC LIMIT 1) " +
                  "WHERE eo.workflow_stage IN ('testing_completed','analytics_failed') AND eo.current_assignee=? ORDER BY eo.id DESC";
            PreparedStatement ps1 = conn.prepareStatement(eoSql);
            if (!"admin".equals(role)) ps1.setString(1, anaUser);
            ResultSet rs1 = ps1.executeQuery();
            while (rs1.next()) myExtJobs.add(new Object[]{
                rs1.getInt("id"), rs1.getString("st"), rs1.getString("ref"), rs1.getString("title"),
                rs1.getString("vtype"), rs1.getString("client"), rs1.getString("dl"), rs1.getString("qty"),
                rs1.getInt("tscore"), rs1.getString("tres")
            });
            // customer_requirements
            String crSql = "admin".equals(role)
                ? "SELECT cr.id,'cr' AS st,CONCAT('CR-',cr.id) AS ref,COALESCE(cr.req_title,'—') AS title," +
                  "COALESCE(cr.vehicle_type,'—') AS vtype,COALESCE(c.full_name,cr.client_name,'—') AS client," +
                  "COALESCE(cr.deadline,'—') AS dl,'1' AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=cr.id AND tr.source_type='cr' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
                  "WHERE cr.workflow_stage IN ('testing_completed','analytics_failed') ORDER BY cr.id DESC"
                : "SELECT cr.id,'cr' AS st,CONCAT('CR-',cr.id) AS ref,COALESCE(cr.req_title,'—') AS title," +
                  "COALESCE(cr.vehicle_type,'—') AS vtype,COALESCE(c.full_name,cr.client_name,'—') AS client," +
                  "COALESCE(cr.deadline,'—') AS dl,'1' AS qty," +
                  "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres " +
                  "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
                  "LEFT JOIN testing_results tr ON tr.job_ref_id=cr.id AND tr.source_type='cr' " +
                  "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
                  "WHERE cr.workflow_stage IN ('testing_completed','analytics_failed') AND cr.current_assignee=? ORDER BY cr.id DESC";
            PreparedStatement ps2 = conn.prepareStatement(crSql);
            if (!"admin".equals(role)) ps2.setString(1, anaUser);
            ResultSet rs2 = ps2.executeQuery();
            while (rs2.next()) myExtJobs.add(new Object[]{
                rs2.getInt("id"), rs2.getString("st"), rs2.getString("ref"), rs2.getString("title"),
                rs2.getString("vtype"), rs2.getString("client"), rs2.getString("dl"), rs2.getString("qty"),
                rs2.getInt("tscore"), rs2.getString("tres")
            });
        } catch (Exception e) {}
    }

    /* PAGE STATE */
    boolean showLanding = (surface == null && reqIdStr == null);
    boolean showIntList = "internal".equals(surface) && reqIdStr == null;
    boolean showExtList = "external".equals(surface) && reqIdStr == null;
    boolean showDetail  = reqIdStr != null && !reqIdStr.trim().isEmpty();

    int    selId  = 0;
    String selSrc = srcParam != null ? srcParam : "internal";
    if (showDetail) { try { selId = Integer.parseInt(reqIdStr.trim()); } catch (Exception ig) {} }

    /* DETAIL DATA */
    String d_ref="—",d_title="—",d_vtype="—",d_client="—",d_dl="—",d_qty="1";
    int d_tscore=0; String d_tres="—",d_tnotes="—",d_tests_json="[]";
    // QC data
    String qc_action="—",qc_severity="—",qc_notes="—",qc_user="—";
    // Design data
    String ds_designer="—",ds_title="—",ds_subcategory="—",ds_engine="—",ds_version="—",ds_overview="—",ds_remarks="—";
    String ana_market="",ana_rec="Approve",ana_risk="Low",ana_notes="";
    double ana_cost=0,ana_roi=0; int ana_units=0; boolean alreadySubmitted=false;

    if (showDetail && selId > 0) {
        try (Connection conn = DBConnection.getConnection()) {
            String jq = "internal".equals(selSrc)
                ? "SELECT COALESCE(job_number,CONCAT('INT-',id)) AS ref,COALESCE(model_name,'—') AS title,COALESCE(vehicle_type,'—') AS vtype,COALESCE(brand_name,'—') AS client,COALESCE(target_date,'—') AS dl,COALESCE(quantity,'1') AS qty FROM internal_jobs WHERE id=?"
                : "external".equals(selSrc)
                ? "SELECT COALESCE(order_number,CONCAT('EXT-',id)) AS ref,CONCAT(client_name,' — Bulk') AS title,COALESCE(vehicle_type,'—') AS vtype,COALESCE(client_name,'—') AS client,COALESCE(deadline,'—') AS dl,'1' AS qty FROM external_orders WHERE id=?"
                : "SELECT CONCAT('CR-',id) AS ref,COALESCE(req_title,'—') AS title,COALESCE(vehicle_type,'—') AS vtype,COALESCE(client_name,'—') AS client,COALESCE(deadline,'—') AS dl,'1' AS qty FROM customer_requirements WHERE id=?";
            PreparedStatement ps = conn.prepareStatement(jq);
            ps.setInt(1, selId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) { d_ref=rs.getString("ref"); d_title=rs.getString("title"); d_vtype=rs.getString("vtype"); d_client=rs.getString("client"); d_dl=rs.getString("dl"); d_qty=rs.getString("qty"); }
            String tSrc = "internal".equals(selSrc)?"internal":("external".equals(selSrc)?"external":"cr");
            // Testing result
            try {
                PreparedStatement tp = conn.prepareStatement("SELECT overall_score,overall_result,tester_notes,COALESCE(tests_json,'[]') AS tj FROM testing_results WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
                tp.setInt(1,selId); tp.setString(2,tSrc);
                ResultSet tr = tp.executeQuery();
                if (tr.next()) { d_tscore=tr.getInt("overall_score"); d_tres=tr.getString("overall_result")!=null?tr.getString("overall_result"):"—"; d_tnotes=tr.getString("tester_notes")!=null?tr.getString("tester_notes"):"—"; d_tests_json=tr.getString("tj")!=null?tr.getString("tj"):"[]"; }
            } catch (Exception ig) {}
            // QC result
            try {
                PreparedStatement qp = conn.prepareStatement("SELECT action,COALESCE(severity,'—') AS sev,COALESCE(inspector_notes,'—') AS notes,COALESCE(qc_user,'—') AS qu FROM qc_inspections WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
                qp.setInt(1,selId); qp.setString(2,tSrc);
                ResultSet qr = qp.executeQuery();
                if (qr.next()) { qc_action=qr.getString("action")!=null?qr.getString("action"):"—"; qc_severity=qr.getString("sev"); qc_notes=qr.getString("notes"); qc_user=qr.getString("qu"); }
            } catch (Exception ig) {}
            // Design submission
            String dSrc = "internal".equals(selSrc)?"internal_job":("external".equals(selSrc)?"external_order":"cr");
            try {
                PreparedStatement dp = conn.prepareStatement("SELECT COALESCE(designer_username,'—') AS du,COALESCE(design_title,'—') AS dt,COALESCE(sub_category,'—') AS sc,COALESCE(engine_type,'—') AS et,COALESCE(design_version,'—') AS dv,COALESCE(overview_notes,'—') AS ov,COALESCE(designer_remarks,'—') AS dr FROM design_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
                dp.setInt(1,selId); dp.setString(2,dSrc);
                ResultSet dr2 = dp.executeQuery();
                if (dr2.next()) { ds_designer=dr2.getString("du"); ds_title=dr2.getString("dt"); ds_subcategory=dr2.getString("sc"); ds_engine=dr2.getString("et"); ds_version=dr2.getString("dv"); ds_overview=dr2.getString("ov"); ds_remarks=dr2.getString("dr"); }
            } catch (Exception ig) {}
            // Analytics submission
            PreparedStatement ap = conn.prepareStatement("SELECT * FROM analytics_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
            ap.setInt(1,selId); ap.setString(2,tSrc);
            ResultSet ar = ap.executeQuery();
            if (ar.next()) { alreadySubmitted=true; ana_market=ar.getString("market_segment")!=null?ar.getString("market_segment"):""; ana_cost=ar.getDouble("cost_estimate"); ana_units=ar.getInt("projected_units"); ana_roi=ar.getDouble("roi_pct"); ana_risk=ar.getString("risk_level")!=null?ar.getString("risk_level"):"Low"; ana_rec=ar.getString("recommendation")!=null?ar.getString("recommendation"):"Approve"; ana_notes=ar.getString("analyst_notes")!=null?ar.getString("analyst_notes"):""; }
        } catch (Exception e) {}
    }

    String successMsg = request.getParameter("success")!=null?request.getParameter("success"):(request.getAttribute("success")!=null?(String)request.getAttribute("success"):null);
    String errorMsg   = request.getParameter("error")!=null?request.getParameter("error"):(request.getAttribute("error")!=null?(String)request.getAttribute("error"):null);
    String initial    = anaName!=null&&!anaName.isEmpty()?String.valueOf(anaName.charAt(0)).toUpperCase():"A";

    // Determine default surface based on stream
    String defaultSurface = "internal".equals(anaStream) ? "internal" : "external".equals(anaStream) ? "external" : "internal";
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Analytics — AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Exo+2:wght@400;500;600;700;800&family=Rajdhani:wght@500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<script src="https://cdn.jsdelivr.net/npm/apexcharts@3.46.0/dist/apexcharts.min.js"></script>
<style>
:root{
  --bg:#0a0e1a;--surface:#0f1623;--card:#151e2d;--border:#1e2d45;
  --accent:#00c8ff;--accent2:#ff6b35;--green:#00e676;--purple:#7c5cfc;
  --ext:#00b4a6;--int:#6c63ff;--amber:#ffc107;
  --text:#dde4ef;--muted:#5a7090;
  --SB1:260px;--tst:#f59e0b;
}
*{margin:0;padding:0;box-sizing:border-box;}
html,body{height:100%;overflow:hidden;}
body{background:var(--bg);color:var(--text);font-family:'Exo 2',sans-serif;display:flex;flex-direction:column;}

/* TOPBAR */
.topbar{background:linear-gradient(135deg,#0b1628,#101c30);border-bottom:2px solid var(--accent);padding:10px 18px;display:flex;align-items:center;gap:14px;flex-shrink:0;box-shadow:0 3px 20px rgba(0,200,255,.12);z-index:100;}
.tb-logo{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;color:var(--accent);letter-spacing:2px;}
.tb-logo span{color:var(--text);}
.tb-sep{width:1px;height:22px;background:var(--border);}
.tb-title{font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:600;color:var(--muted);letter-spacing:1px;text-transform:uppercase;}
.tb-right{margin-left:auto;display:flex;align-items:center;gap:10px;}
.tb-badge{padding:3px 12px;border-radius:16px;font-size:11px;font-weight:700;border:1px solid;}
.tb-badge.stream-int{color:var(--int);border-color:var(--int);background:rgba(108,99,255,.1);}
.tb-badge.stream-ext{color:var(--ext);border-color:var(--ext);background:rgba(0,180,166,.1);}
.tb-badge.stream-both{color:var(--amber);border-color:var(--amber);background:rgba(255,193,7,.1);}
.tb-user{font-size:12px;color:var(--muted);}
.tb-user strong{color:var(--text);}
.tb-logout{font-size:11px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.tb-logout:hover{color:var(--accent2);border-color:var(--accent2);}
.tb-home{font-size:11px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;transition:all .2s;display:flex;align-items:center;gap:5px;}
.tb-home:hover{color:var(--accent);border-color:var(--accent);}

/* LAYOUT */
.layout{display:flex;flex:1;overflow:hidden;}

/* SIDEBAR */
.sb1{width:var(--SB1);min-width:var(--SB1);background:var(--surface);border-right:1px solid var(--border);display:flex;flex-direction:column;overflow:hidden;}
.sb1-head{padding:12px 14px;border-bottom:1px solid var(--border);background:rgba(0,200,255,.03);flex-shrink:0;}
.sb1-head-title{font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;margin-bottom:10px;}
.surf-toggle{display:flex;border-radius:10px;overflow:hidden;border:1px solid var(--border);}
.st-btn{flex:1;padding:7px 6px;text-align:center;font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;letter-spacing:1px;text-decoration:none;transition:all .2s;color:var(--muted);}
.st-btn.int{border-right:1px solid var(--border);}
.st-btn.int.active,.st-btn.int:hover{background:var(--int);color:#fff;}
.st-btn.ext.active,.st-btn.ext:hover{background:var(--ext);color:#fff;}
.sb1-body{flex:1;overflow-y:auto;}
.sb1-stream{border-bottom:1px solid var(--border);}
.sb1-stream-hd{padding:8px 14px;display:flex;align-items:center;gap:8px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1.5px;background:rgba(255,255,255,.02);}
.sb1-stream-hd.int{color:var(--int);}
.sb1-stream-hd.ext{color:var(--ext);}
.sb1-cnt{margin-left:auto;padding:1px 7px;border-radius:8px;font-size:10px;font-weight:800;}
.sb1-cnt.int{background:rgba(108,99,255,.2);color:var(--int);}
.sb1-cnt.ext{background:rgba(0,180,166,.2);color:var(--ext);}
.sb1-item{display:flex;flex-direction:column;gap:2px;padding:9px 14px 9px 20px;border-bottom:1px solid rgba(30,45,69,.5);text-decoration:none;color:var(--muted);transition:all .15s;cursor:pointer;}
.sb1-item:hover{background:rgba(0,200,255,.04);color:var(--text);}
.sb1-item.active-int{background:rgba(108,99,255,.08);border-left:3px solid var(--int);color:#b5b0ff;}
.sb1-item.active-ext{background:rgba(0,180,166,.08);border-left:3px solid var(--ext);color:#5eead4;}
.si-num{font-size:10px;font-weight:700;font-family:'Rajdhani',sans-serif;}
.si-num.int{color:var(--int);}
.si-num.ext{color:var(--ext);}
.si-title{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:220px;}
.si-score{font-size:10px;margin-top:2px;}
.score-bar{height:3px;border-radius:2px;background:var(--border);margin-top:3px;}
.score-fill{height:100%;border-radius:2px;}
.score-fill.int{background:linear-gradient(90deg,var(--int),var(--accent));}
.score-fill.ext{background:linear-gradient(90deg,var(--ext),var(--green));}
.sb1-empty{padding:14px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;}

/* MAIN */
.main{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.main-body{flex:1;overflow-y:auto;padding:20px 24px;}

/* LANDING */
.land-wrap{max-width:820px;margin:0 auto;}
.land-title{font-family:'Rajdhani',sans-serif;font-size:26px;font-weight:700;color:var(--accent);letter-spacing:3px;text-transform:uppercase;text-align:center;margin-bottom:6px;}
.land-sub{font-size:13px;color:var(--muted);text-align:center;margin-bottom:28px;}
.stream-badge{display:inline-flex;align-items:center;gap:6px;padding:4px 16px;border-radius:20px;font-size:12px;font-weight:700;margin-bottom:28px;}
.stream-badge.int{background:rgba(108,99,255,.15);color:var(--int);border:1px solid var(--int);}
.stream-badge.ext{background:rgba(0,180,166,.15);color:var(--ext);border:1px solid var(--ext);}
.stream-badge.both{background:rgba(255,193,7,.12);color:var(--amber);border:1px solid var(--amber);}
.surf-cards{display:grid;gap:18px;}
.surf-cards.two{grid-template-columns:1fr 1fr;}
.surf-cards.one{grid-template-columns:1fr;max-width:460px;margin:0 auto;}
.surf-card{border-radius:16px;padding:26px 22px;text-decoration:none;color:var(--text);transition:all .3s;display:block;position:relative;overflow:hidden;}
.surf-card.ic{background:linear-gradient(135deg,rgba(108,99,255,.12),rgba(108,99,255,.04));border:2px solid var(--int);}
.surf-card.ec{background:linear-gradient(135deg,rgba(0,180,166,.12),rgba(0,180,166,.04));border:2px solid var(--ext);}
.surf-card:hover{transform:translateY(-3px);}
.surf-card.ic:hover{box-shadow:0 14px 40px rgba(108,99,255,.25);}
.surf-card.ec:hover{box-shadow:0 14px 40px rgba(0,180,166,.25);}
.sc-icon{font-size:30px;margin-bottom:12px;}
.sc-title{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin-bottom:6px;}
.sc-title.ic{color:var(--int);}
.sc-title.ec{color:var(--ext);}
.sc-desc{font-size:12px;color:var(--muted);line-height:1.5;margin-bottom:14px;}
.sc-count{display:inline-block;font-size:11px;font-weight:700;padding:3px 12px;border-radius:16px;}
.sc-count.ic{background:rgba(108,99,255,.2);color:var(--int);}
.sc-count.ec{background:rgba(0,180,166,.2);color:var(--ext);}

/* KPI STRIP */
.kpi-strip{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px;}
.kpi{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:14px 16px;position:relative;overflow:hidden;}
.kpi::after{content:'';position:absolute;bottom:0;left:0;right:0;height:2px;}
.kpi.ka::after{background:var(--amber);}
.kpi.kg::after{background:var(--green);}
.kpi.kp::after{background:var(--accent);}
.kpi-l{font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:6px;}
.kpi-n{font-family:'Rajdhani',sans-serif;font-size:28px;font-weight:700;line-height:1;}
.kpi-n.ka{color:var(--amber);}
.kpi-n.kg{color:var(--green);}
.kpi-n.kp{color:var(--accent);}
.kpi-s{font-size:10px;color:var(--muted);margin-top:3px;}

/* JOB LIST */
.list-header{display:flex;align-items:center;gap:12px;margin-bottom:18px;padding-bottom:12px;border-bottom:1px solid var(--border);}
.lh-back{font-size:12px;color:var(--muted);text-decoration:none;padding:4px 10px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.lh-back:hover{color:var(--accent);border-color:var(--accent);}
.lh-title{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;}
.lh-title.int{color:var(--int);}
.lh-title.ext{color:var(--ext);}
.job-card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px 18px;margin-bottom:10px;display:flex;align-items:center;gap:14px;text-decoration:none;color:var(--text);transition:all .2s;}
.job-card.ic{border-left:4px solid var(--int);}
.job-card.ec{border-left:4px solid var(--ext);}
.job-card:hover{transform:translateX(3px);}
.job-card.ic:hover{background:rgba(108,99,255,.05);border-color:var(--int);}
.job-card.ec:hover{background:rgba(0,180,166,.05);border-color:var(--ext);}
.jc-icon{width:44px;height:44px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:800;flex-shrink:0;}
.jc-icon.ic{background:rgba(108,99,255,.15);color:var(--int);}
.jc-icon.ec{background:rgba(0,180,166,.15);color:var(--ext);}
.jc-body{flex:1;min-width:0;}
.jc-num{font-size:10px;font-weight:700;margin-bottom:3px;}
.jc-num.int{color:var(--int);}
.jc-num.ext{color:var(--ext);}
.jc-title{font-size:14px;font-weight:700;margin-bottom:4px;}
.jc-meta{font-size:11px;color:var(--muted);}
.jc-right{display:flex;flex-direction:column;align-items:flex-end;gap:6px;flex-shrink:0;}
.score-pill{font-size:10px;font-weight:700;padding:3px 10px;border-radius:14px;}
.score-hi{background:rgba(0,230,118,.1);color:var(--green);}
.score-md{background:rgba(255,193,7,.1);color:var(--amber);}
.score-lo{background:rgba(255,107,53,.1);color:var(--accent2);}
.score-pct{font-size:11px;font-weight:700;color:var(--accent);}
.score-bar-sm{width:80px;height:4px;border-radius:2px;background:var(--border);}
.score-fill-sm{height:100%;border-radius:2px;}
.score-fill-sm.int{background:linear-gradient(90deg,var(--int),var(--accent));}
.score-fill-sm.ext{background:linear-gradient(90deg,var(--ext),var(--green));}

/* EMPTY */
.empty-state{text-align:center;padding:50px 20px;}
.empty-icon{font-size:40px;margin-bottom:12px;opacity:.3;}
.empty-text{color:var(--muted);font-size:13px;}

/* WORKBENCH DETAIL */
.wb-layout{display:grid;grid-template-columns:300px 1fr;gap:18px;align-items:start;}
.info-card{background:var(--card);border:1px solid var(--border);border-radius:12px;overflow:hidden;}
.ic-head{padding:12px 16px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:8px;font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1.5px;}
.ic-head.int{color:var(--int);}
.ic-head.ext{color:var(--ext);}
.ic-head.test{color:var(--accent);}
.ic-body{padding:14px 16px;}
.info-row{display:flex;justify-content:space-between;align-items:flex-start;padding:7px 0;border-bottom:1px solid rgba(30,45,69,.5);font-size:12px;}
.info-row:last-child{border-bottom:none;}
.ir-l{color:var(--muted);font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.5px;}
.ir-v{font-weight:700;text-align:right;max-width:55%;}
.ts-bar{height:6px;border-radius:3px;background:var(--border);margin-top:6px;}
.ts-fill{height:100%;border-radius:3px;}
.ts-fill.hi{background:linear-gradient(90deg,var(--green),#4ade80);}
.ts-fill.md{background:linear-gradient(90deg,var(--amber),#fbbf24);}
.ts-fill.lo{background:linear-gradient(90deg,var(--accent2),#fb923c);}
.tn-box{background:rgba(0,200,255,.04);border:1px solid rgba(0,200,255,.1);border-radius:8px;padding:10px 12px;font-size:11px;color:var(--muted);line-height:1.6;margin-top:10px;white-space:pre-wrap;}

/* FORM */
.form-card{background:var(--card);border:1px solid var(--border);border-radius:12px;overflow:hidden;}
.fc-head{padding:12px 18px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:8px;font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;color:var(--accent);text-transform:uppercase;letter-spacing:1.5px;}
.fc-body{padding:18px;}
.f-sec{margin-bottom:18px;}
.f-sec-title{font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--accent);text-transform:uppercase;letter-spacing:2px;margin-bottom:10px;display:flex;align-items:center;gap:8px;}
.f-sec-title::after{content:'';flex:1;height:1px;background:var(--border);}
.f-row{display:grid;grid-template-columns:1fr 1fr;gap:12px;}
.fg{margin-bottom:12px;}
.fg label{display:block;margin-bottom:5px;font-size:10px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:1px;}
.fc{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:8px;padding:9px 12px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;transition:all .2s;outline:none;}
.fc:focus{border-color:var(--accent);background:rgba(0,200,255,.04);box-shadow:0 0 0 3px rgba(0,200,255,.08);}
textarea.fc{resize:vertical;min-height:90px;}
.risk-row{display:flex;gap:8px;}
.risk-opt{flex:1;padding:9px 8px;border:1px solid var(--border);border-radius:9px;text-align:center;cursor:pointer;font-size:11px;font-weight:700;color:var(--muted);transition:all .2s;font-family:'Rajdhani',sans-serif;letter-spacing:.5px;background:transparent;}
.risk-opt.low.active{background:rgba(0,230,118,.1);border-color:var(--green);color:var(--green);}
.risk-opt.med.active{background:rgba(255,193,7,.1);border-color:var(--amber);color:var(--amber);}
.risk-opt.hi.active{background:rgba(255,107,53,.1);border-color:var(--accent2);color:var(--accent2);}
.rec-row{display:flex;gap:8px;}
.rec-btn{flex:1;padding:10px 8px;border:1px solid var(--border);border-radius:9px;text-align:center;cursor:pointer;font-size:11px;font-weight:700;color:var(--muted);transition:all .2s;font-family:'Rajdhani',sans-serif;letter-spacing:.5px;background:transparent;}
.rec-btn.approve.active{background:rgba(0,230,118,.1);border-color:var(--green);color:var(--green);}
.rec-btn.conditional.active{background:rgba(255,193,7,.1);border-color:var(--amber);color:var(--amber);}
.rec-btn.reject.active{background:rgba(255,107,53,.1);border-color:var(--accent2);color:var(--accent2);}
.sub-btn{width:100%;padding:13px;border-radius:10px;border:none;font-family:'Rajdhani',sans-serif;font-size:14px;font-weight:700;letter-spacing:2px;text-transform:uppercase;cursor:pointer;background:linear-gradient(135deg,var(--accent),#0080aa);color:#000;transition:all .2s;margin-top:6px;}
.sub-btn:hover{transform:translateY(-2px);box-shadow:0 6px 20px rgba(0,200,255,.3);}
.submitted-banner{background:rgba(0,230,118,.08);border:1px solid var(--green);border-radius:10px;padding:12px 16px;display:flex;align-items:center;gap:10px;font-size:12px;font-weight:700;color:var(--green);margin-bottom:14px;}

/* ALERT */
.alert{border-radius:10px;padding:10px 16px;font-size:12px;font-weight:700;margin-bottom:16px;display:flex;align-items:center;gap:8px;}
.alert-ok{background:rgba(0,230,118,.08);border:1px solid var(--green);color:var(--green);}
.alert-err{background:rgba(255,107,53,.08);border:1px solid var(--accent2);color:var(--accent2);}

/* SECTION TABS */
.sec-tabs{display:flex;align-items:center;gap:6px;padding:0 0 16px;border-bottom:1px solid var(--border);margin-bottom:18px;flex-wrap:wrap;}
.sec-tab{padding:7px 14px;border-radius:9px;border:1px solid var(--border);background:transparent;color:var(--muted);font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;letter-spacing:1px;cursor:pointer;transition:all .2s;display:flex;align-items:center;gap:6px;}
.sec-tab:hover{border-color:var(--accent);color:var(--accent);}
.sec-tab.active{background:rgba(0,200,255,.1);border-color:var(--accent);color:var(--accent);}
.sec-tab-form.active{background:rgba(108,99,255,.1);border-color:var(--int);color:var(--int);}
.sec-tab-form:hover{border-color:var(--int);color:var(--int);}
.as-status{margin-left:auto;font-size:10px;font-weight:700;color:var(--muted);display:flex;align-items:center;gap:5px;}
.as-status-inline{margin-left:auto;font-size:10px;font-weight:700;color:var(--muted);}
/* LAYOUTS */
.wb-layout3{display:grid;grid-template-columns:1fr 1fr;gap:18px;}
.wb-layout-form{display:grid;grid-template-columns:1fr 300px;gap:18px;align-items:start;}
/* PIPELINE */
.pipeline-steps{display:flex;align-items:center;margin:14px 0;}
.ps{display:flex;flex-direction:column;align-items:center;gap:5px;}
.ps-dot{width:30px;height:30px;border-radius:50%;background:var(--green);border:2px solid var(--green);display:flex;align-items:center;justify-content:center;font-size:12px;color:#000;flex-shrink:0;}
.ps.active .ps-dot{background:var(--accent);border-color:var(--accent);color:#000;box-shadow:0 0 10px rgba(0,200,255,.4);}
.ps-line{flex:1;height:2px;background:var(--green);margin:0 4px;margin-bottom:20px;}
.ps-line:not(.done){background:var(--border);}
.ps-label{font-size:10px;font-weight:700;color:var(--text);font-family:'Rajdhani',sans-serif;letter-spacing:.5px;}
.ps-sub{font-size:9px;color:var(--muted);text-align:center;}
/* SCORE SUMMARY */
.score-summary{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:14px;}
.ss-item{background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:9px;padding:10px 12px;}
.ss-label{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:5px;}
.ss-val{font-family:'Rajdhani',sans-serif;font-size:16px;font-weight:700;margin-bottom:5px;}
.ss-bar{height:4px;border-radius:2px;background:var(--border);}
.ss-fill{height:100%;border-radius:2px;}
/* DATA BOXES */
.data-sec-title{font-size:9px;font-weight:700;color:var(--accent);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:6px;}
.data-box{background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:11px 13px;font-size:12px;color:var(--text);line-height:1.65;min-height:50px;white-space:pre-wrap;}
/* STREAM TAG */
.stream-tag{padding:2px 8px;border-radius:8px;font-size:10px;font-weight:700;}
.st-int{background:rgba(108,99,255,.2);color:var(--int);}
.st-ext{background:rgba(0,180,166,.2);color:var(--ext);}
/* TEST RESULTS */
.test-results-header{display:flex;align-items:flex-start;gap:20px;background:var(--card);border:1px solid var(--border);border-radius:12px;padding:18px 20px;margin-bottom:16px;}
.tr-score-circle{flex-shrink:0;}
.tr-summary{flex:1;}
.tr-result{font-family:'Rajdhani',sans-serif;font-size:22px;font-weight:700;letter-spacing:1px;margin-bottom:3px;}
.tr-sub{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:10px;}
.tr-notes{font-size:11px;color:var(--muted);line-height:1.6;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:9px 11px;}
/* TEST DATA TABLE */
.test-data-table{width:100%;border-collapse:collapse;font-size:12px;background:var(--card);border-radius:12px;overflow:hidden;}
.test-data-table thead tr{background:rgba(0,200,255,.05);border-bottom:2px solid var(--border);}
.test-data-table th{padding:10px 13px;text-align:left;font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1px;font-family:'Rajdhani',sans-serif;}
.test-data-table td{padding:10px 13px;border-bottom:1px solid rgba(30,45,69,.5);vertical-align:middle;}
.test-data-table tr:last-child td{border-bottom:none;}
.test-data-table tr:hover td{background:rgba(0,200,255,.02);}
.tr-pass{color:var(--green);font-weight:700;}
.tr-fail{color:var(--accent2);font-weight:700;}
.tr-cond{color:var(--amber);font-weight:700;}
.tr-na{color:var(--muted);}
/* TIPS */
.tip-item{display:flex;align-items:center;gap:8px;font-size:11px;color:var(--muted);padding:5px 0;border-bottom:1px solid rgba(30,45,69,.3);}
.tip-item:last-child{border-bottom:none;}
.tip-dot{width:8px;height:8px;border-radius:50%;flex-shrink:0;}
</style>
</head>
<body>

<%-- TOPBAR --%>
<div class="topbar">
  <div class="tb-logo">AUTO<span>PROD</span></div>
  <div class="tb-sep"></div>
  <div class="tb-title">Analytics Module</div>
  <% if(!"admin".equals(role)){ %>
  <span class="tb-badge stream-<%= anaStream %>">
    <%= "internal".equals(anaStream)?"🏭 INTERNAL STREAM":"external".equals(anaStream)?"📦 EXTERNAL STREAM":"ALL STREAMS" %>
  </span>
  <% } %>
  <div class="tb-right">
    <div class="tb-user"><%= anaName %> <strong style="color:var(--accent);">| ANALYTICS</strong></div>
    <a href="../dashboard.jsp" class="tb-home"><i class="bi bi-grid-1x2-fill"></i> Dashboard</a>
    <a href="<%= ctx %>/logout" class="tb-logout"><i class="bi bi-box-arrow-left"></i> Logout</a>
  </div>
</div>

<div class="layout">

  <%-- SIDEBAR --%>
  <div class="sb1">
    <div class="sb1-head">
      <div class="sb1-head-title">My Work Queue</div>
      <div class="surf-toggle">
        <% if(canSeeInternal){ %>
        <a href="analytics_module.jsp?surface=internal"
           class="st-btn int <%= ("internal".equals(surface)||("landing".equals(surface==null?"landing":""))&&"internal".equals(defaultSurface))?"active":"" %>">
          🏭 INTERNAL
        </a>
        <% } %>
        <% if(canSeeExternal){ %>
        <a href="analytics_module.jsp?surface=external"
           class="st-btn ext <%= "external".equals(surface)?"active":"" %>">
          📦 EXTERNAL
        </a>
        <% } %>
      </div>
    </div>
    <div class="sb1-body">
      <% if(canSeeInternal){ %>
      <div class="sb1-stream">
        <div class="sb1-stream-hd int">
          🏭 Internal Jobs
          <span class="sb1-cnt int"><%= myIntJobs.size() %></span>
        </div>
        <% if(myIntJobs.isEmpty()){ %>
        <div class="sb1-empty">No internal jobs assigned</div>
        <% } else { for(Object[] j:myIntJobs){ int jid=(Integer)j[0];String jref=(String)j[2],jtit=(String)j[3];int jscore=(Integer)j[8];
           boolean isActive=showDetail&&selId==jid&&"internal".equals(selSrc); %>
        <a href="analytics_module.jsp?reqId=<%= jid %>&src=internal"
           class="sb1-item <%= isActive?"active-int":"" %>">
          <span class="si-num int"><%= jref %></span>
          <span class="si-title"><%= jtit %></span>
          <span class="si-score" style="color:var(--muted);">Test: <%= jscore %>%</span>
          <div class="score-bar"><div class="score-fill int" style="width:<%= jscore %>%;"></div></div>
        </a>
        <% } } %>
      </div>
      <% } %>
      <% if(canSeeExternal){ %>
      <div class="sb1-stream">
        <div class="sb1-stream-hd ext">
          📦 External Orders
          <span class="sb1-cnt ext"><%= myExtJobs.size() %></span>
        </div>
        <% if(myExtJobs.isEmpty()){ %>
        <div class="sb1-empty">No external orders assigned</div>
        <% } else { for(Object[] j:myExtJobs){ int jid=(Integer)j[0];String jsrc=(String)j[1],jref=(String)j[2],jtit=(String)j[3];int jscore=(Integer)j[8];
           boolean isActive=showDetail&&selId==jid&&jsrc.equals(selSrc); %>
        <a href="analytics_module.jsp?reqId=<%= jid %>&src=<%= jsrc %>"
           class="sb1-item <%= isActive?"active-ext":"" %>">
          <span class="si-num ext"><%= jref %></span>
          <span class="si-title"><%= jtit %></span>
          <span class="si-score" style="color:var(--muted);">Test: <%= jscore %>%</span>
          <div class="score-bar"><div class="score-fill ext" style="width:<%= jscore %>%;"></div></div>
        </a>
        <% } } %>
      </div>
      <% } %>
    </div>
  </div>

  <%-- MAIN --%>
  <div class="main">
    <div class="main-body">

      <% if(successMsg!=null){ %><div class="alert alert-ok"><i class="bi bi-check-circle-fill"></i> <%= successMsg %></div><% } %>
      <% if(errorMsg!=null){ %><div class="alert alert-err"><i class="bi bi-exclamation-triangle-fill"></i> <%= errorMsg %></div><% } %>

      <%-- ══ LANDING ══ --%>
      <% if(showLanding || (surface==null && reqIdStr==null)){ %>
      <div class="land-wrap">
        <div class="land-title">Analytics Workbench</div>
        <div class="land-sub">Review testing results and submit your market analysis report.</div>
        <div style="text-align:center;">
          <span class="stream-badge <%= "internal".equals(anaStream)?"int":"external".equals(anaStream)?"ext":"both" %>">
            <%= "internal".equals(anaStream)?"🏭 Internal Stream Only":"external".equals(anaStream)?"📦 External Stream Only":"🔀 All Streams (Admin)" %>
          </span>
        </div>

        <%-- KPI Strip --%>
        <%
        int kpiPending=myIntJobs.size()+myExtJobs.size();
        int kpiCompleted=0,kpiTestPass=0,kpiTestTotal=0;
        try(Connection kc=DBConnection.getConnection()){
            if(canSeeInternal){ResultSet kr=kc.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE workflow_stage='analytics_completed'");if(kr.next())kpiCompleted+=kr.getInt(1);}
            if(canSeeExternal){ResultSet kr=kc.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE workflow_stage='analytics_completed'");if(kr.next())kpiCompleted+=kr.getInt(1);ResultSet kr2=kc.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage='analytics_completed'");if(kr2.next())kpiCompleted+=kr2.getInt(1);}
            ResultSet ktr=kc.createStatement().executeQuery("SELECT SUM(CASE WHEN status='pass' THEN 1 ELSE 0 END) AS tp,COUNT(*) AS tt FROM testing_status");
            if(ktr.next()){kpiTestPass=ktr.getInt("tp");kpiTestTotal=ktr.getInt("tt");}
        }catch(Exception ig){}
        int passRate=kpiTestTotal>0?(int)Math.round(kpiTestPass*100.0/kpiTestTotal):0;
        %>
        <div class="kpi-strip" style="margin-bottom:28px;">
          <div class="kpi ka">
            <div class="kpi-l">Pending Analysis</div>
            <div class="kpi-n ka"><%= kpiPending %></div>
            <div class="kpi-s">Jobs awaiting your review</div>
          </div>
          <div class="kpi kg">
            <div class="kpi-l">Completed</div>
            <div class="kpi-n kg"><%= kpiCompleted %></div>
            <div class="kpi-s">Analytics submitted</div>
          </div>
          <div class="kpi kp">
            <div class="kpi-l">Test Pass Rate</div>
            <div class="kpi-n kp"><%= passRate %>%</div>
            <div class="kpi-s"><%= kpiTestPass %> passed of <%= kpiTestTotal %></div>
          </div>
        </div>

        <%-- Stream cards --%>
        <div class="surf-cards <%= (canSeeInternal&&canSeeExternal)?"two":"one" %>">
          <% if(canSeeInternal){ %>
          <a href="analytics_module.jsp?surface=internal" class="surf-card ic">
            <div class="sc-icon">🏭</div>
            <div class="sc-title ic">Internal Jobs</div>
            <div class="sc-desc">Analytics for internally created production orders routed from the testing module.</div>
            <span class="sc-count ic"><%= myIntJobs.size() %> job<%= myIntJobs.size()!=1?"s":"" %> pending</span>
          </a>
          <% } %>
          <% if(canSeeExternal){ %>
          <a href="analytics_module.jsp?surface=external" class="surf-card ec">
            <div class="sc-icon">📦</div>
            <div class="sc-title ec">External & Customer Orders</div>
            <div class="sc-desc">Analytics for bulk client orders and customer requirement submissions.</div>
            <span class="sc-count ec"><%= myExtJobs.size() %> order<%= myExtJobs.size()!=1?"s":"" %> pending</span>
          </a>
          <% } %>
        </div>
      </div>

      <%-- ══ INTERNAL LIST ══ --%>
      <% } else if(showIntList){ %>
      <div class="list-header">
        <a href="analytics_module.jsp" class="lh-back">← Back</a>
        <div class="lh-title int">🏭 Internal Jobs — Analytics Queue</div>
      </div>
      <% if(myIntJobs.isEmpty()){ %>
      <div class="empty-state"><div class="empty-icon">🏭</div><div class="empty-text">No internal jobs in your queue.<br>Jobs appear here after a tester submits a pass result.</div></div>
      <% } else { for(Object[] j:myIntJobs){ int jid=(Integer)j[0];String jref=(String)j[2],jtit=(String)j[3],jvtype=(String)j[4],jbrand=(String)j[5],jdl=(String)j[6];int jscore=(Integer)j[8];String jres=(String)j[9];String sc=jscore>=75?"score-hi":jscore>=50?"score-md":"score-lo"; %>
      <a href="analytics_module.jsp?reqId=<%= jid %>&src=internal" class="job-card ic">
        <div class="jc-icon ic">INT</div>
        <div class="jc-body">
          <div class="jc-num int"><%= jref %></div>
          <div class="jc-title"><%= jtit %></div>
          <div class="jc-meta"><%= jvtype.replace("_"," ").toUpperCase() %> &nbsp;·&nbsp; <%= jbrand %> &nbsp;·&nbsp; Deadline: <%= jdl %></div>
        </div>
        <div class="jc-right">
          <span class="score-pill <%= sc %>"><%= jres %></span>
          <span class="score-pct"><%= jscore %>%</span>
          <div class="score-bar-sm"><div class="score-fill-sm int" style="width:<%= jscore %>%;"></div></div>
        </div>
      </a>
      <% } } %>

      <%-- ══ EXTERNAL LIST ══ --%>
      <% } else if(showExtList){ %>
      <div class="list-header">
        <a href="analytics_module.jsp" class="lh-back">← Back</a>
        <div class="lh-title ext">📦 External & Customer Orders — Analytics Queue</div>
      </div>
      <% if(myExtJobs.isEmpty()){ %>
      <div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">No external orders in your queue.<br>Orders arrive here once testing is completed.</div></div>
      <% } else { for(Object[] j:myExtJobs){ int jid=(Integer)j[0];String jsrc=(String)j[1],jref=(String)j[2],jtit=(String)j[3],jvtype=(String)j[4],jcl=(String)j[5],jdl=(String)j[6];int jscore=(Integer)j[8];String jres=(String)j[9];String sc=jscore>=75?"score-hi":jscore>=50?"score-md":"score-lo"; %>
      <a href="analytics_module.jsp?reqId=<%= jid %>&src=<%= jsrc %>" class="job-card ec">
        <div class="jc-icon ec">EXT</div>
        <div class="jc-body">
          <div class="jc-num ext"><%= jref %> <span style="font-size:9px;background:rgba(0,180,166,.2);color:var(--ext);padding:1px 6px;border-radius:6px;"><%= jsrc.toUpperCase() %></span></div>
          <div class="jc-title"><%= jtit %></div>
          <div class="jc-meta"><%= jvtype.replace("_"," ").toUpperCase() %> &nbsp;·&nbsp; <%= jcl %> &nbsp;·&nbsp; Deadline: <%= jdl %></div>
        </div>
        <div class="jc-right">
          <span class="score-pill <%= sc %>"><%= jres %></span>
          <span class="score-pct"><%= jscore %>%</span>
          <div class="score-bar-sm"><div class="score-fill-sm ext" style="width:<%= jscore %>%;"></div></div>
        </div>
      </a>
      <% } } %>

      <%-- ══ WORKBENCH DETAIL ══ --%>
      <% } else if(showDetail){ %>
      <div class="list-header">
        <a href="analytics_module.jsp?surface=<%= "internal".equals(selSrc)?"internal":"external" %>" class="lh-back">← Back to list</a>
        <div class="lh-title <%= "internal".equals(selSrc)?"int":"ext" %>">
          <%= "internal".equals(selSrc)?"🏭 INTERNAL":"📦 EXTERNAL" %> — Analytics Workbench
        </div>
        <span style="font-size:11px;color:var(--muted);margin-left:auto;"><%= d_ref %></span>
      </div>

      <% if(alreadySubmitted){ %>
      <div class="submitted-banner"><i class="bi bi-check-circle-fill"></i> Analysis already submitted — you can update and resubmit below.</div>
      <% } %>

      <%-- SECTION TABS --%>
      <div class="sec-tabs">
        <button class="sec-tab active" onclick="showSec('overview',this)"><i class="bi bi-info-circle"></i> Overview</button>
        <button class="sec-tab" onclick="showSec('design',this)"><i class="bi bi-pencil-ruler"></i> Design Data</button>
        <button class="sec-tab" onclick="showSec('qc',this)"><i class="bi bi-shield-check"></i> QC Data</button>
        <button class="sec-tab" onclick="showSec('testing',this)"><i class="bi bi-flask-fill"></i> Test Results</button>
        <button class="sec-tab sec-tab-form" onclick="showSec('form',this)"><i class="bi bi-bar-chart-fill"></i> Analytics Form</button>
        <span class="as-status" id="as-status"></span>
      </div>

      <%-- ── SECTION: OVERVIEW ── --%>
      <div id="sec-overview" class="sec-panel">
        <div class="wb-layout3">
          <div class="info-card">
            <div class="ic-head <%= "internal".equals(selSrc)?"int":"ext" %>">
              <i class="bi bi-<%= "internal".equals(selSrc)?"building":"box-seam" %>"></i>
              Job Details
            </div>
            <div class="ic-body">
              <div class="info-row"><span class="ir-l">Reference</span><span class="ir-v" style="color:<%= "internal".equals(selSrc)?"var(--int)":"var(--ext)" %>;"><strong><%= d_ref %></strong></span></div>
              <div class="info-row"><span class="ir-l">Title</span><span class="ir-v"><%= d_title %></span></div>
              <div class="info-row"><span class="ir-l">Vehicle Type</span><span class="ir-v"><%= d_vtype.replace("_"," ").toUpperCase() %></span></div>
              <div class="info-row"><span class="ir-l"><%= "internal".equals(selSrc)?"Brand":"Client" %></span><span class="ir-v"><%= d_client %></span></div>
              <div class="info-row"><span class="ir-l">Deadline</span><span class="ir-v"><%= d_dl %></span></div>
              <div class="info-row"><span class="ir-l">Quantity</span><span class="ir-v"><%= d_qty %></span></div>
              <div class="info-row"><span class="ir-l">Stream</span><span class="ir-v"><span class="stream-tag <%= "internal".equals(selSrc)?"st-int":"st-ext" %>"><%= selSrc.toUpperCase() %></span></span></div>
            </div>
          </div>
          <div class="info-card">
            <div class="ic-head" style="color:var(--purple);"><i class="bi bi-diagram-3-fill"></i> Pipeline Summary</div>
            <div class="ic-body">
              <div class="pipeline-steps">
                <div class="ps done"><div class="ps-dot"><i class="bi bi-check2"></i></div><div class="ps-label">Design</div><div class="ps-sub"><%= ds_designer.equals("—")?"Not loaded":ds_designer %></div></div>
                <div class="ps-line done"></div>
                <div class="ps done"><div class="ps-dot"><i class="bi bi-check2"></i></div><div class="ps-label">QC</div><div class="ps-sub" style="color:<%= "approved".equals(qc_action)?"var(--green)":"qc_conditional".equals(qc_action)?"var(--amber)":"var(--accent2)" %>;"><%= "approved".equals(qc_action)?"Approved":"qc_conditional".equals(qc_action)?"Conditional":qc_action.equals("—")?"Pending":qc_action %></div></div>
                <div class="ps-line done"></div>
                <div class="ps done"><div class="ps-dot"><i class="bi bi-check2"></i></div><div class="ps-label">Testing</div><div class="ps-sub" style="color:<%= d_tres.toLowerCase().contains("pass")?"var(--green)":"var(--accent2)" %>;"><%= d_tres %> (<%= d_tscore %>%)</div></div>
                <div class="ps-line"></div>
                <div class="ps active"><div class="ps-dot"><i class="bi bi-bar-chart-fill"></i></div><div class="ps-label">Analytics</div><div class="ps-sub" style="color:var(--accent);">In Progress</div></div>
              </div>
              <div class="score-summary">
                <div class="ss-item">
                  <div class="ss-label">Test Score</div>
                  <div class="ss-val" style="color:<%= d_tscore>=75?"var(--green)":d_tscore>=50?"var(--amber)":"var(--accent2)" %>;"><%= d_tscore %>%</div>
                  <div class="ss-bar"><div class="ss-fill" style="width:<%= d_tscore %>%;background:<%= d_tscore>=75?"var(--green)":d_tscore>=50?"var(--amber)":"var(--accent2)" %>;"></div></div>
                </div>
                <div class="ss-item">
                  <div class="ss-label">QC Status</div>
                  <div class="ss-val" style="color:<%= "approved".equals(qc_action)?"var(--green)":"qc_conditional".equals(qc_action)?"var(--amber)":"var(--muted)" %>;"><%= "approved".equals(qc_action)?"✓ Approved":"qc_conditional".equals(qc_action)?"⚠ Conditional":qc_action.equals("—")?"Pending":qc_action %></div>
                </div>
                <div class="ss-item">
                  <div class="ss-label">Design Ver.</div>
                  <div class="ss-val" style="color:var(--purple);"><%= ds_version %></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%-- ── SECTION: DESIGN DATA ── --%>
      <div id="sec-design" class="sec-panel" style="display:none;">
        <div class="wb-layout3">
          <div class="info-card">
            <div class="ic-head" style="color:var(--purple);"><i class="bi bi-pencil-ruler"></i> Design Submission</div>
            <div class="ic-body">
              <div class="info-row"><span class="ir-l">Designer</span><span class="ir-v" style="color:var(--purple);"><strong><%= ds_designer %></strong></span></div>
              <div class="info-row"><span class="ir-l">Design Title</span><span class="ir-v"><%= ds_title %></span></div>
              <div class="info-row"><span class="ir-l">Sub-Category</span><span class="ir-v"><%= ds_subcategory %></span></div>
              <div class="info-row"><span class="ir-l">Version</span><span class="ir-v"><span style="background:rgba(124,92,252,.2);color:var(--purple);padding:2px 8px;border-radius:6px;font-size:11px;font-weight:700;"><%= ds_version %></span></span></div>
              <div class="info-row"><span class="ir-l">Engine Type</span><span class="ir-v"><%= ds_engine %></span></div>
            </div>
          </div>
          <div class="info-card">
            <div class="ic-head" style="color:var(--purple);"><i class="bi bi-file-text-fill"></i> Designer Notes</div>
            <div class="ic-body">
              <div class="data-sec-title">Overview</div>
              <div class="data-box"><%= ds_overview.equals("—")?"No overview provided.":ds_overview %></div>
              <div class="data-sec-title" style="margin-top:12px;">Designer Remarks</div>
              <div class="data-box"><%= ds_remarks.equals("—")?"No remarks.":ds_remarks %></div>
            </div>
          </div>
        </div>
      </div>

      <%-- ── SECTION: QC DATA ── --%>
      <div id="sec-qc" class="sec-panel" style="display:none;">
        <div class="wb-layout3">
          <div class="info-card">
            <div class="ic-head" style="color:<%= "approved".equals(qc_action)?"var(--green)":"qc_conditional".equals(qc_action)?"var(--amber)":"var(--accent2)" %>;"><i class="bi bi-shield-check"></i> QC Inspection</div>
            <div class="ic-body">
              <div class="info-row"><span class="ir-l">Inspector</span><span class="ir-v"><strong><%= qc_user %></strong></span></div>
              <div class="info-row"><span class="ir-l">Decision</span>
                <span class="ir-v">
                  <span style="padding:3px 10px;border-radius:8px;font-size:11px;font-weight:700;
                    background:<%= "approved".equals(qc_action)?"rgba(0,230,118,.15)":"qc_conditional".equals(qc_action)?"rgba(255,193,7,.15)":"rgba(255,107,53,.15)" %>;
                    color:<%= "approved".equals(qc_action)?"var(--green)":"qc_conditional".equals(qc_action)?"var(--amber)":"var(--accent2)" %>;">
                    <%= "approved".equals(qc_action)?"✓ APPROVED":"qc_conditional".equals(qc_action)?"⚠ CONDITIONAL":qc_action.equals("—")?"PENDING":qc_action.toUpperCase() %>
                  </span>
                </span>
              </div>
              <div class="info-row"><span class="ir-l">Severity</span>
                <span class="ir-v">
                  <span style="padding:2px 9px;border-radius:6px;font-size:10px;font-weight:700;
                    background:<%= "Critical".equals(qc_severity)?"rgba(255,107,53,.15)":"High".equals(qc_severity)?"rgba(255,193,7,.15)":"rgba(0,230,118,.1)" %>;
                    color:<%= "Critical".equals(qc_severity)?"var(--accent2)":"High".equals(qc_severity)?"var(--amber)":"var(--green)" %>;">
                    <%= qc_severity %>
                  </span>
                </span>
              </div>
            </div>
          </div>
          <div class="info-card">
            <div class="ic-head" style="color:var(--muted);"><i class="bi bi-clipboard2-check-fill"></i> Inspector Notes</div>
            <div class="ic-body">
              <div class="data-box" style="min-height:120px;"><%= qc_notes.equals("—")?"No inspection notes recorded.":qc_notes %></div>
            </div>
          </div>
        </div>
      </div>

      <%-- ── SECTION: TEST RESULTS ── --%>
      <div id="sec-testing" class="sec-panel" style="display:none;">
        <div class="test-results-header">
          <div class="tr-score-circle">
            <svg viewBox="0 0 80 80" width="80" height="80">
              <circle cx="40" cy="40" r="34" fill="none" stroke="var(--border)" stroke-width="7"/>
              <circle cx="40" cy="40" r="34" fill="none"
                stroke="<%= d_tscore>=75?"#00e676":d_tscore>=50?"#ffc107":"#ff6b35" %>"
                stroke-width="7" stroke-linecap="round"
                stroke-dasharray="<%= Math.round(2*Math.PI*34*d_tscore/100.0) %> 213"
                transform="rotate(-90 40 40)"/>
              <text x="40" y="38" text-anchor="middle" font-family="Rajdhani" font-size="16" font-weight="700"
                fill="<%= d_tscore>=75?"#00e676":d_tscore>=50?"#ffc107":"#ff6b35" %>"><%= d_tscore %>%</text>
              <text x="40" y="52" text-anchor="middle" font-family="Exo 2" font-size="8" fill="#5a7090">SCORE</text>
            </svg>
          </div>
          <div class="tr-summary">
            <div class="tr-result" style="color:<%= d_tres.toLowerCase().contains("pass")?"var(--green)":d_tres.toLowerCase().contains("conditional")?"var(--amber)":"var(--accent2)" %>;">
              <%= d_tres %>
            </div>
            <div class="tr-sub">Overall Test Result</div>
            <div class="tr-notes"><%= d_tnotes.length()>180?d_tnotes.substring(0,180)+"…":d_tnotes %></div>
          </div>
        </div>
        <%-- Individual test rows from tests_json --%>
        <div id="test-rows-container">
          <table class="test-data-table">
            <thead>
              <tr>
                <th>#</th><th>Category</th><th>Test Type</th>
                <th>Result</th><th>Score</th><th>Remarks</th>
              </tr>
            </thead>
            <tbody id="test-rows-body">
              <tr><td colspan="6" style="text-align:center;color:var(--muted);padding:18px;font-style:italic;">Loading test data...</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <%-- ── SECTION: ANALYTICS FORM ── --%>
      <div id="sec-form" class="sec-panel" style="display:none;">
        <div class="wb-layout-form">
          <div class="form-card">
            <div class="fc-head"><i class="bi bi-bar-chart-fill"></i> Analytics Assessment
              <span class="as-status-inline" id="as-status-form"></span>
            </div>
            <div class="fc-body">
              <form id="anaForm" method="post" action="<%= ctx %>/jsp/save_analytics_work.jsp">
                <input type="hidden" name="jobId"   value="<%= selId %>">
                <input type="hidden" name="srcType" value="<%= selSrc %>">

                <div class="f-sec">
                  <div class="f-sec-title">Market & Financial Data</div>
                  <div class="fg">
                    <label>Market Segment</label>
                    <input type="text" id="f_market" name="market_segment" class="fc" required placeholder="e.g. Premium SUV, Budget Sedan…" value="<%= ana_market %>">
                  </div>
                  <div class="f-row">
                    <div class="fg"><label>Cost Estimate (₹)</label><input type="number" id="f_cost" name="cost_estimate" class="fc" min="0" step="1000" placeholder="e.g. 2500000" value="<%= (long)ana_cost %>"></div>
                    <div class="fg"><label>Projected Units</label><input type="number" id="f_units" name="projected_units" class="fc" min="0" placeholder="e.g. 500" value="<%= ana_units %>"></div>
                  </div>
                  <div class="fg"><label>Expected ROI (%)</label><input type="number" id="f_roi" name="roi_pct" class="fc" min="-100" max="999" step="0.1" placeholder="e.g. 18.5" value="<%= ana_roi %>"></div>
                </div>

                <div class="f-sec">
                  <div class="f-sec-title">Risk Assessment</div>
                  <input type="hidden" name="risk_level" id="riskInput" value="<%= ana_risk %>">
                  <div class="risk-row">
                    <div class="risk-opt low <%= "Low".equals(ana_risk)?"active":"" %>" onclick="setRisk('Low',this)">🟢 LOW</div>
                    <div class="risk-opt med <%= "Medium".equals(ana_risk)?"active":"" %>" onclick="setRisk('Medium',this)">🟡 MEDIUM</div>
                    <div class="risk-opt hi  <%= "High".equals(ana_risk)?"active":"" %>" onclick="setRisk('High',this)">🔴 HIGH</div>
                  </div>
                </div>

                <div class="f-sec">
                  <div class="f-sec-title">Final Recommendation</div>
                  <input type="hidden" name="recommendation" id="recInput" value="<%= ana_rec %>">
                  <div class="rec-row">
                    <div class="rec-btn approve <%= "Approve".equals(ana_rec)?"active":"" %>"       onclick="setRec('Approve',this)">✅ APPROVE</div>
                    <div class="rec-btn conditional <%= "Conditional".equals(ana_rec)?"active":"" %>" onclick="setRec('Conditional',this)">⚠️ CONDITIONAL</div>
                    <div class="rec-btn reject <%= "Reject".equals(ana_rec)?"active":"" %>"         onclick="setRec('Reject',this)">❌ REJECT</div>
                  </div>
                </div>

                <div class="f-sec">
                  <div class="f-sec-title">Analyst Notes</div>
                  <div class="fg">
                    <textarea id="f_notes" name="analyst_notes" class="fc" rows="7" required placeholder="Market positioning, competitive landscape, production feasibility, risks, and justification for your recommendation…"><%= ana_notes %></textarea>
                  </div>
                </div>

                <button type="submit" class="sub-btn">
                  <%= alreadySubmitted?"⟳ UPDATE & RESUBMIT ANALYSIS":"⟶ SUBMIT ANALYTICS REPORT" %>
                </button>
              </form>
            </div>
          </div>

          <%-- Quick reference panel beside the form --%>
          <div style="display:flex;flex-direction:column;gap:14px;">
            <div class="info-card">
              <div class="ic-head <%= "internal".equals(selSrc)?"int":"ext" %>"><i class="bi bi-bookmark-fill"></i> Quick Ref</div>
              <div class="ic-body">
                <div class="info-row"><span class="ir-l">Job</span><span class="ir-v" style="color:<%= "internal".equals(selSrc)?"var(--int)":"var(--ext)" %>;"><strong><%= d_ref %></strong></span></div>
                <div class="info-row"><span class="ir-l">Vehicle</span><span class="ir-v"><%= d_vtype.replace("_"," ").toUpperCase() %></span></div>
                <div class="info-row"><span class="ir-l">Test</span><span class="ir-v" style="color:<%= d_tscore>=75?"var(--green)":d_tscore>=50?"var(--amber)":"var(--accent2)" %>;"><strong><%= d_tscore %>%</strong></span></div>
                <div class="info-row"><span class="ir-l">QC</span><span class="ir-v" style="color:<%= "approved".equals(qc_action)?"var(--green)":"var(--amber)" %>;"><%= "approved".equals(qc_action)?"✓ Approved":"qc_conditional".equals(qc_action)?"⚠ Conditional":"Pending" %></span></div>
                <div class="info-row"><span class="ir-l">Designer</span><span class="ir-v"><%= ds_designer %></span></div>
              </div>
            </div>
            <div class="info-card">
              <div class="ic-head" style="color:var(--amber);"><i class="bi bi-lightbulb-fill"></i> Analysis Tips</div>
              <div class="ic-body">
                <div class="tip-item"><span class="tip-dot" style="background:var(--green);"></span>Score ≥75% → Strong production candidate</div>
                <div class="tip-item"><span class="tip-dot" style="background:var(--amber);"></span>Score 50–74% → Review before approval</div>
                <div class="tip-item"><span class="tip-dot" style="background:var(--accent2);"></span>Score &lt;50% → High risk, consider rejection</div>
                <div class="tip-item"><span class="tip-dot" style="background:var(--accent);"></span>ROI &gt;15% → Commercially viable</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%-- end showDetail --%>
      <% } %>

    </div><%-- /main-body --%>
  </div><%-- /main --%>
</div><%-- /layout --%>


<script>
function setRec(val,el){document.getElementById('recInput').value=val;document.querySelectorAll('.rec-btn').forEach(b=>b.classList.remove('active'));el.classList.add('active');scheduleAnaSave();}
function setRisk(val,el){document.getElementById('riskInput').value=val;document.querySelectorAll('.risk-opt').forEach(b=>b.classList.remove('active'));el.classList.add('active');scheduleAnaSave();}

/* ── SECTION TABS ── */
function showSec(id, btn){
  document.querySelectorAll('.sec-panel').forEach(function(p){p.style.display='none';});
  document.querySelectorAll('.sec-tab').forEach(function(b){b.classList.remove('active');});
  document.getElementById('sec-'+id).style.display='';
  if(btn) btn.classList.add('active');
  if(id==='testing') renderTestRows();
}

/* ── RENDER TEST ROWS from tests_json ── */
var testsData = [];
(function(){
  var el=document.getElementById('tests-json-data');
  if(el){
    try{
      /* Textarea content is HTML-entity-encoded — decode before parsing */
      var raw = el.value || el.textContent || el.innerText || '[]';
      /* Unescape HTML entities */
      var txt = document.createElement('textarea');
      txt.innerHTML = raw;
      raw = txt.value;
      testsData = JSON.parse(raw);
    }catch(e){ testsData=[]; }
  }
})();

/* Auto-render if testing section is visible on load */
(function(){
  var tp = document.getElementById('sec-testing');
  if(tp && tp.style.display !== 'none') renderTestRows();
})();

function renderTestRows(){
  var tbody = document.getElementById('test-rows-body');
  if(!tbody) return;
  if(!testsData || testsData.length === 0){
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--muted);padding:18px;font-style:italic;">No individual test data recorded.</td></tr>';
    return;
  }
  var html = '';
  testsData.forEach(function(t, i){
    var res = t.result || '—';
    var rc = res==='Pass'?'tr-pass':res==='Fail'?'tr-fail':res==='Conditional'?'tr-cond':'tr-na';
    var sc = parseInt(t.score)||0;
    var barColor = sc>=75?'var(--green)':sc>=50?'var(--amber)':'var(--accent2)';
    html += '<tr>'+
      '<td style="color:var(--muted);font-weight:700;">'+(i+1)+'</td>'+
      '<td style="font-weight:700;">'+esc(t.category||'—')+'</td>'+
      '<td style="color:var(--tst,#f59e0b);">'+esc(t.type||'—')+'</td>'+
      '<td><span class="'+rc+'">'+esc(res)+'</span></td>'+
      '<td>'+
        '<div style="display:flex;align-items:center;gap:8px;">'+
        '<span style="font-weight:700;color:'+barColor+';">'+sc+'</span>'+
        '<div style="flex:1;height:5px;border-radius:3px;background:var(--border);"><div style="width:'+sc+'%;height:100%;border-radius:3px;background:'+barColor+';"></div></div>'+
        '</div>'+
      '</td>'+
      '<td style="color:var(--muted);font-size:11px;">'+esc(t.remarks||'—')+'</td>'+
    '</tr>';
  });
  tbody.innerHTML = html;
}
function esc(s){ return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

/* ── AUTOSAVE (draft to analytics_submissions) ── */
var _anaAS = null;
function scheduleAnaSave(){ clearTimeout(_anaAS); setAnaSt('● Unsaved','#f59e0b'); _anaAS = setTimeout(anaSave, 1200); }
function setAnaSt(msg,col){ ['as-status','as-status-form'].forEach(function(id){ var el=document.getElementById(id); if(el){el.innerHTML=msg;el.style.color=col||'var(--muted)';} }); }

function anaPayload(){
  return {
    jobId:          '<%= selId %>',
    srcType:        '<%= selSrc %>',
    market_segment: document.getElementById('f_market')  ? document.getElementById('f_market').value  : '',
    cost_estimate:  document.getElementById('f_cost')    ? document.getElementById('f_cost').value    : '0',
    projected_units:document.getElementById('f_units')   ? document.getElementById('f_units').value   : '0',
    roi_pct:        document.getElementById('f_roi')     ? document.getElementById('f_roi').value     : '0',
    risk_level:     document.getElementById('riskInput') ? document.getElementById('riskInput').value : 'Low',
    recommendation: document.getElementById('recInput')  ? document.getElementById('recInput').value  : 'Approve',
    analyst_notes:  document.getElementById('f_notes')   ? document.getElementById('f_notes').value   : ''
  };
}

function anaSave(){
  var p = anaPayload();
  if(!p.jobId || p.jobId==='0') return;
  setAnaSt('💾 Saving...','#60a5fa');
  fetch('<%= ctx %>/jsp/save_analytics_draft.jsp',{
    method:'POST',
    headers:{'Content-Type':'application/json;charset=UTF-8'},
    body:JSON.stringify(p)
  }).then(function(r){return r.json();}).then(function(d){
    if(d.success){
      setAnaSt('✓ Draft saved · '+new Date().toLocaleTimeString(),'#4ade80');
      setTimeout(function(){setAnaSt('','var(--muted)');},3000);
    } else {
      setAnaSt('✗ '+(d.error||'Save failed'),'#f87171');
    }
  }).catch(function(){setAnaSt('✗ Network error','#f87171');});
}

/* Attach input listeners for autosave */
['f_market','f_cost','f_units','f_roi','f_notes'].forEach(function(id){
  var el=document.getElementById(id);
  if(el) el.addEventListener('input', scheduleAnaSave);
});

/* Save on page hide */
window.addEventListener('pagehide', function(){
  var p = anaPayload();
  if(p.jobId && p.jobId!=='0' && navigator.sendBeacon){
    navigator.sendBeacon('<%= ctx %>/jsp/save_analytics_draft.jsp',
      new Blob([JSON.stringify(p)],{type:'application/json;charset=UTF-8'}));
  }
});

/* Load draft on open */
(function(){
  var jobId='<%= selId %>';
  var srcType='<%= selSrc %>';
  if(!jobId||jobId==='0') return;
  fetch('<%= ctx %>/jsp/save_analytics_draft.jsp?action=load&jobId='+jobId+'&srcType='+srcType)
  .then(function(r){return r.json();}).then(function(d){
    if(d.success && d.draft){
      var dr=d.draft;
      if(dr.market_segment && !document.getElementById('f_market').value)
        document.getElementById('f_market').value=dr.market_segment;
      if(dr.cost_estimate && !document.getElementById('f_cost').value)
        document.getElementById('f_cost').value=dr.cost_estimate;
      if(dr.projected_units && !document.getElementById('f_units').value)
        document.getElementById('f_units').value=dr.projected_units;
      if(dr.roi_pct && !document.getElementById('f_roi').value)
        document.getElementById('f_roi').value=dr.roi_pct;
      if(dr.analyst_notes && !document.getElementById('f_notes').value)
        document.getElementById('f_notes').value=dr.analyst_notes;
      if(dr.risk_level){ document.getElementById('riskInput').value=dr.risk_level; document.querySelectorAll('.risk-opt').forEach(function(b){b.classList.toggle('active',b.textContent.toUpperCase().includes(dr.risk_level.toUpperCase()));}); }
      if(dr.recommendation){ document.getElementById('recInput').value=dr.recommendation; document.querySelectorAll('.rec-btn').forEach(function(b){b.classList.toggle('active',b.textContent.toUpperCase().includes(dr.recommendation.toUpperCase()));}); }
      setAnaSt('↺ Draft restored','#60a5fa');
      setTimeout(function(){setAnaSt('','var(--muted)');},2500);
    }
  }).catch(function(){});
})();
</script>

<textarea id="tests-json-data" style="display:none;" readonly><%= d_tests_json.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;") %></textarea>
</body>
</html>
