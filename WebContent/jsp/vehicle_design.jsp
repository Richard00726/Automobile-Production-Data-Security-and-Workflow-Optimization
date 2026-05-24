<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*,com.automobile.db.DBConnection,java.util.*" %>
<%
    /* ═══════════════════════════════════════════════
       AUTH GUARD
    ═══════════════════════════════════════════════ */
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect(request.getContextPath() + "/index.jsp"); return;
    }
    String role = (String) sess.getAttribute("role");
    if (!"design".equals(role) && !"admin".equals(role)) {
        response.sendRedirect(request.getContextPath() + "/dashboard.jsp"); return;
    }
    String fullName   = (String) sess.getAttribute("fullName");
    if (fullName == null) fullName = "Designer";
    String loggedUser = (String) sess.getAttribute("username");
    if (loggedUser == null) loggedUser = "";

    // Base URL for all links (servlet URL, not JSP path)
    String BASE = request.getContextPath() + "/vehicle";

    /* ═══════════════════════════════════════════════
       DESIGNER PROFILE — vehicle_type, slot
    ═══════════════════════════════════════════════ */
    String designerVehicleType  = null;
    String designerVehicleLabel = "All Categories";
    int    designerSlot         = 0;
    if (!"admin".equals(role)) {
        try (Connection c = DBConnection.getConnection()) {
            PreparedStatement p = c.prepareStatement(
                "SELECT vehicle_type, slot_number FROM vehicle_designers " +
                "WHERE username=? AND is_active=1 LIMIT 1");
            p.setString(1, loggedUser);
            ResultSet r = p.executeQuery();
            if (r.next()) {
                designerVehicleType  = r.getString("vehicle_type");
                designerSlot         = r.getInt("slot_number");
                if (designerVehicleType != null)
                    designerVehicleLabel = designerVehicleType.replace("_"," ").toUpperCase();
            }
        } catch (Exception e) {}
    }

    /* ═══════════════════════════════════════════════
       URL PARAMETERS
    ═══════════════════════════════════════════════ */
    String surface  = request.getParameter("surface");   // "internal" | "external"
    String reqIdStr = request.getParameter("reqId");
    String source   = request.getParameter("source");    // "internal_job" | null=external

    /* ═══════════════════════════════════════════════
       SIDEBAR 1 DATA — My Assigned Jobs (both streams)
    ═══════════════════════════════════════════════ */
    List<Object[]> myIntJobs = new ArrayList<>();
    List<Object[]> myExtReqs = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        // Internal jobs assigned to me
        String vtF = (designerVehicleType != null && !"admin".equals(role)) ? " AND vehicle_type=?" : "";
        String sql = "admin".equals(role)
            ? "SELECT id,job_number,model_name,vehicle_type,workflow_stage FROM internal_jobs ORDER BY id DESC"
            : "SELECT id,job_number,model_name,vehicle_type,workflow_stage FROM internal_jobs WHERE current_assignee=?" + vtF + " ORDER BY id DESC";
        PreparedStatement ps = conn.prepareStatement(sql);
        int i=1;
        if (!"admin".equals(role)) ps.setString(i++, loggedUser);
        if (designerVehicleType != null && !"admin".equals(role)) ps.setString(i, designerVehicleType);
        ResultSet rs = ps.executeQuery();
        while (rs.next()) {
            myIntJobs.add(new Object[]{
                rs.getInt("id"),
                rs.getString("job_number") != null ? rs.getString("job_number") : "INT-"+rs.getInt("id"),
                rs.getString("model_name") != null ? rs.getString("model_name") : "Job",
                rs.getString("workflow_stage") != null ? rs.getString("workflow_stage") : ""
            });
        }
        // External reqs assigned to me — UNION customer_requirements + external_orders
        String vtF2 = (designerVehicleType != null && !"admin".equals(role)) ? " AND cr.vehicle_type=?" : "";
        String sql2 = "admin".equals(role)
            ? "SELECT cr.id, CAST(cr.req_number AS CHAR) AS req_num_str," +
              " CONVERT(cr.req_title USING utf8mb4) AS req_title," +
              " CONVERT(cr.workflow_stage USING utf8mb4) AS workflow_stage, 'cr' AS src" +
              " FROM customer_requirements cr" +
              " WHERE cr.current_assignee NOT IN ('admin','qc','testing','analytics')" +
              "   AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected')" +
              " UNION ALL" +
              " SELECT eo.id, CONVERT(eo.order_number USING utf8mb4)," +
              " CONVERT(CONCAT(eo.client_name,' - Bulk') USING utf8mb4)," +
              " CONVERT(eo.workflow_stage USING utf8mb4), 'ext'" +
              " FROM external_orders eo WHERE eo.workflow_stage='admin_initial_approved'" +
              " ORDER BY id DESC"
            : "SELECT cr.id, CAST(cr.req_number AS CHAR) AS req_num_str," +
              " CONVERT(cr.req_title USING utf8mb4) AS req_title," +
              " CONVERT(cr.workflow_stage USING utf8mb4) AS workflow_stage, 'cr' AS src" +
              " FROM customer_requirements cr" +
              " WHERE cr.current_assignee=? AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected')" + vtF2 +
              " UNION ALL" +
              " SELECT eo.id, CONVERT(eo.order_number USING utf8mb4)," +
              " CONVERT(CONCAT(eo.client_name,' - Bulk') USING utf8mb4)," +
              " CONVERT(eo.workflow_stage USING utf8mb4), 'ext'" +
              " FROM external_orders eo" +
              " WHERE eo.current_assignee=? AND eo.workflow_stage='admin_initial_approved'" +
              (designerVehicleType != null ? " AND eo.vehicle_type=?" : "") +
              " ORDER BY id DESC";
        PreparedStatement ps2 = conn.prepareStatement(sql2);
        int j=1;
        if (!"admin".equals(role)) {
            ps2.setString(j++, loggedUser);  // for customer_requirements
            if (designerVehicleType != null) ps2.setString(j++, designerVehicleType); // vtF2
            ps2.setString(j++, loggedUser);  // for external_orders
            if (designerVehicleType != null) ps2.setString(j++, designerVehicleType); // ext vehicle_type
        }
        ResultSet rs2 = ps2.executeQuery();
        while (rs2.next()) {
            String src = rs2.getString("src");
            myExtReqs.add(new Object[]{
                rs2.getInt("id"),
                rs2.getString("req_num_str") != null ? rs2.getString("req_num_str") : ("ext".equals(src)?"EXT-":"REQ-")+rs2.getInt("id"),
                rs2.getString("req_title")   != null ? rs2.getString("req_title")   : "Requirement",
                rs2.getString("workflow_stage") != null ? rs2.getString("workflow_stage") : "",
                src  // "cr" or "ext" — used when building the detail link
            });
        }
    } catch (Exception e) {}

    /* ═══════════════════════════════════════════════
       SIDEBAR 2 DATA — Team Members (same vehicle pool)
    ═══════════════════════════════════════════════ */
    List<Object[]> teamMembers = new ArrayList<>();
    String poolType = designerVehicleType != null ? designerVehicleType : "two_wheeler";
    try (Connection conn = DBConnection.getConnection()) {
        PreparedStatement ps = conn.prepareStatement(
            "SELECT vd.slot_number, vd.full_name, vd.username, vd.is_active, u.last_active " +
            "FROM vehicle_designers vd " +
            "LEFT JOIN users u ON CONVERT(vd.username USING utf8mb4)=CONVERT(u.username USING utf8mb4) " +
            "WHERE vd.vehicle_type=? ORDER BY vd.slot_number ASC");
        ps.setString(1, poolType);
        ResultSet rs = ps.executeQuery();
        while (rs.next()) {
            teamMembers.add(new Object[]{
                rs.getInt("slot_number"),
                rs.getString("full_name")  != null ? rs.getString("full_name")  : "",
                rs.getString("username")   != null ? rs.getString("username")   : "",
                rs.getInt("is_active"),
                rs.getTimestamp("last_active")
            });
        }
    } catch (Exception e) {}

    /* ═══════════════════════════════════════════════
       SIDEBAR 3 DATA — Workflow History (internal + external)
    ═══════════════════════════════════════════════ */
    List<Object[]> histInt = new ArrayList<>();
    List<Object[]> histExt = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        // Internal history
        String vtF3 = (designerVehicleType != null && !"admin".equals(role)) ? " AND vehicle_type=?" : "";
        String hsql = "admin".equals(role)
            ? "SELECT job_number,model_name,workflow_stage FROM internal_jobs ORDER BY id DESC LIMIT 30"
            : "SELECT job_number,model_name,workflow_stage FROM internal_jobs WHERE current_assignee=?" + vtF3 + " ORDER BY id DESC LIMIT 30";
        PreparedStatement hps = conn.prepareStatement(hsql);
        int hi=1;
        if (!"admin".equals(role)) hps.setString(hi++, loggedUser);
        if (designerVehicleType != null && !"admin".equals(role)) hps.setString(hi, designerVehicleType);
        ResultSet hrs = hps.executeQuery();
        while (hrs.next()) {
            histInt.add(new Object[]{
                hrs.getString("job_number") != null ? hrs.getString("job_number") : "INT",
                hrs.getString("model_name") != null ? hrs.getString("model_name") : "",
                hrs.getString("workflow_stage") != null ? hrs.getString("workflow_stage") : ""
            });
        }
        // External history — UNION customer_requirements + external_orders
        String vtF4 = (designerVehicleType != null && !"admin".equals(role)) ? " AND cr.vehicle_type=?" : "";
        String esql = "admin".equals(role)
            ? "SELECT CAST(cr.req_number AS CHAR) AS rn," +
              " CONVERT(cr.req_title USING utf8mb4) AS rt," +
              " CONVERT(cr.workflow_stage USING utf8mb4) AS ws" +
              " FROM customer_requirements cr WHERE cr.current_assignee NOT IN ('admin') ORDER BY cr.id DESC LIMIT 30"
            : "SELECT CAST(cr.req_number AS CHAR) AS rn," +
              " CONVERT(cr.req_title USING utf8mb4) AS rt," +
              " CONVERT(cr.workflow_stage USING utf8mb4) AS ws" +
              " FROM customer_requirements cr WHERE cr.current_assignee=?" + vtF4 +
              " UNION ALL" +
              " SELECT CONVERT(eo.order_number USING utf8mb4)," +
              " CONVERT(CONCAT(eo.client_name,' - Bulk Order') USING utf8mb4)," +
              " CONVERT(eo.workflow_stage USING utf8mb4)" +
              " FROM external_orders eo WHERE eo.current_assignee=?" +
              (designerVehicleType != null ? " AND eo.vehicle_type=?" : "") +
              " ORDER BY rn DESC LIMIT 30";
        PreparedStatement eps = conn.prepareStatement(esql);
        int ei=1;
        if (!"admin".equals(role)) {
            eps.setString(ei++, loggedUser);
            if (designerVehicleType != null) eps.setString(ei++, designerVehicleType);
            eps.setString(ei++, loggedUser);
            if (designerVehicleType != null) eps.setString(ei++, designerVehicleType);
        }
        ResultSet ers = eps.executeQuery();
        while (ers.next()) {
            histExt.add(new Object[]{
                ers.getString("rn") != null ? ers.getString("rn") : "REQ",
                ers.getString("rt") != null ? ers.getString("rt") : "",
                ers.getString("ws") != null ? ers.getString("ws") : ""
            });
        }
    } catch (Exception e) {}

    /* ═══════════════════════════════════════════════
       LOAD JOB / REQ DETAIL
    ═══════════════════════════════════════════════ */
    String reqNumber="", clientName="", moduleName="", budget="";
    String deadline="", reqTitle="", reqDesc="", adminNotes="";
    String brandName="", vehicleTypeDetail="", designType="external";
    int    quantityNum = 1;
    boolean reqLoaded = false;
    boolean isInternalJob = false;

    if (reqIdStr != null && !reqIdStr.trim().isEmpty()) {
        if ("internal_job".equals(source)) {
            try (Connection conn = DBConnection.getConnection()) {
                String sql = !"admin".equals(role)
                    ? "SELECT * FROM internal_jobs WHERE id=? AND current_assignee=?"
                    : "SELECT * FROM internal_jobs WHERE id=?";
                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setInt(1, Integer.parseInt(reqIdStr.trim()));
                if (!"admin".equals(role)) ps.setString(2, loggedUser);
                ResultSet rs = ps.executeQuery();
                if (rs.next()) {
                    reqNumber       = rs.getString("job_number")       != null ? rs.getString("job_number")       : "INT-"+reqIdStr;
                    brandName       = rs.getString("brand_name")       != null ? rs.getString("brand_name")       : "";
                    moduleName      = rs.getString("vehicle_category") != null ? rs.getString("vehicle_category") : "";
                    reqTitle        = rs.getString("model_name")       != null ? rs.getString("model_name")       : "";
                    deadline        = rs.getString("target_date")      != null ? rs.getString("target_date")      : "";
                    adminNotes      = rs.getString("admin_notes")      != null ? rs.getString("admin_notes")      : "";
                    vehicleTypeDetail = rs.getString("vehicle_type")   != null ? rs.getString("vehicle_type")     : "";
                    try { quantityNum = rs.getInt("quantity"); } catch(Exception ig){}
                    designType      = "internal";
                    isInternalJob   = true;
                    reqLoaded       = true;
                    surface         = "internal";
                }
            } catch (Exception e) {}
        } else if ("external_order".equals(source)) {
            // ── Load from external_orders table (bulk order) ──
            try (Connection conn = DBConnection.getConnection()) {
                String sql = !"admin".equals(role)
                    ? "SELECT * FROM external_orders WHERE id=? AND current_assignee=?"
                    : "SELECT * FROM external_orders WHERE id=?";
                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setInt(1, Integer.parseInt(reqIdStr.trim()));
                if (!"admin".equals(role)) ps.setString(2, loggedUser);
                ResultSet rs = ps.executeQuery();
                if (rs.next()) {
                    reqNumber         = rs.getString("order_number")         != null ? rs.getString("order_number")         : "EXT-"+reqIdStr;
                    clientName        = rs.getString("client_name")          != null ? rs.getString("client_name")          : "";
                    moduleName        = rs.getString("vehicle_type")         != null ? rs.getString("vehicle_type").replace("_"," ") : "";
                    budget            = rs.getString("budget")               != null ? rs.getString("budget")               : "";
                    deadline          = rs.getString("deadline")             != null ? rs.getString("deadline")             : "";
                    reqTitle          = "Bulk Order: " + reqNumber + " — " + clientName;
                    reqDesc           = rs.getString("special_requirements") != null ? rs.getString("special_requirements") : "";
                    adminNotes        = rs.getString("admin_notes")          != null ? rs.getString("admin_notes")          : "";
                    vehicleTypeDetail = rs.getString("vehicle_type")         != null ? rs.getString("vehicle_type")         : "";
                    try { quantityNum = rs.getInt("quantity"); } catch(Exception ig){}
                    designType        = "external";
                    reqLoaded         = true;
                    surface           = "external";
                }
            } catch (Exception e) {}
        } else {
            try (Connection conn = DBConnection.getConnection()) {
                String sql = !"admin".equals(role)
                    ? "SELECT cr.*,c.full_name AS cname FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id WHERE cr.id=? AND cr.current_assignee=? AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected','submitted')"
                    : "SELECT cr.*,c.full_name AS cname FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id WHERE cr.id=? AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected','submitted')";
                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setInt(1, Integer.parseInt(reqIdStr.trim()));
                if (!"admin".equals(role)) ps.setString(2, loggedUser);
                ResultSet rs = ps.executeQuery();
                if (rs.next()) {
                    reqNumber   = rs.getString("req_number")  != null ? rs.getString("req_number")  : "#"+reqIdStr;
                    clientName  = rs.getString("cname")       != null ? rs.getString("cname")        : rs.getString("client_name") != null ? rs.getString("client_name") : "";
                    moduleName  = rs.getString("module_name") != null ? rs.getString("module_name")  : "";
                    budget      = rs.getString("budget")      != null ? rs.getString("budget")       : "";
                    deadline    = rs.getString("deadline")    != null ? rs.getString("deadline")     : "";
                    reqTitle    = rs.getString("req_title")   != null ? rs.getString("req_title")    : "";
                    reqDesc     = rs.getString("req_desc")    != null ? rs.getString("req_desc")     : "";
                    try { adminNotes      = rs.getString("admin_notes") != null ? rs.getString("admin_notes") : ""; } catch(Exception ig){}
                    try { designType      = rs.getString("design_type") != null ? rs.getString("design_type") : "external"; } catch(Exception ig){}
                    try { brandName       = rs.getString("brand_name")  != null ? rs.getString("brand_name")  : ""; } catch(Exception ig){}
                    try { vehicleTypeDetail = rs.getString("vehicle_type") != null ? rs.getString("vehicle_type") : ""; } catch(Exception ig){}
                    reqLoaded   = true;
                    surface     = designType;
                }
            } catch (Exception e) {}
        }
    }

    // ── Load existing draft if present ──
    String draftJson = "null";
    if (reqLoaded && reqIdStr != null && !reqIdStr.trim().isEmpty()) {
        try (Connection conn = DBConnection.getConnection()) {
            String srcForDraft = (source != null && !source.isEmpty()) ? source : "cr";
            PreparedStatement dq = conn.prepareStatement(
                "SELECT * FROM design_submissions WHERE job_ref_id=? AND designer_username=? AND source_type=? ORDER BY last_saved_at DESC LIMIT 1");
            dq.setInt(1, Integer.parseInt(reqIdStr.trim()));
            dq.setString(2, loggedUser);
            dq.setString(3, srcForDraft);
            ResultSet dr = dq.executeQuery();
            if (dr.next()) {
                StringBuilder sb = new StringBuilder("{");
                String[] cols = {"design_title","design_status","designer_remarks","design_version",
                                 "est_date","sub_category","overview_notes","engine_type","displacement","cylinders",
                                 "max_power","max_torque","transmission","length_mm","width_mm","height_mm",
                                 "wheelbase_mm","kerb_weight_kg","capacity","progress_pct",
                                 "blueprint_file","model_3d_file","extra_files"};
                for (int ci=0; ci<cols.length; ci++) {
                    String val = "";
                    try { val = dr.getString(cols[ci]); if (val == null) val = ""; } catch(Exception ig) {}
                    // Escape for JS string
                    val = val.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","");
                    sb.append("\"").append(cols[ci]).append("\":\"").append(val).append("\"");
                    if (ci < cols.length-1) sb.append(",");
                }
                // parts_checklist and features_checked are JSON strings — add them raw
                String partsRaw = "";
                String featsRaw = "";
                try { partsRaw = dr.getString("parts_checklist"); if(partsRaw==null) partsRaw="[]"; } catch(Exception ig){ partsRaw="[]"; }
                try { featsRaw = dr.getString("features_checked"); if(featsRaw==null) featsRaw="[]"; } catch(Exception ig){ featsRaw="[]"; }
                sb.append(",\"parts_checklist_raw\":").append(partsRaw);
                sb.append(",\"features_checked_raw\":").append(featsRaw);
                sb.append("}");
                draftJson = sb.toString();
            }
        } catch (Exception ig) {}
    }

    // View state
    boolean showLanding  = (reqIdStr == null || reqIdStr.trim().isEmpty()) && surface == null;
    boolean showIntList  = "internal".equals(surface) && !reqLoaded;
    boolean showExtList  = "external".equals(surface) && !reqLoaded;
    boolean showDetail   = reqLoaded;
    boolean isIntDetail  = reqLoaded && "internal".equals(designType);
    String  activeSurf   = surface != null ? surface : "landing";
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>Design Module — AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&family=Exo+2:wght@300;400;500;600&display=swap" rel="stylesheet"/>
<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet"/>
<style>
:root{
  --bg:#0a0e1a; --surface:#0f1623; --card:#151e2d; --border:#1e2d45;
  --accent:#00c8ff; --accent2:#ff6b35; --green:#00e676; --purple:#7c5cfc;
  --ext:#00b4a6; --int:#6c63ff;
  --text:#dde4ef; --muted:#5a7090;
  --SB1:252px; --SB2:220px;
}
*{margin:0;padding:0;box-sizing:border-box;}
html,body{height:100%;overflow:hidden;}
body{background:var(--bg);color:var(--text);font-family:'Exo 2',sans-serif;display:flex;flex-direction:column;}

/* TOPBAR */
.topbar{
  background:linear-gradient(135deg,#0b1628,#101c30);
  border-bottom:2px solid var(--accent);
  padding:10px 18px;
  display:flex;align-items:center;gap:14px;
  flex-shrink:0;
  box-shadow:0 3px 20px rgba(0,200,255,0.12);
  z-index:100;
}
.tb-logo{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;color:var(--accent);letter-spacing:2px;}
.tb-logo span{color:var(--text);}
.tb-sep{width:1px;height:22px;background:var(--border);}
.tb-title{font-family:'Rajdhani',sans-serif;font-size:14px;font-weight:600;color:var(--muted);letter-spacing:1px;text-transform:uppercase;}
.tb-right{margin-left:auto;display:flex;align-items:center;gap:10px;}
.tb-badge{padding:3px 12px;border-radius:16px;font-size:11px;font-weight:700;border:1px solid;}
.tb-badge.cat{color:var(--accent);border-color:var(--accent);background:rgba(0,200,255,0.08);}
.tb-badge.slot{color:var(--purple);border-color:var(--purple);background:rgba(124,92,252,0.1);}
.tb-user{font-size:12px;color:var(--muted);}
.tb-user strong{color:var(--text);}
.tb-logout{font-size:11px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.tb-logout:hover{color:var(--accent2);border-color:var(--accent2);}

/* LAYOUT — 3 columns */
.layout{display:flex;flex:1;overflow:hidden;}

/* ── SIDEBAR 1 ── My Jobs */
.sb1{
  width:0;min-width:0;
  background:var(--surface);border-right:1px solid var(--border);
  display:flex;flex-direction:column;overflow:hidden;
}
.sb1-head{
  padding:12px 14px;border-bottom:1px solid var(--border);
  background:rgba(0,200,255,0.04);flex-shrink:0;
}
.sb1-head-title{font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;margin-bottom:10px;}
.surf-toggle{display:flex;border-radius:10px;overflow:hidden;border:1px solid var(--border);}
.st-btn{
  flex:1;padding:7px 6px;text-align:center;
  font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;letter-spacing:1px;
  text-decoration:none;transition:all .2s;color:var(--muted);
}
.st-btn.int{border-right:1px solid var(--border);}
.st-btn.int.active,.st-btn.int:hover{background:var(--int);color:#fff;}
.st-btn.ext.active,.st-btn.ext:hover{background:var(--ext);color:#fff;}
.sb1-body{flex:1;overflow-y:auto;}
.sb1-stream{border-bottom:1px solid var(--border);}
.sb1-stream-hd{
  padding:8px 14px;display:flex;align-items:center;gap:8px;
  font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1.5px;
  background:rgba(255,255,255,0.02);cursor:default;
}
.sb1-stream-hd.int{color:var(--int);}
.sb1-stream-hd.ext{color:var(--ext);}
.sb1-cnt{margin-left:auto;padding:1px 7px;border-radius:8px;font-size:10px;font-weight:800;}
.sb1-cnt.int{background:rgba(108,99,255,0.2);color:var(--int);}
.sb1-cnt.ext{background:rgba(0,180,166,0.2);color:var(--ext);}
.sb1-item{
  display:flex;flex-direction:column;gap:2px;
  padding:9px 14px 9px 20px;
  border-bottom:1px solid rgba(30,45,69,0.5);
  text-decoration:none;color:var(--muted);
  transition:all .15s;cursor:pointer;
}
.sb1-item:hover{background:rgba(0,200,255,0.04);color:var(--text);}
.sb1-item.active-int{background:rgba(108,99,255,0.08);border-left:3px solid var(--int);color:#b5b0ff;}
.sb1-item.active-ext{background:rgba(0,180,166,0.08);border-left:3px solid var(--ext);color:#5eead4;}
.si-num{font-size:10px;font-weight:700;font-family:'Rajdhani',sans-serif;}
.si-num.int{color:var(--int);}
.si-num.ext{color:var(--ext);}
.si-title{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:210px;}
.si-pct{font-size:10px;margin-top:2px;}
.pct-bar-mini{height:3px;border-radius:2px;background:var(--border);margin-top:3px;}
.pct-fill-mini{height:100%;border-radius:2px;transition:width .3s;}
.pct-fill-mini.int{background:linear-gradient(90deg,var(--int),var(--accent));}
.pct-fill-mini.ext{background:linear-gradient(90deg,var(--ext),var(--green));}
.sb1-empty{padding:14px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;}

/* ── MAIN CONTENT ── */
.main{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.main-progress{
  background:var(--card);border-bottom:1px solid var(--border);
  padding:8px 20px;flex-shrink:0;
}
.prog-track{display:flex;align-items:center;}
.prog-step{flex:1;text-align:center;position:relative;}
.prog-step::after{content:'';position:absolute;top:16px;left:50%;right:-50%;height:2px;background:var(--border);z-index:0;}
.prog-step:last-child::after{display:none;}
.prog-dot{width:32px;height:32px;border-radius:50%;background:var(--surface);border:2px solid var(--border);margin:0 auto 5px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;position:relative;z-index:1;}
.prog-step.done .prog-dot{background:var(--green);border-color:var(--green);color:#000;}
.prog-step.active .prog-dot{background:var(--accent);border-color:var(--accent);color:#000;box-shadow:0 0 10px rgba(0,200,255,0.5);}
.prog-step.done::after{background:var(--green);}
.prog-lbl{font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;}
.prog-step.done .prog-lbl{color:var(--green);}
.prog-step.active .prog-lbl{color:var(--accent);}
.main-body{flex:1;overflow-y:auto;padding:20px 24px;}

/* ── SIDEBAR RIGHT WRAP ── */
.sb-right{
  width:var(--SB2);min-width:var(--SB2);
  background:var(--surface);border-left:1px solid var(--border);
  display:flex;flex-direction:column;overflow:hidden;
}
/* Team section */
.sbr-team{flex:0 0 auto;border-bottom:2px solid var(--border);}
.sbr-head{padding:10px 14px;background:rgba(255,255,255,0.02);border-bottom:1px solid var(--border);}
.sbr-head-title{font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;display:flex;align-items:center;justify-content:space-between;}
.sbr-head-cnt{background:var(--accent);color:#000;border-radius:8px;padding:1px 7px;font-size:9px;font-weight:800;}
.team-scroll{max-height:260px;overflow-y:auto;}
.tm-row{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,0.5);display:flex;align-items:center;gap:9px;}
.tm-av{width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:800;flex-shrink:0;color:#fff;}
.tm-info{flex:1;min-width:0;}
.tm-name{font-size:11px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.tm-sub{font-size:9px;color:var(--muted);display:flex;align-items:center;gap:5px;margin-top:1px;}
.tm-status{display:flex;align-items:center;gap:4px;margin-top:2px;}
.tm-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;}
.tm-stxt{font-size:9px;font-weight:700;}
.tm-you{font-size:8px;padding:1px 5px;border-radius:6px;background:rgba(0,200,255,0.15);color:var(--accent);font-weight:700;flex-shrink:0;}
/* History section */
.sbr-hist{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.hist-tabs{display:flex;border-bottom:1px solid var(--border);flex-shrink:0;}
.hist-tab{flex:1;padding:8px 4px;text-align:center;font-size:9px;font-weight:700;cursor:pointer;color:var(--muted);transition:all .2s;letter-spacing:.5px;text-transform:uppercase;border-bottom:2px solid transparent;margin-bottom:-1px;}
.hist-tab:hover{background:rgba(255,255,255,0.02);}
.hist-tab.ai{color:var(--int);border-color:var(--int);}
.hist-tab.ae{color:var(--ext);border-color:var(--ext);}
.hist-body{flex:1;overflow-y:auto;}
.hist-item{padding:8px 12px;border-bottom:1px solid rgba(30,45,69,0.4);}
.hist-num{font-size:10px;font-weight:700;font-family:'Rajdhani',sans-serif;}
.hist-num.int{color:var(--int);}
.hist-num.ext{color:var(--ext);}
.hist-title{font-size:11px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:190px;margin:2px 0;}
.hist-stage-badge{font-size:9px;font-weight:700;padding:1px 7px;border-radius:6px;display:inline-block;}
.hsb-done{background:rgba(0,230,118,.12);color:var(--green);}
.hsb-prog{background:rgba(0,200,255,.12);color:var(--accent);}
.hsb-pend{background:rgba(255,193,7,.12);color:#ffc107;}
.hist-empty{padding:16px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;}

/* ── LANDING PAGE ── */
.land-wrap{max-width:800px;margin:0 auto;}
.land-title{font-family:'Rajdhani',sans-serif;font-size:26px;font-weight:700;color:var(--accent);letter-spacing:3px;text-transform:uppercase;text-align:center;margin-bottom:6px;}
.land-sub{font-size:13px;color:var(--muted);text-align:center;margin-bottom:24px;}
.land-cat-badge{display:inline-block;padding:5px 18px;border-radius:20px;font-size:12px;font-weight:700;margin-bottom:24px;}
.surf-cards{display:grid;grid-template-columns:1fr 1fr;gap:18px;}
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

/* ── JOB LIST ── */
.list-header{display:flex;align-items:center;gap:12px;margin-bottom:18px;padding-bottom:12px;border-bottom:1px solid var(--border);}
.lh-back{font-size:12px;color:var(--muted);text-decoration:none;padding:4px 10px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.lh-back:hover{color:var(--accent);border-color:var(--accent);}
.lh-title{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;}
.job-card{
  background:var(--card);border:1px solid var(--border);border-radius:12px;
  padding:16px 18px;margin-bottom:10px;
  display:flex;align-items:center;gap:14px;
  text-decoration:none;color:var(--text);transition:all .2s;
}
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
.jc-num.ic{color:var(--int);}
.jc-num.ec{color:var(--ext);}
.jc-title{font-size:14px;font-weight:700;margin-bottom:4px;}
.jc-meta{font-size:11px;color:var(--muted);}
.jc-right{display:flex;flex-direction:column;align-items:flex-end;gap:6px;flex-shrink:0;}
.jc-badge{font-size:10px;font-weight:700;padding:3px 10px;border-radius:14px;white-space:nowrap;}
.b-ready{background:rgba(0,230,118,.1);color:var(--green);}
.b-rework{background:rgba(255,107,53,.1);color:var(--accent2);}
.jc-pct{font-size:11px;font-weight:700;color:var(--accent);}
.pct-bar-sm{width:80px;height:4px;border-radius:2px;background:var(--border);}
.pct-fill-sm{height:100%;border-radius:2px;}
.pct-fill-sm.ic{background:linear-gradient(90deg,var(--int),var(--accent));}
.pct-fill-sm.ec{background:linear-gradient(90deg,var(--ext),var(--green));}
.empty-state{text-align:center;padding:50px 20px;}
.empty-icon{font-size:40px;margin-bottom:12px;opacity:.3;}
.empty-text{color:var(--muted);font-size:13px;}

/* ── DETAIL FORM ── */
.detail-banner{
  display:flex;align-items:center;gap:20px;flex-wrap:wrap;
  padding:12px 18px;margin-bottom:18px;border-radius:10px;border-left:4px solid;
}
.detail-banner.ic{background:rgba(108,99,255,.07);border-color:var(--int);}
.detail-banner.ec{background:rgba(0,180,166,.07);border-color:var(--ext);}
.db-item label{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;display:block;margin-bottom:2px;}
.db-item span{font-size:13px;font-weight:600;}

/* ── PROGRESS TRACKER (inside detail) ── */
.task-progress{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:18px 20px;margin-bottom:18px;}
.tp-title{font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;margin-bottom:14px;display:flex;align-items:center;justify-content:space-between;}
.tp-pct{font-size:20px;font-weight:700;color:var(--accent);}
.tp-bar{height:10px;background:var(--border);border-radius:6px;margin-bottom:12px;overflow:hidden;}
.tp-fill{height:100%;border-radius:6px;background:linear-gradient(90deg,var(--int),var(--accent),var(--green));transition:width .4s;}
.tp-stages{display:flex;gap:8px;flex-wrap:wrap;}
.tp-stage{font-size:10px;font-weight:700;padding:4px 12px;border-radius:20px;cursor:pointer;border:1px solid;transition:all .2s;}
.tp-stage.ns{color:var(--muted);border-color:var(--border);background:transparent;}
.tp-stage.active{color:#ffc107;border-color:#ffc107;background:rgba(255,193,7,.1);}
.tp-stage.done{color:var(--green);border-color:var(--green);background:rgba(0,230,118,.08);}

/* CARD */
.card{background:var(--card);border:1px solid var(--border);border-radius:12px;margin-bottom:16px;}
.card-head{padding:12px 18px;border-bottom:1px solid var(--border);display:flex;align-items:center;gap:10px;background:rgba(255,255,255,0.02);}
.card-head i{color:var(--accent);font-size:13px;}
.card-head h3{font-family:'Rajdhani',sans-serif;font-size:14px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;}
.card-body{padding:18px;}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:18px;}
.fg{margin-bottom:14px;}
.fg:last-child{margin-bottom:0;}
.fg label{display:block;margin-bottom:5px;font-size:10px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:1px;}
.fg label .req{color:var(--accent2);}
.fc{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:8px;padding:9px 12px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;transition:all .2s;outline:none;}
.fc:focus{border-color:var(--accent);background:rgba(0,200,255,.04);box-shadow:0 0 0 3px rgba(0,200,255,.08);}
.fc option{background:var(--surface);}
textarea.fc{resize:vertical;min-height:70px;}
.spec-grid{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:10px;padding:14px;margin-bottom:12px;}
.ftrs-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;}
.ftr{display:flex;align-items:center;gap:7px;padding:8px 10px;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:7px;cursor:pointer;transition:all .2s;}
.ftr:hover{border-color:var(--accent);}
.ftr input[type=checkbox]{accent-color:var(--accent);width:13px;height:13px;}
.ftr label{font-size:11px;color:var(--muted);cursor:pointer;}
.ftr:has(input:checked){border-color:var(--green);background:rgba(0,230,118,.04);}
.ftr:has(input:checked) label{color:var(--green);}
.sec-title{font-family:'Rajdhani',sans-serif;font-size:11px;font-weight:700;color:var(--accent);text-transform:uppercase;letter-spacing:2px;margin:14px 0 10px;display:flex;align-items:center;gap:8px;}
.sec-title::after{content:'';flex:1;height:1px;background:var(--border);}
.chklist{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-bottom:14px;}
.ci{display:flex;align-items:center;gap:7px;padding:8px 10px;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:7px;cursor:pointer;transition:all .2s;user-select:none;}
.ci:hover{border-color:var(--accent);}
.ci-dot{width:9px;height:9px;border-radius:50%;flex-shrink:0;transition:background .2s;}
.ci-dot.ns{background:#3a3a5a;}.ci-dot.ip{background:#ffc107;}.ci-dot.dn{background:var(--green);}.ci-dot.na{background:#2a2a3a;opacity:.4;}
.ci span.ci-name{flex:1;font-size:10.5px;}
.ci .ci-st{font-size:9px;font-weight:700;padding:1px 6px;border-radius:6px;}
.ci .ci-st.ns{background:rgba(80,80,100,.3);color:#666;}
.ci .ci-st.ip{background:rgba(255,193,7,.15);color:#ffc107;}
.ci .ci-st.dn{background:rgba(0,230,118,.12);color:var(--green);}
.ci .ci-st.na{background:rgba(80,80,80,.1);color:#444;}
.ci.state-ip{border-color:#ffc107;}.ci.state-dn{border-color:var(--green);background:rgba(0,230,118,.03);}
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:6px;position:sticky;bottom:0;background:var(--card);padding:12px 0 4px;z-index:10;border-top:1px solid var(--border);}
.btn{padding:10px 24px;border-radius:9px;font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;cursor:pointer;border:none;display:inline-flex;align-items:center;gap:7px;transition:all .2s;text-decoration:none;}
.btn-primary{background:linear-gradient(135deg,var(--accent),#0080aa);color:#000;box-shadow:0 4px 14px rgba(0,200,255,.25);}
.btn-primary:hover{transform:translateY(-2px);}
.btn-success{background:linear-gradient(135deg,var(--green),#009944);color:#000;}
.btn-outline{background:transparent;border:1px solid var(--border);color:var(--muted);}
.btn-outline:hover{border-color:var(--accent);color:var(--accent);}
.note-box{border-radius:9px;padding:12px 16px;margin-bottom:14px;border-left:4px solid;}
.note-box.admin{background:rgba(255,193,7,.05);border-color:#ffc107;}
.note-box.req{background:rgba(0,180,166,.05);border-color:var(--ext);}
.note-box-title{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:1px;margin-bottom:6px;}
.note-box.admin .note-box-title{color:#ffc107;}
.note-box.req .note-box-title{color:var(--ext);}
.note-box-body{font-size:12px;color:var(--text);line-height:1.6;}
/* Color Swatches */
.color-row{display:flex;gap:7px;flex-wrap:wrap;margin-top:5px;}
.col-swatch{width:26px;height:26px;border-radius:50%;cursor:pointer;border:3px solid transparent;transition:all .2s;}
.col-swatch:hover,.col-swatch.sel{border-color:#fff;transform:scale(1.2);}
/* vehicle SVG */
.v-canvas{background:linear-gradient(135deg,#0a1420,#121e2e);border:1px solid var(--border);border-radius:10px;padding:14px;text-align:center;margin-bottom:10px;}
.v-svg{width:100%;max-width:440px;height:150px;display:block;margin:0 auto;}
.vtab-row{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;}
.vtab{padding:5px 14px;border-radius:16px;font-size:11px;font-weight:600;cursor:pointer;border:1px solid var(--border);background:transparent;color:var(--muted);transition:all .2s;font-family:'Exo 2',sans-serif;}
.vtab.active{background:var(--accent);color:#000;border-color:var(--accent);}
</style>
</head>
<body>

<!-- TOPBAR -->
<div class="topbar">
  <div class="tb-logo">AUTO<span>PROD</span></div>
  <div class="tb-sep"></div>
  <div class="tb-title">Design Module</div>
  <% if (!"admin".equals(role) && designerVehicleType != null) { %>
  <span class="tb-badge cat">🏷️ <%= designerVehicleLabel %></span>
  <% if (designerSlot > 0) { %><span class="tb-badge slot">Slot <%= designerSlot %></span><% } %>
  <% } else if (!"admin".equals(role)) { %>
  <span class="tb-badge" style="color:var(--accent2);border-color:var(--accent2);">⚠️ No Category</span>
  <% } %>
  <div class="tb-right">
    <span class="tb-user">👤 <strong><%= fullName %></strong></span>
    <a href="<%= request.getContextPath() %>/logout" class="tb-logout"><i class="fas fa-sign-out-alt"></i> Logout</a>
  </div>
</div>

<div class="layout">

<!-- ══════════════════════════════════
     SIDEBAR 1 — My Assigned Jobs
══════════════════════════════════ -->
<div class="sb1" style="display:none;">
  <div class="sb1-head">
    <div class="sb1-head-title">My Assigned Jobs</div>
    <div class="surf-toggle">
      <a href="<%= BASE %>?surface=internal" class="st-btn int <%= "internal".equals(activeSurf)?"active":"" %>">🏭 INTERNAL</a>
      <a href="<%= BASE %>?surface=external" class="st-btn ext <%= "external".equals(activeSurf)?"active":"" %>">🤝 EXTERNAL</a>
    </div>
  </div>
  <div class="sb1-body">

    <!-- Internal stream -->
    <div class="sb1-stream">
      <div class="sb1-stream-hd int">
        <i class="fas fa-industry" style="font-size:10px;"></i> Internal
        <span class="sb1-cnt int"><%= myIntJobs.size() %></span>
      </div>
      <% if (myIntJobs.isEmpty()) { %>
      <div class="sb1-empty">No internal jobs</div>
      <% } else { for (Object[] j : myIntJobs) {
          int jid = (Integer)j[0]; String jnum=(String)j[1]; String jtitle=(String)j[2]; String jstage=(String)j[3];
          boolean actJ = reqIdStr!=null && reqIdStr.equals(String.valueOf(jid)) && "internal_job".equals(source);
      %>
      <a href="<%= BASE %>?reqId=<%= jid %>&surface=internal&source=internal_job"
         class="sb1-item <%= actJ?"active-int":"" %>">
        <span class="si-num int"><%= jnum %></span>
        <span class="si-title"><%= jtitle %></span>
        <%
          int sideIntPct=0;
          try(java.sql.Connection sc=com.automobile.db.DBConnection.getConnection()){
            java.sql.PreparedStatement sp=sc.prepareStatement(
              "SELECT progress_pct FROM design_submissions WHERE job_ref_id=? AND designer_username=? AND source_type='internal_job' LIMIT 1");
            sp.setInt(1,jid); sp.setString(2,loggedUser);
            java.sql.ResultSet sr=sp.executeQuery(); if(sr.next()) sideIntPct=sr.getInt(1);
          }catch(Exception ig){}
        %>
        <div style="display:flex;align-items:center;gap:5px;">
          <div class="pct-bar-mini" style="flex:1;"><div class="pct-fill-mini int" style="width:<%= sideIntPct %>%"></div></div>
          <span style="font-size:9px;font-weight:700;color:<%= sideIntPct>=100?"var(--green)":sideIntPct>0?"#ffc107":"var(--muted)" %>;min-width:24px;text-align:right;"><%= sideIntPct %>%</span>
        </div>
      </a>
      <% } } %>
    </div>

    <!-- External stream -->
    <div class="sb1-stream">
      <div class="sb1-stream-hd ext">
        <i class="fas fa-handshake" style="font-size:10px;"></i> External
        <span class="sb1-cnt ext"><%= myExtReqs.size() %></span>
      </div>
      <% if (myExtReqs.isEmpty()) { %>
      <div class="sb1-empty">No external requirements</div>
      <% } else { for (Object[] r : myExtReqs) {
          int rid=(Integer)r[0]; String rnum=(String)r[1]; String rtitle=(String)r[2];
          String rsrc = r.length>4 && r[4]!=null ? (String)r[4] : "cr";
          boolean actR = reqIdStr!=null && reqIdStr.equals(String.valueOf(rid)) && !"internal_job".equals(source);
          String extLink = "ext".equals(rsrc)
              ? BASE+"?reqId="+rid+"&surface=external&source=external_order"
              : BASE+"?reqId="+rid+"&surface=external";
      %>
      <a href="<%= extLink %>"
         class="sb1-item <%= actR?"active-ext":"" %>">
        <span class="si-num ext"><%= rnum %></span>
        <span class="si-title"><%= rtitle %></span>
        <%
          int sideExtPct=0;
          try(java.sql.Connection sc2=com.automobile.db.DBConnection.getConnection()){
            String seSrc="ext".equals(rsrc)?"external_order":"cr";
            java.sql.PreparedStatement sp2=sc2.prepareStatement(
              "SELECT progress_pct FROM design_submissions WHERE job_ref_id=? AND designer_username=? AND source_type=? LIMIT 1");
            sp2.setInt(1,rid); sp2.setString(2,loggedUser); sp2.setString(3,seSrc);
            java.sql.ResultSet sr2=sp2.executeQuery(); if(sr2.next()) sideExtPct=sr2.getInt(1);
          }catch(Exception ig){}
        %>
        <div style="display:flex;align-items:center;gap:5px;">
          <div class="pct-bar-mini" style="flex:1;"><div class="pct-fill-mini ext" style="width:<%= sideExtPct %>%"></div></div>
          <span style="font-size:9px;font-weight:700;color:<%= sideExtPct>=100?"var(--green)":sideExtPct>0?"#ffc107":"var(--muted)" %>;min-width:24px;text-align:right;"><%= sideExtPct %>%</span>
        </div>
      </a>
      <% } } %>
    </div>

  </div>
</div><!-- /sb1 -->

<!-- ══════════════════════════════════
     MAIN CONTENT
══════════════════════════════════ -->
<div class="main">

  <!-- Progress Bar -->
  <div class="main-progress">
    <div class="prog-track">
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Request</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Approved</div></div>
      <div class="prog-step active"><div class="prog-dot">3</div><div class="prog-lbl">Design</div></div>
      <div class="prog-step"><div class="prog-dot">4</div><div class="prog-lbl">QC</div></div>
      <div class="prog-step"><div class="prog-dot">5</div><div class="prog-lbl">Testing</div></div>
      <div class="prog-step"><div class="prog-dot">6</div><div class="prog-lbl">Analytics</div></div>
      <div class="prog-step"><div class="prog-dot">7</div><div class="prog-lbl">Final</div></div>
    </div>
  </div>

  <div class="main-body">

  <%-- ════ LANDING PAGE ════ --%>
  <% if (showLanding) { %>
  <div class="land-wrap">
    <div style="text-align:center;margin-bottom:20px;">
      <a href="<%=request.getContextPath()%>/dashboard.jsp" style="display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;margin-bottom:16px;transition:all .2s;" onmouseover="this.style.color='var(--accent)';this.style.borderColor='var(--accent)';" onmouseout="this.style.color='var(--muted)';this.style.borderColor='var(--border)';">
        <i class="fas fa-arrow-left"></i> Back to Dashboard
      </a>
      <div class="land-title">Design Module</div>
      <div class="land-sub">Choose your work stream to begin.</div>
      <% if (!"admin".equals(role) && designerVehicleType != null) { %>
      <span class="land-cat-badge" style="background:rgba(0,200,255,.1);border:1px solid var(--accent);color:var(--accent);">🏷️ Your Category: <%= designerVehicleLabel %> &nbsp;·&nbsp; Slot <%= designerSlot %></span>
      <% } else if (!"admin".equals(role)) { %>
      <span class="land-cat-badge" style="background:rgba(255,107,53,.1);border:1px solid var(--accent2);color:var(--accent2);">⚠️ No vehicle category assigned — contact admin</span>
      <% } %>
    </div>
    <div class="surf-cards">
      <%-- Count for display --%>
      <%
        int intCnt=myIntJobs.size(), extCnt=myExtReqs.size();
      %>
      <a href="<%= BASE %>?surface=internal" class="surf-card ic">
        <div class="sc-icon">🏭</div>
        <div class="sc-title ic">Internal</div>
        <div class="sc-desc">Company manufacturing jobs.<br>KTM · Bajaj · BMW · Tata · Hero · TVS</div>
        <span class="sc-count ic"><%= intCnt %> job<%= intCnt!=1?"s":"" %> assigned</span>
      </a>
      <a href="<%= BASE %>?surface=external" class="surf-card ec">
        <div class="sc-icon">🤝</div>
        <div class="sc-title ec">External</div>
        <div class="sc-desc">Customer-requested designs.<br>Admin-approved requirements for your pool.</div>
        <span class="sc-count ec"><%= extCnt %> req<%= extCnt!=1?"s":"" %> assigned</span>
      </a>
    </div>
  </div>

  <%-- ════ INTERNAL JOB LIST ════ --%>
  <% } else if (showIntList) { %>
  <div class="list-header">
    <a href="<%= BASE %>" class="lh-back">← Back</a>
    <div class="lh-title" style="color:var(--int);">🏭 Internal Manufacturing Jobs</div>
    <% if (designerVehicleType!=null) { %><span style="font-size:11px;color:var(--muted);">— <%= designerVehicleLabel %></span><% } %>
  </div>
  <%
  boolean anyInt=false;
  try (Connection conn=DBConnection.getConnection()) {
      String vtF=(designerVehicleType!=null && !"admin".equals(role))?" AND vehicle_type=?":"";
      String sql="admin".equals(role)
          ?"SELECT * FROM internal_jobs ORDER BY id DESC"
          :"SELECT * FROM internal_jobs WHERE current_assignee=? AND workflow_stage IN ('admin_created','admin_initial_approved')"+vtF+" ORDER BY id DESC";
      PreparedStatement ps=conn.prepareStatement(sql);
      int idx=1;
      if (!"admin".equals(role)) ps.setString(idx++,loggedUser);
      if (designerVehicleType!=null && !"admin".equals(role)) ps.setString(idx,designerVehicleType);
      ResultSet rs=ps.executeQuery();
      while (rs.next()) {
          anyInt=true;
          int jid=rs.getInt("id");
          String jNum=rs.getString("job_number")!=null?rs.getString("job_number"):"INT-"+jid;
          String jBrand=rs.getString("brand_name")!=null?rs.getString("brand_name"):"—";
          String jTitle=rs.getString("model_name")!=null?rs.getString("model_name"):rs.getString("vehicle_category")!=null?rs.getString("vehicle_category"):"Job";
          String jVtype=rs.getString("vehicle_type")!=null?rs.getString("vehicle_type").replace("_"," ").toUpperCase():"";
          String jDead=rs.getString("target_date")!=null?rs.getString("target_date"):"—";
          String jQty=rs.getString("quantity")!=null?rs.getString("quantity"):"1";
          String abbr=jBrand.length()>=3?jBrand.substring(0,3).toUpperCase():jBrand.toUpperCase();
          /* Load saved progress from design_submissions */
          int savedPct=0;
          try {
              PreparedStatement pq=conn.prepareStatement(
                  "SELECT progress_pct FROM design_submissions WHERE job_ref_id=? AND designer_username=? AND source_type='internal_job' ORDER BY last_saved_at DESC LIMIT 1");
              pq.setInt(1,jid); pq.setString(2,loggedUser);
              ResultSet pr=pq.executeQuery();
              if(pr.next()) savedPct=pr.getInt("progress_pct");
          } catch(Exception ig){}
          String pctColor=savedPct>=100?"var(--green)":savedPct>=50?"#ffc107":"var(--accent)";
  %>
  <a href="<%= BASE %>?reqId=<%= jid %>&surface=internal&source=internal_job" class="job-card ic">
    <div class="jc-icon ic"><%= abbr %></div>
    <div class="jc-body">
      <div class="jc-num ic"><%= jNum %> &nbsp;·&nbsp; <span style="color:var(--muted);"><%= jVtype %></span></div>
      <div class="jc-title"><%= jTitle %></div>
      <div class="jc-meta">🏎️ <%= jBrand %> &nbsp;&nbsp; 📦 Qty: <%= jQty %> &nbsp;&nbsp; ⏰ <%= jDead %></div>
    </div>
    <div class="jc-right">
      <span class="jc-badge b-ready">✅ Ready for Design</span>
      <span class="jc-pct" style="color:<%= pctColor %>;"><%= savedPct %>%</span>
      <div class="pct-bar-sm"><div class="pct-fill-sm ic" style="width:<%= savedPct %>%"></div></div>
    </div>
  </a>
  <%  }
      if (!anyInt) { %>
  <div class="empty-state"><div class="empty-icon">🏭</div><p class="empty-text">No internal jobs assigned to you yet.</p></div>
  <%  }
  } catch (Exception e) { %><div style="color:var(--accent2);font-size:12px;padding:12px;">DB Error: <%= e.getMessage() %></div><% } %>

  <%-- ════ EXTERNAL REQ LIST ════ --%>
  <% } else if (showExtList) { %>
  <div class="list-header">
    <a href="<%= BASE %>" class="lh-back">← Back</a>
    <div class="lh-title" style="color:var(--ext);">🤝 Customer Requirements</div>
    <% if (designerVehicleType!=null) { %><span style="font-size:11px;color:var(--muted);">— <%= designerVehicleLabel %></span><% } %>
  </div>
  <%
  boolean anyExt=false;
  try (Connection conn=DBConnection.getConnection()) {
      // customer_requirements (individual + bulk portal submissions)
      String vtF=(designerVehicleType!=null && !"admin".equals(role))?" AND cr.vehicle_type=?":"";
      String sql="admin".equals(role)
          ?"SELECT cr.id, CAST(cr.req_number AS CHAR) AS rnum," +
           " CONVERT(cr.req_title USING utf8mb4) AS req_title," +
           " CONVERT(cr.module_name USING utf8mb4) AS module_name," +
           " CONVERT(cr.budget USING utf8mb4) AS budget," +
           " CONVERT(cr.deadline USING utf8mb4) AS deadline," +
           " CONVERT(cr.workflow_stage USING utf8mb4) AS workflow_stage, 'cr' AS src," +
           " CONVERT(COALESCE(c.full_name,cr.client_name) USING utf8mb4) AS cname," +
           " CONVERT(cr.vehicle_type USING utf8mb4) AS vehicle_type" +
           " FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id" +
           " WHERE cr.current_assignee NOT IN ('admin','qc','testing','analytics')" +
           " AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected')" +
           " UNION ALL" +
           " SELECT eo.id, CONVERT(eo.order_number USING utf8mb4)," +
           " CONVERT(CONCAT(eo.client_name,' - Bulk Order') USING utf8mb4)," +
           " CONVERT(eo.vehicle_type USING utf8mb4)," +
           " CONVERT(COALESCE(eo.budget,'') USING utf8mb4)," +
           " CAST(eo.deadline AS CHAR)," +
           " CONVERT(eo.workflow_stage USING utf8mb4), 'ext'," +
           " CONVERT(eo.client_name USING utf8mb4)," +
           " CONVERT(eo.vehicle_type USING utf8mb4)" +
           " FROM external_orders eo WHERE eo.workflow_stage='admin_initial_approved'" +
           " ORDER BY id DESC"
          :"SELECT cr.id, CAST(cr.req_number AS CHAR) AS rnum," +
           " CONVERT(cr.req_title USING utf8mb4) AS req_title," +
           " CONVERT(cr.module_name USING utf8mb4) AS module_name," +
           " CONVERT(cr.budget USING utf8mb4) AS budget," +
           " CONVERT(cr.deadline USING utf8mb4) AS deadline," +
           " CONVERT(cr.workflow_stage USING utf8mb4) AS workflow_stage, 'cr' AS src," +
           " CONVERT(COALESCE(c.full_name,cr.client_name) USING utf8mb4) AS cname," +
           " CONVERT(cr.vehicle_type USING utf8mb4) AS vehicle_type" +
           " FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id" +
           " WHERE cr.current_assignee=? AND cr.workflow_stage IN ('admin_initial_approved','qc_rejected')"+vtF+
           " UNION ALL" +
           " SELECT eo.id, CONVERT(eo.order_number USING utf8mb4)," +
           " CONVERT(CONCAT(eo.client_name,' - Bulk Order') USING utf8mb4)," +
           " CONVERT(eo.vehicle_type USING utf8mb4)," +
           " CONVERT(COALESCE(eo.budget,'') USING utf8mb4)," +
           " CAST(eo.deadline AS CHAR)," +
           " CONVERT(eo.workflow_stage USING utf8mb4), 'ext'," +
           " CONVERT(eo.client_name USING utf8mb4)," +
           " CONVERT(eo.vehicle_type USING utf8mb4)" +
           " FROM external_orders eo WHERE eo.current_assignee=?" +
           (designerVehicleType!=null ? " AND eo.vehicle_type=?" : "") +
           " ORDER BY id DESC";
      PreparedStatement ps=conn.prepareStatement(sql);
      int idx=1;
      if (!"admin".equals(role)) {
          ps.setString(idx++,loggedUser);
          if (designerVehicleType!=null) ps.setString(idx++,designerVehicleType);
          ps.setString(idx++,loggedUser);
          if (designerVehicleType!=null) ps.setString(idx++,designerVehicleType);
      }
      ResultSet rs=ps.executeQuery();
      while (rs.next()) {
          anyExt=true;
          int rid=rs.getInt("id");
          String rsrc=rs.getString("src");
          String rNum=rs.getString("rnum")!=null?rs.getString("rnum"):("ext".equals(rsrc)?"EXT-":"REQ-")+rid;
          String rTitle=rs.getString("req_title")!=null?rs.getString("req_title"):rs.getString("module_name")!=null?rs.getString("module_name"):"Requirement";
          String rCname=rs.getString("cname")!=null?rs.getString("cname"):"—";
          String rVtype=rs.getString("vehicle_type")!=null?rs.getString("vehicle_type").replace("_"," ").toUpperCase():"";
          String rBudget=rs.getString("budget")!=null?rs.getString("budget"):"—";
          String rDead=rs.getString("deadline")!=null?rs.getString("deadline"):"—";
          boolean isRework="qc_rejected".equals(rs.getString("workflow_stage"));
          String detailLink = "ext".equals(rsrc)
              ? BASE+"?reqId="+rid+"&surface=external&source=external_order"
              : BASE+"?reqId="+rid+"&surface=external";
          String rowIcon = "ext".equals(rsrc) ? "building" : "user";
          String rowBadgeCls = isRework ? "b-rework" : "b-ready";
          String rowLabelIcon = "ext".equals(rsrc) ? "Bulk Order" : (isRework ? "Rework" : "Approved");
          /* Load saved progress */
          int extPct=0;
          try {
              String extSrc="ext".equals(rsrc)?"external_order":"cr";
              PreparedStatement pq=conn.prepareStatement(
                  "SELECT progress_pct FROM design_submissions WHERE job_ref_id=? AND designer_username=? AND source_type=? ORDER BY last_saved_at DESC LIMIT 1");
              pq.setInt(1,rid); pq.setString(2,loggedUser); pq.setString(3,extSrc);
              ResultSet pr=pq.executeQuery();
              if(pr.next()) extPct=pr.getInt("progress_pct");
          } catch(Exception ig){}
          String extPctColor=extPct>=100?"var(--green)":extPct>=50?"#ffc107":"var(--ext)";
      %>
  <a href="<%= detailLink %>" class="job-card ec">
    <div class="jc-icon ec"><i class="fas fa-<%= rowIcon %>" style="font-size:16px;"></i></div>
    <div class="jc-body">
      <div class="jc-num ec"><%= rNum %> &nbsp;·&nbsp; <span style="color:var(--muted);"><%= rVtype %></span></div>
      <div class="jc-title"><%= rTitle %></div>
      <div class="jc-meta">👤 <%= rCname %> &nbsp;&nbsp; 💰 <%= rBudget %> &nbsp;&nbsp; ⏰ <%= rDead %></div>
    </div>
    <div class="jc-right">
      <span class="jc-badge <%= rowBadgeCls %>"><%= rowLabelIcon %></span>
      <span class="jc-pct" style="color:<%= extPctColor %>;"><%= extPct %>%</span>
      <div class="pct-bar-sm"><div class="pct-fill-sm ec" style="width:<%= extPct %>%"></div></div>
    </div>
  </a>
  <%  }
      if (!anyExt) { %>
  <div class="empty-state"><div class="empty-icon">🤝</div><p class="empty-text">No external requirements assigned to you yet.</p></div>
  <%  }
  } catch (Exception e) { %><div style="color:var(--accent2);font-size:12px;padding:12px;">DB Error: <%= e.getMessage() %></div><% } %>

  <%-- ════ DETAIL FORM ════ --%>
  <% } else if (showDetail) { %>

  <!-- Back + surface label -->
  <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px;">
    <a href="<%= BASE %>?surface=<%= isIntDetail?"internal":"external" %>" class="lh-back">← Back to list</a>
    <span style="font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;color:<%= isIntDetail?"var(--int)":"var(--ext)" %>;text-transform:uppercase;letter-spacing:2px;">
      <%= isIntDetail?"🏭 INTERNAL":"🤝 EXTERNAL" %> DESIGN
    </span>
  </div>

  <!-- Top Save Draft bar -->
  <div style="display:flex;align-items:center;justify-content:space-between;background:var(--card);border:1px solid var(--border);border-radius:10px;padding:10px 16px;margin-bottom:14px;">
    <div style="display:flex;align-items:center;gap:8px;">
      <span id="top-progress-pct" style="font-size:22px;font-weight:700;color:var(--accent);">0%</span>
      <div>
        <div style="font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;">Design Progress</div>
        <div style="width:160px;height:6px;background:var(--border);border-radius:4px;margin-top:4px;">
          <div id="top-progress-bar" style="width:0%;height:100%;background:linear-gradient(90deg,var(--int),var(--accent),var(--green));border-radius:4px;transition:width .4s;"></div>
        </div>
      </div>
    </div>
    <div style="display:flex;gap:8px;align-items:center;">
      <span id="top-save-status" style="font-size:11px;color:var(--muted);"></span>
      <button class="btn btn-success" onclick="saveDraft()" style="padding:7px 18px;font-size:12px;"><i class="fas fa-save"></i> Save Draft</button>
    </div>
  </div>

  <!-- Draft restored banner -->
  <div id="draft-restored-banner" style="display:none;background:rgba(0,200,127,.08);border:1px solid rgba(0,200,127,.3);border-radius:10px;padding:10px 16px;margin-bottom:14px;align-items:center;gap:10px;">
    <i class="fas fa-history" style="color:#00c87f;"></i>
    <span style="font-size:12px;color:#00c87f;font-weight:600;">Draft restored — your previous work has been loaded back.</span>
    <button onclick="document.getElementById('draft-restored-banner').style.display='none'" style="margin-left:auto;background:none;border:none;color:#5a7090;cursor:pointer;font-size:14px;">&times;</button>
  </div>
  <div class="detail-banner <%= isIntDetail?"ic":"ec" %>">
    <div class="db-item"><label>Job/Req No.</label><span style="color:var(--accent);"><%= reqNumber %></span></div>
    <div class="db-item"><label><%= isIntDetail?"Brand":"Customer" %></label><span><%= isIntDetail?brandName:clientName %></span></div>
    <div class="db-item"><label>Category</label><span><%= moduleName %></span></div>
    <% if (!isIntDetail && !budget.isEmpty()) { %><div class="db-item"><label>Budget</label><span><%= budget %></span></div><% } %>
    <div class="db-item"><label>Deadline</label><span><%= deadline %></span></div>
    <div class="db-item"><label>Vehicle Type</label><span style="color:<%= isIntDetail?"var(--int)":"var(--ext)" %>"><%= vehicleTypeDetail.replace("_"," ").toUpperCase() %></span></div>
  </div>

  <!-- TASK PROGRESS TRACKER -->
  <div class="task-progress">
    <div class="tp-title">
      Design Completion Progress
      <span class="tp-pct" id="tp-pct">0%</span>
    </div>
    <div class="tp-bar"><div class="tp-fill" id="tp-fill" style="width:0%"></div></div>
    <div class="tp-stages">
      <span class="tp-stage ns" onclick="setStage(0)" id="st0">🔴 Not Started</span>
      <span class="tp-stage ns" onclick="setStage(25)" id="st25">📐 Sketching (25%)</span>
      <span class="tp-stage ns" onclick="setStage(50)" id="st50">🖥️ CAD Design (50%)</span>
      <span class="tp-stage ns" onclick="setStage(75)" id="st75">🔩 Parts Layout (75%)</span>
      <span class="tp-stage ns" onclick="setStage(100)" id="st100">✅ Design Complete (100%)</span>
    </div>
  </div>

  <!-- Notes from Admin/Customer -->
  <% if (adminNotes!=null && !adminNotes.trim().isEmpty()) { %>
  <div class="note-box admin">
    <div class="note-box-title">📌 Admin Instructions</div>
    <div class="note-box-body"><%= adminNotes.replace("\n","<br>") %></div>
  </div>
  <% } %>
  <% if (!isIntDetail && reqDesc!=null && !reqDesc.trim().isEmpty()) { %>
  <div class="note-box req">
    <div class="note-box-title">📋 Customer Requirement Details</div>
    <div class="note-box-body"><%= reqDesc.replace("\n","<br>") %></div>
  </div>
  <% } %>

  <!-- Vehicle Preview + Basic Info -->
  <div class="grid2">
    <div class="card">
      <div class="card-head"><i class="fas fa-car"></i><h3>Vehicle Preview</h3></div>
      <div class="card-body">
        <%
        // Pick preview tab based on vehicle type
        String pvTab = "car";
        if(vehicleTypeDetail.contains("bus"))pvTab="bus";
        else if(vehicleTypeDetail.contains("lorry")||vehicleTypeDetail.contains("heavy"))pvTab="truck";
        else if(vehicleTypeDetail.contains("two_wheeler")||vehicleTypeDetail.contains("three_wheeler"))pvTab="bike";
        %>
        <div class="vtab-row">
          <button class="vtab <%= "car".equals(pvTab)?"active":"" %>" onclick="showV('car',this)">Car/SUV</button>
          <button class="vtab <%= "bus".equals(pvTab)?"active":"" %>" onclick="showV('bus',this)">Bus</button>
          <button class="vtab <%= "truck".equals(pvTab)?"active":"" %>" onclick="showV('truck',this)">Truck</button>
          <button class="vtab <%= "bike".equals(pvTab)?"active":"" %>" onclick="showV('bike',this)">Bike</button>
        </div>
        <div class="v-canvas"><svg id="vsvg" class="v-svg" viewBox="0 0 500 200"></svg></div>
        <div class="fg" style="margin-top:10px;margin-bottom:0;">
          <label>Vehicle Color</label>
          <div class="color-row">
            <div class="col-swatch sel" style="background:#c0392b;" onclick="setColor('#c0392b',this)"></div>
            <div class="col-swatch" style="background:#1a1a2e;" onclick="setColor('#1a1a2e',this)"></div>
            <div class="col-swatch" style="background:#ecf0f1;" onclick="setColor('#ecf0f1',this)"></div>
            <div class="col-swatch" style="background:#2980b9;" onclick="setColor('#2980b9',this)"></div>
            <div class="col-swatch" style="background:#27ae60;" onclick="setColor('#27ae60',this)"></div>
            <div class="col-swatch" style="background:#e67e22;" onclick="setColor('#e67e22',this)"></div>
            <div class="col-swatch" style="background:#8e44ad;" onclick="setColor('#8e44ad',this)"></div>
            <div class="col-swatch" style="background:#7f8c8d;" onclick="setColor('#7f8c8d',this)"></div>
          </div>
        </div>
      </div>
    </div>
    <div class="card">
      <div class="card-head"><i class="fas fa-clipboard-list"></i><h3>Basic Design Info</h3><span id="badge-basic" style="margin-left:auto;font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);">0%</span></div>
      <div class="card-body">
        <div class="fg"><label>Design Title <span class="req">*</span></label><input type="text" class="fc" id="design-title" placeholder="e.g. <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %>-2025-Design"/></div>
        <%
        // Vehicle category options — filtered by designer's vehicle type
        String vt = vehicleTypeDetail.toLowerCase();
        %>
        <div class="fg"><label>Vehicle Sub-Category <span class="req">*</span></label>
          <select class="fc" id="vehicle-subcat">
            <option>-- Select --</option>
            <% if(vt.contains("two_wheeler")){ %>
              <option>Motorcycle (100-150cc)</option><option>Motorcycle (150-250cc)</option>
              <option>Motorcycle (250cc+)</option><option>Scooter (Geared)</option>
              <option>Scooter (Automatic)</option><option>Electric Bike</option><option>Electric Scooter</option>
            <% } else if(vt.contains("three_wheeler")){ %>
              <option>Auto Rickshaw (Petrol)</option><option>Auto Rickshaw (CNG)</option>
              <option>Auto Rickshaw (Electric)</option><option>Cargo 3-Wheeler</option>
              <option>Passenger 3-Wheeler</option>
            <% } else if(vt.contains("car")){ %>
              <option>Hatchback</option><option>Sedan</option><option>SUV</option>
              <option>MUV / MPV</option><option>Coupe</option><option>Crossover</option>
              <option>Electric Car</option><option>Hybrid Car</option>
            <% } else if(vt.contains("van")){ %>
              <option>Mini Van</option><option>Cargo Van</option><option>Passenger Van</option>
              <option>Electric Van</option><option>Refrigerated Van</option>
            <% } else if(vt.contains("bus")){ %>
              <option>Mini Bus (15–30 seats)</option><option>Standard Bus (30–50 seats)</option>
              <option>Large Bus (50+ seats)</option><option>Electric Bus</option>
              <option>School Bus</option><option>Luxury / Sleeper Bus</option><option>Double Decker</option>
            <% } else if(vt.contains("lorry")){ %>
              <option>Light Truck (LCV)</option><option>Medium Truck (MCV)</option>
              <option>Heavy Truck (HCV)</option><option>Tipper / Dump Truck</option>
              <option>Tanker Truck</option><option>Container Truck</option>
            <% } else if(vt.contains("heavy")){ %>
              <option>Tractor</option><option>Excavator / JCB</option><option>Crane</option>
              <option>Bulldozer</option><option>Forklift</option><option>Road Roller</option>
            <% } else if(vt.contains("special")){ %>
              <option>Ambulance</option><option>Fire Truck</option><option>Police Van</option>
              <option>Mobile Hospital</option><option>Armoured Vehicle</option><option>Rescue Vehicle</option>
            <% } else { %>
              <option>Sedan</option><option>SUV</option><option>Bus</option><option>Truck</option><option>Motorcycle</option>
            <% } %>
          </select>
        </div>
        <div class="fg"><label>Design Version</label><input type="text" class="fc" id="design-version" value="v1.0"/></div>
        <div class="fg"><label>Est. Completion Date <span class="req">*</span></label><input type="date" class="fc" id="est-date"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Design Overview Notes</label><textarea class="fc" id="design-overview" placeholder="Brief overview of the design approach..."></textarea></div>
      </div>
    </div>
  </div>

  <%-- ── ENGINE / POWERTRAIN SPECS (vehicle-type aware) ── --%>
  <div class="card">
    <% String vt2 = vehicleTypeDetail.toLowerCase(); %>
    <div class="card-head" style="position:relative;">
      <i class="fas fa-cog"></i>
      <h3>
        <% if(vt2.contains("two_wheeler")||vt2.contains("three_wheeler")){%>Engine & Powertrain — <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %>
        <%}else if(vt2.contains("bus")||vt2.contains("lorry")||vt2.contains("heavy")){%>Engine & Drivetrain — <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %>
        <%}else if(vt2.contains("special")){%>Propulsion System — Special Purpose Vehicle
        <%}else{%>Engine Specifications — <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %><%}%>
      </h3><span id="badge-engine" style="margin-left:auto;font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);">0%</span></div>
    <div class="card-body">
      <div class="spec-grid">
        <div class="fg" style="margin-bottom:0;"><label>Engine Type <span class="req">*</span></label>
          <select class="fc" id="sel-engine-type">
            <option>-- Select --</option>
            <%if(vt2.contains("two_wheeler")){%>
              <option>Single Cylinder (Air Cooled)</option><option>Single Cylinder (Oil Cooled)</option>
              <option>Twin Cylinder</option><option>4-Stroke Petrol</option><option>2-Stroke Petrol</option>
              <option>Electric Motor</option>
            <%}else if(vt2.contains("three_wheeler")){%>
              <option>Single Cylinder Petrol</option><option>Single Cylinder CNG</option>
              <option>Electric Motor</option><option>Diesel</option>
            <%}else if(vt2.contains("bus")||vt2.contains("lorry")){%>
              <option>Diesel (CRDI)</option><option>Diesel (Turbocharged)</option>
              <option>CNG</option><option>LNG</option><option>Hybrid (Diesel+Electric)</option>
              <option>Full Electric</option>
            <%}else if(vt2.contains("heavy")){%>
              <option>Diesel (High Torque)</option><option>Diesel (Turbocharged)</option>
              <option>Electric Motor (Industrial)</option><option>LPG</option>
            <%}else if(vt2.contains("special")){%>
              <option>Petrol</option><option>Diesel</option><option>Hybrid</option><option>Electric Motor</option>
            <%}else{%>
              <option>Petrol (NA)</option><option>Petrol (Turbo)</option>
              <option>Diesel (CRDI)</option><option>Diesel (Turbo)</option>
              <option>Hybrid</option><option>Full Electric</option><option>CNG</option>
            <%}%>
          </select>
        </div>
        <div class="fg" style="margin-bottom:0;">
          <label><% if(vt2.contains("two_wheeler")||vt2.contains("three_wheeler")){%>Displacement (cc)<%}else if(vt2.contains("heavy")){%>Engine Capacity (L)<%}else{%>Displacement (cc)<%}%></label>
          <input type="number" class="fc" id="inp-displacement" placeholder="<%=vt2.contains("two_wheeler")?"e.g. 150":vt2.contains("bus")?"e.g. 5200":"e.g. 1998"%>"/>
        </div>
        <%if(!vt2.contains("heavy")&&!vt2.contains("special")){%>
        <div class="fg" style="margin-bottom:0;"><label>Cylinders</label>
          <select class="fc" id="sel-cylinders">
            <option>-- Select --</option>
            <%if(vt2.contains("two_wheeler")){%><option value="1 (Single)">1 (Single)</option><option value="2 (Parallel Twin)">2 (Parallel Twin)</option><option value="2 (V-Twin)">2 (V-Twin)</option><option value="Electric Motor">Electric Motor</option>
            <%}else if(vt2.contains("bus")||vt2.contains("lorry")){%><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="8">8</option><option value="Electric Motor">Electric Motor</option>
            <%}else{%><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="6 (V6)">6 (V6)</option><option value="8 (V8)">8 (V8)</option><option value="Electric Motor">Electric Motor</option><%}%>
          </select>
        </div>
        <%}%>
      </div>
      <div class="spec-grid" style="margin-bottom:0;">
        <div class="fg" style="margin-bottom:0;"><label>Max Power</label><input type="text" class="fc" id="inp-power" placeholder="<%=vt2.contains("two_wheeler")?"15 PS @ 8500 RPM":vt2.contains("bus")?"280 BHP @ 2200 RPM":"150 BHP @ 6000 RPM"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Max Torque</label><input type="text" class="fc" id="inp-torque" placeholder="<%=vt2.contains("two_wheeler")?"14 Nm @ 6500 RPM":vt2.contains("bus")?"1050 Nm @ 1400 RPM":"250 Nm @ 2000 RPM"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Transmission</label>
          <select class="fc" id="sel-transmission">
            <%if(vt2.contains("two_wheeler")){%><option value="5-Speed Manual">5-Speed Manual</option><option value="6-Speed Manual">6-Speed Manual</option><option value="CVT (Automatic)">CVT (Automatic)</option><option value="Single Speed (EV)">Single Speed (EV)</option>
            <%}else if(vt2.contains("bus")||vt2.contains("lorry")){%><option value="6-Speed Manual">6-Speed Manual</option><option value="8-Speed Manual">8-Speed Manual</option><option value="Automatic">Automatic</option><option value="AMT">AMT</option><option value="Single Speed (EV)">Single Speed (EV)</option>
            <%}else{%><option value="5-Speed Manual">5-Speed Manual</option><option value="6-Speed Manual">6-Speed Manual</option><option value="Automatic">Automatic</option><option value="CVT">CVT</option><option value="DCT">DCT</option><option value="Single Speed (EV)">Single Speed (EV)</option><%}%>
          </select>
        </div>
      </div>
    </div>
  </div>

  <%-- ── DIMENSIONS & CAPACITY ── --%>
  <div class="card">
    <% String vt3 = vehicleTypeDetail.toLowerCase(); %>
    <div class="card-head"><i class="fas fa-ruler-combined"></i><h3>Dimensions & Capacity</h3><span id="badge-dims" style="margin-left:auto;font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);">0%</span></div>
    <div class="card-body">
      <div class="spec-grid">
        <div class="fg" style="margin-bottom:0;"><label>Length (mm)</label><input type="number" class="fc" id="inp-length" placeholder="<%=vt3.contains("two_wheeler")?"2000":vt3.contains("bus")?"10500":vt3.contains("lorry")?"8500":"4200"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Width (mm)</label><input type="number" class="fc" id="inp-width" placeholder="<%=vt3.contains("two_wheeler")?"750":vt3.contains("bus")?"2500":"1800"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Height (mm)</label><input type="number" class="fc" id="inp-height" placeholder="<%=vt3.contains("two_wheeler")?"1100":vt3.contains("bus")?"3200":"1600"%>"/></div>
      </div>
      <div class="spec-grid" style="margin-bottom:0;">
        <div class="fg" style="margin-bottom:0;"><label>Wheelbase (mm)</label><input type="number" class="fc" id="inp-wheelbase" placeholder="<%=vt3.contains("two_wheeler")?"1340":vt3.contains("bus")?"6000":"2600"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>Kerb Weight (kg)</label><input type="number" class="fc" id="inp-weight" placeholder="<%=vt3.contains("two_wheeler")?"145":vt3.contains("bus")?"9500":"1400"%>"/></div>
        <div class="fg" style="margin-bottom:0;"><label>
          <% if(vt3.contains("bus")){%>Passenger Capacity
          <%}else if(vt3.contains("lorry")||vt3.contains("heavy")){%>Payload Capacity (tons)
          <%}else if(vt3.contains("two_wheeler")||vt3.contains("three_wheeler")){%>Rider Capacity
          <%}else{%>Seating Capacity<%}%></label>
          <input type="number" class="fc" id="inp-capacity" placeholder="<%=vt3.contains("bus")?"45":vt3.contains("lorry")?"15":vt3.contains("two_wheeler")?"2":"5"%>"/>
        </div>
      </div>
    </div>
  </div>

  <%-- ── FEATURES & SAFETY (vehicle-type specific) ── --%>
  <div class="card">
    <% String vt4 = vehicleTypeDetail.toLowerCase(); %>
    <div class="card-head"><i class="fas fa-list-check"></i><h3>Features &amp; Safety — <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %></h3><span id="badge-features" style="margin-left:auto;font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);">0%</span></div>
    <div class="card-body">
      <%if(vt4.contains("two_wheeler")||vt4.contains("three_wheeler")){%>
      <div class="sec-title">Safety Systems</div>
      <div class="ftrs-grid" style="margin-bottom:14px;">
        <div class="ftr"><input type="checkbox" id="f1"/><label for="f1">ABS (Anti-lock Braking)</label></div>
        <div class="ftr"><input type="checkbox" id="f2"/><label for="f2">CBS (Combined Braking)</label></div>
        <div class="ftr"><input type="checkbox" id="f3"/><label for="f3">Disc Brake Front</label></div>
        <div class="ftr"><input type="checkbox" id="f4"/><label for="f4">Disc Brake Rear</label></div>
        <div class="ftr"><input type="checkbox" id="f5"/><label for="f5">Traction Control</label></div>
        <div class="ftr"><input type="checkbox" id="f6"/><label for="f6">Side Stand Indicator</label></div>
      </div>
      <div class="sec-title">Electronics & Comfort</div>
      <div class="ftrs-grid">
        <div class="ftr"><input type="checkbox" id="f7" checked/><label for="f7">Digital Instrument Cluster</label></div>
        <div class="ftr"><input type="checkbox" id="f8"/><label for="f8">Bluetooth Connectivity</label></div>
        <div class="ftr"><input type="checkbox" id="f9"/><label for="f9">USB Charging Port</label></div>
        <div class="ftr"><input type="checkbox" id="f10"/><label for="f10">LED Headlamp</label></div>
        <div class="ftr"><input type="checkbox" id="f11"/><label for="f11">LED Tail Light</label></div>
        <div class="ftr"><input type="checkbox" id="f12"/><label for="f12">Turn-by-Turn Navigation</label></div>
      </div>
      <%}else if(vt4.contains("bus")){%>
      <div class="sec-title">Passenger Safety</div>
      <div class="ftrs-grid" style="margin-bottom:14px;">
        <div class="ftr"><input type="checkbox" id="f1" checked/><label for="f1">Emergency Exit Doors</label></div>
        <div class="ftr"><input type="checkbox" id="f2" checked/><label for="f2">Fire Extinguisher</label></div>
        <div class="ftr"><input type="checkbox" id="f3"/><label for="f3">Panic Button System</label></div>
        <div class="ftr"><input type="checkbox" id="f4" checked/><label for="f4">ABS</label></div>
        <div class="ftr"><input type="checkbox" id="f5"/><label for="f5">EBS (Electronic Brake)</label></div>
        <div class="ftr"><input type="checkbox" id="f6"/><label for="f6">Rollover Protection</label></div>
      </div>
      <div class="sec-title">Passenger Comfort</div>
      <div class="ftrs-grid">
        <div class="ftr"><input type="checkbox" id="f7" checked/><label for="f7">Air Conditioning</label></div>
        <div class="ftr"><input type="checkbox" id="f8"/><label for="f8">Reclining Seats</label></div>
        <div class="ftr"><input type="checkbox" id="f9"/><label for="f9">USB Charging at Seats</label></div>
        <div class="ftr"><input type="checkbox" id="f10"/><label for="f10">CCTV / Surveillance</label></div>
        <div class="ftr"><input type="checkbox" id="f11"/><label for="f11">GPS Fleet Tracking</label></div>
        <div class="ftr"><input type="checkbox" id="f12"/><label for="f12">Wheelchair Access Ramp</label></div>
      </div>
      <%}else if(vt4.contains("lorry")||vt4.contains("heavy")){%>
      <div class="sec-title">Safety & Driver Aid</div>
      <div class="ftrs-grid" style="margin-bottom:14px;">
        <div class="ftr"><input type="checkbox" id="f1" checked/><label for="f1">ABS + EBD</label></div>
        <div class="ftr"><input type="checkbox" id="f2"/><label for="f2">Hill Start Assist</label></div>
        <div class="ftr"><input type="checkbox" id="f3"/><label for="f3">Lane Departure Warning</label></div>
        <div class="ftr"><input type="checkbox" id="f4" checked/><label for="f4">Driver Airbag</label></div>
        <div class="ftr"><input type="checkbox" id="f5"/><label for="f5">Blind Spot Monitoring</label></div>
        <div class="ftr"><input type="checkbox" id="f6"/><label for="f6">Collision Warning</label></div>
      </div>
      <div class="sec-title">Utility & Cargo</div>
      <div class="ftrs-grid">
        <div class="ftr"><input type="checkbox" id="f7" checked/><label for="f7">GPS Tracking</label></div>
        <div class="ftr"><input type="checkbox" id="f8"/><label for="f8">Load Sensor / Scale</label></div>
        <div class="ftr"><input type="checkbox" id="f9"/><label for="f9">Refrigerated Cargo Unit</label></div>
        <div class="ftr"><input type="checkbox" id="f10"/><label for="f10">Hydraulic Lift Gate</label></div>
        <div class="ftr"><input type="checkbox" id="f11"/><label for="f11">Reverse Camera</label></div>
        <div class="ftr"><input type="checkbox" id="f12"/><label for="f12">Air Suspension</label></div>
      </div>
      <%}else if(vt4.contains("special")){%>
      <div class="sec-title">Emergency / Special Equipment</div>
      <div class="ftrs-grid" style="margin-bottom:14px;">
        <div class="ftr"><input type="checkbox" id="f1" checked/><label for="f1">Emergency Siren + Beacon</label></div>
        <div class="ftr"><input type="checkbox" id="f2" checked/><label for="f2">High-Visibility Markings</label></div>
        <div class="ftr"><input type="checkbox" id="f3"/><label for="f3">Onboard Medical Equipment</label></div>
        <div class="ftr"><input type="checkbox" id="f4" checked/><label for="f4">Communication Radio</label></div>
        <div class="ftr"><input type="checkbox" id="f5"/><label for="f5">Night Vision System</label></div>
        <div class="ftr"><input type="checkbox" id="f6"/><label for="f6">Armour Plating</label></div>
      </div>
      <div class="sec-title">Crew Safety</div>
      <div class="ftrs-grid">
        <div class="ftr"><input type="checkbox" id="f7" checked/><label for="f7">ABS</label></div>
        <div class="ftr"><input type="checkbox" id="f8"/><label for="f8">Rollover Protection</label></div>
        <div class="ftr"><input type="checkbox" id="f9"/><label for="f9">Fire Suppression System</label></div>
        <div class="ftr"><input type="checkbox" id="f10" checked/><label for="f10">GPS Tracking</label></div>
        <div class="ftr"><input type="checkbox" id="f11"/><label for="f11">CCTV</label></div>
        <div class="ftr"><input type="checkbox" id="f12"/><label for="f12">Run-Flat Tyres</label></div>
      </div>
      <%}else{/* car / van default */
      %>
      <div class="sec-title">Safety</div>
      <div class="ftrs-grid" style="margin-bottom:14px;">
        <div class="ftr"><input type="checkbox" id="f1" checked/><label for="f1">ABS</label></div>
        <div class="ftr"><input type="checkbox" id="f2" checked/><label for="f2">EBD</label></div>
        <div class="ftr"><input type="checkbox" id="f3"/><label for="f3">ESP</label></div>
        <div class="ftr"><input type="checkbox" id="f4" checked/><label for="f4">Front Airbags</label></div>
        <div class="ftr"><input type="checkbox" id="f5"/><label for="f5">Side Airbags</label></div>
        <div class="ftr"><input type="checkbox" id="f6"/><label for="f6">TPMS</label></div>
      </div>
      <div class="sec-title">Comfort</div>
      <div class="ftrs-grid">
        <div class="ftr"><input type="checkbox" id="f7" checked/><label for="f7">Air Conditioning</label></div>
        <div class="ftr"><input type="checkbox" id="f8"/><label for="f8">Climate Control</label></div>
        <div class="ftr"><input type="checkbox" id="f9" checked/><label for="f9">Power Windows</label></div>
        <div class="ftr"><input type="checkbox" id="f10"/><label for="f10">Sunroof</label></div>
        <div class="ftr"><input type="checkbox" id="f11" checked/><label for="f11">Infotainment</label></div>
        <div class="ftr"><input type="checkbox" id="f12"/><label for="f12">GPS Navigation</label></div>
      </div>
      <%}%>
    </div>
  </div>

  <%-- ── PARTS CHECKLIST (vehicle-type specific) ── --%>
  <div class="card">
    <% String vt5 = vehicleTypeDetail.toLowerCase(); %>
    <div class="card-head">
      <i class="fas fa-tasks"></i><h3>Parts Checklist — <%= vehicleTypeDetail.replace("_"," ").toUpperCase() %></h3><span id="badge-parts" style="margin-left:auto;font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);">0%</span>
      <span id="cl-summary" style="margin-left:auto;font-size:10px;color:var(--muted);font-weight:400;"></span>
    </div>
    <div class="card-body">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
        <span style="font-size:10px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;">Checklist Completion</span>
        <span id="cl-pct" style="font-size:13px;font-weight:700;color:var(--accent);">0%</span>
      </div>
      <div style="background:var(--border);border-radius:4px;height:6px;margin-bottom:16px;">
        <div id="cl-bar" style="width:0%;background:linear-gradient(90deg,var(--int),var(--accent),var(--green));height:100%;border-radius:4px;transition:width .4s;"></div>
      </div>

      <%if(vt5.contains("two_wheeler")){%>
      <div class="sec-title"><i class="fas fa-motorcycle" style="color:var(--accent2);"></i> Frame & Body</div>
      <div class="chklist">
        <% for(String p:new String[]{"Main Frame","Sub Frame","Front Fairing","Rear Fairing","Fuel Tank","Seat Unit","Mudguard (Front)","Mudguard (Rear)","Side Panels","Exhaust Heat Shield"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Engine & Drivetrain</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Assembly","Cylinder Block","Crankshaft","Piston & Rings","Carburetor / FI","Air Filter","Exhaust System","Chain Drive / Belt","Gearbox","Kickstarter / E-start"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical & Suspension</div>
      <div class="chklist">
        <% for(String p:new String[]{"Battery / EV Pack","Headlamp (LED)","Tail Lamp","Instrument Cluster","Wiring Harness","Front Fork (Suspension)","Rear Shock Absorber","Front Wheel & Tyre","Rear Wheel & Tyre","Braking System"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else if(vt5.contains("three_wheeler")){%>
      <div class="sec-title"><i class="fas fa-car" style="color:var(--accent2);"></i> Body & Chassis</div>
      <div class="chklist">
        <% for(String p:new String[]{"Main Chassis Frame","Passenger Cabin Body","Hood / Front Cover","Rear Body Panel","Roof Structure","Floor Pan","Driver Seat","Passenger Seats","Grab Rails","Cargo Tray (if applicable)"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Engine & Drivetrain</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Assembly","Fuel System","Exhaust System","Gearbox","Differential","Drive Axle","Wheel Assembly x3","Braking System","Suspension Arms","Steering Mechanism"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical</div>
      <div class="chklist">
        <% for(String p:new String[]{"Battery / EV Pack","Headlamp","Tail Lamp","Instrument Cluster","Wiring Harness","Horn","Indicator Lights","Meter / Fare System","CNG Kit (if applicable)","Charging Port (EV)"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else if(vt5.contains("bus")){%>
      <div class="sec-title"><i class="fas fa-bus" style="color:var(--accent2);"></i> Body & Structure</div>
      <div class="chklist">
        <% for(String p:new String[]{"Monocoque / Ladder Frame","Front Bumper","Rear Bumper","Side Body Panels","Roof Panel","Front Windshield","Side Windows (all)","Emergency Exit Doors","Main Entry Door","Floor Assembly"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Drivetrain & Chassis</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Assembly","Gearbox / Transmission","Prop Shaft","Rear Axle / Drive Axle","Front Axle","Air Suspension (all 4)","ABS Braking System","Air Brake Compressor","Steering Mechanism","Fuel / CNG Tank"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical & Interior</div>
      <div class="chklist">
        <% for(String p:new String[]{"Main Battery Bank","Alternator / Generator","ECU / Body Control Unit","Headlamps","Tail Lamps","Interior Lighting","Passenger Seat Assembly","AC Unit (Roof Mounted)","CCTV System","Infotainment / PA System"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else if(vt5.contains("lorry")||vt5.contains("heavy")){%>
      <div class="sec-title"><i class="fas fa-truck" style="color:var(--accent2);"></i> Chassis & Body</div>
      <div class="chklist">
        <% for(String p:new String[]{"Ladder Chassis Frame","Cab Assembly","Front Bumper","Cabin Doors","Windshield","Cargo Bed / Container Mount","Rear Body Panel","Fuel Tank (large)","Fifth Wheel Coupling","Mudguards (all axles)"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Drivetrain & Axles</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Assembly (HD)","Gearbox (Multi-speed)","Prop Shaft","Front Axle","Rear Drive Axles (tandem)","Air Brake System","Clutch Assembly","Differential (front+rear)","Suspension Springs (all)","Tyre Assembly (all axles)"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical & Cab Interior</div>
      <div class="chklist">
        <% for(String p:new String[]{"Alternator","Battery Banks","ECU / Telematics Unit","Headlamps","Tail & Marker Lamps","Wiring Harness (full)","Driver Instrument Cluster","Air Conditioning (Cab)","GPS / Fleet Tracker","Reverse Camera & Sensors"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else if(vt5.contains("special")){%>
      <div class="sec-title"><i class="fas fa-ambulance" style="color:var(--accent2);"></i> Body & Structure</div>
      <div class="chklist">
        <% for(String p:new String[]{"Vehicle Base Chassis","Custom Body Shell","Emergency Doors (all)","Reinforced Windows","Roof Beacon Mounting","Siren System Mount","External Lighting Rig","High-Vis Body Markings","Compartment Dividers","Equipment Storage Racks"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Drivetrain</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Assembly","Gearbox","4WD System (if req.)","Braking System","Suspension","Steering","Fuel System","Exhaust","Tyres (heavy-duty)","Tow Hook / Winch"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical & Special Systems</div>
      <div class="chklist">
        <% for(String p:new String[]{"Main Battery","Alternator","ECU","Emergency Siren & Beacon","Communication Radio","CCTV / Body Cameras","GPS Tracking","Medical / Special Equipment Wiring","Interior Emergency Lighting","Power Inverter / Generator"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else if(vt5.contains("van")){%>
      <div class="sec-title"><i class="fas fa-shuttle-van" style="color:var(--accent2);"></i> Body & Exterior</div>
      <div class="chklist">
        <% for(String p:new String[]{"Front Bumper","Rear Bumper","Side Sliding Door","Rear Doors","Roof Panel","Side Body Panels","Windshield","Side Windows","Cargo Floor","Load Liner"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Drivetrain</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Block","Gearbox","Driveshaft","Rear Axle","Braking System","Suspension (all)","Steering","Fuel Tank","Exhaust","Tyres"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical</div>
      <div class="chklist">
        <% for(String p:new String[]{"Battery / EV Pack","Alternator","ECU","Headlamps","Tail Lamps","Interior Lighting","Wiring Harness","Instrument Cluster","Infotainment","Reverse Camera"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>

      <%}else{/* car default */
      %>
      <div class="sec-title"><i class="fas fa-car" style="color:var(--accent2);"></i> Body &amp; Exterior</div>
      <div class="chklist">
        <% for(String p:new String[]{"Front Bumper","Rear Bumper","Hood/Bonnet","Doors","Roof Panel","Side Skirts","Fenders","Trunk Lid","Windows","Windshield"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-cog" style="color:var(--accent);"></i> Engine &amp; Drivetrain</div>
      <div class="chklist">
        <% for(String p:new String[]{"Engine Block","Cylinder Head","Crankshaft","Camshaft","Pistons","Fuel Injectors","Exhaust","Gearbox","Driveshaft","Differential"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <div class="sec-title"><i class="fas fa-bolt" style="color:#ffc107;"></i> Electrical</div>
      <div class="chklist">
        <% for(String p:new String[]{"Battery/EV Pack","Alternator","Starter Motor","ECU","Wiring Harness","Fuse Box","Headlights","Tail Lights","Instrument Cluster","Infotainment System"}){ %>
        <div class="ci" onclick="cycleCI(this)"><span class="ci-dot ns"></span><span class="ci-name"><%= p %></span><span class="ci-st ns">Not Started</span></div>
        <% } %>
      </div>
      <%}%>
    </div>
  </div>

  <!-- Remarks + Submit -->
  <div class="card">
    <div class="card-head"><i class="fas fa-paper-plane"></i><h3>Remarks &amp; Submit</h3></div>
    <div class="card-body">
      <div class="grid2">
        <div>
          <div class="fg"><label>Design Status <span class="req">*</span></label>
            <select class="fc" id="design-status">
              <option>In Progress</option>
              <option>Design Complete — Ready for QC</option>
              <option>On Hold</option>
              <option>Revision Required</option>
            </select></div>
          <div class="fg" style="margin-bottom:0;"><label>Designer Remarks <span class="req">*</span></label>
            <textarea class="fc" id="designer-remarks" style="min-height:90px;" placeholder="Design decisions, challenges, completion notes..."></textarea></div>
        </div>
        <div>
          <div class="fg"><label>Design Blueprint / CAD File</label><input type="file" class="fc" id="file-blueprint" accept=".pdf,.dwg,.png,.jpg,.zip"/></div>
          <div class="fg"><label>3D Model (Optional)</label><input type="file" class="fc" id="file-3d" accept=".obj,.stl,.fbx,.zip"/></div>
          <div class="fg" style="margin-bottom:0;"><label>Additional Documents</label><input type="file" class="fc" id="file-docs" multiple/></div>
        </div>
      </div>
      <div class="actions" style="margin-top:14px;">
        <button class="btn btn-primary" onclick="submitToQC()"><i class="fas fa-paper-plane"></i> Submit to QC</button>
        <button class="btn btn-outline" onclick="window.print()"><i class="fas fa-print"></i> Export PDF</button>
        <a href="<%= BASE %>?surface=<%= isIntDetail?"internal":"external" %>" class="btn btn-outline"><i class="fas fa-arrow-left"></i> Back</a>
      </div>
    </div>
  </div>
  <% } %>
  </div><!-- /main-body -->
</div><!-- /main -->

<!-- ══════════════════════════════════
     SIDEBAR RIGHT — Team + History
══════════════════════════════════ -->
<div class="sb-right">

  <!-- TEAM MEMBERS -->
  <div class="sbr-team">
    <div class="sbr-head">
      <div class="sbr-head-title">
        👥 <%= designerVehicleLabel %> Team
        <span class="sbr-head-cnt"><%= teamMembers.size() %></span>
      </div>
    </div>
    <div class="team-scroll">
      <% if (teamMembers.isEmpty()) { %>
      <div style="padding:14px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;">No team members</div>
      <% } else { for (Object[] tm : teamMembers) {
          int tmSlot=(Integer)tm[0];
          String tmName=(String)tm[1];
          String tmUser=(String)tm[2];
          int tmActive=(Integer)tm[3];
          java.sql.Timestamp tmLast=(java.sql.Timestamp)tm[4];
          String dotC="#3a3a5a"; String stTxt="Offline"; String stCol="#5a7090";
          if (tmLast!=null) {
              long diff=(System.currentTimeMillis()-tmLast.getTime())/60000L;
              if (diff<=5){dotC="#22c55e";stTxt="Online";stCol="#22c55e";}
              else if(diff<=30){dotC="#f59e0b";stTxt="Away "+diff+"m";stCol="#f59e0b";}
          }
          boolean isMe=tmUser.equals(loggedUser);
          String[] np=tmName.split(" ");
          String ini="";
          for(String n:np) if(!n.isEmpty()) ini+=n.charAt(0);
          if(ini.length()>2) ini=ini.substring(0,2);
          String avBg=isMe?"linear-gradient(135deg,var(--accent),#0088bb)":
                       (tmSlot==1?"linear-gradient(135deg,#6c63ff,#4f46e5)":
                        tmSlot==2?"linear-gradient(135deg,#00b4a6,#008c84)":
                                  "linear-gradient(135deg,#f59e0b,#b45309)");
      %>
      <div class="tm-row">
        <div class="tm-av" style="background:<%= avBg %>;"><%= ini.toUpperCase() %></div>
        <div class="tm-info">
          <div class="tm-name"><%= tmName %> <% if(isMe){%><span class="tm-you">YOU</span><%}%></div>
          <div class="tm-sub">@<%= tmUser %> &nbsp;·&nbsp; <span style="color:var(--purple);font-weight:700;">Slot <%= tmSlot %></span></div>
          <div class="tm-status"><span class="tm-dot" style="background:<%= dotC %>;"></span><span class="tm-stxt" style="color:<%= stCol %>;"><%= stTxt %></span></div>
        </div>
      </div>
      <% } } %>
    </div>
  </div>

  <!-- WORKFLOW HISTORY -->
  <div class="sbr-hist">
    <div style="padding:8px 14px;background:rgba(255,255,255,.02);border-bottom:1px solid var(--border);flex-shrink:0;">
      <div style="font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;">Workflow History</div>
    </div>
    <div class="hist-tabs">
      <div class="hist-tab ai" id="ht-int" onclick="switchHist('int',this)">🏭 Internal (<%= histInt.size() %>)</div>
      <div class="hist-tab" id="ht-ext" onclick="switchHist('ext',this)">🤝 External (<%= histExt.size() %>)</div>
    </div>
    <div class="hist-body">
      <!-- Internal -->
      <div id="hbody-int">
        <% if(histInt.isEmpty()){ %><div class="hist-empty">No internal history</div>
        <% } else { for(Object[] h:histInt){
            String hn=(String)h[0]; String ht=(String)h[1]; String hs=(String)h[2];
            String sc=hs.contains("complete")||hs.contains("approved")||hs.contains("done")?"hsb-done":hs.contains("progress")||hs.contains("created")?"hsb-prog":"hsb-pend";
        %>
        <div class="hist-item">
          <div class="hist-num int"><%= hn %></div>
          <div class="hist-title"><%= ht %></div>
          <span class="hist-stage-badge <%= sc %>"><%= hs.replace("_"," ").toUpperCase() %></span>
        </div>
        <% } } %>
      </div>
      <!-- External -->
      <div id="hbody-ext" style="display:none;">
        <% if(histExt.isEmpty()){ %><div class="hist-empty">No external history</div>
        <% } else { for(Object[] h:histExt){
            String hn=(String)h[0]; String ht=(String)h[1]; String hs=(String)h[2];
            String sc=hs.contains("complete")||hs.contains("approved")||hs.contains("done")?"hsb-done":hs.contains("progress")||hs.contains("created")?"hsb-prog":"hsb-pend";
        %>
        <div class="hist-item">
          <div class="hist-num ext"><%= hn %></div>
          <div class="hist-title"><%= ht %></div>
          <span class="hist-stage-badge <%= sc %>"><%= hs.replace("_"," ").toUpperCase() %></span>
        </div>
        <% } } %>
      </div>
    </div>
  </div>

</div><!-- /sb-right -->

</div><!-- /layout -->

<script>
/* ══════════════════════════════════════════════
   VEHICLE DESIGN MODULE — CLEAN JS
   Order: ciStates → setStage → updateChecklist
          → cycleCI → restoreDraft → save/submit
   ══════════════════════════════════════════════ */

var SAVED_DRAFT = <%= draftJson %>;

/* ── 1. State definitions ── */
var ciStates=[
  {key:'ns',dot:'ns',label:'Not Started',cls:'ns'},
  {key:'ip',dot:'ip',label:'In Progress',cls:'ip'},
  {key:'dn',dot:'dn',label:'Completed',  cls:'dn'},
  {key:'na',dot:'na',label:'N/A',        cls:'na'}
];

/* ── 2. Apply progress to all bars ── */
var curStage=0;
function applyProgress(pct){
  pct=Math.min(100,Math.max(0,parseInt(pct)||0));
  curStage=pct;
  /* Main tracker bar */
  var fill=document.getElementById('tp-fill');
  var lbl =document.getElementById('tp-pct');
  if(fill) fill.style.width=pct+'%';
  if(lbl)  lbl.textContent=pct+'%';
  /* Top bar */
  var topBar=document.getElementById('top-progress-bar');
  var topPct=document.getElementById('top-progress-pct');
  if(topBar) topBar.style.width=pct+'%';
  if(topPct) topPct.textContent=pct+'%';

  /* Stage pills — find which milestone we are AT or moving toward */
  var milestones=[0,25,50,75,100];
  /* currentMilestone = highest milestone that pct has reached */
  var reached=-1;
  milestones.forEach(function(v){ if(pct>=v) reached=v; });

  milestones.forEach(function(v){
    var el=document.getElementById('st'+v); if(!el) return;
    if(v<reached){
      /* fully passed — green done */
      el.className='tp-stage done';
      el.style.color='var(--green)';
      el.style.borderColor='var(--green)';
      el.style.background='rgba(0,230,118,.08)';
    } else if(v===reached){
      /* current milestone — highlighted by stage */
      var stageColors=[
        {c:'#9b59b6',bg:'rgba(155,89,182,.12)'},  /* 0 — not started purple */
        {c:'#3498db',bg:'rgba(52,152,219,.12)'},   /* 25 — sketching blue */
        {c:'#e67e22',bg:'rgba(230,126,34,.12)'},   /* 50 — CAD orange */
        {c:'#e74c3c',bg:'rgba(231,76,60,.12)'},    /* 75 — parts red */
        {c:'#00e676',bg:'rgba(0,230,118,.15)'}     /* 100 — complete green */
      ];
      var idx=milestones.indexOf(v);
      var sc=stageColors[idx]||stageColors[0];
      el.className='tp-stage active';
      el.style.color=sc.c;
      el.style.borderColor=sc.c;
      el.style.background=sc.bg;
    } else {
      /* upcoming — grey */
      el.className='tp-stage ns';
      el.style.color='';
      el.style.borderColor='';
      el.style.background='';
    }
  });
}
/* Keep setStage as alias so manual clicks still work */
function setStage(pct){ applyProgress(pct); }

/* ── 3. Section badges — show each card's fill level ── */
function updateSectionBadge(badgeId, pct){
  var el=document.getElementById(badgeId);
  if(!el) return;
  el.textContent=pct+'%';
  el.style.background=pct===100?'rgba(0,230,118,.15)':pct>0?'rgba(255,193,7,.12)':'rgba(80,80,100,.2)';
  el.style.color=pct===100?'var(--green)':pct>0?'#ffc107':'var(--muted)';
}

/* ── 4. Master progress calculator ── */
function calcOverallProgress(){
  var score=0;

  /* === SECTION 1: Basic Design Info — 20 points === */
  var basicScore=0;
  var title=document.getElementById('design-title');
  var subcat=document.getElementById('vehicle-subcat');
  var estDate=document.getElementById('est-date');
  var version=document.getElementById('design-version');
  if(title&&title.value.trim().length>0)   basicScore+=7;
  if(subcat&&subcat.value!=='-- Select --'&&subcat.value!=='')  basicScore+=6;
  if(estDate&&estDate.value.trim().length>0) basicScore+=5;
  if(version&&version.value.trim().length>0) basicScore+=2;
  score+=basicScore;
  updateSectionBadge('badge-basic', Math.round((basicScore/20)*100));

  /* === SECTION 2: Engine Specifications — 20 points === */
  var engScore=0;
  var eng=document.getElementById('sel-engine-type');
  var disp=document.getElementById('inp-displacement');
  var cyl=document.getElementById('sel-cylinders');
  var pwr=document.getElementById('inp-power');
  var tor=document.getElementById('inp-torque');
  var trans=document.getElementById('sel-transmission');
  if(eng&&eng.value&&eng.value!=='-- Select --')   engScore+=5;
  if(disp&&disp.value.trim().length>0)             engScore+=4;
  if(cyl&&cyl.value&&cyl.value!=='-- Select --')   engScore+=3;
  if(pwr&&pwr.value.trim().length>0)               engScore+=4;
  if(tor&&tor.value.trim().length>0)               engScore+=2;
  if(trans&&trans.value&&trans.value.length>0)     engScore+=2;
  score+=engScore;
  updateSectionBadge('badge-engine', Math.round((engScore/20)*100));

  /* === SECTION 3: Dimensions — 15 points === */
  var dimScore=0;
  var dimIds=['inp-length','inp-width','inp-height','inp-wheelbase','inp-weight','inp-capacity'];
  var dimPts=[4,3,2,2,2,2];
  dimIds.forEach(function(id,i){
    var el=document.getElementById(id);
    if(el&&el.value.trim().length>0) dimScore+=dimPts[i];
  });
  score+=dimScore;
  updateSectionBadge('badge-dims', Math.round((dimScore/15)*100));

  /* === SECTION 4: Features & Safety — 10 points === */
  var featScore=0;
  var cbs=document.querySelectorAll('.ftr input[type="checkbox"]');
  var checked=0;
  cbs.forEach(function(cb){if(cb.checked)checked++;});
  if(cbs.length>0) featScore=Math.round((checked/cbs.length)*10);
  score+=featScore;
  updateSectionBadge('badge-features', Math.round((featScore/10)*100));

  /* === SECTION 5: Parts Checklist — 35 points === */
  var items=document.querySelectorAll('.ci');
  var total=items.length, done=0, inprog=0;
  items.forEach(function(el){
    var dot=el.querySelector('.ci-dot');
    if(!dot) return;
    if(dot.classList.contains('dn')) done++;
    else if(dot.classList.contains('ip')) inprog++;
  });
  var partsPct=total>0?Math.round((done/total)*100):0;
  var partScore=total>0?Math.round((done/total)*35):0;
  score+=partScore;
  /* Update checklist bar */
  var bar=document.getElementById('cl-bar');
  var pctEl=document.getElementById('cl-pct');
  var sumEl=document.getElementById('cl-summary');
  if(bar)  bar.style.width=partsPct+'%';
  if(pctEl) pctEl.textContent=partsPct+'%';
  if(sumEl) sumEl.textContent=done+'/'+total+' parts done'+(inprog?' · '+inprog+' in progress':'');
  updateSectionBadge('badge-parts', partsPct);

  /* === Apply total to both bars === */
  applyProgress(score);
  return score;
}

/* Alias so cycleCI still works */
function updateChecklist(){ calcOverallProgress(); }

/* ── 4. Click a part to cycle its state ── */
function cycleCI(el){
  var dot=el.querySelector('.ci-dot');
  var st =el.querySelector('.ci-st');
  if(!dot||!st) return;
  var cur=0;
  for(var i=0;i<ciStates.length;i++){if(dot.classList.contains(ciStates[i].dot)){cur=i;break;}}
  var next=(cur+1)%ciStates.length;
  ciStates.forEach(function(s){
    dot.classList.remove(s.dot); st.classList.remove(s.cls); el.classList.remove('state-'+s.key);
  });
  dot.classList.add(ciStates[next].dot);
  st.classList.add(ciStates[next].cls);
  st.textContent=ciStates[next].label;
  el.classList.add('state-'+ciStates[next].key);
  updateChecklist();
  /* debounced auto-save */
  clearTimeout(window._autoSave);
  window._autoSave=setTimeout(function(){ doDesignSave('save_draft',true); },1200);
}

/* ── 5. Restore saved draft on page load ── */
function restoreDraft(d){
  if(!d) return;
  function sv(id,val){
    var el=document.getElementById(id);
    if(!el||val===undefined||val==='') return;
    if(el.tagName==='SELECT'){
      for(var i=0;i<el.options.length;i++){
        if(el.options[i].text===val||el.options[i].value===val){
          el.selectedIndex=i; return;
        }
      }
    } else {
      el.value=val;
    }
  }
  sv('design-title',     d.design_title);
  sv('designer-remarks', d.designer_remarks);
  sv('design-version',   d.design_version);
  sv('est-date',         d.est_date);
  sv('design-overview',  d.overview_notes);

  /* design-status select */
  var ds=document.getElementById('design-status');
  if(ds&&d.design_status){
    for(var i=0;i<ds.options.length;i++){
      if(ds.options[i].text===d.design_status||ds.options[i].value===d.design_status){ds.selectedIndex=i;break;}
    }
  }
  /* vehicle sub-category select */
  var sc=document.getElementById('vehicle-subcat');
  if(sc&&d.sub_category){
    for(var i=0;i<sc.options.length;i++){
      if(sc.options[i].text===d.sub_category||sc.options[i].value===d.sub_category){sc.selectedIndex=i;break;}
    }
  }

  /* engine specs restore by ID */
  function rs(id,val){
    var el=document.getElementById(id);
    if(!el||!val||val==='') return;
    if(el.tagName==='SELECT'){
      /* Match by option text since options have no value attribute */
      for(var i=0;i<el.options.length;i++){
        if(el.options[i].text===val||el.options[i].value===val){
          el.selectedIndex=i; return;
        }
      }
      /* Partial match fallback */
      for(var i=0;i<el.options.length;i++){
        if(el.options[i].text.indexOf(val)>=0||val.indexOf(el.options[i].text)>=0){
          el.selectedIndex=i; return;
        }
      }
    } else {
      el.value=val;
    }
  }
  rs('sel-engine-type', d.engine_type);
  rs('inp-displacement',d.displacement);
  rs('sel-cylinders',   d.cylinders);
  rs('inp-power',       d.max_power);
  rs('inp-torque',      d.max_torque);
  rs('sel-transmission',d.transmission);
  rs('inp-length',      d.length_mm);
  rs('inp-width',       d.width_mm);
  rs('inp-height',      d.height_mm);
  rs('inp-wheelbase',   d.wheelbase_mm);
  rs('inp-weight',      d.kerb_weight_kg);
  rs('inp-capacity',    d.capacity);

  /* features checkboxes */
  if(d.features_checked_raw && Array.isArray(d.features_checked_raw)){
    var cbs=document.querySelectorAll('.ftr input[type="checkbox"]');
    d.features_checked_raw.forEach(function(f,i){if(cbs[i])cbs[i].checked=!!f.checked;});
  }

  /* parts checklist */
  if(d.parts_checklist_raw && Array.isArray(d.parts_checklist_raw) && d.parts_checklist_raw.length>0){
    var items=document.querySelectorAll('.ci');
    d.parts_checklist_raw.forEach(function(p,i){
      if(!items[i]) return;
      var dot=items[i].querySelector('.ci-dot');
      var st =items[i].querySelector('.ci-st');
      if(!dot||!st) return;
      var idx=0;
      for(var s=0;s<ciStates.length;s++){if(ciStates[s].label===p.status){idx=s;break;}}
      ciStates.forEach(function(cs){
        dot.classList.remove(cs.dot); st.classList.remove(cs.cls); items[i].classList.remove('state-'+cs.key);
      });
      dot.classList.add(ciStates[idx].dot);
      st.classList.add(ciStates[idx].cls);
      st.textContent=ciStates[idx].label;
      items[i].classList.add('state-'+ciStates[idx].key);
    });
    updateChecklist();
  } else if(d.progress_pct && parseInt(d.progress_pct)>0){
    setStage(parseInt(d.progress_pct));
  }

  /* recalculate progress after all fields restored */
  calcOverallProgress();

  /* show banner */
  var banner=document.getElementById('draft-restored-banner');
  if(banner) banner.style.display='flex';
}

/* ── 6. Save Draft / Submit to QC ── */
function saveDraft(){ doDesignSave('save_draft',false); }

function submitToQC(){
  if(curStage<100){
    alert('Parts checklist must be 100% complete before submitting to QC.\nCurrent: '+curStage+'%\n\nMark all parts as Completed first.');
    return;
  }
  var rem=document.getElementById('designer-remarks');
  if(!rem||rem.value.trim().length<5){
    alert('Please enter Designer Remarks before submitting.');
    if(rem) rem.focus(); return;
  }
  if(!confirm('Submit this design to QC?\n\nThe order will move to the QC team for review.')) return;
  doDesignSave('submit_qc',false);
}

function doDesignSave(actionType, silent){
  /* collect all form values */
  function fv(id){var el=document.getElementById(id);return el?el.value:'';}

  /* parts as simple array — no nested objects to break JSON parsing */
  var partNames=[], partStatuses=[];
  document.querySelectorAll('.ci').forEach(function(ci){
    var n=ci.querySelector('.ci-name'), s=ci.querySelector('.ci-st');
    if(n&&s){ partNames.push(n.textContent.trim()); partStatuses.push(s.textContent.trim()); }
  });

  /* features as parallel arrays */
  var featNames=[], featChecked=[];
  document.querySelectorAll('.ftr input[type="checkbox"]').forEach(function(cb){
    var lbl=document.querySelector('label[for="'+cb.id+'"]');
    featNames.push(lbl?lbl.textContent.trim():'');
    featChecked.push(cb.checked?'1':'0');
  });

  var payload={
    actionType:   actionType,
    reqId:        '<%=reqIdStr!=null?reqIdStr:""%>',
    sourceType:   '<%=source!=null?source:"cr"%>',
    designTitle:  fv('design-title'),
    designStatus: fv('design-status'),
    remarks:      fv('designer-remarks'),
    version:      fv('design-version'),
    estDate:      fv('est-date'),
    subCategory:  fv('vehicle-subcat'),
    overviewNotes:fv('design-overview'),
    progressPct:  String(calcOverallProgress()),
    /* parts and features as pipe-delimited strings — avoids nested JSON parsing issues */
    partNames:    partNames.join('||'),
    partStatuses: partStatuses.join('||'),
    featNames:    featNames.join('||'),
    featChecked:  featChecked.join('||')
  };

  /* engine specs — collected by explicit ID */
  function gid(id){var el=document.getElementById(id);return el?el.value:'';}
  payload.engineType   = gid('sel-engine-type');
  payload.displacement = gid('inp-displacement');
  payload.cylinders    = gid('sel-cylinders');
  payload.maxPower     = gid('inp-power');
  payload.maxTorque    = gid('inp-torque');
  payload.transmission = gid('sel-transmission');
  payload.lengthMM     = gid('inp-length');
  payload.widthMM      = gid('inp-width');
  payload.heightMM     = gid('inp-height');
  payload.wheelbase    = gid('inp-wheelbase');
  payload.kerbWeight   = gid('inp-weight');
  payload.capacity     = gid('inp-capacity');

  if(!silent){
    var btns=document.querySelectorAll('.actions button');
    btns.forEach(function(b){b.disabled=true;});
    var old=document.getElementById('save-msg'); if(old) old.remove();
    var msg=document.createElement('div');
    msg.id='save-msg';
    msg.style.cssText='padding:10px 16px;border-radius:8px;font-size:12px;font-weight:600;margin-top:10px;'
      +'display:flex;align-items:center;gap:8px;background:#1e3a5f;color:#60a5fa;';
    msg.innerHTML='<i class="fas fa-spinner fa-spin"></i> '+(actionType==='submit_qc'?'Submitting to QC...':'Saving draft...');
    var actDiv=document.querySelector('.actions');
    if(actDiv) actDiv.parentNode.insertBefore(msg,actDiv.nextSibling);
  }

  /* auto-save toast */
  if(silent){
    var t=document.getElementById('autosave-toast');
    if(!t){
      t=document.createElement('div'); t.id='autosave-toast';
      t.style.cssText='position:fixed;bottom:20px;right:20px;background:#0a1e12;border:1px solid #00c87f;'
        +'color:#00c87f;padding:7px 14px;border-radius:8px;font-size:11px;font-weight:700;'
        +'z-index:9999;display:flex;align-items:center;gap:7px;';
      document.body.appendChild(t);
    }
    t.style.opacity='1';
    t.innerHTML='<i class="fas fa-save"></i> Saving...';
  }

  /* For QC submit include files via FormData; for drafts use JSON */
  var url='<%=request.getContextPath()%>/jsp/save_design_work.jsp';
  var hasFiles = actionType==='submit_qc' && (
      (document.getElementById('file-blueprint') && document.getElementById('file-blueprint').files.length>0) ||
      (document.getElementById('file-3d')        && document.getElementById('file-3d').files.length>0)        ||
      (document.getElementById('file-docs')       && document.getElementById('file-docs').files.length>0)
  );

  var fetchPromise;
  if(hasFiles){
    var fd=new FormData();
    Object.keys(payload).forEach(function(k){ fd.append(k,payload[k]); });
    var bp=document.getElementById('file-blueprint'); if(bp&&bp.files[0]) fd.append('blueprintFile',bp.files[0]);
    var td=document.getElementById('file-3d');        if(td&&td.files[0]) fd.append('model3dFile',td.files[0]);
    var dc=document.getElementById('file-docs');      if(dc&&dc.files.length>0) for(var fi=0;fi<dc.files.length;fi++) fd.append('extraFiles',dc.files[fi]);
    fetchPromise=fetch(url,{method:'POST',body:fd});
  } else {
    fetchPromise=fetch(url,{method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},body:JSON.stringify(payload)});
  }

  fetchPromise
  .then(function(r){return r.text();})
  .then(function(txt){
    var data; try{data=JSON.parse(txt);}catch(e){data={error:'Server: '+txt.substring(0,100)};}

    if(!silent){
      var btns=document.querySelectorAll('.actions button');
      btns.forEach(function(b){b.disabled=false;});
      var msg=document.getElementById('save-msg');
      if(data.success){
        var ts=document.getElementById('top-save-status');
        if(ts){ts.style.color='#4ade80';ts.textContent=(data.message||'Saved!')+' · '+new Date().toLocaleTimeString();}
        if(actionType==='submit_qc'){
          setTimeout(function(){window.location.href='<%=BASE%>?surface=<%=isIntDetail?"internal":"external"%>';},1800);
        } else {
          setTimeout(function(){if(msg&&msg.parentNode){msg.style.opacity='0';}},4000);
        }
      } else {
        var ts=document.getElementById('top-save-status');
        if(ts){ts.style.color='#f87171';ts.textContent='Error: '+(data.error||'Save failed');}
      }
    } else {
      var t=document.getElementById('autosave-toast');
      if(t){
        if(data.success){
          t.innerHTML='<i class="fas fa-check-circle"></i> Draft saved';
          setTimeout(function(){t.style.opacity='0';},2500);
        } else {
          t.innerHTML='<i class="fas fa-exclamation-circle"></i> Save failed';
          t.style.color='#f87171'; t.style.borderColor='#f87171';
          setTimeout(function(){t.style.opacity='0';},3000);
        }
      }
    }
  })
  .catch(function(e){
    if(!silent){
      var btns=document.querySelectorAll('.actions button');
      btns.forEach(function(b){b.disabled=false;});
      var ts=document.getElementById('top-save-status');
      if(ts){ts.style.color='#f87171';ts.textContent='Network error';}
    }
  });
}

/* ── Vehicle SVG preview ── */
var vColor='#c0392b';
var vType='<%=(showDetail&&vehicleTypeDetail.contains("bus"))?"bus":(showDetail&&(vehicleTypeDetail.contains("lorry")||vehicleTypeDetail.contains("heavy")))?"truck":(showDetail&&(vehicleTypeDetail.contains("two_wheeler")||vehicleTypeDetail.contains("three_wheeler")))?"bike":"car"%>';
function drawCar(c){
  return '<rect x="60" y="100" width="380" height="65" rx="8" fill="'+c+'" stroke="#555" stroke-width="2"/>'+
    '<path d="M150 100 Q185 52 270 48 Q340 48 360 100 Z" fill="'+c+'" stroke="#555" stroke-width="2"/>'+
    '<path d="M162 98 Q190 62 268 58 Q328 58 348 98 Z" fill="rgba(120,210,255,0.3)" stroke="#888" stroke-width="1"/>'+
    '<circle cx="150" cy="167" r="25" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="150" cy="167" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<circle cx="360" cy="167" r="25" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="360" cy="167" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<rect x="36" y="118" width="10" height="16" rx="3" fill="#ff1744"/>'+
    '<ellipse cx="445" cy="126" rx="12" ry="9" fill="#fffde7" stroke="#f9a825" stroke-width="2"/>'+
    '<ellipse cx="250" cy="194" rx="180" ry="5" fill="rgba(0,0,0,0.3)"/>';
}
function drawBus(c){
  var w='';
  for(var i=0;i<6;i++){var x=60+i*58;w+='<rect x="'+x+'" y="68" width="42" height="46" rx="4" fill="rgba(120,210,255,0.35)" stroke="#777" stroke-width="1.5"/>';}
  return '<rect x="28" y="55" width="444" height="120" rx="10" fill="'+c+'" stroke="#555" stroke-width="2"/>'+w+
    '<circle cx="100" cy="178" r="24" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="100" cy="178" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<circle cx="390" cy="178" r="24" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="390" cy="178" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<ellipse cx="250" cy="200" rx="210" ry="5" fill="rgba(0,0,0,0.3)"/>';
}
function drawTruck(c){
  return '<rect x="310" y="62" width="158" height="108" rx="8" fill="'+c+'" stroke="#555" stroke-width="2"/>'+
    '<rect x="324" y="74" width="124" height="54" rx="5" fill="rgba(120,210,255,0.35)" stroke="#777" stroke-width="1.5"/>'+
    '<rect x="30" y="80" width="284" height="90" rx="5" fill="'+c+'" stroke="#444" stroke-width="2"/>'+
    '<circle cx="100" cy="174" r="24" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="100" cy="174" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<circle cx="380" cy="174" r="24" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="380" cy="174" r="12" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<ellipse cx="250" cy="200" rx="210" ry="5" fill="rgba(0,0,0,0.3)"/>';
}
function drawBike(c){
  return '<line x1="190" y1="110" x2="310" y2="110" stroke="'+c+'" stroke-width="10" stroke-linecap="round"/>'+
    '<ellipse cx="250" cy="108" rx="46" ry="20" fill="'+c+'" stroke="#555" stroke-width="2"/>'+
    '<rect x="212" y="118" width="76" height="36" rx="6" fill="#333" stroke="#555" stroke-width="1.5"/>'+
    '<circle cx="148" cy="160" r="38" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="148" cy="160" r="20" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<circle cx="352" cy="160" r="38" fill="#222" stroke="#888" stroke-width="3"/>'+
    '<circle cx="352" cy="160" r="20" fill="#555" stroke="#bbb" stroke-width="2"/>'+
    '<ellipse cx="250" cy="200" rx="150" ry="5" fill="rgba(0,0,0,0.3)"/>';
}
function showV(type,btn){
  document.querySelectorAll('.vtab').forEach(function(t){t.classList.remove('active');});
  btn.classList.add('active'); vType=type; renderV();
}
function setColor(c,el){
  document.querySelectorAll('.col-swatch').forEach(function(s){s.classList.remove('sel');});
  el.classList.add('sel'); vColor=c; renderV();
}
function renderV(){
  var canvas=document.querySelector('.v-canvas');
  if(!canvas) return;
  var h='';
  if(vType==='car')  h=drawCar(vColor);
  if(vType==='bus')  h=drawBus(vColor);
  if(vType==='truck')h=drawTruck(vColor);
  if(vType==='bike') h=drawBike(vColor);
  /* Replace the whole SVG tag — avoids innerHTML issues in SVG namespace */
  canvas.innerHTML='<svg id="vsvg" class="v-svg" viewBox="0 0 500 200" xmlns="http://www.w3.org/2000/svg">'+h+'</svg>';
}
renderV();


/* ── History tab switch ── */
function switchHist(type,btn){
  document.getElementById('hbody-int').style.display=type==='int'?'block':'none';
  document.getElementById('hbody-ext').style.display=type==='ext'?'block':'none';
  document.querySelectorAll('.hist-tab').forEach(function(t){t.className='hist-tab';});
  btn.className='hist-tab a'+type;
}

/* ── Init on page load ── */
renderV();
calcOverallProgress();
if(SAVED_DRAFT){ restoreDraft(SAVED_DRAFT); }

/* ── Attach live progress listeners to all form fields ── */
(function attachListeners(){
  var fieldIds=[
    'design-title','vehicle-subcat','est-date','design-version','design-overview',
    'sel-engine-type','inp-displacement','sel-cylinders','inp-power','inp-torque','sel-transmission',
    'inp-length','inp-width','inp-height','inp-wheelbase','inp-weight','inp-capacity',
    'designer-remarks'
  ];
  fieldIds.forEach(function(id){
    var el=document.getElementById(id);
    if(!el) return;
    el.addEventListener('input',  function(){ calcOverallProgress(); });
    el.addEventListener('change', function(){ calcOverallProgress(); });
  });
  /* Feature checkboxes */
  document.querySelectorAll('.ftr input[type="checkbox"]').forEach(function(cb){
    cb.addEventListener('change', function(){ calcOverallProgress(); });
  });
})();
</script>
</body>
</html>
