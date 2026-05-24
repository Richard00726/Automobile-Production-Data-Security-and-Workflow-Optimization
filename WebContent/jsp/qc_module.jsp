<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.util.*" %>
<%
    /* ═══ AUTH ═══ */
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp"); return;
    }
    String role   = (String) sess.getAttribute("role");
    String qcUser = (String) sess.getAttribute("username");
    String qcName = (String) sess.getAttribute("fullName");
    if (qcName == null) qcName = qcUser;
    if (!"qc".equals(role) && !"admin".equals(role)) {
        response.sendRedirect("../dashboard.jsp"); return;
    }
    request.setAttribute("currentPage","qc");

    String success = request.getAttribute("success") != null
        ? (String) request.getAttribute("success")
        : request.getParameter("success");
    String error = request.getAttribute("error") != null
        ? (String) request.getAttribute("error")
        : request.getParameter("error");

    /* ═══ QC USER PROFILE ═══ */
    String qcVehicleType  = null;
    String qcVehicleLabel = "All Categories";
    int    qcSlot         = 0;
    if (!"admin".equals(role)) {
        try (Connection c = DBConnection.getConnection()) {
            PreparedStatement p = c.prepareStatement(
                "SELECT vehicle_type,slot_number FROM module_team_members " +
                "WHERE module_role='qc' AND username=? AND is_active=1 LIMIT 1");
            p.setString(1, qcUser);
            ResultSet r = p.executeQuery();
            if (r.next()) {
                qcVehicleType  = r.getString("vehicle_type");
                qcSlot         = r.getInt("slot_number");
                if (qcVehicleType != null)
                    qcVehicleLabel = qcVehicleType.replace("_"," ").toUpperCase();
            }
        } catch (Exception e) {}
    }

    /* ═══ URL PARAMETERS ═══ */
    String surface  = request.getParameter("surface");  // "internal" | "external"
    String reqIdStr = request.getParameter("reqId");
    String srcParam = request.getParameter("src");      // "internal" | "external" | "cr"

    /* ═══ LOAD INTERNAL JOBS (my queue) ═══ */
    List<Object[]> myIntJobs = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        String sql = "admin".equals(role)
            ? "SELECT ij.id, ij.job_number, ij.model_name, ij.vehicle_type, ij.brand_name, " +
              "ij.target_date, ij.quantity, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username " +
              "FROM internal_jobs ij " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=ij.id AND source_type='internal_job' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=ij.id AND qd.source_type='internal' " +
              "WHERE ij.workflow_stage IN ('design_completed','qc_approved') ORDER BY ij.id DESC"
            : "SELECT ij.id, ij.job_number, ij.model_name, ij.vehicle_type, ij.brand_name, " +
              "ij.target_date, ij.quantity, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username " +
              "FROM internal_jobs ij " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=ij.id AND source_type='internal_job' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=ij.id AND qd.source_type='internal' AND qd.qc_user=? " +
              "WHERE ij.workflow_stage IN ('design_completed','qc_approved') AND ij.current_assignee=? ORDER BY ij.id DESC";
        PreparedStatement ps = conn.prepareStatement(sql);
        if (!"admin".equals(role)) { ps.setString(1, qcUser); ps.setString(2, qcUser); }
        ResultSet rs = ps.executeQuery();
        while (rs.next()) myIntJobs.add(new Object[]{
            rs.getInt("id"), "internal",
            rs.getString("job_number")      != null ? rs.getString("job_number")      : "INT-"+rs.getInt("id"),
            rs.getString("model_name")      != null ? rs.getString("model_name")      : "Job",
            rs.getString("vehicle_type")    != null ? rs.getString("vehicle_type")    : "",
            rs.getString("brand_name")      != null ? rs.getString("brand_name")      : "",
            rs.getString("target_date")     != null ? rs.getString("target_date")     : "—",
            rs.getString("quantity")        != null ? rs.getString("quantity")        : "1",
            rs.getInt("qc_pct"),
            rs.getString("designer_username") != null ? rs.getString("designer_username") : "—"
        });
    } catch (Exception e) {}

    /* ═══ LOAD EXTERNAL JOBS (external_orders + customer_requirements) ═══ */
    List<Object[]> myExtJobs = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        // external_orders
        String eoSql = "admin".equals(role)
            ? "SELECT eo.id, eo.order_number, CONCAT(eo.client_name,' - Bulk Order') AS title, " +
              "eo.vehicle_type, eo.client_name, eo.deadline, '1' AS qty, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username, 'external' AS src " +
              "FROM external_orders eo " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=eo.id AND source_type='external_order' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=eo.id AND qd.source_type='external' " +
              "WHERE eo.workflow_stage IN ('design_completed','qc_approved') ORDER BY eo.id DESC"
            : "SELECT eo.id, eo.order_number, CONCAT(eo.client_name,' - Bulk Order') AS title, " +
              "eo.vehicle_type, eo.client_name, eo.deadline, '1' AS qty, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username, 'external' AS src " +
              "FROM external_orders eo " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=eo.id AND source_type='external_order' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=eo.id AND qd.source_type='external' AND qd.qc_user=? " +
              "WHERE eo.workflow_stage IN ('design_completed','qc_approved') AND eo.current_assignee=? ORDER BY eo.id DESC";
        PreparedStatement ps1 = conn.prepareStatement(eoSql);
        if (!"admin".equals(role)) { ps1.setString(1, qcUser); ps1.setString(2, qcUser); }
        ResultSet rs1 = ps1.executeQuery();
        while (rs1.next()) myExtJobs.add(new Object[]{
            rs1.getInt("id"), "external",
            rs1.getString("order_number") != null ? rs1.getString("order_number") : "EXT-"+rs1.getInt("id"),
            rs1.getString("title"), rs1.getString("vehicle_type"),
            rs1.getString("client_name"), rs1.getString("deadline"),
            rs1.getString("qty"), rs1.getInt("qc_pct"),
            rs1.getString("designer_username") != null ? rs1.getString("designer_username") : "—"
        });
        // customer_requirements
        String crSql = "admin".equals(role)
            ? "SELECT cr.id, CONCAT('CR-',cr.id) AS rnum, cr.req_title AS title, " +
              "cr.vehicle_type, COALESCE(c.full_name,cr.client_name) AS cname, cr.deadline, '1' AS qty, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username, 'cr' AS src " +
              "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=cr.id AND qd.source_type='cr' " +
              "WHERE cr.workflow_stage IN ('design_completed','qc_approved') ORDER BY cr.id DESC"
            : "SELECT cr.id, CONCAT('CR-',cr.id) AS rnum, cr.req_title AS title, " +
              "cr.vehicle_type, COALESCE(c.full_name,cr.client_name) AS cname, cr.deadline, '1' AS qty, " +
              "COALESCE(qd.progress_pct,0) AS qc_pct, ds.designer_username, 'cr' AS src " +
              "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
              "LEFT JOIN design_submissions ds ON ds.id = (" +
              "  SELECT id FROM design_submissions WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN qc_drafts qd ON qd.job_ref_id=cr.id AND qd.source_type='cr' AND qd.qc_user=? " +
              "WHERE cr.workflow_stage IN ('design_completed','qc_approved') AND cr.current_assignee=? ORDER BY cr.id DESC";
        PreparedStatement ps2 = conn.prepareStatement(crSql);
        if (!"admin".equals(role)) { ps2.setString(1, qcUser); ps2.setString(2, qcUser); }
        ResultSet rs2 = ps2.executeQuery();
        while (rs2.next()) myExtJobs.add(new Object[]{
            rs2.getInt("id"), "cr",
            rs2.getString("rnum"), rs2.getString("title"), rs2.getString("vehicle_type"),
            rs2.getString("cname"), rs2.getString("deadline"),
            rs2.getString("qty"), rs2.getInt("qc_pct"),
            rs2.getString("designer_username") != null ? rs2.getString("designer_username") : "—"
        });
    } catch (Exception e) {}

    /* ═══ PAGE STATE ═══ */
    boolean showLanding = (surface == null && reqIdStr == null);
    boolean showIntList = "internal".equals(surface) && reqIdStr == null;
    boolean showExtList = "external".equals(surface) && reqIdStr == null;
    boolean showDetail  = reqIdStr != null && !reqIdStr.trim().isEmpty();

    /* ═══ LOAD DETAIL DATA ═══ */
    int selId = 0;
    String selSrc = srcParam != null ? srcParam : "internal";
    if (showDetail) {
        try { selId = Integer.parseInt(reqIdStr.trim()); } catch (Exception ig) {}
    }

    // Design submission fields
    String ds_title="—",ds_status="—",ds_remarks="—",ds_version="—",ds_subCat="—",ds_overview="—";
    String ds_engine="—",ds_disp="—",ds_cyl="—",ds_power="—",ds_torque="—",ds_trans="—";
    String ds_len="—",ds_wid="—",ds_hei="—",ds_wb="—",ds_kw="—",ds_cap="—";
    String ds_designer="—",ds_partsJson="[]",ds_featsJson="[]";
    String ds_blueprint="—",ds_model3d="—",ds_extraFiles="—";
    int    ds_pct=0;
    // Job meta fields
    String sel_ref="—",sel_title="—",sel_vtype="—",sel_brand="—",sel_deadline="—",sel_qty="1";

    if (showDetail && selId > 0) {
        // Get job meta from preloaded list first
        List<Object[]> allJobs = new ArrayList<>(myIntJobs);
        allJobs.addAll(myExtJobs);
        for (Object[] jr : allJobs) {
            if ((Integer)jr[0]==selId && selSrc.equals((String)jr[1])) {
                sel_ref      = (String) jr[2];
                sel_title    = (String) jr[3];
                sel_vtype    = (String) jr[4];
                sel_brand    = (String) jr[5];
                sel_deadline = (String) jr[6];
                sel_qty      = (String) jr[7];
                break;
            }
        }

        // Fallback: load job meta directly from DB if not found in preloaded list
        if ("—".equals(sel_ref)) {
            try (Connection conn = DBConnection.getConnection()) {
                String metaSql = "internal".equals(selSrc)
                    ? "SELECT job_number AS ref, model_name AS title, vehicle_type, brand_name, target_date, quantity FROM internal_jobs WHERE id=?"
                    : "external".equals(selSrc)
                    ? "SELECT order_number AS ref, CONCAT(client_name,' - Bulk Order') AS title, vehicle_type, client_name AS brand_name, deadline AS target_date, '1' AS quantity FROM external_orders WHERE id=?"
                    : "SELECT CONCAT('CR-',id) AS ref, req_title AS title, vehicle_type, client_name AS brand_name, deadline AS target_date, '1' AS quantity FROM customer_requirements WHERE id=?";
                PreparedStatement mps = conn.prepareStatement(metaSql);
                mps.setInt(1, selId);
                ResultSet mrs = mps.executeQuery();
                if (mrs.next()) {
                    sel_ref      = nvl(mrs.getString("ref"));
                    sel_title    = nvl(mrs.getString("title"));
                    sel_vtype    = nvl(mrs.getString("vehicle_type"));
                    sel_brand    = nvl(mrs.getString("brand_name"));
                    sel_deadline = nvl(mrs.getString("target_date"));
                    sel_qty      = nvl(mrs.getString("quantity"));
                }
            } catch (Exception e) {}
        }
        // Map to design_submissions source_type
        String dsSrc = "internal".equals(selSrc) ? "internal_job"
                     : "external".equals(selSrc)  ? "external_order"
                     : "cr";
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement dps = conn.prepareStatement(
                "SELECT * FROM design_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
            dps.setInt(1, selId); dps.setString(2, dsSrc);
            ResultSet drs = dps.executeQuery();
            if (drs.next()) {
                ds_title    = nvl(drs.getString("design_title"));
                ds_status   = nvl(drs.getString("design_status"));
                ds_remarks  = nvl(drs.getString("designer_remarks"));
                ds_version  = nvl(drs.getString("design_version"));
                ds_subCat   = nvl(drs.getString("sub_category"));
                ds_overview = nvl(drs.getString("overview_notes"));
                ds_engine   = nvl(drs.getString("engine_type"));
                ds_disp     = nvl(drs.getString("displacement"));
                ds_cyl      = nvl(drs.getString("cylinders"));
                ds_power    = nvl(drs.getString("max_power"));
                ds_torque   = nvl(drs.getString("max_torque"));
                ds_trans    = nvl(drs.getString("transmission"));
                ds_len      = nvl(drs.getString("length_mm"));
                ds_wid      = nvl(drs.getString("width_mm"));
                ds_hei      = nvl(drs.getString("height_mm"));
                ds_wb       = nvl(drs.getString("wheelbase_mm"));
                ds_kw       = nvl(drs.getString("kerb_weight_kg"));
                ds_cap      = nvl(drs.getString("capacity"));
                ds_designer = nvl(drs.getString("designer_username"));
                ds_partsJson= drs.getString("parts_checklist")  != null ? drs.getString("parts_checklist")  : "[]";
                ds_featsJson= drs.getString("features_checked") != null ? drs.getString("features_checked")  : "[]";
                ds_pct      = drs.getInt("progress_pct");
                try{ ds_blueprint = nvl(drs.getString("blueprint_file")); }catch(Exception ig){}
                try{ ds_model3d   = nvl(drs.getString("model_3d_file")); }catch(Exception ig){}
                try{ ds_extraFiles= nvl(drs.getString("extra_files")); }catch(Exception ig){}
            }
        } catch (Exception e) {}
    }

    // Back link logic
    String ctx = request.getContextPath();
    String backLink = showDetail
        ? ("internal".equals(selSrc)
            ? ctx + "/qc?surface=internal"
            : ctx + "/qc?surface=external")
        : ctx + "/qc";

    String jsPartsJson = ds_partsJson.replace("</","<\\/");
    String jsFeatsJson = ds_featsJson.replace("</","<\\/");

    /* ═══ QC HISTORY ═══ */
    List<Object[]> histInt = new ArrayList<>();
    List<Object[]> histExt = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        // Internal history
        String hiSql = "admin".equals(role)
            ? "SELECT h.source_id,h.action,h.remarks,h.actioned_by,h.actioned_at,ij.job_number,ij.model_name " +
              "FROM unified_workflow_history h JOIN internal_jobs ij ON h.source_id=ij.id " +
              "WHERE h.source_type='internal' AND h.stage='design_completed' " +
              "AND h.action IN ('approved','qc_rejected','qc_conditional') ORDER BY h.id DESC LIMIT 20"
            : "SELECT h.source_id,h.action,h.remarks,h.actioned_by,h.actioned_at,ij.job_number,ij.model_name " +
              "FROM unified_workflow_history h JOIN internal_jobs ij ON h.source_id=ij.id " +
              "WHERE h.source_type='internal' AND h.stage='design_completed' " +
              "AND h.action IN ('approved','qc_rejected','qc_conditional') AND h.actioned_by=? ORDER BY h.id DESC LIMIT 20";
        PreparedStatement hip = conn.prepareStatement(hiSql);
        if (!"admin".equals(role)) hip.setString(1, qcUser);
        ResultSet hir = hip.executeQuery();
        while (hir.next()) histInt.add(new Object[]{
            hir.getString("job_number"), hir.getString("model_name"),
            hir.getString("action"), hir.getString("remarks"),
            hir.getString("actioned_by"), hir.getTimestamp("actioned_at")
        });
        // External history (eo + cr combined)
        String heSql = "admin".equals(role)
            ? "SELECT h.source_id,h.source_type,h.action,h.remarks,h.actioned_by,h.actioned_at," +
              "COALESCE(eo.order_number,CONCAT('CR-',cr.id)) AS ref," +
              "COALESCE(eo.model_name,cr.vehicle_type) AS title " +
              "FROM unified_workflow_history h " +
              "LEFT JOIN external_orders eo ON h.source_type='external' AND h.source_id=eo.id " +
              "LEFT JOIN customer_requirements cr ON h.source_type='cr' AND h.source_id=cr.id " +
              "WHERE h.source_type IN ('external','cr') AND h.stage='design_completed' " +
              "AND h.action IN ('approved','qc_rejected','qc_conditional') ORDER BY h.id DESC LIMIT 20"
            : "SELECT h.source_id,h.source_type,h.action,h.remarks,h.actioned_by,h.actioned_at," +
              "COALESCE(eo.order_number,CONCAT('CR-',cr.id)) AS ref," +
              "COALESCE(eo.model_name,cr.vehicle_type) AS title " +
              "FROM unified_workflow_history h " +
              "LEFT JOIN external_orders eo ON h.source_type='external' AND h.source_id=eo.id " +
              "LEFT JOIN customer_requirements cr ON h.source_type='cr' AND h.source_id=cr.id " +
              "WHERE h.source_type IN ('external','cr') AND h.stage='design_completed' " +
              "AND h.action IN ('approved','qc_rejected','qc_conditional') AND h.actioned_by=? ORDER BY h.id DESC LIMIT 20";
        PreparedStatement hep = conn.prepareStatement(heSql);
        if (!"admin".equals(role)) hep.setString(1, qcUser);
        ResultSet her = hep.executeQuery();
        while (her.next()) histExt.add(new Object[]{
            her.getString("ref"), her.getString("title"),
            her.getString("action"), her.getString("remarks"),
            her.getString("actioned_by"), her.getTimestamp("actioned_at")
        });
    } catch (Exception e) {}

    /* ═══ QC TEAM MEMBERS (same pool) ═══ */
    List<Object[]> teamMembers = new ArrayList<>();
    String poolType = qcVehicleType != null ? qcVehicleType : "";
    if (!"admin".equals(role) && !poolType.isEmpty()) {
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement p = conn.prepareStatement(
                "SELECT mt.slot_number, mt.full_name, mt.username, mt.is_active, u.last_active " +
                "FROM module_team_members mt " +
                "LEFT JOIN users u ON CONVERT(mt.username USING utf8mb4) COLLATE utf8mb4_general_ci = CONVERT(u.username USING utf8mb4) COLLATE utf8mb4_general_ci " +
                "WHERE mt.module_role='qc' AND mt.vehicle_type=? ORDER BY mt.slot_number ASC");
            p.setString(1, poolType);
            ResultSet r = p.executeQuery();
            while (r.next()) teamMembers.add(new Object[]{
                r.getInt("slot_number"), r.getString("full_name"),
                r.getString("username") != null ? r.getString("username") : "",
                r.getInt("is_active"), r.getTimestamp("last_active")
            });
        } catch (Exception e) {}
    }
%><%!
    // Helper: null-safe string, returns "—" for null/empty
    private String nvl(String s) { return (s != null && !s.isEmpty()) ? s : "—"; }
%><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>QC Module &#8212; AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&family=Exo+2:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<style>
:root{
  --bg:#0a1020;--surface:#0f1a2e;--card:#111e35;--border:#1e2d45;
  --text:#d0d8e8;--muted:#4a5c7a;
  --accent:#00c8ff;--accent2:#ff6b35;--green:#00e676;--purple:#7c5cfc;
  --int:#6c63ff;--ext:#00b4a6;--qc:#22c55e;--qc2:#16a34a;
}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);color:var(--text);font-family:'Exo 2',sans-serif;font-size:13px;height:100vh;display:flex;flex-direction:column;overflow:hidden;}
/* TOPBAR */
.topbar{height:46px;background:var(--surface);border-bottom:1px solid var(--border);display:flex;align-items:center;gap:14px;padding:0 18px;flex-shrink:0;box-shadow:0 3px 20px rgba(0,200,100,.08);z-index:100;}
.tb-logo{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;color:var(--qc);letter-spacing:2px;}
.tb-logo span{color:var(--text);}
.tb-sep{width:1px;height:22px;background:var(--border);}
.tb-title{font-family:'Rajdhani',sans-serif;font-size:14px;font-weight:600;color:var(--muted);letter-spacing:1px;text-transform:uppercase;}
.tb-badge{padding:3px 12px;border-radius:16px;font-size:11px;font-weight:700;border:1px solid;}
.tb-badge.cat{color:var(--qc);border-color:var(--qc);background:rgba(34,197,94,.08);}
.tb-badge.slot{color:var(--purple);border-color:var(--purple);background:rgba(124,92,252,.1);}
.tb-right{margin-left:auto;display:flex;align-items:center;gap:10px;}
.tb-user{font-size:12px;color:var(--muted);}
.tb-user strong{color:var(--text);}
.tb-logout{font-size:11px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.tb-logout:hover{color:var(--accent2);border-color:var(--accent2);}
/* LAYOUT */
.layout{display:flex;flex:1;overflow:hidden;}
/* MAIN */
.main{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.main-progress{background:var(--card);border-bottom:1px solid var(--border);padding:8px 20px;flex-shrink:0;}
.prog-track{display:flex;align-items:center;}
.prog-step{flex:1;text-align:center;position:relative;}
.prog-step::after{content:'';position:absolute;top:16px;left:50%;right:-50%;height:2px;background:var(--border);z-index:0;}
.prog-step:last-child::after{display:none;}
.prog-dot{width:32px;height:32px;border-radius:50%;background:var(--surface);border:2px solid var(--border);margin:0 auto 4px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;position:relative;z-index:1;}
.prog-step.done .prog-dot{background:var(--green);border-color:var(--green);color:#000;}
.prog-step.done::after{background:var(--green);}
.prog-step.active .prog-dot{background:var(--qc);border-color:var(--qc);color:#000;box-shadow:0 0 12px rgba(34,197,94,.5);}
.prog-lbl{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;}
.prog-step.done .prog-lbl{color:var(--green);}
.prog-step.active .prog-lbl{color:var(--qc);}
.main-body{flex:1;overflow-y:auto;padding:20px 24px;}
/* ALERTS */
.alert-bar{padding:10px 16px;border-radius:8px;margin-bottom:16px;font-size:12px;font-weight:700;display:flex;align-items:center;gap:8px;}
.alert-s{background:rgba(34,197,94,.1);border:1px solid var(--qc);color:var(--qc);}
.alert-e{background:rgba(255,107,53,.1);border:1px solid var(--accent2);color:var(--accent2);}
/* LANDING */
.land-wrap{max-width:760px;margin:0 auto;}
.land-title{font-family:'Rajdhani',sans-serif;font-size:26px;font-weight:700;color:var(--qc);letter-spacing:3px;text-transform:uppercase;text-align:center;margin-bottom:6px;}
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
/* LIST */
.list-header{display:flex;align-items:center;gap:12px;margin-bottom:18px;padding-bottom:12px;border-bottom:1px solid var(--border);}
.lh-back{font-size:12px;color:var(--muted);text-decoration:none;padding:4px 10px;border:1px solid var(--border);border-radius:8px;transition:all .2s;}
.lh-back:hover{color:var(--accent);border-color:var(--accent);}
.lh-title{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;}
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
.jc-num.ic{color:var(--int);}
.jc-num.ec{color:var(--ext);}
.jc-title{font-size:14px;font-weight:700;margin-bottom:4px;}
.jc-meta{font-size:11px;color:var(--muted);}
.jc-right{display:flex;flex-direction:column;align-items:flex-end;gap:6px;flex-shrink:0;}
.jc-badge{font-size:10px;font-weight:700;padding:3px 10px;border-radius:14px;white-space:nowrap;background:rgba(34,197,94,.12);color:var(--qc);}
.jc-pct{font-size:11px;font-weight:700;}
.pct-bar-sm{width:80px;height:4px;border-radius:2px;background:var(--border);}
.pct-fill-sm{height:100%;border-radius:2px;}
.pct-fill-sm.ic{background:linear-gradient(90deg,var(--int),var(--accent));}
.pct-fill-sm.ec{background:linear-gradient(90deg,var(--ext),var(--green));}
.empty-state{text-align:center;padding:50px 20px;}
.empty-icon{font-size:40px;margin-bottom:12px;opacity:.3;}
.empty-text{color:var(--muted);font-size:13px;}
/* DETAIL */
.detail-banner{display:flex;align-items:center;gap:16px;flex-wrap:wrap;padding:12px 18px;margin-bottom:16px;border-radius:10px;border-left:4px solid;}
.detail-banner.ic{background:rgba(108,99,255,.07);border-color:var(--int);}
.detail-banner.ec{background:rgba(0,180,166,.07);border-color:var(--ext);}
.db-item label{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:1px;display:block;margin-bottom:2px;}
.db-item span{font-size:13px;font-weight:600;}
.stage-pill{background:rgba(34,197,94,.12);color:var(--qc);padding:4px 13px;border-radius:12px;font-size:10px;font-weight:700;border:1px solid rgba(34,197,94,.3);margin-left:auto;}
/* TABS */
.tab-row{display:flex;gap:0;border-bottom:1px solid var(--border);margin-bottom:16px;}
.tab-btn{padding:9px 18px;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:var(--muted);background:none;border:none;cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;transition:all .2s;}
.tab-btn:hover{color:var(--qc);}
.tab-btn.on{color:var(--qc);border-bottom-color:var(--qc);}
/* SECTION */
.sec{background:var(--card);border:1px solid var(--border);border-radius:12px;margin-bottom:14px;overflow:hidden;}
.sec-head{padding:11px 16px;display:flex;align-items:center;gap:10px;border-bottom:1px solid var(--border);background:rgba(255,255,255,.02);}
.sec-icon{width:28px;height:28px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0;}
.sec-title{font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;}
.sec-sub{font-size:10px;color:var(--muted);margin-top:1px;}
.ro-pill{background:rgba(74,92,122,.3);color:var(--muted);font-size:9px;font-weight:700;padding:2px 8px;border-radius:6px;margin-left:auto;}
.sec-body{padding:16px;}
/* SPEC GRID */
.spec-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:9px;}
.sc{background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:9px 12px;}
.sc-lbl{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;font-weight:700;margin-bottom:3px;}
.sc-val{font-size:12px;font-weight:700;color:var(--text);}
.note-box{border-radius:8px;padding:11px 14px;margin-bottom:12px;}
.nb-lbl{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;margin-bottom:5px;}
.nb-body{font-size:12px;color:var(--text);line-height:1.6;}
/* PARTS TABLE */
.pt{width:100%;border-collapse:collapse;font-size:12px;}
.pt th{padding:8px 12px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:1px solid var(--border);text-align:left;}
.pt td{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,.5);vertical-align:middle;}
.pt tr:last-child td{border-bottom:none;}
.pt tr:hover td{background:rgba(255,255,255,.01);}
.ps-done{background:rgba(0,230,118,.12);color:var(--green);padding:2px 8px;border-radius:6px;font-size:9px;font-weight:700;}
.ps-pend{background:rgba(255,193,7,.12);color:#ffc107;padding:2px 8px;border-radius:6px;font-size:9px;font-weight:700;}
.ps-na{background:rgba(80,80,100,.3);color:var(--muted);padding:2px 8px;border-radius:6px;font-size:9px;font-weight:700;}
.vg{display:flex;gap:4px;}
.vb{border:1px solid var(--border);border-radius:6px;padding:4px 9px;font-size:10px;font-weight:700;cursor:pointer;background:transparent;color:var(--muted);transition:all .15s;font-family:'Exo 2',sans-serif;}
.vb.vp:hover,.vb.vp.sel{background:var(--green);color:#000;border-color:var(--green);}
.vb.vf:hover,.vb.vf.sel{background:var(--accent2);color:#000;border-color:var(--accent2);}
.vb.vr:hover,.vb.vr.sel{background:#ffc107;color:#000;border-color:#ffc107;}
.vrem{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:6px;padding:5px 8px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:10px;outline:none;}
.vrem:focus{border-color:var(--qc);}
/* MEAS */
.mt{width:100%;border-collapse:collapse;font-size:12px;}
.mt th{padding:8px 12px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:1px solid var(--border);text-align:left;}
.mt td{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,.5);vertical-align:middle;}
.mt tr:last-child td{border-bottom:none;}
.mi{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:7px;padding:7px 10px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;outline:none;transition:border .2s;}
.mi:focus{border-color:var(--qc);background:rgba(34,197,94,.04);}
.ck-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;padding:10px 12px;}
.ck-item{display:flex;align-items:center;gap:7px;padding:7px 10px;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:7px;cursor:pointer;transition:all .2s;}
.ck-item:hover{border-color:var(--qc);}
.ck-item input[type=checkbox]{accent-color:var(--qc);width:13px;height:13px;}
.ck-item label{font-size:11px;color:var(--muted);cursor:pointer;}
/* DECISION */
.fg{margin-bottom:13px;}
.fg label{display:block;font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px;}
.fc{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:8px;padding:9px 12px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;outline:none;transition:all .2s;}
.fc:focus{border-color:var(--qc);background:rgba(34,197,94,.04);}
.fc option{background:var(--surface);}
textarea.fc{resize:vertical;min-height:80px;}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
.defect-grid{display:grid;grid-template-columns:1fr 1fr;gap:7px;}
.di{display:flex;align-items:center;gap:8px;padding:8px 11px;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;cursor:pointer;transition:all .15s;}
.di:hover{border-color:var(--qc);background:rgba(34,197,94,.04);}
.di input[type=checkbox]{accent-color:var(--qc);width:13px;height:13px;}
.di label{font-size:11px;color:var(--muted);cursor:pointer;}
/* ACTIONS */
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:6px;position:sticky;bottom:0;background:var(--card);padding:12px 0 4px;z-index:10;border-top:1px solid var(--border);}
.btn{padding:10px 22px;border-radius:9px;font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;cursor:pointer;border:none;display:inline-flex;align-items:center;gap:7px;transition:all .2s;}
.btn-approve{background:linear-gradient(135deg,var(--qc),#15803d);color:#000;box-shadow:0 4px 14px rgba(34,197,94,.25);}
.btn-approve:hover{transform:translateY(-2px);}
.btn-reject{background:linear-gradient(135deg,#dc2626,#b91c1c);color:#fff;}
.btn-reject:hover{transform:translateY(-2px);}
.btn-cond{background:linear-gradient(135deg,#d97706,#b45309);color:#000;}
.btn-cond:hover{transform:translateY(-2px);}
.btn-draft{background:transparent;border:1px solid var(--border);color:var(--muted);}
.btn-draft:hover{border-color:var(--accent);color:var(--accent);}
/* HISTORY TABLE */
.ht{width:100%;border-collapse:collapse;font-size:12px;}
.ht th{padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;}
.ht td{padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);}
.ht tr:last-child td{border-bottom:none;}
.ha-app{background:rgba(34,197,94,.12);color:var(--green);padding:2px 9px;border-radius:8px;font-size:10px;font-weight:700;}
.ha-rej{background:rgba(220,38,38,.12);color:#f87171;padding:2px 9px;border-radius:8px;font-size:10px;font-weight:700;}
.ha-cond{background:rgba(217,119,6,.12);color:#fbbf24;padding:2px 9px;border-radius:8px;font-size:10px;font-weight:700;}
/* RIGHT SIDEBAR */
.sb-right{width:220px;min-width:220px;background:var(--surface);border-left:1px solid var(--border);display:flex;flex-direction:column;overflow:hidden;}
.sbr-team{flex:0 0 auto;border-bottom:2px solid var(--border);}
.sbr-head{padding:10px 14px;background:rgba(255,255,255,.02);border-bottom:1px solid var(--border);}
.sbr-head-title{font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;display:flex;align-items:center;justify-content:space-between;}
.sbr-head-cnt{background:var(--qc);color:#000;border-radius:8px;padding:1px 7px;font-size:9px;font-weight:800;}
.team-scroll{max-height:240px;overflow-y:auto;}
.tm-row{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,.5);display:flex;align-items:center;gap:9px;}
.tm-av{width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:800;flex-shrink:0;color:#fff;}
.tm-info{flex:1;min-width:0;}
.tm-name{font-size:11px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.tm-sub{font-size:9px;color:var(--muted);margin-top:1px;}
.tm-status{display:flex;align-items:center;gap:4px;margin-top:2px;}
.tm-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;}
.tm-stxt{font-size:9px;font-weight:700;}
.tm-you{font-size:8px;padding:1px 5px;border-radius:6px;background:rgba(34,197,94,.15);color:var(--qc);font-weight:700;flex-shrink:0;}
.sbr-hist{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.htabs{display:flex;border-bottom:1px solid var(--border);flex-shrink:0;}
.htab{flex:1;padding:8px 4px;text-align:center;font-size:9px;font-weight:700;cursor:pointer;color:var(--muted);transition:all .2s;letter-spacing:.5px;text-transform:uppercase;border-bottom:2px solid transparent;margin-bottom:-1px;}
.htab:hover{background:rgba(255,255,255,.02);}
.htab.hi{color:var(--int);border-color:var(--int);}
.htab.he{color:var(--ext);border-color:var(--ext);}
.hbody{flex:1;overflow-y:auto;}
.hi-item{padding:8px 12px;border-bottom:1px solid rgba(30,45,69,.4);}
.hi-num{font-size:10px;font-weight:700;font-family:'Rajdhani',sans-serif;}
.hi-num.int{color:var(--int);}
.hi-num.ext{color:var(--ext);}
.hi-title{font-size:11px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:190px;margin:2px 0;}
.hi-badge{font-size:9px;font-weight:700;padding:1px 7px;border-radius:6px;display:inline-block;}
.hib-app{background:rgba(34,197,94,.12);color:var(--qc);}
.hib-rej{background:rgba(220,38,38,.12);color:#f87171;}
.hib-cond{background:rgba(217,119,6,.12);color:#fbbf24;}
.hi-empty{padding:16px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;}
/* PROGRESS TRACKER */
.task-progress{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:14px;}
.tp-title{font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;margin-bottom:12px;display:flex;align-items:center;justify-content:space-between;}
.tp-pct{font-size:20px;font-weight:700;color:var(--qc);}
.tp-bar{height:10px;background:var(--border);border-radius:6px;margin-bottom:12px;overflow:hidden;}
.tp-fill{height:100%;border-radius:6px;background:linear-gradient(90deg,var(--qc),var(--accent),var(--green));transition:width .4s;}
.tp-stages{display:flex;gap:8px;flex-wrap:wrap;}
.tp-stage{font-size:10px;font-weight:700;padding:4px 12px;border-radius:20px;cursor:pointer;border:1px solid;transition:all .2s;}
.tp-stage.ns{color:var(--muted);border-color:var(--border);background:transparent;}
.tp-stage.active{color:#ffc107;border-color:#ffc107;background:rgba(255,193,7,.1);}
.tp-stage.done{color:var(--qc);border-color:var(--qc);background:rgba(34,197,94,.08);}
.sec-badge{font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;margin-left:auto;background:rgba(80,80,100,.2);color:var(--muted);}
</style>
</head>
<body>

<!-- TOPBAR -->
<div class="topbar">
  <div class="tb-logo">AUTO<span>PROD</span></div>
  <div class="tb-sep"></div>
  <div class="tb-title">QC Module</div>
  <% if (!"admin".equals(role) && qcVehicleType != null) { %>
  <span class="tb-badge cat">&#127937; <%= qcVehicleLabel %></span>
  <% if (qcSlot > 0) { %><span class="tb-badge slot">Slot <%= qcSlot %></span><% } %>
  <% } %>
  <div class="tb-right">
    <span class="tb-user">&#128737; <strong><%= qcName %></strong></span>
    <a href="<%= request.getContextPath() %>/logout" class="tb-logout"><i class="fas fa-sign-out-alt"></i> Logout</a>
  </div>
</div>

<div class="layout">

<!-- ══ MAIN ══ -->
<div class="main">

  <!-- Progress tracker -->
  <div class="main-progress">
    <div class="prog-track">
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Request</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Approved</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Design</div></div>
      <div class="prog-step active"><div class="prog-dot">4</div><div class="prog-lbl">QC</div></div>
      <div class="prog-step"><div class="prog-dot">5</div><div class="prog-lbl">Testing</div></div>
      <div class="prog-step"><div class="prog-dot">6</div><div class="prog-lbl">Analytics</div></div>
      <div class="prog-step"><div class="prog-dot">7</div><div class="prog-lbl">Final</div></div>
    </div>
  </div>

  <div class="main-body">

    <!-- Alerts -->
    <% if (success != null && !success.isEmpty()) { %>
    <div class="alert-bar alert-s"><i class="fas fa-check-circle"></i> <%= success %></div>
    <% } %>
    <% if (error != null && !error.isEmpty()) { %>
    <div class="alert-bar alert-e"><i class="fas fa-exclamation-triangle"></i> <%= error %></div>
    <% } %>

    <%-- ════ LANDING ════ --%>
    <% if (showLanding) { %>
    <div class="land-wrap">
      <div style="text-align:center;margin-bottom:20px;">
        <a href="<%= request.getContextPath() %>/dashboard.jsp"
           style="display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;margin-bottom:16px;transition:all .2s;"
           onmouseover="this.style.color='var(--accent)';this.style.borderColor='var(--accent)';"
           onmouseout="this.style.color='var(--muted)';this.style.borderColor='var(--border)';">
          <i class="fas fa-arrow-left"></i> Back to Dashboard
        </a>
        <div class="land-title">QC Module</div>
        <div class="land-sub">Choose your inspection stream to begin.</div>
        <% if (!"admin".equals(role) && qcVehicleType != null) { %>
        <span class="land-cat-badge" style="background:rgba(34,197,94,.1);border:1px solid var(--qc);color:var(--qc);">&#128737; Your Pool: <%= qcVehicleLabel %> &nbsp;&middot;&nbsp; Slot <%= qcSlot %></span>
        <% } else if (!"admin".equals(role) && qcVehicleType == null) { %>
        <span class="land-cat-badge" style="background:rgba(255,107,53,.1);border:1px solid var(--accent2);color:var(--accent2);">&#9888; No pool assigned &mdash; contact admin</span>
        <% } %>
      </div>
      <div class="surf-cards">
        <a href="<%= request.getContextPath() %>/qc?surface=internal" class="surf-card ic">
          <div class="sc-icon">&#127981;</div>
          <div class="sc-title ic">Internal QC</div>
          <div class="sc-desc">Quality control for internal manufacturing jobs.<br>Review design specs, components and measurements.</div>
          <span class="sc-count ic"><%= myIntJobs.size() %> job<%= myIntJobs.size()!=1?"s":"" %> in queue</span>
        </a>
        <a href="<%= request.getContextPath() %>/qc?surface=external" class="surf-card ec">
          <div class="sc-icon">&#129309;</div>
          <div class="sc-title ec">External QC</div>
          <div class="sc-desc">Quality control for customer orders &amp; requirements.<br>Bulk orders and individual customer requests.</div>
          <span class="sc-count ec"><%= myExtJobs.size() %> job<%= myExtJobs.size()!=1?"s":"" %> in queue</span>
        </a>
      </div>
    </div>

    <%-- ════ INTERNAL LIST ════ --%>
    <% } else if (showIntList) { %>
    <div class="list-header">
      <a href="<%= request.getContextPath() %>/qc" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:var(--int);">&#127981; Internal QC Jobs</div>
      <% if (qcVehicleType!=null && !"admin".equals(role)) { %>
      <span style="font-size:11px;color:var(--muted);">&#8212; <%= qcVehicleLabel %></span>
      <% } %>
    </div>
    <% if (myIntJobs.isEmpty()) { %>
    <div class="empty-state"><div class="empty-icon">&#127981;</div><p class="empty-text">No internal jobs assigned to you yet.<br>Jobs will appear here when designers submit their work.</p></div>
    <% } else { for (Object[] j : myIntJobs) {
        int jid=(Integer)j[0]; String jref=(String)j[2]; String jtit=(String)j[3];
        String jvt=(String)j[4]; String jbrand=(String)j[5];
        String jdead=(String)j[6]; String jqty=(String)j[7];
        int jpct=(Integer)j[8]; String jdes=(String)j[9];
        String abbr=jbrand.length()>=3?jbrand.substring(0,3).toUpperCase():jbrand.toUpperCase();
        String pctCol=jpct>=100?"var(--green)":jpct>0?"#ffc107":"var(--accent)";
        String qcBadgeTxt = jpct>=100?"&#9745; QC Complete":jpct>0?"&#128203; QC In Progress":"&#9651; Pending QC";
        String qcBadgeStyle = jpct>=100?"background:rgba(34,197,94,.15);color:var(--qc);":jpct>0?"background:rgba(255,193,7,.12);color:#ffc107;":"background:rgba(0,200,255,.1);color:var(--accent);";
    %>
    <a href="<%= request.getContextPath() %>/qc?reqId=<%= jid %>&src=internal&surface=internal" class="job-card ic">
      <div class="jc-icon ic"><%= abbr.isEmpty()?"INT":abbr %></div>
      <div class="jc-body">
        <div class="jc-num ic"><%= jref %> &nbsp;&middot;&nbsp; <span style="color:var(--muted);"><%= jvt.replace("_"," ").toUpperCase() %></span></div>
        <div class="jc-title"><%= jtit %></div>
        <div class="jc-meta">&#127950; <%= jbrand %> &nbsp;&nbsp; &#128230; Qty: <%= jqty %> &nbsp;&nbsp; &#9997; @<%= jdes %> &nbsp;&nbsp; &#8987; <%= jdead %></div>
      </div>
      <div class="jc-right">
        <span class="jc-badge" style="<%= qcBadgeStyle %>"><%= qcBadgeTxt %></span>
        <span class="jc-pct" style="color:<%= pctCol %>;"><%= jpct %>% QC</span>
        <div class="pct-bar-sm"><div class="pct-fill-sm ic" style="width:<%= jpct %>%"></div></div>
      </div>
    </a>
    <% } } %>

    <%-- ════ EXTERNAL LIST ════ --%>
    <% } else if (showExtList) { %>
    <div class="list-header">
      <a href="<%= request.getContextPath() %>/qc" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:var(--ext);">&#129309; External QC Jobs</div>
    </div>
    <% if (myExtJobs.isEmpty()) { %>
    <div class="empty-state"><div class="empty-icon">&#129309;</div><p class="empty-text">No external jobs assigned to you yet.<br>Jobs will appear here when designers submit their work.</p></div>
    <% } else { for (Object[] r : myExtJobs) {
        int rid=(Integer)r[0]; String rsrc=(String)r[1]; String rref=(String)r[2];
        String rtit=(String)r[3]; String rvt=(String)r[4]; String rclient=(String)r[5];
        String rdead=(String)r[6]; int rpct=(Integer)r[8]; String rdes=(String)r[9];
        String pctCol=rpct>=100?"var(--green)":rpct>0?"#ffc107":"var(--accent)";
        String clientAbbr=rclient!=null&&rclient.length()>=3?rclient.substring(0,3).toUpperCase():"EXT";
        String qcBadgeTxt2 = rpct>=100?"&#9745; QC Complete":rpct>0?"&#128203; QC In Progress":"&#9651; Pending QC";
        String qcBadgeStyle2 = rpct>=100?"background:rgba(0,180,166,.2);color:var(--ext);":rpct>0?"background:rgba(255,193,7,.12);color:#ffc107;":"background:rgba(0,180,166,.08);color:var(--ext);";
    %>
    <a href="<%= request.getContextPath() %>/qc?reqId=<%= rid %>&src=<%= rsrc %>&surface=external" class="job-card ec">
      <div class="jc-icon ec"><%= clientAbbr %></div>
      <div class="jc-body">
        <div class="jc-num ec"><%= rref %> &nbsp;&middot;&nbsp; <span style="color:var(--muted);"><%= rvt.replace("_"," ").toUpperCase() %></span></div>
        <div class="jc-title"><%= rtit %></div>
        <div class="jc-meta">&#128101; <%= rclient %> &nbsp;&nbsp; &#9997; @<%= rdes %> &nbsp;&nbsp; &#8987; <%= rdead %></div>
      </div>
      <div class="jc-right">
        <span class="jc-badge" style="<%= qcBadgeStyle2 %>"><%= qcBadgeTxt2 %></span>
        <span class="jc-pct" style="color:<%= pctCol %>;"><%= rpct %>% QC</span>
        <div class="pct-bar-sm"><div class="pct-fill-sm ec" style="width:<%= rpct %>%"></div></div>
      </div>
    </a>
    <% } } %>

    <%-- ════ DETAIL / INSPECTION FORM ════ --%>
    <% } else if (showDetail) {
        boolean isInt = "internal".equals(selSrc);
        String detailBannerCls = isInt ? "ic" : "ec";
        String detailColor = isInt ? "var(--int)" : "var(--ext)";
    %>
    <!-- Back + Detail Banner -->
    <div class="list-header" style="margin-bottom:12px;">
      <a href="<%= backLink %>" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:<%= detailColor %>;">
        <%= isInt?"&#127981; Internal":"&#129309; External" %> QC Inspection
      </div>
    </div>

    <!-- DRAFT RESTORED BANNER -->
    <div id="draft-restored-banner" style="display:none;background:rgba(34,197,94,.08);border:1px solid rgba(34,197,94,.3);border-radius:10px;padding:10px 16px;margin-bottom:14px;align-items:center;gap:10px;">
      <i class="fas fa-history" style="color:var(--qc);"></i>
      <span style="font-size:12px;color:var(--qc);font-weight:600;">Draft restored &#8212; your previous inspection notes have been reloaded.</span>
      <button onclick="document.getElementById('draft-restored-banner').style.display='none'" style="margin-left:auto;background:none;border:none;color:var(--muted);cursor:pointer;font-size:14px;">&times;</button>
    </div>

    <div class='detail-banner <%= detailBannerCls %>'>
      <div class="db-item"><label>Job Ref</label><span style="color:<%= detailColor %>;font-family:'Rajdhani',sans-serif;"><%= sel_ref %></span></div>
      <div class="db-item"><label>Model</label><span><%= sel_title %></span></div>
      <div class="db-item"><label>Vehicle Type</label><span><%= sel_vtype.replace("_"," ") %></span></div>
      <div class="db-item"><label>Designer</label><span>@<%= ds_designer %></span></div>
      <div class="db-item"><label>Design %</label><span style="color:var(--qc);"><%= ds_pct %>%</span></div>
      <span class="stage-pill">&#9679; Design Complete</span>
    </div>

    <!-- TASK PROGRESS TRACKER -->
    <div class="task-progress">
      <div class="tp-title">
        QC Inspection Progress
        <div style="display:flex;align-items:center;gap:10px;">
          <span id="top-save-status" style="font-size:11px;color:var(--muted);"></span>
          <button type="button" class="btn btn-draft" style="padding:5px 14px;font-size:11px;" onclick="saveDraft()">
            <i class="fas fa-save"></i> Save Draft
          </button>
          <span class="tp-pct" id="tp-pct">0%</span>
        </div>
      </div>
      <div class="tp-bar"><div class="tp-fill" id="tp-fill" style="width:0%"></div></div>
      <div class="tp-stages">
        <span class="tp-stage ns" id="st0">&#128270; Reviewing Design</span>
        <span class="tp-stage ns" id="st25">&#9989; Inspecting Parts (25%)</span>
        <span class="tp-stage ns" id="st50">&#128207; Measurements (50%)</span>
        <span class="tp-stage ns" id="st75">&#128203; Decision (75%)</span>
        <span class="tp-stage ns" id="st100">&#9745; QC Complete (100%)</span>
      </div>
    </div>

    <!-- TABS -->
    <div class="tab-row">
      <button class="tab-btn on" onclick="qcTab('form',this)"><i class="fas fa-clipboard-check"></i> Inspection Form</button>
      <button class="tab-btn"    onclick="qcTab('hist',this)"><i class="fas fa-history"></i>
        <%= isInt?"Internal":"External" %> History
      </button>
    </div>

    <!-- ═══ INSPECTION FORM ═══ -->
    <div id="qc-form">
    <form method="post" action="<%= request.getContextPath() %>/jsp/save_qc_work.jsp" enctype="multipart/form-data" id="qcForm">
      <input type="hidden" name="jobId"           value="<%= selId %>">
      <input type="hidden" name="srcType"          value="<%= selSrc %>">
      <input type="hidden" name="action"           id="qcAction" value="approved">
      <input type="hidden" name="qcVerdicts"       id="qcVerdictsInput" value="">
      <input type="hidden" name="complianceChecks" id="complianceInput" value="">

      <!-- SECTION 1: DESIGN SPECS -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--qc);">
          <div class="sec-icon" style="background:rgba(34,197,94,.12);">&#128196;</div>
          <div><div class="sec-title" style="color:var(--qc);">Section 1 &#8212; Design Specifications</div>
          <div class="sec-sub">Designer&#39;s submitted work &#8212; read only</div></div>
          <span class="ro-pill">READ ONLY</span>
          <span class="sec-badge" id="badge-s1">0%</span>
        </div>
        <div class="sec-body">
          <% if (!ds_overview.equals("—") && !ds_overview.isEmpty()) { %>
          <div class="note-box" style="background:rgba(34,197,94,.04);border:1px solid rgba(34,197,94,.2);">
            <div class="nb-lbl" style="color:var(--qc);">&#128221; Design Overview</div>
            <div class="nb-body"><%= ds_overview %></div>
          </div>
          <% } %>
          <div class="spec-grid" style="margin-bottom:12px;">
            <div class="sc"><div class="sc-lbl">Design Title</div><div class="sc-val"><%= ds_title %></div></div>
            <div class="sc"><div class="sc-lbl">Sub Category</div><div class="sc-val"><%= ds_subCat %></div></div>
            <div class="sc"><div class="sc-lbl">Version</div><div class="sc-val"><%= ds_version %></div></div>
            <div class="sc"><div class="sc-lbl">Engine Type</div><div class="sc-val"><%= ds_engine %></div></div>
            <div class="sc"><div class="sc-lbl">Displacement</div><div class="sc-val"><%= ds_disp %> cc</div></div>
            <div class="sc"><div class="sc-lbl">Cylinders</div><div class="sc-val"><%= ds_cyl %></div></div>
            <div class="sc"><div class="sc-lbl">Max Power</div><div class="sc-val"><%= ds_power %></div></div>
            <div class="sc"><div class="sc-lbl">Max Torque</div><div class="sc-val"><%= ds_torque %></div></div>
            <div class="sc"><div class="sc-lbl">Transmission</div><div class="sc-val"><%= ds_trans %></div></div>
            <div class="sc"><div class="sc-lbl">Length (mm)</div><div class="sc-val"><%= ds_len %></div></div>
            <div class="sc"><div class="sc-lbl">Width (mm)</div><div class="sc-val"><%= ds_wid %></div></div>
            <div class="sc"><div class="sc-lbl">Height (mm)</div><div class="sc-val"><%= ds_hei %></div></div>
            <div class="sc"><div class="sc-lbl">Wheelbase (mm)</div><div class="sc-val"><%= ds_wb %></div></div>
            <div class="sc"><div class="sc-lbl">Kerb Weight (kg)</div><div class="sc-val"><%= ds_kw %></div></div>
            <div class="sc"><div class="sc-lbl">Capacity</div><div class="sc-val"><%= ds_cap %></div></div>
          </div>
          <% if (!ds_remarks.equals("—") && !ds_remarks.isEmpty()) { %>
          <div class="note-box" style="background:rgba(255,193,7,.04);border:1px solid rgba(255,193,7,.2);">
            <div class="nb-lbl" style="color:#ffc107;">&#128172; Designer Remarks</div>
            <div class="nb-body"><%= ds_remarks %></div>
          </div>
          <% } %>

          <%-- Designer Documents --%>
          <% boolean hasBlueprint = !ds_blueprint.equals("—") && !ds_blueprint.isEmpty();
             boolean hasModel3d   = !ds_model3d.equals("—")   && !ds_model3d.isEmpty();
             boolean hasExtras    = !ds_extraFiles.equals("—") && !ds_extraFiles.isEmpty();
             if (hasBlueprint || hasModel3d || hasExtras) { %>
          <div class="note-box" style="background:rgba(108,99,255,.05);border:1px solid rgba(108,99,255,.25);margin-top:10px;">
            <div class="nb-lbl" style="color:var(--int);">&#128206; Designer Documents &amp; Files</div>
            <div style="display:flex;flex-wrap:wrap;gap:10px;margin-top:8px;">
              <% if (hasBlueprint) {
                   String bpName = ds_blueprint.contains("_") ? "Blueprint / CAD File" : ds_blueprint;
                   String bpExt  = ds_blueprint.contains(".") ? ds_blueprint.substring(ds_blueprint.lastIndexOf(".")).toLowerCase() : "";
                   String bpIcon = bpExt.equals(".pdf") ? "&#128196;" : bpExt.equals(".png")||bpExt.equals(".jpg")||bpExt.equals(".jpeg") ? "&#128444;" : "&#128196;";
              %>
              <a href="<%= request.getContextPath() %>/uploads/design/<%= ds_blueprint %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:8px 14px;background:rgba(108,99,255,.1);border:1px solid rgba(108,99,255,.3);border-radius:8px;text-decoration:none;color:var(--int);font-size:12px;font-weight:600;transition:all .2s;"
                 onmouseover="this.style.background='rgba(108,99,255,.2)'" onmouseout="this.style.background='rgba(108,99,255,.1)'">
                <%= bpIcon %> Blueprint / CAD File
                <span style="font-size:9px;background:rgba(108,99,255,.3);padding:1px 6px;border-radius:4px;"><%= bpExt.isEmpty()?"FILE":bpExt.substring(1).toUpperCase() %></span>
              </a>
              <% } %>
              <% if (hasModel3d) {
                   String tdExt = ds_model3d.contains(".") ? ds_model3d.substring(ds_model3d.lastIndexOf(".")).toLowerCase() : "";
              %>
              <a href="<%= request.getContextPath() %>/uploads/design/<%= ds_model3d %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:8px 14px;background:rgba(0,200,255,.07);border:1px solid rgba(0,200,255,.25);border-radius:8px;text-decoration:none;color:var(--accent);font-size:12px;font-weight:600;transition:all .2s;"
                 onmouseover="this.style.background='rgba(0,200,255,.15)'" onmouseout="this.style.background='rgba(0,200,255,.07)'">
                &#128347; 3D Model File
                <span style="font-size:9px;background:rgba(0,200,255,.2);padding:1px 6px;border-radius:4px;"><%= tdExt.isEmpty()?"FILE":tdExt.substring(1).toUpperCase() %></span>
              </a>
              <% } %>
              <% if (hasExtras) {
                   String[] extraArr = ds_extraFiles.split(",");
                   for (String ef : extraArr) {
                       if (ef.trim().isEmpty()) continue;
                       String[] parts2 = ef.trim().split("\\|");
                       String efFile = parts2[0];
                       String efOrig = parts2.length > 1 ? parts2[1] : efFile;
                       String efExt  = efFile.contains(".") ? efFile.substring(efFile.lastIndexOf(".")).toLowerCase() : "";
                       String efIcon = efExt.equals(".pdf")?"&#128196;":efExt.equals(".png")||efExt.equals(".jpg")?"&#128444;":"&#128196;";
              %>
              <a href="<%= request.getContextPath() %>/uploads/design/<%= efFile %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:8px 14px;background:rgba(34,197,94,.06);border:1px solid rgba(34,197,94,.25);border-radius:8px;text-decoration:none;color:var(--qc);font-size:12px;font-weight:600;transition:all .2s;max-width:280px;"
                 onmouseover="this.style.background='rgba(34,197,94,.14)'" onmouseout="this.style.background='rgba(34,197,94,.06)'">
                <%= efIcon %> <span style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:180px;"><%= efOrig %></span>
                <span style="font-size:9px;background:rgba(34,197,94,.2);padding:1px 6px;border-radius:4px;flex-shrink:0;"><%= efExt.isEmpty()?"FILE":efExt.substring(1).toUpperCase() %></span>
              </a>
              <% } } %>
            </div>
          </div>
          <% } %>

          <%-- QC Reference Documents Upload — only show if designer didn't upload files --%>
          <% if (!hasBlueprint && !hasModel3d && !hasExtras) { %>
          <div style="margin-top:12px;background:rgba(74,92,122,.08);border:1px dashed rgba(74,92,122,.4);border-radius:10px;padding:14px 16px;">
            <div style="font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">
              &#128196; No designer files attached &mdash;
              <span style="font-weight:400;text-transform:none;letter-spacing:0;color:var(--muted);">
                You can upload your own reference documents below
              </span>
            </div>
            <div id="qcDocsPreview" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:10px;"></div>
            <label style="display:inline-flex;align-items:center;gap:8px;padding:7px 14px;background:rgba(74,92,122,.1);border:1px dashed rgba(74,92,122,.5);border-radius:8px;cursor:pointer;font-size:12px;color:var(--muted);font-weight:600;transition:all .2s;"
                   onmouseover="this.style.color='var(--text)';this.style.borderColor='var(--muted)';"
                   onmouseout="this.style.color='var(--muted)';this.style.borderColor='rgba(74,92,122,.5)';">
              <i class="fas fa-paperclip"></i> Attach Reference Files
              <input type="file" id="qcDocFiles" name="qcDocFiles" multiple
                     accept=".pdf,.png,.jpg,.jpeg,.dwg,.zip,.doc,.docx,.xls,.xlsx"
                     style="display:none;" onchange="previewQcDocs(this)">
            </label>
            <span style="font-size:10px;color:var(--muted);margin-left:8px;">PDF, PNG, JPG, DWG, ZIP — max 10MB each</span>
          </div>
          <% } else { %>
          <div id="qcDocsPreview" style="display:none;"></div>
          <input type="file" id="qcDocFiles" name="qcDocFiles" multiple style="display:none;" onchange="previewQcDocs(this)">
          <% } %>
        </div>
      </div>

      <!-- SECTION 2: COMPONENT CHECKLIST -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid #ffc107;">
          <div class="sec-icon" style="background:rgba(255,193,7,.12);">&#9989;</div>
          <div><div class="sec-title" style="color:#ffc107;">Section 2 &#8212; Component Inspection</div>
          <div class="sec-sub">Pass / Fail / Needs Rework for each part</div></div>
          <span class="sec-badge" id="badge-s2">0%</span>
        </div>
        <div style="padding:0;">
          <table class="pt" id="partsTable">
            <thead><tr>
              <th style="width:34px;">#</th><th>Component</th>
              <th style="width:100px;">Designer Status</th>
              <th style="width:200px;">QC Verdict</th>
              <th>Inspector Note</th>
            </tr></thead>
            <tbody id="partsTbody">
              <tr><td colspan="5" style="text-align:center;padding:16px;color:var(--muted);font-style:italic;">Loading checklist...</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- SECTION 3: MEASUREMENTS -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--accent);">
          <div class="sec-icon" style="background:rgba(0,200,255,.12);">&#128207;</div>
          <div><div class="sec-title" style="color:var(--accent);">Section 3 &#8212; QC Measurements</div>
          <div class="sec-sub">Actual vs design spec &#8212; 5% tolerance auto-check</div></div>
          <span class="sec-badge" id="badge-s3">0%</span>
        </div>
        <div style="padding:0;">
          <table class="mt">
            <thead><tr>
              <th>Parameter</th><th style="width:140px;">Design Spec</th>
              <th style="width:150px;">Actual Measured</th><th style="width:110px;">Result</th>
            </tr></thead>
            <tbody>
            <% String[][] measRows={{"Length (mm)",ds_len,"meas_length","res_len"},
                {"Width (mm)",ds_wid,"meas_width","res_wid"},
                {"Height (mm)",ds_hei,"meas_height","res_hei"},
                {"Wheelbase (mm)",ds_wb,"meas_wheelbase","res_wb"},
                {"Kerb Weight (kg)",ds_kw,"meas_weight","res_kw"},
                {"Displacement (cc)",ds_disp,"meas_disp","res_disp"}};
            for (String[] mr : measRows) { %>
            <tr>
              <td style="font-weight:600;"><%= mr[0] %></td>
              <td style="color:var(--muted);"><%= mr[1] %></td>
              <td><input type="text" class="mi" name="<%= mr[2] %>" placeholder="Enter actual"
                         data-design="<%= mr[1] %>" data-resid="<%= mr[3] %>" oninput="checkMeas(this)"></td>
              <td><span id="<%= mr[3] %>" style="font-size:11px;font-weight:700;color:var(--muted);">&#8212;</span></td>
            </tr>
            <% } %>
            <tr><td colspan="4" style="padding:8px 12px;background:rgba(255,255,255,.02);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;">&#128737; Safety &amp; Compliance</td></tr>
            <tr><td colspan="4" style="padding:0;">
              <div class="ck-grid">
                <% String[][] cks={{"c1","AIS Standards"},{"c2","BIS Compliance"},{"c3","Emission Norms"},{"c4","Crash Safety"},{"c5","Noise Standards"},{"c6","Material Quality"}};
                for (String[] ck : cks) { %>
                <div class="ck-item"><input type="checkbox" id="<%= ck[0] %>" name="compliance" value="<%= ck[1] %>">
                <label for="<%= ck[0] %>"><%= ck[1] %></label></div>
                <% } %>
              </div>
            </td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- SECTION 4: QC DECISION -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--purple);">
          <div class="sec-icon" style="background:rgba(124,92,252,.12);">&#128203;</div>
          <div><div class="sec-title" style="color:var(--purple);">Section 4 &#8212; Overall QC Decision</div>
          <div class="sec-sub">Final verdict &#8212; updates workflow stage</div></div>
          <span class="sec-badge" id="badge-s4">0%</span>
        </div>
        <div class="sec-body">
          <div class="grid2" style="margin-bottom:13px;">
            <div class="fg">
              <label>&#9888; Severity Level</label>
              <select name="severity" id="sevSel" class="fc">
                <option value="None">None &#8212; No defects</option>
                <option value="Minor">Minor &#8212; Small issues</option>
                <option value="Major">Major &#8212; Significant issues</option>
                <option value="Critical">Critical &#8212; Must fix before approval</option>
              </select>
            </div>
            <div class="fg">
              <label>&#128203; Overall Remarks <span style="color:var(--accent2);">*</span></label>
              <select name="remarks" class="fc">
                <option value="All checks passed">&#9989; All checks passed</option>
                <option value="Minor cosmetic issues noted">Minor cosmetic issues noted</option>
                <option value="Approved with conditions">Approved with conditions</option>
                <option value="Requires rework on specific parts">Requires rework on specific parts</option>
                <option value="Failed safety standards">Failed safety standards</option>
                <option value="Dimensional mismatch found">Dimensional mismatch found</option>
                <option value="Material quality not acceptable">Material quality not acceptable</option>
                <option value="Refer to senior engineer">Refer to senior engineer</option>
              </select>
            </div>
          </div>
          <div class="fg">
            <label>&#128221; Inspector Notes <span style="color:var(--accent2);">*</span></label>
            <textarea name="inspector_notes" id="inspNotes" class="fc" required
              placeholder="Detailed observations, measurements, defects found, recommendations..."></textarea>
          </div>
          <div class="fg">
            <label>&#128295; Defect Categories</label>
            <div class="defect-grid">
              <% String[][] defs={{"d1","Structural"},{"d2","Electrical / Electronics"},{"d3","Mechanical / Drivetrain"},{"d4","Cosmetic / Exterior"},{"d5","Safety Systems"},{"d6","Dimensional Mismatch"}};
              for (String[] df : defs) { %>
              <div class="di"><input type="checkbox" name="defects" id="<%= df[0] %>" value="<%= df[1] %>">
              <label for="<%= df[0] %>"><%= df[1] %></label></div>
              <% } %>
            </div>
          </div>
          <div class="fg">
            <label>&#128247; Evidence Photo <span style="font-weight:400;color:var(--muted);">(optional &#183; JPG/PNG &#183; max 5MB)</span></label>
            <input type="file" name="qcPhoto" accept="image/jpeg,image/png,image/webp"
                   style="width:100%;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:8px 12px;color:var(--muted);font-family:'Exo 2',sans-serif;cursor:pointer;"
                   onchange="prevPhoto(this)">
            <div id="photoPrev" style="display:none;margin-top:8px;border-radius:8px;overflow:hidden;border:1px solid var(--border);max-height:140px;">
              <img id="photoPrevImg" src="" alt="" style="width:100%;height:140px;object-fit:cover;">
            </div>
          </div>
          <!-- ACTION BUTTONS -->
          <div class="actions">
            <button type="button" class="btn btn-approve" onclick="submitQC('approved')">
              <i class="fas fa-check"></i> Approve &#8212; Send to Testing
            </button>
            <button type="button" class="btn btn-reject" onclick="submitQC('qc_rejected')">
              <i class="fas fa-times"></i> Reject &#8212; Back to Designer
            </button>
            <button type="button" class="btn btn-cond" onclick="submitQC('qc_conditional')">
              <i class="fas fa-exclamation-triangle"></i> Conditional Approval
            </button>
            <button type="button" class="btn btn-draft" style="margin-left:auto;" onclick="saveDraft(false)">
              <i class="fas fa-save"></i> Save Draft
            </button>
          </div>
        </div>
      </div>
    </form>
    </div><!-- /qc-form -->

    <!-- ═══ HISTORY TAB ═══ -->
    <div id="qc-hist" style="display:none;">
    <div class="sec">
      <div class="sec-head">
        <div class="sec-icon" style="background:rgba(124,92,252,.12);">&#128203;</div>
        <div><div class="sec-title"><%= isInt?"Internal":"External" %> QC History</div>
        <div class="sec-sub">Past approvals, rejections &amp; conditional decisions</div></div>
      </div>
      <div style="overflow-x:auto;">
        <table class="ht">
          <thead><tr><th>#</th><th>Job Ref</th><th>Model</th><th>Decision</th><th>Remarks</th><th>Officer</th><th>Date</th></tr></thead>
          <tbody>
          <%
          List<Object[]> showHist = isInt ? histInt : histExt;
          if (showHist.isEmpty()) { %>
          <tr><td colspan="7" style="text-align:center;padding:28px;color:var(--muted);font-style:italic;">No QC decisions recorded yet.</td></tr>
          <% }
          int hi=1; for (Object[] h : showHist) {
              String ha=(String)h[2];
              String hcls="approved".equals(ha)?"ha-app":"qc_rejected".equals(ha)?"ha-rej":"ha-cond";
              String hlbl="approved".equals(ha)?"Approved":"qc_rejected".equals(ha)?"Rejected":"Conditional";
              java.sql.Timestamp hdt=(java.sql.Timestamp)h[5];
              String hds=hdt!=null?hdt.toString().substring(0,16):"—";
          %>
          <tr>
            <td style="color:var(--muted);"><%= hi++ %></td>
            <td style='font-weight:700;font-family:"Rajdhani",sans-serif;color:<%= isInt?"var(--int)":"var(--ext)" %>;'><%= h[0] %></td>
            <td style="color:var(--text);"><%= h[1] %></td>
            <td><span class="<%= hcls %>"><%= hlbl %></span></td>
            <td style="font-size:11px;color:var(--muted);max-width:200px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;"><%= h[3]!=null?h[3]:"—" %></td>
            <td><code style="background:rgba(255,255,255,.05);padding:2px 7px;border-radius:5px;font-size:10px;color:var(--muted);">@<%= h[4] %></code></td>
            <td style="font-size:10px;color:var(--muted);"><%= hds %></td>
          </tr>
          <% } %>
          </tbody>
        </table>
      </div>
    </div>
    </div><!-- /qc-hist -->

    <% } // end showDetail %>
  </div><!-- /main-body -->
</div><!-- /main -->

<!-- ══ RIGHT SIDEBAR: QC TEAM + HISTORY ══ -->
<div class="sb-right">
  <!-- TEAM MEMBERS -->
  <div class="sbr-team">
    <div class="sbr-head">
      <div class="sbr-head-title">
        &#128737; <%= qcVehicleLabel %> Team
        <span class="sbr-head-cnt"><%= teamMembers.size() %></span>
      </div>
    </div>
    <div class="team-scroll">
      <% if (teamMembers.isEmpty()) { %>
      <div style="padding:14px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;">No team members</div>
      <% } else { for (Object[] tm : teamMembers) {
          int    tmSlot   = (Integer)   tm[0];
          String tmName   = (String)    tm[1];
          String tmUser   = (String)    tm[2];
          int    tmActive = (Integer)   tm[3];
          java.sql.Timestamp tmLast = (java.sql.Timestamp) tm[4];
          String dotC="#3a3a5a"; String stTxt="Offline"; String stCol="#5a7090";
          if (tmLast != null) {
              long diff = (System.currentTimeMillis()-tmLast.getTime())/60000L;
              if (diff<=5) { dotC="#22c55e"; stTxt="Online"; stCol="#22c55e"; }
              else if (diff<=30) { dotC="#f59e0b"; stTxt="Away "+diff+"m"; stCol="#f59e0b"; }
          }
          boolean isMe = tmUser.equals(qcUser);
          String[] np = tmName.split(" ");
          String ini = "";
          for (String n : np) if (!n.isEmpty()) ini += n.charAt(0);
          if (ini.length()>2) ini = ini.substring(0,2);
          String avBg = isMe ? "linear-gradient(135deg,var(--qc),#15803d)"
                      : (tmSlot==1 ? "linear-gradient(135deg,#6c63ff,#4f46e5)"
                      : tmSlot==2  ? "linear-gradient(135deg,#00b4a6,#008c84)"
                      :              "linear-gradient(135deg,#f59e0b,#b45309)");
      %>
      <div class="tm-row">
        <div class="tm-av" style="background:<%= avBg %>;"><%= ini.toUpperCase() %></div>
        <div class="tm-info">
          <div class="tm-name"><%= tmName %> <% if(isMe){%><span class="tm-you">YOU</span><%}%></div>
          <div class="tm-sub">@<%= tmUser %> &nbsp;&middot;&nbsp; <span style="color:var(--purple);font-weight:700;">Slot <%= tmSlot %></span></div>
          <div class="tm-status">
            <span class="tm-dot" style="background:<%= dotC %>;"></span>
            <span class="tm-stxt" style="color:<%= stCol %>;"><%= stTxt %></span>
          </div>
        </div>
      </div>
      <% } } %>
    </div>
  </div>

  <!-- WORKFLOW HISTORY -->
  <div class="sbr-hist">
    <div style="padding:8px 14px;background:rgba(255,255,255,.02);border-bottom:1px solid var(--border);flex-shrink:0;">
      <div style="font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;">QC History</div>
    </div>
    <div class="htabs">
      <div class="htab hi" id="ht-int" onclick="switchHist('int',this)">&#127981; Internal (<%= histInt.size() %>)</div>
      <div class="htab"    id="ht-ext" onclick="switchHist('ext',this)">&#129309; External (<%= histExt.size() %>)</div>
    </div>
    <div class="hbody">
      <!-- Internal history -->
      <div id="hbody-int">
        <% if (histInt.isEmpty()) { %><div class="hi-empty">No internal history</div>
        <% } else { for (Object[] h : histInt) {
            String hn=(String)h[0]; String ht2=(String)h[1]; String ha=(String)h[2];
            String hcls="approved".equals(ha)?"hib-app":"qc_rejected".equals(ha)?"hib-rej":"hib-cond";
            String hlbl="approved".equals(ha)?"Approved":"qc_rejected".equals(ha)?"Rejected":"Conditional";
        %>
        <div class="hi-item">
          <div class="hi-num int"><%= hn %></div>
          <div class="hi-title"><%= ht2 %></div>
          <span class="hi-badge <%= hcls %>"><%= hlbl %></span>
        </div>
        <% } } %>
      </div>
      <!-- External history -->
      <div id="hbody-ext" style="display:none;">
        <% if (histExt.isEmpty()) { %><div class="hi-empty">No external history</div>
        <% } else { for (Object[] h : histExt) {
            String hn=(String)h[0]; String ht2=(String)h[1]; String ha=(String)h[2];
            String hcls="approved".equals(ha)?"hib-app":"qc_rejected".equals(ha)?"hib-rej":"hib-cond";
            String hlbl="approved".equals(ha)?"Approved":"qc_rejected".equals(ha)?"Rejected":"Conditional";
        %>
        <div class="hi-item">
          <div class="hi-num ext"><%= hn %></div>
          <div class="hi-title"><%= ht2 %></div>
          <span class="hi-badge <%= hcls %>"><%= hlbl %></span>
        </div>
        <% } } %>
      </div>
    </div>
  </div>
</div><!-- /sb-right -->

</div><!-- /layout -->

<script>
var partsData = <%= jsPartsJson %>;
var qcVerdicts = {};
var curQcPct   = 0;

// ── PROGRESS CALCULATION ──
function calcQCProgress() {
    var score = 0;

    // Section 1: Design specs loaded = 15pts (auto if design data present)
    var s1 = parseInt('<%= !ds_title.equals("—") ? "15" : "0" %>');
    score += s1;
    updateBadge('badge-s1', s1, 15);

    // Section 2: Part verdicts — 35pts
    // If no parts checklist from designer, give full credit (not inspector's fault)
    var totalParts = partsData ? partsData.length : 0;
    var s2 = 0;
    if (totalParts === 0) {
        s2 = 35; // no parts to inspect — full credit
    } else {
        var verdictCount = Object.keys(qcVerdicts).filter(function(k){
            return qcVerdicts[k] && qcVerdicts[k].verdict;
        }).length;
        s2 = Math.round((verdictCount / totalParts) * 35);
    }
    updateBadge('badge-s2', s2, 35);
    score += s2;

    // Section 3: Measurements + compliance — 25pts
    // Each measurement = 3pts (6 total = 18pts), each compliance = 1pt (6 total = 7pts max→capped)
    var measInputs = document.querySelectorAll('input[name^="meas_"]');
    var measFilled = 0;
    measInputs.forEach(function(inp){ if (inp.value.trim().length > 0) measFilled++; });
    var compTotal   = document.querySelectorAll('input[name=compliance]').length;
    var compChecked = document.querySelectorAll('input[name=compliance]:checked').length;
    var measScore = measInputs.length > 0 ? Math.round((measFilled / measInputs.length) * 18) : 18;
    var compScore = compTotal > 0 ? Math.round((compChecked / compTotal) * 7) : 7;
    var s3 = Math.min(25, measScore + compScore);
    updateBadge('badge-s3', s3, 25);
    score += s3;

    // Section 4: Decision fields — 25pts
    // Notes (any text) = 8pts, Severity selected ≠ blank = 4pts,
    // Remarks selected ≠ default = 5pts, Defects (any 1+) = 4pts, Photo = 4pts
    var notes    = document.getElementById('inspNotes');
    var sev      = document.getElementById('sevSel');
    var rem      = document.querySelector('select[name=remarks]');
    var defects  = document.querySelectorAll('input[name=defects]:checked').length;
    var photo    = document.querySelector('input[name=qcPhoto]');

    var notesScore  = (notes  && notes.value.trim().length > 0)               ?  8 : 0;
    var sevScore    = (sev    && sev.value && sev.value !== '')                ?  4 : 0;
    var remScore    = (rem    && rem.value && rem.value !== '')                ?  5 : 0;
    var defScore    = defects > 0                                              ?  4 : 0;
    var photoScore  = (photo  && photo.files && photo.files.length > 0)       ?  4 : 0;

    var s4 = Math.min(25, notesScore + sevScore + remScore + defScore + photoScore);
    updateBadge('badge-s4', s4, 25);
    score += s4;

    var pct = Math.min(100, score);
    curQcPct = pct;

    // Update progress bars
    var fill = document.getElementById('tp-fill');
    var lbl  = document.getElementById('tp-pct');
    if (fill) fill.style.width = pct + '%';
    if (lbl)  lbl.textContent  = pct + '%';

    // Stage pills
    [0,25,50,75,100].forEach(function(v,i,arr){
        var el = document.getElementById('st'+v); if (!el) return;
        if (pct>=100 && v===100) el.className='tp-stage active';
        else if (pct>=v && (i===arr.length-1 || pct<arr[i+1])) el.className='tp-stage active';
        else if (pct>v) el.className='tp-stage done';
        else el.className='tp-stage ns';
    });
    return pct;
}

function updateBadge(id,val,max) {
    var el=document.getElementById(id); if(!el) return;
    var pct=max>0?Math.round((val/max)*100):0;
    el.textContent=pct+'%';
    el.style.background=pct>=100?'rgba(34,197,94,.15)':pct>0?'rgba(255,193,7,.12)':'rgba(80,80,100,.2)';
    el.style.color=pct>=100?'var(--qc)':pct>0?'#ffc107':'var(--muted)';
}

// Auto-recalc on any form change
document.addEventListener('change', function(e){ if(e.target.closest&&e.target.closest('#qcForm')){ calcQCProgress(); scheduleAutoSave(); } });
document.addEventListener('input',  function(e){ if(e.target.closest&&e.target.closest('#qcForm')){ calcQCProgress(); scheduleAutoSave(); } });

function scheduleAutoSave(){
    clearTimeout(window._qcAS);
    window._qcAS=setTimeout(function(){ saveDraft(true); },2000);
}

// Save Draft — uses sendBeacon for page-close reliability
function saveDraft(silent) {
    var notes   = document.getElementById('inspNotes');
    var sev     = document.getElementById('sevSel');
    var remarks = document.querySelector('select[name=remarks]');
    var checks  = []; document.querySelectorAll('input[name=compliance]:checked').forEach(function(c){checks.push(c.value);});
    var defs    = []; document.querySelectorAll('input[name=defects]:checked').forEach(function(d){defs.push(d.value);});

    // Collect measurements (Section 3)
    var measFields = ['meas_length','meas_width','meas_height','meas_wheelbase','meas_weight','meas_disp'];
    var measData = {};
    measFields.forEach(function(f){
        var el = document.querySelector('input[name='+f+']');
        if (el) measData[f] = el.value;
    });

    // Collect per-part remark notes (Section 2)
    var partRemarks = {};
    document.querySelectorAll('.vrem').forEach(function(el){
        var id = el.id; // vr_0, vr_1, ...
        if (el.value.trim()) partRemarks[id] = el.value;
    });

    var payload = {
        jobId:           '<%= selId %>',
        srcType:         '<%= selSrc %>',
        qcVerdicts:      qcVerdicts,
        partRemarks:     partRemarks,
        inspector_notes: notes   ? notes.value   : '',
        severity:        sev     ? sev.value      : 'None',
        remarks:         remarks ? remarks.value  : '',
        compliance:      checks.join(','),
        defects:         defs.join(','),
        measurements:    measData,
        progress_pct:    String(curQcPct)
    };
    var url     = '<%= request.getContextPath() %>/jsp/save_qc_draft.jsp';
    var jsonStr = JSON.stringify(payload);

    // Use sendBeacon if available (works even during page unload)
    if (navigator.sendBeacon) {
        var blob = new Blob([jsonStr], {type:'application/json; charset=UTF-8'});
        navigator.sendBeacon(url, blob);
        if (!silent || document.visibilityState !== 'hidden') {
            doFetchSave(url, jsonStr, silent);
        }
    } else {
        doFetchSave(url, jsonStr, silent);
    }
}

function doFetchSave(url, jsonStr, silent) {
    var ts=document.getElementById('top-save-status');
    if(!silent&&ts){ts.style.color='#60a5fa';ts.textContent='Saving...';}
    else showToast('Saving...');
    fetch(url,{
        method:'POST',headers:{'Content-Type':'application/json; charset=UTF-8'},
        body:jsonStr
    }).then(function(r){return r.text();}).then(function(txt){
        var data; try{data=JSON.parse(txt);}catch(e){data={error:'Parse fail: '+txt.substring(0,120)};}
        if(data.success){
            if(!silent&&ts){ts.style.color='#4ade80';ts.textContent='\u2713 Saved \u00b7 '+new Date().toLocaleTimeString();}
            else showToast('\u2713 Auto-saved');
        } else {
            var errMsg = data.error || 'Unknown error';
            if(!silent&&ts){ts.style.color='#f87171';ts.textContent='\u2717 '+errMsg;}
            showToast('\u2717 '+errMsg.substring(0,60));
            console.error('QC Draft save failed:',txt);
        }
    }).catch(function(e){ showToast('\u2717 Network error'); console.error(e); });
}

function showToast(msg){
    var t=document.getElementById('as-toast');
    if(!t){t=document.createElement('div');t.id='as-toast';
        t.style.cssText='position:fixed;bottom:20px;right:20px;background:#0a1e12;border:1px solid var(--qc);color:var(--qc);padding:7px 14px;border-radius:8px;font-size:11px;font-weight:700;z-index:9999;display:flex;align-items:center;gap:7px;transition:opacity .3s;';
        document.body.appendChild(t);}
    t.style.opacity='1';t.innerHTML='<i class="fas fa-save"></i> '+msg;
    clearTimeout(window._tt);window._tt=setTimeout(function(){t.style.opacity='0';},6000);
}

// ── RENDER PARTS TABLE ──
(function(){
    var tb = document.getElementById('partsTbody');
    if (!tb) return;
    if (!partsData || !partsData.length) {
        tb.innerHTML = '<tr><td colspan="5" style="text-align:center;padding:16px;color:var(--muted);font-style:italic;">No parts checklist from designer yet.</td></tr>';
        return;
    }
    tb.innerHTML = partsData.map(function(p,i){
        var name   = p.name||p.part||('Part '+(i+1));
        var status = (p.status||'pending').toLowerCase();
        var scls   = status==='done'?'ps-done':status==='na'?'ps-na':'ps-pend';
        var slbl   = status==='done'?'&#10003; Done':status==='na'?'N/A':'&#9679; Pending';
        return '<tr data-idx="'+i+'">'+
            '<td style="color:var(--muted);">'+(i+1)+'</td>'+
            '<td style="font-weight:600;color:var(--text);">'+esc(name)+'</td>'+
            '<td><span class="'+scls+'">'+slbl+'</span></td>'+
            '<td><div class="vg">'+
                '<button type="button" class="vb vp" onclick="setV('+i+',\'pass\',this)">&#10003; Pass</button>'+
                '<button type="button" class="vb vf" onclick="setV('+i+',\'fail\',this)">&#10007; Fail</button>'+
                '<button type="button" class="vb vr" onclick="setV('+i+',\'rework\',this)">&#8635; Rework</button>'+
            '</div></td>'+
            '<td><input type="text" class="vrem" placeholder="Note..." id="vr_'+i+'" '+
                'onchange="setV('+i+',(qcVerdicts['+i+']||{}).verdict||null,null,this.value)"></td>'+
        '</tr>';
    }).join('');

    // ── LOAD SAVED DRAFT (runs AFTER parts table is rendered) ──
    fetch('<%= request.getContextPath() %>/jsp/save_qc_draft.jsp?action=load&jobId=<%= selId %>&srcType=<%= selSrc %>')
    .then(function(r){ return r.text(); })
    .then(function(txt){
        var data; try{ data=JSON.parse(txt); } catch(e){ return; }
        if(!data.success || !data.draft) { calcQCProgress(); return; }
        var d = data.draft;

        // Section 4: Inspector notes
        if(d.inspector_notes){ var n=document.getElementById('inspNotes'); if(n) n.value=d.inspector_notes; }

        // Section 4: Severity
        if(d.severity){ var s=document.getElementById('sevSel'); if(s) for(var i=0;i<s.options.length;i++) if(s.options[i].value===d.severity){s.selectedIndex=i;break;} }

        // Section 4: Remarks dropdown
        if(d.remarks){ var r=document.querySelector('select[name=remarks]'); if(r) for(var i=0;i<r.options.length;i++) if(r.options[i].value===d.remarks){r.selectedIndex=i;break;} }

        // Section 3: Compliance checkboxes
        if(d.compliance) d.compliance.split(',').forEach(function(v){
            v=v.trim(); if(!v) return;
            var cb=document.querySelector('input[name=compliance][value="'+v+'"]');
            if(cb) cb.checked=true;
        });

        // Section 4: Defect categories
        if(d.defects) d.defects.split(',').forEach(function(v){
            v=v.trim(); if(!v) return;
            var cb=document.querySelector('input[name=defects][value="'+v+'"]');
            if(cb) cb.checked=true;
        });

        // Section 2: Part verdicts — d.qc_verdicts is already an object from server
        var savedVerdicts = {};
        if(d.qc_verdicts){
            if(typeof d.qc_verdicts === 'object') savedVerdicts = d.qc_verdicts;
            else try{ savedVerdicts = JSON.parse(d.qc_verdicts); }catch(e){}
        }
        qcVerdicts = savedVerdicts;

        // Apply verdict button highlights + remark notes
        Object.keys(qcVerdicts).forEach(function(idx){
            var v = qcVerdicts[idx];
            if(!v) return;
            var row = document.querySelector('#partsTbody tr[data-idx="'+idx+'"]');
            if(!row) return;
            // Highlight verdict button
            if(v.verdict){
                row.querySelectorAll('.vb').forEach(function(b){ b.classList.remove('sel'); });
                var cls = v.verdict==='pass'?'.vp':v.verdict==='fail'?'.vf':'.vr';
                var btn = row.querySelector(cls);
                if(btn) btn.classList.add('sel');
            }
            // Restore remark note
            if(v.remark){
                var remInput = document.getElementById('vr_'+idx);
                if(remInput) remInput.value = v.remark;
            }
        });

        // Section 2: Per-part remarks (separate field)
        if(d.part_remarks){
            var pr = typeof d.part_remarks==='object' ? d.part_remarks : {};
            try{ if(typeof d.part_remarks==='string') pr=JSON.parse(d.part_remarks); }catch(e){}
            Object.keys(pr).forEach(function(id){
                var el=document.getElementById(id); if(el) el.value=pr[id];
            });
        }

        // Section 3: Measurements
        if(d.measurements){
            var meas = typeof d.measurements==='object' ? d.measurements : {};
            try{ if(typeof d.measurements==='string') meas=JSON.parse(d.measurements); }catch(e){}
            Object.keys(meas).forEach(function(f){
                var el=document.querySelector('input[name='+f+']');
                if(el && meas[f]){ el.value=meas[f]; checkMeas(el); }
            });
        }

        // Update hidden input
        document.getElementById('qcVerdictsInput').value = JSON.stringify(qcVerdicts);

        // Show restored banner if any real content
        var hasContent = (d.inspector_notes && d.inspector_notes.length>0)
            || Object.keys(qcVerdicts).length > 0
            || (d.compliance && d.compliance.length>0);
        var banner = document.getElementById('draft-restored-banner');
        if(banner && hasContent) banner.style.display='flex';

        // Restore previously uploaded QC docs display
        if(d.qc_doc_files && d.qc_doc_files.length > 0){
            var preview = document.getElementById('qcDocsPreview');
            if(preview){
                preview.style.display='flex';
                preview.style.flexWrap='wrap';
                preview.style.gap='8px';
                preview.style.marginBottom='10px';
                uploadedQcDocs = [];
                d.qc_doc_files.split(',').forEach(function(entry){
                    if(!entry.trim()) return;
                    var parts = entry.split('|');
                    var fname = parts[0]; var orig = parts.length>1 ? parts[1] : fname;
                    uploadedQcDocs.push({fname:fname, orig:orig});
                    var ext = fname.split('.').pop().toLowerCase();
                    var icon=['png','jpg','jpeg'].indexOf(ext)>=0?'&#128444;':ext==='pdf'?'&#128196;':ext==='dwg'?'&#128208;':'&#128206;';
                    var tag = makeBadge(icon+' '+orig, orig, 'var(--qc)', 'rgba(34,197,94,.1)', 'rgba(34,197,94,.3)');
                    tag.style.cursor='pointer';
                    (function(f){ tag.onclick=function(){ window.open('<%= request.getContextPath() %>/uploads/qc/'+f,'_blank'); }; })(fname);
                    preview.appendChild(tag);
                });
            }
        }

        calcQCProgress();
    })
    .catch(function(){ calcQCProgress(); });
})();

function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

function setV(i,verdict,btn,remark){
    if(!qcVerdicts[i]) qcVerdicts[i]={};
    if(verdict!==null && verdict!==undefined) qcVerdicts[i].verdict = verdict;
    if(remark!==undefined) qcVerdicts[i].remark = remark;
    if(btn){
        btn.closest('tr').querySelectorAll('.vb').forEach(function(b){ b.classList.remove('sel'); });
        btn.classList.add('sel');
    }
    document.getElementById('qcVerdictsInput').value = JSON.stringify(qcVerdicts);
    calcQCProgress();
    scheduleAutoSave();
}

function checkMeas(inp){
    var design=parseFloat(inp.getAttribute('data-design'));
    var actual=parseFloat(inp.value);
    var el=document.getElementById(inp.getAttribute('data-resid'));
    if(!el) return;
    if(isNaN(actual)||isNaN(design)||design===0){el.innerHTML='&#8212;';el.style.color='var(--muted)';return;}
    var diff=Math.abs(actual-design)/design*100;
    if(diff<=2){el.innerHTML='&#10003; Match';el.style.color='var(--green)';}
    else if(diff<=5){el.innerHTML='&#9888; &plusmn;'+diff.toFixed(1)+'%';el.style.color='#ffc107';}
    else{el.innerHTML='&#10007; &plusmn;'+diff.toFixed(1)+'%';el.style.color='var(--accent2)';}
}

function qcTab(id,btn){
    ['form','hist'].forEach(function(t){ document.getElementById('qc-'+t).style.display=t===id?'':'none'; });
    document.querySelectorAll('.tab-btn').forEach(function(b){ b.classList.remove('on'); });
    if(btn) btn.classList.add('on');
}

function submitQC(action){
    var notes=document.getElementById('inspNotes');
    if(notes&&notes.value.trim()===''){alert('Inspector Notes are required.');notes.focus();return;}
    if(action==='approved'&&document.getElementById('sevSel').value==='Critical'){
        if(!confirm('Severity is CRITICAL. Approve anyway?')) return;
    }
    if(action==='qc_rejected'){if(!confirm('Reject and send back to designer?')) return;}
    var checks=[];
    document.querySelectorAll('input[name=compliance]:checked').forEach(function(c){checks.push(c.value);});
    document.getElementById('complianceInput').value=checks.join(',');
    document.getElementById('qcAction').value=action;
    document.getElementById('qcForm').submit();
}

function prevPhoto(inp){
    var p=document.getElementById('photoPrev'),i=document.getElementById('photoPrevImg');
    if(inp.files&&inp.files[0]){var r=new FileReader();r.onload=function(e){i.src=e.target.result;p.style.display='block';};r.readAsDataURL(inp.files[0]);}
    else p.style.display='none';
}

function switchHist(which, btn) {
    document.getElementById('hbody-int').style.display = which==='int' ? '' : 'none';
    document.getElementById('hbody-ext').style.display = which==='ext' ? '' : 'none';
    document.querySelectorAll('.htab').forEach(function(t){ t.className='htab'; });
    if (btn) btn.classList.add(which==='int'?'hi':'he');
}

// Track uploaded QC doc filenames (persists across saves)
var uploadedQcDocs = []; // [{fname, orig}]

function previewQcDocs(inp){
    var preview = document.getElementById('qcDocsPreview');
    if(!preview||!inp.files||!inp.files.length) return;

    // Upload each file immediately via FormData
    Array.from(inp.files).forEach(function(file){
        var fd = new FormData();
        fd.append('action','upload');
        fd.append('jobId','<%= selId %>');
        fd.append('srcType','<%= selSrc %>');
        fd.append('qcDocFile', file);

        // Show pending badge
        var tag = makeBadge('&#9203; Uploading...', file.name, '#ffc107', 'rgba(255,193,7,.1)', 'rgba(255,193,7,.3)');
        tag.setAttribute('data-pending', file.name);
        preview.appendChild(tag);

        fetch('<%= request.getContextPath() %>/jsp/save_qc_draft.jsp', {
            method:'POST', body: fd
        }).then(function(r){ return r.text(); }).then(function(txt){
            var data; try{ data=JSON.parse(txt); }catch(e){ data={error:txt}; }
            // Remove pending badge
            var old=preview.querySelector('[data-pending="'+file.name+'"]');
            if(old) old.remove();
            if(data.success && data.fname){
                uploadedQcDocs.push({fname:data.fname, orig:file.name});
                var ext=data.fname.split('.').pop().toLowerCase();
                var icon=['png','jpg','jpeg'].indexOf(ext)>=0?'&#128444;':ext==='pdf'?'&#128196;':ext==='dwg'?'&#128208;':'&#128206;';
                var link=makeBadge(icon+' '+file.name, file.name, 'var(--qc)', 'rgba(34,197,94,.1)', 'rgba(34,197,94,.3)');
                link.style.cursor='pointer';
                link.title='Click to open';
                link.onclick=function(){ window.open('<%= request.getContextPath() %>/uploads/qc/'+data.fname,'_blank'); };
                preview.appendChild(link);
                // Auto-save draft to store the new filename
                saveDraft(true);
            } else {
                showToast('\u2717 Upload failed: '+file.name);
            }
        }).catch(function(){
            var old=preview.querySelector('[data-pending="'+file.name+'"]');
            if(old) old.remove();
            showToast('\u2717 Upload error');
        });
    });
    // Reset input so same file can be re-selected
    inp.value='';
}

function makeBadge(html, title, color, bg, border){
    var tag=document.createElement('div');
    tag.title=title;
    tag.style.cssText='display:inline-flex;align-items:center;gap:6px;padding:5px 10px;'
        +'background:'+bg+';border:1px solid '+border+';'
        +'border-radius:6px;font-size:11px;color:'+color+';max-width:220px;';
    tag.innerHTML=html+' <span style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:140px;">'+title+'</span>';
    return tag;
}

/* ══ AUTO-SAVE TRIGGERS ══ */

// 1. Save when user switches tab or minimises window
document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'hidden') {
        saveDraft(true);
    }
});

// 2. Save when user navigates away / closes tab
window.addEventListener('beforeunload', function() {
    saveDraft(true);
});

// 3. Save when window loses focus (switch app, alt+tab)
window.addEventListener('blur', function() {
    clearTimeout(window._qcAS);
    saveDraft(true);
});

// 4. Periodic auto-save every 30 seconds regardless of activity
setInterval(function() {
    if (document.getElementById('qcForm')) {
        saveDraft(true);
    }
}, 30000);

// 5. Save on user idle — 10 seconds of no mouse/keyboard activity
var _idleTimer;
function resetIdleTimer() {
    clearTimeout(_idleTimer);
    _idleTimer = setTimeout(function() {
        if (document.getElementById('qcForm')) {
            saveDraft(true);
        }
    }, 10000);
}
['mousemove','keydown','scroll','click','touchstart'].forEach(function(evt) {
    document.addEventListener(evt, resetIdleTimer, {passive:true});
});
resetIdleTimer();
</script>
</body>
</html>
