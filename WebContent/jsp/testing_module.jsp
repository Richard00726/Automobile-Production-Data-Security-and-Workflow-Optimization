<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.util.*" %>
<%
    /* ═══ AUTH ═══ */
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp"); return;
    }
    String role    = (String) sess.getAttribute("role");
    String tstUser = (String) sess.getAttribute("username");
    String tstName = (String) sess.getAttribute("fullName");
    if (tstName == null) tstName = tstUser;
    if (!"testing".equals(role) && !"admin".equals(role)) {
        response.sendRedirect("../dashboard.jsp"); return;
    }
    request.setAttribute("currentPage","testing");

    String success = request.getAttribute("success") != null
        ? (String) request.getAttribute("success") : request.getParameter("success");
    String error = request.getAttribute("error") != null
        ? (String) request.getAttribute("error") : request.getParameter("error");

    /* ═══ TESTER PROFILE ═══ */
    String tstVehicleType  = null;
    String tstVehicleLabel = "All Categories";
    int    tstSlot         = 0;
    if (!"admin".equals(role)) {
        try (Connection c = DBConnection.getConnection()) {
            PreparedStatement p = c.prepareStatement(
                "SELECT vehicle_type,slot_number FROM module_team_members " +
                "WHERE module_role='testing' AND username=? AND is_active=1 LIMIT 1");
            p.setString(1, tstUser);
            ResultSet r = p.executeQuery();
            if (r.next()) {
                tstVehicleType  = r.getString("vehicle_type");
                tstSlot         = r.getInt("slot_number");
                if (tstVehicleType != null)
                    tstVehicleLabel = tstVehicleType.replace("_"," ").toUpperCase();
            }
        } catch (Exception e) {}
    }

    /* ═══ URL PARAMETERS ═══ */
    String surface  = request.getParameter("surface");
    String reqIdStr = request.getParameter("reqId");
    String srcParam = request.getParameter("src");

    /* ═══ LOAD INTERNAL JOBS ═══ */
    List<Object[]> myIntJobs = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        String sql = "admin".equals(role)
            ? "SELECT ij.id, ij.job_number, ij.model_name, ij.vehicle_type, ij.brand_name, " +
              "ij.target_date, ij.quantity, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username " +
              "FROM internal_jobs ij " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=ij.id AND source_type='internal_job' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=ij.id AND td.source_type='internal' " +
              "WHERE ij.workflow_stage IN ('qc_approved','testing_failed') ORDER BY ij.id DESC"
            : "SELECT ij.id, ij.job_number, ij.model_name, ij.vehicle_type, ij.brand_name, " +
              "ij.target_date, ij.quantity, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username " +
              "FROM internal_jobs ij " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=ij.id AND source_type='internal_job' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=ij.id AND td.source_type='internal' AND td.tester_user=? " +
              "WHERE ij.workflow_stage IN ('qc_approved','testing_failed') AND ij.current_assignee=? ORDER BY ij.id DESC";
        PreparedStatement ps = conn.prepareStatement(sql);
        if (!"admin".equals(role)) { ps.setString(1, tstUser); ps.setString(2, tstUser); }
        ResultSet rs = ps.executeQuery();
        while (rs.next()) myIntJobs.add(new Object[]{
            rs.getInt("id"), "internal",
            rs.getString("job_number") != null ? rs.getString("job_number") : "INT-"+rs.getInt("id"),
            rs.getString("model_name") != null ? rs.getString("model_name") : "Job",
            rs.getString("vehicle_type") != null ? rs.getString("vehicle_type") : "",
            rs.getString("brand_name")   != null ? rs.getString("brand_name")   : "",
            rs.getString("target_date")  != null ? rs.getString("target_date")  : "—",
            rs.getString("quantity")     != null ? rs.getString("quantity")     : "1",
            rs.getInt("tst_pct"),
            rs.getString("designer_username") != null ? rs.getString("designer_username") : "—"
        });
    } catch (Exception e) {}

    /* ═══ LOAD EXTERNAL JOBS ═══ */
    List<Object[]> myExtJobs = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        String eoSql = "admin".equals(role)
            ? "SELECT eo.id, eo.order_number, CONCAT(eo.client_name,' - Bulk Order') AS title, " +
              "eo.vehicle_type, eo.client_name, eo.deadline, '1' AS qty, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username, 'external' AS src " +
              "FROM external_orders eo " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=eo.id AND source_type='external_order' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=eo.id AND td.source_type='external' " +
              "WHERE eo.workflow_stage IN ('qc_approved','testing_failed') ORDER BY eo.id DESC"
            : "SELECT eo.id, eo.order_number, CONCAT(eo.client_name,' - Bulk Order') AS title, " +
              "eo.vehicle_type, eo.client_name, eo.deadline, '1' AS qty, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username, 'external' AS src " +
              "FROM external_orders eo " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=eo.id AND source_type='external_order' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=eo.id AND td.source_type='external' AND td.tester_user=? " +
              "WHERE eo.workflow_stage IN ('qc_approved','testing_failed') AND eo.current_assignee=? ORDER BY eo.id DESC";
        PreparedStatement ps1 = conn.prepareStatement(eoSql);
        if (!"admin".equals(role)) { ps1.setString(1, tstUser); ps1.setString(2, tstUser); }
        ResultSet rs1 = ps1.executeQuery();
        while (rs1.next()) myExtJobs.add(new Object[]{
            rs1.getInt("id"), "external",
            rs1.getString("order_number") != null ? rs1.getString("order_number") : "EXT-"+rs1.getInt("id"),
            rs1.getString("title"), rs1.getString("vehicle_type"),
            rs1.getString("client_name"), rs1.getString("deadline"),
            rs1.getString("qty"), rs1.getInt("tst_pct"),
            rs1.getString("designer_username") != null ? rs1.getString("designer_username") : "—"
        });
        String crSql = "admin".equals(role)
            ? "SELECT cr.id, CONCAT('CR-',cr.id) AS rnum, cr.req_title AS title, " +
              "cr.vehicle_type, COALESCE(c.full_name,cr.client_name) AS cname, cr.deadline, '1' AS qty, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username, 'cr' AS src " +
              "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=cr.id AND td.source_type='cr' " +
              "WHERE cr.workflow_stage IN ('qc_approved','testing_failed') ORDER BY cr.id DESC"
            : "SELECT cr.id, CONCAT('CR-',cr.id) AS rnum, cr.req_title AS title, " +
              "cr.vehicle_type, COALESCE(c.full_name,cr.client_name) AS cname, cr.deadline, '1' AS qty, " +
              "COALESCE(td.progress_pct,0) AS tst_pct, ds.designer_username, 'cr' AS src " +
              "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id " +
              "LEFT JOIN design_submissions ds ON ds.id=(SELECT id FROM design_submissions WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) " +
              "LEFT JOIN testing_drafts td ON td.job_ref_id=cr.id AND td.source_type='cr' AND td.tester_user=? " +
              "WHERE cr.workflow_stage IN ('qc_approved','testing_failed') AND cr.current_assignee=? ORDER BY cr.id DESC";
        PreparedStatement ps2 = conn.prepareStatement(crSql);
        if (!"admin".equals(role)) { ps2.setString(1, tstUser); ps2.setString(2, tstUser); }
        ResultSet rs2 = ps2.executeQuery();
        while (rs2.next()) myExtJobs.add(new Object[]{
            rs2.getInt("id"), "cr",
            rs2.getString("rnum"), rs2.getString("title"), rs2.getString("vehicle_type"),
            rs2.getString("cname"), rs2.getString("deadline"),
            rs2.getString("qty"), rs2.getInt("tst_pct"),
            rs2.getString("designer_username") != null ? rs2.getString("designer_username") : "—"
        });
    } catch (Exception e) {}

    /* ═══ PAGE STATE ═══ */
    boolean showLanding = (surface == null && reqIdStr == null);
    boolean showIntList = "internal".equals(surface) && reqIdStr == null;
    boolean showExtList = "external".equals(surface) && reqIdStr == null;
    boolean showDetail  = reqIdStr != null && !reqIdStr.trim().isEmpty();

    int    selId  = 0;
    String selSrc = srcParam != null ? srcParam : "internal";
    if (showDetail) { try { selId = Integer.parseInt(reqIdStr.trim()); } catch (Exception ig) {} }

    /* ═══ LOAD DESIGN SUBMISSION (for reading specs) ═══ */
    String ds_title="—",ds_subCat="—",ds_version="—",ds_engine="—",ds_disp="—",ds_cyl="—";
    String ds_power="—",ds_torque="—",ds_trans="—",ds_len="—",ds_wid="—",ds_hei="—";
    String ds_wb="—",ds_kw="—",ds_cap="—",ds_designer="—",ds_overview="—",ds_remarks="—";
    String ds_blueprint="—",ds_model3d="—",ds_extraFiles="—";
    String ds_partsJson="[]"; int ds_pct=0;
    String sel_ref="—",sel_title="—",sel_vtype="—",sel_brand="—",sel_deadline="—";

    if (showDetail && selId > 0) {
        List<Object[]> allJobs = new ArrayList<>(myIntJobs);
        allJobs.addAll(myExtJobs);
        for (Object[] jr : allJobs) {
            if ((Integer)jr[0]==selId && selSrc.equals((String)jr[1])) {
                sel_ref   = (String) jr[2]; sel_title = (String) jr[3];
                sel_vtype = (String) jr[4]; sel_brand = (String) jr[5];
                sel_deadline = (String) jr[6]; break;
            }
        }
        // Fallback: load job meta directly from DB if not found in preloaded list
        if ("—".equals(sel_ref)) {
            try (Connection conn = DBConnection.getConnection()) {
                String metaSql = "internal".equals(selSrc)
                    ? "SELECT job_number AS ref, model_name AS title, vehicle_type, brand_name, target_date FROM internal_jobs WHERE id=?"
                    : "external".equals(selSrc)
                    ? "SELECT order_number AS ref, CONCAT(client_name,' - Bulk Order') AS title, vehicle_type, client_name AS brand_name, deadline AS target_date FROM external_orders WHERE id=?"
                    : "SELECT CONCAT('CR-',id) AS ref, req_title AS title, vehicle_type, client_name AS brand_name, deadline AS target_date FROM customer_requirements WHERE id=?";
                PreparedStatement mps = conn.prepareStatement(metaSql);
                mps.setInt(1, selId);
                ResultSet mrs = mps.executeQuery();
                if (mrs.next()) {
                    sel_ref      = nvl(mrs.getString("ref"));
                    sel_title    = nvl(mrs.getString("title"));
                    sel_vtype    = nvl(mrs.getString("vehicle_type"));
                    sel_brand    = nvl(mrs.getString("brand_name"));
                    sel_deadline = nvl(mrs.getString("target_date"));
                }
            } catch (Exception e) {}
        }
        String dsSrc = "internal".equals(selSrc)?"internal_job":"external".equals(selSrc)?"external_order":"cr";
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement dps = conn.prepareStatement(
                "SELECT * FROM design_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
            dps.setInt(1, selId); dps.setString(2, dsSrc);
            ResultSet drs = dps.executeQuery();
            if (drs.next()) {
                ds_title    = nvl(drs.getString("design_title"));
                ds_subCat   = nvl(drs.getString("sub_category"));
                ds_version  = nvl(drs.getString("design_version"));
                ds_overview = nvl(drs.getString("overview_notes"));
                ds_remarks  = nvl(drs.getString("designer_remarks"));
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
                ds_partsJson= drs.getString("parts_checklist") != null ? drs.getString("parts_checklist") : "[]";
                ds_pct      = drs.getInt("progress_pct");
                try{ ds_blueprint  = nvl(drs.getString("blueprint_file")); }catch(Exception ig){}
                try{ ds_model3d    = nvl(drs.getString("model_3d_file")); }catch(Exception ig){}
                try{ ds_extraFiles = nvl(drs.getString("extra_files")); }catch(Exception ig){}
            }
        } catch (Exception e) {}
    }

    String ctx = request.getContextPath();
    String backLink = showDetail
        ? ("internal".equals(selSrc) ? ctx+"/testing?surface=internal" : ctx+"/testing?surface=external")
        : ctx+"/testing";

    /* ═══ TESTING TEAM MEMBERS ═══ */
    List<Object[]> teamMembers = new ArrayList<>();
    String poolType = tstVehicleType != null ? tstVehicleType : "";
    if (!"admin".equals(role) && !poolType.isEmpty()) {
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement p = conn.prepareStatement(
                "SELECT mt.slot_number,mt.full_name,mt.username,mt.is_active,u.last_active " +
                "FROM module_team_members mt LEFT JOIN users u ON CONVERT(mt.username USING utf8mb4) COLLATE utf8mb4_general_ci = CONVERT(u.username USING utf8mb4) COLLATE utf8mb4_general_ci " +
                "WHERE mt.module_role='testing' AND mt.vehicle_type=? ORDER BY mt.slot_number ASC");
            p.setString(1, poolType);
            ResultSet r = p.executeQuery();
            while (r.next()) teamMembers.add(new Object[]{
                r.getInt("slot_number"), r.getString("full_name"),
                r.getString("username") != null ? r.getString("username") : "",
                r.getInt("is_active"), r.getTimestamp("last_active")
            });
        } catch (Exception e) {}
    }

    /* ═══ TESTING HISTORY ═══ */
    List<Object[]> histInt = new ArrayList<>();
    List<Object[]> histExt = new ArrayList<>();
    try (Connection conn = DBConnection.getConnection()) {
        String hiSql = "admin".equals(role)
            ? "SELECT h.source_id,h.action,h.remarks,h.actioned_by,h.actioned_at,ij.job_number,ij.model_name " +
              "FROM unified_workflow_history h JOIN internal_jobs ij ON h.source_id=ij.id " +
              "WHERE h.source_type='internal' AND h.action IN ('testing_passed','testing_failed','testing_conditional') ORDER BY h.id DESC LIMIT 20"
            : "SELECT h.source_id,h.action,h.remarks,h.actioned_by,h.actioned_at,ij.job_number,ij.model_name " +
              "FROM unified_workflow_history h JOIN internal_jobs ij ON h.source_id=ij.id " +
              "WHERE h.source_type='internal' AND h.action IN ('testing_passed','testing_failed','testing_conditional') AND h.actioned_by=? ORDER BY h.id DESC LIMIT 20";
        PreparedStatement hip = conn.prepareStatement(hiSql);
        if (!"admin".equals(role)) hip.setString(1, tstUser);
        ResultSet hir = hip.executeQuery();
        while (hir.next()) histInt.add(new Object[]{
            hir.getString("job_number"), hir.getString("model_name"),
            hir.getString("action"), hir.getString("remarks"),
            hir.getString("actioned_by"), hir.getTimestamp("actioned_at")
        });
        String heSql = "admin".equals(role)
            ? "SELECT h.source_id,h.source_type,h.action,h.remarks,h.actioned_by,h.actioned_at," +
              "COALESCE(eo.order_number,CONCAT('CR-',cr.id)) AS ref,COALESCE(eo.model_name,cr.vehicle_type) AS title " +
              "FROM unified_workflow_history h " +
              "LEFT JOIN external_orders eo ON h.source_type='external' AND h.source_id=eo.id " +
              "LEFT JOIN customer_requirements cr ON h.source_type='cr' AND h.source_id=cr.id " +
              "WHERE h.source_type IN ('external','cr') AND h.action IN ('testing_passed','testing_failed','testing_conditional') ORDER BY h.id DESC LIMIT 20"
            : "SELECT h.source_id,h.source_type,h.action,h.remarks,h.actioned_by,h.actioned_at," +
              "COALESCE(eo.order_number,CONCAT('CR-',cr.id)) AS ref,COALESCE(eo.model_name,cr.vehicle_type) AS title " +
              "FROM unified_workflow_history h " +
              "LEFT JOIN external_orders eo ON h.source_type='external' AND h.source_id=eo.id " +
              "LEFT JOIN customer_requirements cr ON h.source_type='cr' AND h.source_id=cr.id " +
              "WHERE h.source_type IN ('external','cr') AND h.action IN ('testing_passed','testing_failed','testing_conditional') AND h.actioned_by=? ORDER BY h.id DESC LIMIT 20";
        PreparedStatement hep = conn.prepareStatement(heSql);
        if (!"admin".equals(role)) hep.setString(1, tstUser);
        ResultSet her = hep.executeQuery();
        while (her.next()) histExt.add(new Object[]{
            her.getString("ref"), her.getString("title"),
            her.getString("action"), her.getString("remarks"),
            her.getString("actioned_by"), her.getTimestamp("actioned_at")
        });
    } catch (Exception e) {}

    String jsPartsJson = ds_partsJson.replace("</","<\\/");
%><%!
    private String nvl(String s){ return (s!=null&&!s.isEmpty())?s:"—"; }
%><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Testing Module &#8212; AutoProd</title>
<link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;600;700&family=Exo+2:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<style>
:root{
  --bg:#0a1020;--surface:#0f1a2e;--card:#111e35;--border:#1e2d45;
  --text:#d0d8e8;--muted:#4a5c7a;
  --accent:#00c8ff;--accent2:#ff6b35;--green:#00e676;--purple:#7c5cfc;
  --int:#6c63ff;--ext:#00b4a6;
  --tst:#f59e0b;--tst2:#d97706;
}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);color:var(--text);font-family:'Exo 2',sans-serif;font-size:13px;height:100vh;display:flex;flex-direction:column;overflow:hidden;}
/* TOPBAR */
.topbar{height:46px;background:var(--surface);border-bottom:1px solid var(--border);display:flex;align-items:center;gap:14px;padding:0 18px;flex-shrink:0;box-shadow:0 3px 20px rgba(245,158,11,.06);z-index:100;}
.tb-logo{font-family:'Rajdhani',sans-serif;font-size:18px;font-weight:700;color:var(--tst);letter-spacing:2px;}
.tb-logo span{color:var(--text);}
.tb-sep{width:1px;height:22px;background:var(--border);}
.tb-title{font-family:'Rajdhani',sans-serif;font-size:14px;font-weight:600;color:var(--muted);letter-spacing:1px;text-transform:uppercase;}
.tb-badge{padding:3px 12px;border-radius:16px;font-size:11px;font-weight:700;border:1px solid;}
.tb-badge.cat{color:var(--tst);border-color:var(--tst);background:rgba(245,158,11,.08);}
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
.prog-step.active .prog-dot{background:var(--tst);border-color:var(--tst);color:#000;box-shadow:0 0 12px rgba(245,158,11,.5);}
.prog-lbl{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;}
.prog-step.done .prog-lbl{color:var(--green);}
.prog-step.active .prog-lbl{color:var(--tst);}
.main-body{flex:1;overflow-y:auto;padding:20px 24px;}
/* ALERTS */
.alert-bar{padding:10px 16px;border-radius:8px;margin-bottom:16px;font-size:12px;font-weight:700;display:flex;align-items:center;gap:8px;}
.alert-s{background:rgba(245,158,11,.1);border:1px solid var(--tst);color:var(--tst);}
.alert-e{background:rgba(255,107,53,.1);border:1px solid var(--accent2);color:var(--accent2);}
/* LANDING */
.land-wrap{max-width:760px;margin:0 auto;}
.land-title{font-family:'Rajdhani',sans-serif;font-size:26px;font-weight:700;color:var(--tst);letter-spacing:3px;text-transform:uppercase;text-align:center;margin-bottom:6px;}
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
.job-card.ic:hover{background:rgba(108,99,255,.05);}
.job-card.ec:hover{background:rgba(0,180,166,.05);}
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
.stage-pill{background:rgba(245,158,11,.12);color:var(--tst);padding:4px 13px;border-radius:12px;font-size:10px;font-weight:700;border:1px solid rgba(245,158,11,.3);margin-left:auto;}
/* PROGRESS */
.task-progress{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:14px;}
.tp-title{font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;margin-bottom:12px;display:flex;align-items:center;justify-content:space-between;}
.tp-pct{font-size:20px;font-weight:700;color:var(--tst);}
.tp-bar{height:10px;background:var(--border);border-radius:6px;margin-bottom:12px;overflow:hidden;}
.tp-fill{height:100%;border-radius:6px;background:linear-gradient(90deg,var(--tst),var(--accent),var(--green));transition:width .4s;}
.tp-stages{display:flex;gap:8px;flex-wrap:wrap;}
.tp-stage{font-size:10px;font-weight:700;padding:4px 12px;border-radius:20px;border:1px solid;transition:all .2s;}
.tp-stage.ns{color:var(--muted);border-color:var(--border);background:transparent;}
.tp-stage.active{color:#ffc107;border-color:#ffc107;background:rgba(255,193,7,.1);}
.tp-stage.done{color:var(--tst);border-color:var(--tst);background:rgba(245,158,11,.08);}
/* SECTION */
.sec{background:var(--card);border:1px solid var(--border);border-radius:12px;margin-bottom:14px;overflow:hidden;}
.sec-head{padding:11px 16px;display:flex;align-items:center;gap:10px;border-bottom:1px solid var(--border);background:rgba(255,255,255,.02);}
.sec-icon{width:28px;height:28px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:.85rem;flex-shrink:0;}
.sec-title{font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;}
.sec-sub{font-size:10px;color:var(--muted);margin-top:1px;}
.ro-pill{background:rgba(74,92,122,.3);color:var(--muted);font-size:9px;font-weight:700;padding:2px 8px;border-radius:6px;margin-left:auto;}
.sec-badge{font-size:10px;font-weight:700;padding:2px 10px;border-radius:20px;background:rgba(80,80,100,.2);color:var(--muted);}
.sec-body{padding:16px;}
/* SPEC GRID */
.spec-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:9px;}
.sc{background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:9px 12px;}
.sc-lbl{font-size:9px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;font-weight:700;margin-bottom:3px;}
.sc-val{font-size:12px;font-weight:700;color:var(--text);}
.note-box{border-radius:8px;padding:11px 14px;margin-bottom:12px;}
.nb-lbl{font-size:9px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;margin-bottom:5px;}
.nb-body{font-size:12px;color:var(--text);line-height:1.6;}
/* TEST ROWS */
.test-table{width:100%;border-collapse:collapse;font-size:12px;}
.test-table th{padding:8px 12px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:1px solid var(--border);text-align:left;}
.test-table td{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,.5);vertical-align:middle;}
.test-table tr[data-idx]{transition:background .25s,border-left .25s;}
.test-table tr:last-child td{border-bottom:none;}
.fc{width:100%;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:8px;padding:7px 10px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;outline:none;transition:all .2s;}
.fc:focus{border-color:var(--tst);background:rgba(245,158,11,.04);}
.fc option{background:var(--surface);}
textarea.fc{resize:vertical;min-height:70px;}
.score-inp{width:80px;background:rgba(255,255,255,.03);border:1px solid var(--border);border-radius:7px;padding:6px 9px;color:var(--text);font-family:'Exo 2',sans-serif;font-size:12px;outline:none;text-align:center;transition:all .2s;}
.score-inp:focus{border-color:var(--tst);}
.score-bar{width:100%;height:4px;background:var(--border);border-radius:2px;margin-top:4px;overflow:hidden;}
.score-fill{height:100%;border-radius:2px;background:linear-gradient(90deg,#ef4444,#f59e0b,#22c55e);transition:width .3s;}
.add-row-btn{display:inline-flex;align-items:center;gap:7px;padding:8px 16px;background:rgba(245,158,11,.08);border:1px dashed rgba(245,158,11,.4);border-radius:8px;cursor:pointer;font-size:12px;color:var(--tst);font-weight:600;transition:all .2s;font-family:'Exo 2',sans-serif;}
.add-row-btn:hover{background:rgba(245,158,11,.15);}
.del-row-btn{width:26px;height:26px;border-radius:6px;background:rgba(220,38,38,.1);border:1px solid rgba(220,38,38,.3);color:#f87171;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:11px;transition:all .2s;}
.del-row-btn:hover{background:rgba(220,38,38,.2);}
/* FORM FIELDS */
.fg{margin-bottom:13px;}
.fg label{display:block;font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px;}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
/* ACTIONS */
.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:6px;position:sticky;bottom:0;background:var(--card);padding:12px 0 4px;z-index:10;border-top:1px solid var(--border);}
.btn{padding:10px 22px;border-radius:9px;font-family:'Rajdhani',sans-serif;font-size:13px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;cursor:pointer;border:none;display:inline-flex;align-items:center;gap:7px;transition:all .2s;}
.btn-pass{background:linear-gradient(135deg,var(--tst),var(--tst2));color:#000;box-shadow:0 4px 14px rgba(245,158,11,.25);}
.btn-pass:hover{transform:translateY(-2px);}
.btn-fail{background:linear-gradient(135deg,#dc2626,#b91c1c);color:#fff;}
.btn-fail:hover{transform:translateY(-2px);}
.btn-cond{background:linear-gradient(135deg,#7c5cfc,#6d28d9);color:#fff;}
.btn-cond:hover{transform:translateY(-2px);}
.btn-draft{background:transparent;border:1px solid var(--border);color:var(--muted);}
.btn-draft:hover{border-color:var(--accent);color:var(--accent);}
/* TABS */
.tab-row{display:flex;gap:0;border-bottom:1px solid var(--border);margin-bottom:16px;}
.tab-btn{padding:9px 18px;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:var(--muted);background:none;border:none;cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;transition:all .2s;}
.tab-btn:hover{color:var(--tst);}
.tab-btn.on{color:var(--tst);border-bottom-color:var(--tst);}
/* RIGHT SIDEBAR */
.sb-right{width:220px;min-width:220px;background:var(--surface);border-left:1px solid var(--border);display:flex;flex-direction:column;overflow:hidden;}
.sbr-team{flex:0 0 auto;border-bottom:2px solid var(--border);}
.sbr-head{padding:10px 14px;background:rgba(255,255,255,.02);border-bottom:1px solid var(--border);}
.sbr-head-title{font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;display:flex;align-items:center;justify-content:space-between;}
.sbr-head-cnt{background:var(--tst);color:#000;border-radius:8px;padding:1px 7px;font-size:9px;font-weight:800;}
.team-scroll{max-height:240px;overflow-y:auto;}
.tm-row{padding:9px 12px;border-bottom:1px solid rgba(30,45,69,.5);display:flex;align-items:center;gap:9px;}
.tm-av{width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-family:'Rajdhani',sans-serif;font-size:12px;font-weight:800;flex-shrink:0;color:#fff;}
.tm-info{flex:1;min-width:0;}
.tm-name{font-size:11px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.tm-sub{font-size:9px;color:var(--muted);margin-top:1px;}
.tm-status{display:flex;align-items:center;gap:4px;margin-top:2px;}
.tm-dot{width:7px;height:7px;border-radius:50%;flex-shrink:0;}
.tm-stxt{font-size:9px;font-weight:700;}
.tm-you{font-size:8px;padding:1px 5px;border-radius:6px;background:rgba(245,158,11,.15);color:var(--tst);font-weight:700;flex-shrink:0;}
.sbr-hist{flex:1;display:flex;flex-direction:column;overflow:hidden;}
.htabs{display:flex;border-bottom:1px solid var(--border);flex-shrink:0;}
.htab{flex:1;padding:8px 4px;text-align:center;font-size:9px;font-weight:700;cursor:pointer;color:var(--muted);transition:all .2s;letter-spacing:.5px;text-transform:uppercase;border-bottom:2px solid transparent;margin-bottom:-1px;}
.htab.hi{color:var(--int);border-color:var(--int);}
.htab.he{color:var(--ext);border-color:var(--ext);}
.hbody{flex:1;overflow-y:auto;}
.hi-item{padding:8px 12px;border-bottom:1px solid rgba(30,45,69,.4);}
.hi-num{font-size:10px;font-weight:700;font-family:'Rajdhani',sans-serif;}
.hi-num.int{color:var(--int);}
.hi-num.ext{color:var(--ext);}
.hi-title{font-size:11px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:190px;margin:2px 0;}
.hi-badge{font-size:9px;font-weight:700;padding:1px 7px;border-radius:6px;display:inline-block;}
.hib-pass{background:rgba(34,197,94,.12);color:var(--green);}
.hib-fail{background:rgba(220,38,38,.12);color:#f87171;}
.hib-cond{background:rgba(124,92,252,.12);color:#a78bfa;}
.hi-empty{padding:16px;font-size:11px;color:var(--muted);text-align:center;font-style:italic;}
</style>
</head>
<body>

<!-- TOPBAR -->
<div class="topbar">
  <div class="tb-logo">AUTO<span>PROD</span></div>
  <div class="tb-sep"></div>
  <div class="tb-title">Testing Module</div>
  <% if (!"admin".equals(role) && tstVehicleType != null) { %>
  <span class="tb-badge cat">&#128230; <%= tstVehicleLabel %></span>
  <% if (tstSlot > 0) { %><span class="tb-badge slot">Slot <%= tstSlot %></span><% } %>
  <% } %>
  <div class="tb-right">
    <span class="tb-user">&#128230; <strong><%= tstName %></strong></span>
    <a href="<%= ctx %>/logout" class="tb-logout"><i class="fas fa-sign-out-alt"></i> Logout</a>
  </div>
</div>

<div class="layout">

<!-- ══ MAIN ══ -->
<div class="main">
  <!-- Pipeline progress -->
  <div class="main-progress">
    <div class="prog-track">
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Request</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Approved</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">Design</div></div>
      <div class="prog-step done"><div class="prog-dot"><i class="fas fa-check" style="font-size:10px;"></i></div><div class="prog-lbl">QC</div></div>
      <div class="prog-step active"><div class="prog-dot">5</div><div class="prog-lbl">Testing</div></div>
      <div class="prog-step"><div class="prog-dot">6</div><div class="prog-lbl">Analytics</div></div>
      <div class="prog-step"><div class="prog-dot">7</div><div class="prog-lbl">Final</div></div>
    </div>
  </div>

  <div class="main-body">
    <% if (success!=null&&!success.isEmpty()) { %><div class="alert-bar alert-s"><i class="fas fa-check-circle"></i> <%= success %></div><% } %>
    <% if (error  !=null&&!error.isEmpty())   { %><div class="alert-bar alert-e"><i class="fas fa-exclamation-triangle"></i> <%= error %></div><% } %>

    <%-- ════ LANDING ════ --%>
    <% if (showLanding) { %>
    <div class="land-wrap">
      <div style="text-align:center;margin-bottom:20px;">
        <a href="<%= ctx %>/dashboard.jsp"
           style="display:inline-flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);text-decoration:none;padding:5px 12px;border:1px solid var(--border);border-radius:8px;margin-bottom:16px;"
           onmouseover="this.style.color='var(--accent)';this.style.borderColor='var(--accent)';"
           onmouseout="this.style.color='var(--muted)';this.style.borderColor='var(--border)';">
          <i class="fas fa-arrow-left"></i> Back to Dashboard
        </a>
        <div class="land-title">Testing Module</div>
        <div class="land-sub">Choose your testing stream to begin.</div>
        <% if (!"admin".equals(role) && tstVehicleType != null) { %>
        <span class="land-cat-badge" style="background:rgba(245,158,11,.1);border:1px solid var(--tst);color:var(--tst);">&#128230; Your Pool: <%= tstVehicleLabel %> &nbsp;&middot;&nbsp; Slot <%= tstSlot %></span>
        <% } %>
      </div>
      <div class="surf-cards">
        <a href="<%= ctx %>/testing?surface=internal" class="surf-card ic">
          <div class="sc-icon">&#127981;</div>
          <div class="sc-title ic">Internal Testing</div>
          <div class="sc-desc">Performance &amp; safety testing for internal manufacturing jobs.<br>QC-approved vehicles ready for test phase.</div>
          <span class="sc-count ic"><%= myIntJobs.size() %> job<%= myIntJobs.size()!=1?"s":"" %> in queue</span>
        </a>
        <a href="<%= ctx %>/testing?surface=external" class="surf-card ec">
          <div class="sc-icon">&#129309;</div>
          <div class="sc-title ec">External Testing</div>
          <div class="sc-desc">Testing for customer orders &amp; requirements.<br>QC-approved external jobs awaiting test results.</div>
          <span class="sc-count ec"><%= myExtJobs.size() %> job<%= myExtJobs.size()!=1?"s":"" %> in queue</span>
        </a>
      </div>
    </div>

    <%-- ════ INTERNAL LIST ════ --%>
    <% } else if (showIntList) { %>
    <div class="list-header">
      <a href="<%= ctx %>/testing" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:var(--int);">&#127981; Internal Testing Jobs</div>
      <% if (tstVehicleType!=null&&!"admin".equals(role)) { %><span style="font-size:11px;color:var(--muted);">&#8212; <%= tstVehicleLabel %></span><% } %>
    </div>
    <% if (myIntJobs.isEmpty()) { %>
    <div class="empty-state"><div class="empty-icon">&#127981;</div><p class="empty-text">No internal jobs ready for testing.<br>Jobs appear here after QC approves them.</p></div>
    <% } else { for (Object[] j : myIntJobs) {
        int jid=(Integer)j[0]; String jref=(String)j[2]; String jtit=(String)j[3];
        String jvt=(String)j[4]; String jbrand=(String)j[5];
        String jdead=(String)j[6]; String jqty=(String)j[7];
        int jpct=(Integer)j[8]; String jdes=(String)j[9];
        String abbr=jbrand.length()>=3?jbrand.substring(0,3).toUpperCase():jbrand.toUpperCase();
        String pctCol=jpct>=100?"var(--green)":jpct>0?"#ffc107":"var(--tst)";
        String badgeTxt=jpct>=100?"&#9745; Test Complete":jpct>0?"&#128230; Testing In Progress":"&#9650; Pending Test";
        String badgeStyle=jpct>=100?"background:rgba(34,197,94,.15);color:var(--green);":jpct>0?"background:rgba(255,193,7,.12);color:#ffc107;":"background:rgba(245,158,11,.1);color:var(--tst);";
    %>
    <a href="<%= ctx %>/testing?reqId=<%= jid %>&src=internal&surface=internal" class="job-card ic">
      <div class="jc-icon ic"><%= abbr.isEmpty()?"INT":abbr %></div>
      <div class="jc-body">
        <div class="jc-num ic"><%= jref %> &nbsp;&middot;&nbsp; <span style="color:var(--muted);"><%= jvt.replace("_"," ").toUpperCase() %></span></div>
        <div class="jc-title"><%= jtit %></div>
        <div class="jc-meta">&#127950; <%= jbrand %> &nbsp;&nbsp; &#128230; Qty: <%= jqty %> &nbsp;&nbsp; &#9997; @<%= jdes %> &nbsp;&nbsp; &#8987; <%= jdead %></div>
      </div>
      <div class="jc-right">
        <span class="jc-badge" style="<%= badgeStyle %>"><%= badgeTxt %></span>
        <span class="jc-pct" style="color:<%= pctCol %>;"><%= jpct %>% Test</span>
        <div class="pct-bar-sm"><div class="pct-fill-sm ic" style="width:<%= jpct %>%"></div></div>
      </div>
    </a>
    <% } } %>

    <%-- ════ EXTERNAL LIST ════ --%>
    <% } else if (showExtList) { %>
    <div class="list-header">
      <a href="<%= ctx %>/testing" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:var(--ext);">&#129309; External Testing Jobs</div>
    </div>
    <% if (myExtJobs.isEmpty()) { %>
    <div class="empty-state"><div class="empty-icon">&#129309;</div><p class="empty-text">No external jobs ready for testing.<br>Jobs appear here after QC approves them.</p></div>
    <% } else { for (Object[] r : myExtJobs) {
        int rid=(Integer)r[0]; String rsrc=(String)r[1]; String rref=(String)r[2];
        String rtit=(String)r[3]; String rvt=(String)r[4]; String rclient=(String)r[5];
        String rdead=(String)r[6]; int rpct=(Integer)r[8]; String rdes=(String)r[9];
        String pctCol=rpct>=100?"var(--green)":rpct>0?"#ffc107":"var(--tst)";
        String badgeTxt=rpct>=100?"&#9745; Test Complete":rpct>0?"&#128230; Testing In Progress":"&#9650; Pending Test";
        String badgeStyle=rpct>=100?"background:rgba(34,197,94,.15);color:var(--green);":rpct>0?"background:rgba(255,193,7,.12);color:#ffc107;":"background:rgba(245,158,11,.1);color:var(--tst);";
        String clientAbbr=rclient!=null&&rclient.length()>=3?rclient.substring(0,3).toUpperCase():"EXT";
    %>
    <a href="<%= ctx %>/testing?reqId=<%= rid %>&src=<%= rsrc %>&surface=external" class="job-card ec">
      <div class="jc-icon ec"><%= clientAbbr %></div>
      <div class="jc-body">
        <div class="jc-num ec"><%= rref %> &nbsp;&middot;&nbsp; <span style="color:var(--muted);"><%= rvt.replace("_"," ").toUpperCase() %></span></div>
        <div class="jc-title"><%= rtit %></div>
        <div class="jc-meta">&#128101; <%= rclient %> &nbsp;&nbsp; &#9997; @<%= rdes %> &nbsp;&nbsp; &#8987; <%= rdead %></div>
      </div>
      <div class="jc-right">
        <span class="jc-badge" style="<%= badgeStyle %>"><%= badgeTxt %></span>
        <span class="jc-pct" style="color:<%= pctCol %>;"><%= rpct %>% Test</span>
        <div class="pct-bar-sm"><div class="pct-fill-sm ec" style="width:<%= rpct %>%"></div></div>
      </div>
    </a>
    <% } } %>

    <%-- ════ DETAIL ════ --%>
    <% } else if (showDetail) {
        boolean isInt = "internal".equals(selSrc);
        String detailColor = isInt ? "var(--int)" : "var(--ext)";
        String detailBannerCls = isInt ? "ic" : "ec";
    %>
    <div class="list-header" style="margin-bottom:12px;">
      <a href="<%= backLink %>" class="lh-back">&#8592; Back</a>
      <div class="lh-title" style="color:<%= detailColor %>;">
        <%= isInt?"&#127981; Internal":"&#129309; External" %> Testing
      </div>
    </div>

    <!-- Draft restored banner -->
    <div id="draft-restored-banner" style="display:none;background:rgba(245,158,11,.08);border:1px solid rgba(245,158,11,.3);border-radius:10px;padding:10px 16px;margin-bottom:14px;align-items:center;gap:10px;">
      <i class="fas fa-history" style="color:var(--tst);"></i>
      <span style="font-size:12px;color:var(--tst);font-weight:600;">Draft restored &#8212; your previous test results have been reloaded.</span>
      <button onclick="document.getElementById('draft-restored-banner').style.display='none'" style="margin-left:auto;background:none;border:none;color:var(--muted);cursor:pointer;font-size:14px;">&times;</button>
    </div>

    <div class='detail-banner <%= detailBannerCls %>'>
      <div class="db-item"><label>Job Ref</label><span style="color:<%= detailColor %>;font-family:'Rajdhani',sans-serif;"><%= sel_ref %></span></div>
      <div class="db-item"><label>Model</label><span><%= sel_title %></span></div>
      <div class="db-item"><label>Vehicle Type</label><span><%= sel_vtype.replace("_"," ") %></span></div>
      <div class="db-item"><label>Designer</label><span>@<%= ds_designer %></span></div>
      <div class="db-item"><label>Design %</label><span style="color:var(--green);"><%= ds_pct %>%</span></div>
      <span class="stage-pill">&#9679; QC Approved</span>
    </div>

    <!-- TASK PROGRESS TRACKER -->
    <div class="task-progress">
      <div class="tp-title">
        Testing Progress
        <div style="display:flex;align-items:center;gap:10px;">
          <span id="top-save-status" style="font-size:10px;color:var(--muted);transition:color .3s;display:flex;align-items:center;gap:5px;"></span>
          <span class="tp-pct" id="tp-pct">0%</span>
        </div>
      </div>
      <div class="tp-bar"><div class="tp-fill" id="tp-fill" style="width:0%"></div></div>
      <div class="tp-stages">
        <span class="tp-stage ns" id="st0">&#128270; Reviewing QC Report</span>
        <span class="tp-stage ns" id="st25">&#128230; Running Tests (25%)</span>
        <span class="tp-stage ns" id="st50">&#128202; Recording Results (50%)</span>
        <span class="tp-stage ns" id="st75">&#128203; Final Assessment (75%)</span>
        <span class="tp-stage ns" id="st100">&#9745; Testing Complete (100%)</span>
      </div>
    </div>

    <!-- TABS -->
    <div class="tab-row">
      <button class="tab-btn on" onclick="tstTab('form',this)"><i class="fas fa-flask"></i> Testing Form</button>
      <button class="tab-btn"    onclick="tstTab('hist',this)"><i class="fas fa-history"></i> History</button>
    </div>

    <!-- ═══ TESTING FORM ═══ -->
    <div id="tst-form">
    <form method="post" action="<%= ctx %>/jsp/save_testing_work.jsp" enctype="multipart/form-data" id="tstForm">
      <input type="hidden" name="jobId"   value="<%= selId %>">
      <input type="hidden" name="srcType" value="<%= selSrc %>">
      <input type="hidden" name="action"  id="tstAction" value="testing_passed">
      <input type="hidden" name="testsJson" id="testsJsonInput" value="[]">

      <!-- SECTION 1: DESIGN SPECS (READ-ONLY REFERENCE) -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--tst);">
          <div class="sec-icon" style="background:rgba(245,158,11,.12);">&#128196;</div>
          <div><div class="sec-title" style="color:var(--tst);">Section 1 &#8212; Design &amp; QC Reference</div>
          <div class="sec-sub">Read-only reference from design &amp; QC team</div></div>
          <span class="ro-pill">READ ONLY</span>
          <span class="sec-badge" id="badge-s1">100%</span>
        </div>
        <div class="sec-body">
          <% if (!ds_overview.equals("—")) { %>
          <div class="note-box" style="background:rgba(245,158,11,.04);border:1px solid rgba(245,158,11,.2);">
            <div class="nb-lbl" style="color:var(--tst);">&#128221; Design Overview</div>
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
          <% if (!ds_remarks.equals("—")) { %>
          <div class="note-box" style="background:rgba(108,99,255,.04);border:1px solid rgba(108,99,255,.2);">
            <div class="nb-lbl" style="color:var(--int);">&#128172; Designer Remarks</div>
            <div class="nb-body"><%= ds_remarks %></div>
          </div>
          <% } %>
          <%-- Design files --%>
          <% boolean hasBP=!ds_blueprint.equals("—")&&!ds_blueprint.isEmpty();
             boolean hasMD=!ds_model3d.equals("—")&&!ds_model3d.isEmpty();
             boolean hasEX=!ds_extraFiles.equals("—")&&!ds_extraFiles.isEmpty();
             if (hasBP||hasMD||hasEX) { %>
          <div class="note-box" style="background:rgba(108,99,255,.05);border:1px solid rgba(108,99,255,.2);margin-top:10px;">
            <div class="nb-lbl" style="color:var(--int);">&#128206; Design Documents</div>
            <div style="display:flex;flex-wrap:wrap;gap:10px;margin-top:8px;">
              <% if(hasBP){ String bpExt=ds_blueprint.contains(".")?ds_blueprint.substring(ds_blueprint.lastIndexOf(".")).toLowerCase():""; %>
              <a href="<%= ctx %>/uploads/design/<%= ds_blueprint %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:7px 13px;background:rgba(108,99,255,.1);border:1px solid rgba(108,99,255,.3);border-radius:8px;text-decoration:none;color:var(--int);font-size:12px;font-weight:600;">
                &#128196; Blueprint<span style="font-size:9px;background:rgba(108,99,255,.2);padding:1px 5px;border-radius:4px;"><%= bpExt.isEmpty()?"FILE":bpExt.substring(1).toUpperCase() %></span>
              </a><% } %>
              <% if(hasMD){ String mdExt=ds_model3d.contains(".")?ds_model3d.substring(ds_model3d.lastIndexOf(".")).toLowerCase():""; %>
              <a href="<%= ctx %>/uploads/design/<%= ds_model3d %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:7px 13px;background:rgba(0,200,255,.07);border:1px solid rgba(0,200,255,.25);border-radius:8px;text-decoration:none;color:var(--accent);font-size:12px;font-weight:600;">
                &#128347; 3D Model<span style="font-size:9px;background:rgba(0,200,255,.15);padding:1px 5px;border-radius:4px;"><%= mdExt.isEmpty()?"FILE":mdExt.substring(1).toUpperCase() %></span>
              </a><% } %>
              <% if(hasEX){ for(String ef:ds_extraFiles.split(",")){ if(ef.trim().isEmpty()) continue;
                 String[] pts=ef.trim().split("\\|"); String efn=pts[0]; String efo=pts.length>1?pts[1]:efn;
                 String ext2=efn.contains(".")?efn.substring(efn.lastIndexOf(".")).toLowerCase():""; %>
              <a href="<%= ctx %>/uploads/design/<%= efn %>" target="_blank"
                 style="display:inline-flex;align-items:center;gap:8px;padding:7px 13px;background:rgba(34,197,94,.06);border:1px solid rgba(34,197,94,.25);border-radius:8px;text-decoration:none;color:var(--green);font-size:12px;font-weight:600;max-width:220px;">
                &#128196; <span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:130px;"><%= efo %></span>
                <span style="font-size:9px;background:rgba(34,197,94,.15);padding:1px 5px;border-radius:4px;flex-shrink:0;"><%= ext2.isEmpty()?"FILE":ext2.substring(1).toUpperCase() %></span>
              </a><% } } %>
            </div>
          </div>
          <% } %>
        </div>
      </div>

      <!-- SECTION 2: TEST EXECUTION -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--tst);">
          <div class="sec-icon" style="background:rgba(245,158,11,.12);">&#128202;</div>
          <div>
            <div class="sec-title" style="color:var(--tst);">Section 2 &#8212; Test Execution
              <span id="vtype-label" style="font-size:10px;font-weight:600;background:rgba(245,158,11,.15);color:var(--tst);padding:2px 8px;border-radius:10px;margin-left:8px;text-transform:uppercase;letter-spacing:1px;"></span>
            </div>
            <div class="sec-sub" id="sec2-sub">12 standard tests for this vehicle type. Record result and score for each.</div>
          </div>
          <span class="sec-badge" id="badge-s2">0%</span>

        </div>
        <div style="padding:0;">
          <table class="test-table" id="testTable">
            <thead><tr>
              <th style="width:34px;">#</th>
              <th style="width:170px;">Test Category</th>
              <th style="width:210px;">Test Type</th>
              <th style="width:100px;">Result</th>
              <th style="width:110px;">Score /100</th>
              <th>Remarks</th>
            </tr></thead>
            <tbody id="testTbody">
              <tr><td colspan="6" style="text-align:center;padding:18px;color:var(--muted);font-style:italic;">Loading tests...</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- SECTION 3: OVERALL ASSESSMENT -->
      <div class="sec">
        <div class="sec-head" style="border-left:3px solid var(--purple);">
          <div class="sec-icon" style="background:rgba(124,92,252,.12);">&#128203;</div>
          <div><div class="sec-title" style="color:var(--purple);">Section 3 &#8212; Overall Assessment</div>
          <div class="sec-sub">Final verdict &#8212; send to Analytics or flag for re-work</div></div>
          <span class="sec-badge" id="badge-s3">0%</span>
        </div>
        <div class="sec-body">
          <div class="grid2" style="margin-bottom:13px;">
            <div class="fg">
              <label>Overall Test Result <span style="color:var(--accent2);">*</span></label>
              <select name="overall_result" id="overallResult" class="fc" onchange="calcProgress()">
                <option value="">&#8212; Select Result &#8212;</option>
                <option value="All Tests Passed">&#9989; All Tests Passed</option>
                <option value="Passed with Minor Issues">&#9888; Passed with Minor Issues</option>
                <option value="Conditional Pass">&#128203; Conditional Pass</option>
                <option value="Failed &#8212; Needs Re-test">&#10007; Failed &#8212; Needs Re-test</option>
                <option value="Failed &#8212; Critical Issues">&#128308; Failed &#8212; Critical Issues</option>
              </select>
            </div>
            <div class="fg">
              <label>Overall Score</label>
              <div style="display:flex;align-items:center;gap:10px;">
                <input type="number" name="overall_score" id="overallScore" class="fc" min="0" max="100"
                       placeholder="0-100" style="width:100px;" oninput="calcProgress()">
                <div style="flex:1;">
                  <div id="overallScoreBar" class="score-bar"><div id="overallScoreFill" class="score-fill" style="width:0%;"></div></div>
                  <div style="font-size:9px;color:var(--muted);margin-top:3px;">Score out of 100</div>
                </div>
              </div>
            </div>
          </div>
          <div class="fg">
            <label>Test Engineer Notes <span style="color:var(--accent2);">*</span></label>
            <textarea name="tester_notes" id="tsterNotes" class="fc" required
              placeholder="Detailed observations, test conditions, failures found, recommendations for analytics..."></textarea>
          </div>
          <div class="fg">
            <label>&#128247; Test Evidence Photo <span style="font-weight:400;color:var(--muted);">(optional)</span></label>
            <input type="file" name="testPhoto" accept="image/jpeg,image/png,image/webp"
                   style="width:100%;background:rgba(255,255,255,.02);border:1px solid var(--border);border-radius:8px;padding:8px 12px;color:var(--muted);font-family:'Exo 2',sans-serif;cursor:pointer;"
                   onchange="prevPhoto(this)">
            <div id="photoPrev" style="display:none;margin-top:8px;border-radius:8px;overflow:hidden;border:1px solid var(--border);max-height:140px;">
              <img id="photoPrevImg" src="" alt="" style="width:100%;height:140px;object-fit:cover;">
            </div>
          </div>
          <!-- ACTION BUTTONS -->
          <div class="actions">
            <button type="button" class="btn btn-pass" onclick="submitTesting('testing_passed')">
              <i class="fas fa-check-double"></i> Pass &#8212; Send to Analytics
            </button>
            <button type="button" class="btn btn-fail" onclick="submitTesting('testing_failed')">
              <i class="fas fa-times"></i> Fail &#8212; Back to QC
            </button>
            <button type="button" class="btn btn-cond" onclick="submitTesting('testing_conditional')">
              <i class="fas fa-exclamation-circle"></i> Conditional Pass
            </button>
          </div>
        </div>
      </div>
    </form>
    </div><!-- /tst-form -->

    <!-- ═══ HISTORY TAB ═══ -->
    <div id="tst-hist" style="display:none;">
    <div class="sec">
      <div class="sec-head">
        <div class="sec-icon" style="background:rgba(245,158,11,.12);">&#128202;</div>
        <div><div class="sec-title"><%= isInt?"Internal":"External" %> Testing History</div>
        <div class="sec-sub">Past test results &amp; decisions</div></div>
      </div>
      <div style="overflow-x:auto;">
        <table style="width:100%;border-collapse:collapse;font-size:12px;">
          <thead><tr>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">#</th>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">Job Ref</th>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">Model</th>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">Result</th>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">Engineer</th>
            <th style="padding:8px 14px;background:rgba(255,255,255,.03);font-size:9px;font-weight:700;color:var(--muted);text-transform:uppercase;border-bottom:1px solid var(--border);text-align:left;">Date</th>
          </tr></thead>
          <tbody>
          <% List<Object[]> showHist = isInt ? histInt : histExt;
             if (showHist.isEmpty()) { %>
          <tr><td colspan="6" style="text-align:center;padding:28px;color:var(--muted);font-style:italic;">No test results recorded yet.</td></tr>
          <% }
          int hi=1; for (Object[] h : showHist) {
              String ha=(String)h[2];
              String hcls="testing_passed".equals(ha)?"hib-pass":"testing_failed".equals(ha)?"hib-fail":"hib-cond";
              String hlbl="testing_passed".equals(ha)?"Passed":"testing_failed".equals(ha)?"Failed":"Conditional";
              java.sql.Timestamp hdt=(java.sql.Timestamp)h[5];
              String hds=hdt!=null?hdt.toString().substring(0,16):"—";
          %>
          <tr>
            <td style="padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);color:var(--muted);"><%= hi++ %></td>
            <td style='padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);font-weight:700;font-family:"Rajdhani",sans-serif;color:<%= isInt?"var(--int)":"var(--ext)" %>;'><%= h[0] %></td>
            <td style="padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);"><%= h[1] %></td>
            <td style="padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);"><span class="hi-badge <%= hcls %>"><%= hlbl %></span></td>
            <td style="padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);"><code style="background:rgba(255,255,255,.05);padding:2px 7px;border-radius:5px;font-size:10px;color:var(--muted);">@<%= h[4] %></code></td>
            <td style="padding:9px 14px;border-bottom:1px solid rgba(30,45,69,.5);font-size:10px;color:var(--muted);"><%= hds %></td>
          </tr>
          <% } %>
          </tbody>
        </table>
      </div>
    </div>
    </div><!-- /tst-hist -->

    <% } // end showDetail %>
  </div><!-- /main-body -->
</div><!-- /main -->

<!-- ══ RIGHT SIDEBAR ══ -->
<div class="sb-right">
  <div class="sbr-team">
    <div class="sbr-head">
      <div class="sbr-head-title">
        &#128230; <%= tstVehicleLabel %> Team
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
          if (tmLast!=null){long diff=(System.currentTimeMillis()-tmLast.getTime())/60000L;
              if(diff<=5){dotC="#22c55e";stTxt="Online";stCol="#22c55e";}
              else if(diff<=30){dotC="#f59e0b";stTxt="Away "+diff+"m";stCol="#f59e0b";}}
          boolean isMe=tmUser.equals(tstUser);
          String[] np=tmName.split(" "); String ini="";
          for(String n:np) if(!n.isEmpty()) ini+=n.charAt(0);
          if(ini.length()>2) ini=ini.substring(0,2);
          String avBg=isMe?"linear-gradient(135deg,var(--tst),var(--tst2))"
                      :tmSlot==1?"linear-gradient(135deg,#6c63ff,#4f46e5)"
                      :tmSlot==2?"linear-gradient(135deg,#00b4a6,#008c84)"
                      :"linear-gradient(135deg,#f59e0b,#b45309)";
      %>
      <div class="tm-row">
        <div class="tm-av" style="background:<%= avBg %>;"><%= ini.toUpperCase() %></div>
        <div class="tm-info">
          <div class="tm-name"><%= tmName %> <% if(isMe){%><span class="tm-you">YOU</span><%}%></div>
          <div class="tm-sub">@<%= tmUser %> &nbsp;&middot;&nbsp; <span style="color:var(--purple);font-weight:700;">Slot <%= tmSlot %></span></div>
          <div class="tm-status"><span class="tm-dot" style="background:<%= dotC %>;"></span><span class="tm-stxt" style="color:<%= stCol %>;"><%= stTxt %></span></div>
        </div>
      </div>
      <% } } %>
    </div>
  </div>
  <div class="sbr-hist">
    <div style="padding:8px 14px;background:rgba(255,255,255,.02);border-bottom:1px solid var(--border);flex-shrink:0;">
      <div style="font-family:'Rajdhani',sans-serif;font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:2px;">Testing History</div>
    </div>
    <div class="htabs">
      <div class="htab hi" id="ht-int" onclick="switchHist('int',this)">&#127981; Internal (<%= histInt.size() %>)</div>
      <div class="htab"    id="ht-ext" onclick="switchHist('ext',this)">&#129309; External (<%= histExt.size() %>)</div>
    </div>
    <div class="hbody">
      <div id="hbody-int">
        <% if(histInt.isEmpty()){%><div class="hi-empty">No internal history</div>
        <%}else{for(Object[] h:histInt){String ha=(String)h[2];
          String hcls="testing_passed".equals(ha)?"hib-pass":"testing_failed".equals(ha)?"hib-fail":"hib-cond";
          String hlbl="testing_passed".equals(ha)?"Passed":"testing_failed".equals(ha)?"Failed":"Conditional";%>
        <div class="hi-item"><div class="hi-num int"><%= h[0] %></div>
          <div class="hi-title"><%= h[1] %></div>
          <span class="hi-badge <%= hcls %>"><%= hlbl %></span></div>
        <%}}%>
      </div>
      <div id="hbody-ext" style="display:none;">
        <% if(histExt.isEmpty()){%><div class="hi-empty">No external history</div>
        <%}else{for(Object[] h:histExt){String ha=(String)h[2];
          String hcls="testing_passed".equals(ha)?"hib-pass":"testing_failed".equals(ha)?"hib-fail":"hib-cond";
          String hlbl="testing_passed".equals(ha)?"Passed":"testing_failed".equals(ha)?"Failed":"Conditional";%>
        <div class="hi-item"><div class="hi-num ext"><%= h[0] %></div>
          <div class="hi-title"><%= h[1] %></div>
          <span class="hi-badge <%= hcls %>"><%= hlbl %></span></div>
        <%}}%>
      </div>
    </div>
  </div>
</div><!-- /sb-right -->

</div><!-- /layout -->

<% if (showDetail) { %>
<script>
/* ── VEHICLE TYPE from JSP ── */
var vehicleType = '<%= sel_vtype.toLowerCase().replace("_"," ").trim() %>';

/* ── VEHICLE-TYPE-SPECIFIC TEST CATEGORIES ── */
/* ── FIXED 8-TEST ROWS PER VEHICLE TYPE ── */
var fixedTests = {

  /* ══ BUS / MINIBUS / COACH — 12 tests ══ */
  'bus': [
    { category:'Engine & Powertrain',      type:'Engine Start & Idle Stability',        desc:'Cold/hot start, idle RPM, vibration' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission levels, fuel economy full load' },
    { category:'Transmission',             type:'Gear Shift & Drive Smoothness',        desc:'All gears, reverse, neutral balance' },
    { category:'Braking System',           type:'Air Brake & Emergency Stop',           desc:'Pressure, 60/80 kmh distance, fade' },
    { category:'Braking System',           type:'Parking Brake & Brake Fade Test',      desc:'Hold on grade, fade under repeated use' },
    { category:'Suspension & Handling',    type:'Ride Comfort & Cornering Stability',   desc:'Laden/empty, pothole, turning radius' },
    { category:'Electrical & Systems',     type:'Lights, Doors & PA System',            desc:'All lights, door mechanism, PA, CCTV' },
    { category:'Safety Systems',           type:'Emergency Exits & Fire Suppression',   desc:'Exit doors, fire system, crash sensors' },
    { category:'Passenger Comfort',        type:'AC, Seating & Interior Condition',     desc:'AC/heating, seats, handrails, flooring' },
    { category:'Body & Structure',         type:'Panel Fit, Seals & Water Ingress',     desc:'Body panels, door/window seals, water test' },
    { category:'Performance',              type:'Laden Acceleration & Grade Climb',     desc:'0-60 kmh laden, gradeability test' },
    { category:'Performance',              type:'Highway Cruise & Fuel Economy',        desc:'Steady cruise, fuel economy at 80 kmh' }
  ],

  /* ══ CAR / SEDAN / SUV / HATCHBACK — 12 tests ══ */
  'car': [
    { category:'Engine & Powertrain',      type:'Engine Start & Idle Stability',        desc:'Cold/hot start, idle RPM, vibration' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission check, fuel economy run' },
    { category:'Transmission',             type:'Gear Shift & Drive Smoothness',        desc:'All gears, clutch, reverse, paddle shift' },
    { category:'Braking System',           type:'ABS & Brake Distance Test',            desc:'60/100 kmh stop distance, EBD check' },
    { category:'Braking System',           type:'Parking Brake & Brake Fade',           desc:'Handbrake hold, fade under repeated use' },
    { category:'Suspension & Handling',    type:'Ride Comfort & Cornering',             desc:'Pothole, body roll, wheel alignment' },
    { category:'Electrical & Electronics', type:'Lights, Cluster & Infotainment',       desc:'All lights, ADAS, instrument cluster' },
    { category:'Safety Systems',           type:'Airbags, Seat Belts & Crash Sensors',  desc:'Airbag readiness, belt tensioners, sensors' },
    { category:'Body & Structure',         type:'Panel Fit, Seals & Water Test',        desc:'Body fit, door seals, water ingress' },
    { category:'Body & Structure',         type:'NVH — Noise, Vibration & Harshness',   desc:'Cabin noise at idle, cruise & acceleration' },
    { category:'Performance',              type:'0-100 kmh Acceleration',               desc:'Acceleration timing, throttle response' },
    { category:'Performance',              type:'Highway Cruise & Economy Run',         desc:'Top speed, cruise stability, fuel economy' }
  ],

  /* ══ TRUCK / HEAVY VEHICLE — 12 tests ══ */
  'truck': [
    { category:'Engine & Powertrain',      type:'Engine Start & Turbo Response',        desc:'Cold/hot start, turbo spool, emissions' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission levels, fuel economy full load' },
    { category:'Transmission',             type:'Gear Shift & Heavy Load Drive',        desc:'All gears, clutch under load, PTO check' },
    { category:'Braking System',           type:'Air Brake & Laden Stop Test',          desc:'Brake pressure, 60/80 kmh laden stop' },
    { category:'Braking System',           type:'Jake Brake & Parking Brake Test',      desc:'Engine brake, hold on grade laden' },
    { category:'Suspension & Handling',    type:'Laden Ride & Axle Load Balance',       desc:'Axle balance, pothole, stability laden' },
    { category:'Electrical & Systems',     type:'Lights, Camera & Trailer Connect',     desc:'All lights, reverse camera, trailer plug' },
    { category:'Safety Systems',           type:'Overload Alert & Blind Spot System',   desc:'Overload sensor, tyre pressure, camera' },
    { category:'Body & Structure',         type:'Cabin Fit & Cargo Bed Integrity',      desc:'Panel fit, seals, cargo bed, fifth wheel' },
    { category:'Body & Structure',         type:'NVH — Cabin Noise & Vibration',        desc:'Cabin noise at idle, cruise, loaded drive' },
    { category:'Performance',              type:'Laden Acceleration & Grade Climb',     desc:'0-60 kmh laden, gradeability test' },
    { category:'Performance',              type:'Range Test & Fuel Economy',            desc:'Full load range, fuel at highway cruise' }
  ],

  /* ══ TWO WHEELER / BIKE / MOTORCYCLE — 12 tests ══ */
  'two_wheeler': [
    { category:'Engine & Powertrain',      type:'Engine Start & Rev Response',          desc:'Cold/hot start, idle, throttle response' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission check, fuel economy run' },
    { category:'Transmission',             type:'Gear Shift & Clutch Check',            desc:'All gears, false neutral, smooth drive' },
    { category:'Braking System',           type:'Front Brake Distance Test',            desc:'60 kmh front brake stop distance' },
    { category:'Braking System',           type:'Rear Brake & CBS/ABS Check',           desc:'Rear brake stop, ABS/CBS activation test' },
    { category:'Suspension & Handling',    type:'Front Fork & Rear Shock Check',        desc:'Fork action, rear shock, rebound damping' },
    { category:'Suspension & Handling',    type:'Cornering Stability & Steering Play',  desc:'Lean angle stability, steering play check' },
    { category:'Electrical & Electronics', type:'Lights, Cluster & Kill Switch',        desc:'All lights, indicators, kill switch' },
    { category:'Safety Systems',           type:'Engine Kill on Tip & Tyre Condition',  desc:'Tip sensor, tyre wear, chain/belt tension' },
    { category:'Body & Structure',         type:'Panel Fit, Tank Seal & Exhaust Mount', desc:'Panel finish, tank seal, mirror, footrest' },
    { category:'Performance',              type:'0-60 kmh Acceleration',                desc:'Acceleration timing, throttle response' },
    { category:'Performance',              type:'Top Speed & Fuel Economy Run',         desc:'Top speed, pillion load, highway cruise' }
  ],

  /* ══ ELECTRIC VEHICLE / EV — 12 tests ══ */
  'electric': [
    { category:'Motor & Drivetrain',       type:'Motor Start & Drive Mode Test',        desc:'Start response, all drive modes, efficiency' },
    { category:'Motor & Drivetrain',       type:'Regenerative Braking Check',           desc:'Regen levels, one-pedal drive, smoothness' },
    { category:'Battery System',           type:'Charge Capacity & BMS Check',          desc:'Full charge, AC/DC rate, cell balance' },
    { category:'Battery System',           type:'Battery Temperature & Range Test',     desc:'Thermal management, real-world range' },
    { category:'Braking System',           type:'ABS & Brake Distance Test',            desc:'60/100 kmh stop, regen + friction blend' },
    { category:'Braking System',           type:'Parking Brake & Brake Fade',           desc:'E-park hold, fade under repeated use' },
    { category:'Suspension & Handling',    type:'Ride Comfort & Low-CG Handling',       desc:'Pothole, cornering, noise & vibration' },
    { category:'Electrical & Electronics', type:'Cluster, ADAS & Charging Port',        desc:'OTA, ADAS, V2L, charging port integrity' },
    { category:'Safety Systems',           type:'Thermal Runaway & IP Rating',          desc:'BMS protection, water ingress, insulation' },
    { category:'Body & Structure',         type:'Panel Fit, Seals & NVH Check',         desc:'Body fit, seals, cabin noise & vibration' },
    { category:'Performance',              type:'0-100 kmh Acceleration',               desc:'Launch control, acceleration, torque' },
    { category:'Performance',              type:'Real-World Range & Fast Charge',       desc:'Range, fast charge recovery, V2L test' }
  ],

  /* ══ VAN / MINIVAN — 12 tests ══ */
  'van': [
    { category:'Engine & Powertrain',      type:'Engine Start & Idle Stability',        desc:'Cold/hot start, idle RPM, emissions' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission levels, fuel economy laden' },
    { category:'Transmission',             type:'Gear Shift & Drive Smoothness',        desc:'All gears, reverse, clutch engagement' },
    { category:'Braking System',           type:'ABS & Laden Brake Distance',           desc:'60/80 kmh laden stop, EBD check' },
    { category:'Braking System',           type:'Parking Brake & Brake Fade',           desc:'Handbrake hold on grade, fade test' },
    { category:'Suspension & Handling',    type:'Laden Ride & Stability',               desc:'Payload ride, pothole, wheel alignment' },
    { category:'Electrical & Systems',     type:'Lights, Cluster & Reverse Camera',     desc:'All lights, instrument cluster, camera' },
    { category:'Safety Systems',           type:'Emergency Stop & Crash Sensors',       desc:'Emergency stop, airbags if applicable' },
    { category:'Body & Structure',         type:'Sliding Door, Seals & Cargo Floor',    desc:'Sliding door action, seals, floor integrity' },
    { category:'Body & Structure',         type:'NVH — Cabin Noise & Vibration',        desc:'Cabin noise at idle, laden drive, cruise' },
    { category:'Performance',              type:'Laden Acceleration & Grade Climb',     desc:'0-80 kmh laden, grade climb test' },
    { category:'Performance',              type:'Fuel Economy & Highway Range',         desc:'Economy run, highway cruise, range test' }
  ],

  /* ══ DEFAULT / GENERIC — 12 tests ══ */
  'default': [
    { category:'Engine & Powertrain',      type:'Engine Start & Idle Stability',        desc:'Cold/hot start, idle, vibration check' },
    { category:'Engine & Powertrain',      type:'Emission & Fuel Consumption Test',     desc:'Emission check, fuel economy run' },
    { category:'Transmission',             type:'Gear Shift & Drive Smoothness',        desc:'All gears, reverse, neutral balance' },
    { category:'Braking System',           type:'Brake Distance & ABS Test',            desc:'60/100 kmh stop distance, fade test' },
    { category:'Braking System',           type:'Parking Brake & Brake Fade',           desc:'Hold on grade, fade test' },
    { category:'Suspension & Handling',    type:'Ride Comfort & Cornering',             desc:'Pothole, stability, wheel alignment' },
    { category:'Electrical & Electronics', type:'Lights & Instrument Cluster',          desc:'All lights, cluster, charging system' },
    { category:'Safety Systems',           type:'Emergency Stop & Safety Check',        desc:'Crash sensors, seat belts, airbags' },
    { category:'Body & Structure',         type:'Panel Fit & Water Seal Test',          desc:'Body fit, door seals, water ingress' },
    { category:'Body & Structure',         type:'NVH — Noise, Vibration & Harshness',   desc:'Cabin noise at idle and under load' },
    { category:'Performance',              type:'Acceleration & Grade Climb',           desc:'0-100 kmh, grade climb, throttle response' },
    { category:'Performance',              type:'Fuel Economy & Highway Cruise',        desc:'Economy run, top speed, highway range' }
  ]
};

/* ── RESOLVE VEHICLE TYPE TO KEY ── */
function resolveVehicleKey(vt) {
  vt = (vt||'').toLowerCase();
  if (vt.indexOf('bus')>=0||vt.indexOf('minibus')>=0||vt.indexOf('coach')>=0) return 'bus';
  if (vt.indexOf('truck')>=0||vt.indexOf('lorry')>=0||vt.indexOf('heavy')>=0) return 'truck';
  if (vt.indexOf('van')>=0||vt.indexOf('minivan')>=0) return 'van';
  if (vt.indexOf('bike')>=0||vt.indexOf('two')>=0||vt.indexOf('motor')>=0||
      vt.indexOf('scooter')>=0||vt.indexOf('moped')>=0) return 'two_wheeler';
  if (vt.indexOf('electric')>=0||vt.indexOf('ev')>=0||vt.indexOf('bev')>=0) return 'electric';
  if (vt.indexOf('car')>=0||vt.indexOf('sedan')>=0||vt.indexOf('suv')>=0||
      vt.indexOf('hatch')>=0||vt.indexOf('mpv')>=0||vt.indexOf('coupe')>=0) return 'car';
  return 'default';
}

var vehicleKey   = resolveVehicleKey(vehicleType);
var activeTests  = fixedTests[vehicleKey] || fixedTests['default'];

/* Set section 2 vehicle label */
(function(){
  var labels = {bus:'Bus',car:'Car / SUV',truck:'Truck',two_wheeler:'Two Wheeler',electric:'Electric Vehicle',van:'Van',default:'Vehicle'};
  var lbl = document.getElementById('vtype-label');
  if(lbl) lbl.textContent = labels[vehicleKey] || vehicleType || 'Vehicle';
  var sub = document.getElementById('sec2-sub');
  if(sub) sub.textContent = '12 standard tests for '+( labels[vehicleKey]||'this vehicle type')+'. Record result and score for each.';
})();

var testRowCount = 0;

/* ── BUILD FIXED TEST TABLE ── */
function buildFixedTestTable(savedData) {
  var tbody = document.getElementById('testTbody');
  tbody.innerHTML = '';
  testRowCount = 0;
  activeTests.forEach(function(test, i) {
    var saved = savedData && savedData[i] ? savedData[i] : null;
    var res   = saved ? (saved.result  || '') : '';
    var sc    = saved ? (saved.score   || '') : '';
    var rem   = saved ? (saved.remarks || '') : '';
    var row = document.createElement('tr');
    row.setAttribute('data-idx', i);
    row.setAttribute('data-cat', test.category);
    row.style.transition = 'background .25s, border-left-color .25s';
    var passOpts =
      '<option value="">&#8212; Select &#8212;</option>'+
      '<option value="Pass"'  +(res==='Pass'       ?' selected':'')+'>&#10003; Pass</option>'+
      '<option value="Fail"'  +(res==='Fail'       ?' selected':'')+'>&#10007; Fail</option>'+
      '<option value="Conditional"'+(res==='Conditional'?' selected':'')+'>&#9888; Conditional</option>'+
      '<option value="N/A"'  +(res==='N/A'        ?' selected':'')+'>N/A</option>';
    row.innerHTML =
      '<td style="color:var(--muted);font-size:12px;font-weight:700;text-align:center;width:34px;">'+(i+1)+'</td>'+
      '<td style="padding:10px 12px;">'+
        '<div style="font-size:12px;font-weight:700;color:var(--text);line-height:1.4;">'+test.category+'</div>'+
        '<div style="font-size:10px;color:var(--muted);margin-top:2px;">'+test.desc+'</div>'+
      '</td>'+
      '<td style="padding:10px 12px;">'+
        '<div style="font-size:12px;font-weight:700;color:var(--tst);">'+test.type+'</div>'+
      '</td>'+
      '<td style="padding:8px 10px;"><select class="fc result-sel" style="font-size:12px;font-weight:600;">'+passOpts+'</select></td>'+
      '<td style="padding:8px 10px;">'+
        '<input type="number" class="score-inp" min="0" max="100" placeholder="—" value="'+esc(String(sc===null?'':sc))+'">'+
        '<div class="score-bar"><div class="score-fill" style="width:'+(sc||0)+'%"></div></div>'+
      '</td>'+
      '<td style="padding:8px 10px;"><input type="text" class="fc" style="font-size:11px;" placeholder="Remarks..." value="'+esc(rem)+'"></td>';
    tbody.appendChild(row);

    /* Attach events via JS — no inline handlers needed */
    var sel = row.querySelector('.result-sel');
    sel.addEventListener('change', function(){
      colorResultRow(row, this.value);
      calcProgress();
      autoSaveNow();
    });
    row.querySelector('.score-inp').addEventListener('input', function(){
      updateScore(this, true);
      autoSaveNow();
    });
    row.querySelector('input[type=text]').addEventListener('input', function(){ scheduleAS(); });

    if(res) colorResultRow(row, res);
    /* Update score bar immediately for loaded values (silent=true, no autosave trigger) */
    if(sc){
      var inp = row.querySelector('.score-inp');
      if(inp) updateScore(inp, true);
    }
    testRowCount++;
  });
  calcProgress();
}

function colorResultRow(row, res){
  if(!row) return;
  /* Background */
  row.style.background =
    res==='Pass'        ? 'rgba(34,197,94,.08)'  :
    res==='Fail'        ? 'rgba(220,38,38,.08)'  :
    res==='Conditional' ? 'rgba(251,191,36,.07)' : '';
  /* Left border accent */
  row.style.borderLeft =
    res==='Pass'        ? '4px solid #22c55e' :
    res==='Fail'        ? '4px solid #ef4444' :
    res==='Conditional' ? '4px solid #fbbf24' : '4px solid transparent';
  /* Result select text color */
  var sel = row.querySelector('.result-sel');
  if(sel){
    sel.style.color =
      res==='Pass'        ? '#22c55e' :
      res==='Fail'        ? '#f87171' :
      res==='Conditional' ? '#fbbf24' : 'var(--text)';
    sel.style.fontWeight = res ? '700' : '400';
  }
  /* Score bar color */
  var fill = row.querySelector('.score-fill');
  if(fill){
    fill.style.background =
      res==='Pass'        ? 'linear-gradient(90deg,#16a34a,#22c55e)' :
      res==='Fail'        ? 'linear-gradient(90deg,#b91c1c,#ef4444)' :
      res==='Conditional' ? 'linear-gradient(90deg,#d97706,#fbbf24)' :
      'linear-gradient(90deg,var(--tst),var(--accent),var(--green))';
  }
}
function updateScore(inp, silent){
  var v=Math.min(100,Math.max(0,parseInt(inp.value)||0));
  var bar=inp.nextElementSibling;
  if(bar) bar.querySelector('.score-fill').style.width=v+'%';
  var os=document.getElementById('overallScoreFill');
  if(os) os.style.width=(document.getElementById('overallScore').value||0)+'%';
  calcProgress();
  if(!silent) scheduleAS();
}
function esc(s){ return String(s||'').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

/* ── COLLECT TEST ROWS ── */
function collectTests(){
  var tests=[];
  document.querySelectorAll('#testTbody tr[data-idx]').forEach(function(row){
    var i = parseInt(row.getAttribute('data-idx'));
    var sel = row.querySelector('select');
    var resVal = sel ? sel.value : '';
    var scoreVal = parseInt(row.querySelector('.score-inp').value)||0;
    var remVal = row.querySelector('input[type=text]') ? row.querySelector('input[type=text]').value : '';
    var cat  = row.getAttribute('data-cat')||'';
    var type = activeTests[i] ? activeTests[i].type : '';
    tests.push({category:cat, type:type, result:resVal, score:scoreVal, remarks:remVal});
  });
  return tests;
}

/* ── PROGRESS ── */
var curTstPct = 0;
function calcProgress(){
  var score = 0;

  /* S1: design data loaded = 15pts (auto) */
  score += 15;

  /* S2: test rows — 50pts. Each row with a result selected = 1 point */
  var rows = document.querySelectorAll('#testTbody tr[data-idx]');
  var filled = 0;
  rows.forEach(function(r){
    var sel = r.querySelector('select.result-sel');
    if(sel && sel.value) filled++;
  });
  var totalTests = activeTests ? activeTests.length : 12;
  var s2 = totalTests > 0 ? Math.min(50, Math.round((filled / totalTests) * 50)) : 0;
  setBadge('badge-s2', s2, 50); score += s2;

  /* S3: overall assessment = 35pts */
  var resEl   = document.getElementById('overallResult');
  var notesEl = document.getElementById('tsterNotes');
  var scEl    = document.getElementById('overallScore');
  var s3 = ((resEl&&resEl.value)?15:0) + ((notesEl&&notesEl.value.trim().length>0)?12:0) + ((scEl&&scEl.value)?8:0);
  setBadge('badge-s3', s3, 35); score += s3;

  var pct = Math.min(100, score); curTstPct = pct;
  var fill = document.getElementById('tp-fill'); if(fill) fill.style.width=pct+'%';
  var lbl  = document.getElementById('tp-pct');  if(lbl)  lbl.textContent=pct+'%';
  var osf  = document.getElementById('overallScoreFill');
  if(osf) osf.style.width=(document.getElementById('overallScore').value||0)+'%';

  /* Stage pills */
  [0,25,50,75,100].forEach(function(v,i,arr){
    var el=document.getElementById('st'+v); if(!el) return;
    if(pct>=100&&v===100) el.className='tp-stage active';
    else if(pct>=v&&(i===arr.length-1||pct<arr[i+1])) el.className='tp-stage active';
    else if(pct>v) el.className='tp-stage done';
    else el.className='tp-stage ns';
  });
  return pct;
}
function setBadge(id,val,max){
  var el=document.getElementById(id); if(!el) return;
  var p=max>0?Math.round((val/max)*100):0;
  el.textContent=p+'%';
  el.style.background=p>=100?'rgba(34,197,94,.15)':p>0?'rgba(255,193,7,.12)':'rgba(80,80,100,.2)';
  el.style.color=p>=100?'var(--green)':p>0?'#ffc107':'var(--muted)';
}

/* ── AUTO-SAVE (fully automatic) ── */
function scheduleAS(){
  clearTimeout(window._tstAS);
  setSaveStatus('&#9679; Unsaved','#f59e0b');
  window._tstAS = setTimeout(function(){ autoSave(); }, 800);
}
/* Immediate save — used when result/score changes so back button doesn't lose data */
function autoSaveNow(){
  clearTimeout(window._tstAS);
  autoSave();
}

/* Section 3 fields — overall result, notes, score */
document.addEventListener('change', function(e){
  var t = e.target;
  if(t.id==='overallResult'){ calcProgress(); scheduleAS(); }
});
document.addEventListener('input', function(e){
  var t = e.target;
  if(t.id==='tsterNotes'||t.id==='overallScore'){ calcProgress(); scheduleAS(); }
});
document.addEventListener('visibilitychange', function(){ if(document.visibilityState==='hidden') autoSave(); });
window.addEventListener('blur', function(){ autoSave(); });
window.addEventListener('beforeunload', function(){
  var payload = buildPayload();
  /* Try sendBeacon first (non-blocking) */
  var sent = false;
  if(navigator.sendBeacon){
    sent = navigator.sendBeacon('<%= ctx %>/jsp/save_testing_draft.jsp',
      new Blob([JSON.stringify(payload)], {type:'application/json; charset=UTF-8'}));
  }
  /* Fallback: synchronous XHR — reliable on back navigation */
  if(!sent){
    try{
      var xhr = new XMLHttpRequest();
      xhr.open('POST','<%= ctx %>/jsp/save_testing_draft.jsp', false);
      xhr.setRequestHeader('Content-Type','application/json; charset=UTF-8');
      xhr.send(JSON.stringify(payload));
    }catch(e){}
  }
});
/* Also save on pageshow — catches back button in bfcache browsers */
window.addEventListener('pagehide', function(){
  var payload = buildPayload();
  if(navigator.sendBeacon){
    navigator.sendBeacon('<%= ctx %>/jsp/save_testing_draft.jsp',
      new Blob([JSON.stringify(payload)], {type:'application/json; charset=UTF-8'}));
  }
});
setInterval(function(){ if(document.getElementById('tstForm')) autoSave(); }, 30000);

function setSaveStatus(msg, color){
  var ts = document.getElementById('top-save-status');
  if(ts){ ts.innerHTML = msg; ts.style.color = color || 'var(--muted)'; }
}

function buildPayload(){
  var tests = collectTests();
  var notes = document.getElementById('tsterNotes');
  var res   = document.getElementById('overallResult');
  var sc    = document.getElementById('overallScore');
  return {
    jobId:          '<%= selId %>',
    srcType:        '<%= selSrc %>',
    testsJson:      tests,
    tester_notes:   notes ? notes.value : '',
    overall_result: res   ? res.value   : '',
    overall_score:  sc    ? sc.value    : '',
    progress_pct:   String(curTstPct)
  };
}

function autoSave(){
  if('<%= selId %>' === '0' || '<%= selId %>' === '') return;
  var payload = buildPayload();
  setSaveStatus('&#128190; Saving...','#60a5fa');
  fetch('<%= ctx %>/jsp/save_testing_draft.jsp', {
    method: 'POST',
    headers: {'Content-Type':'application/json; charset=UTF-8'},
    body: JSON.stringify(payload)
  }).then(function(r){ return r.text(); }).then(function(txt){
    var d; try{ d=JSON.parse(txt); }catch(e){ d={error:txt}; }
    if(d.success){
      setSaveStatus('&#10003; Saved &middot; '+new Date().toLocaleTimeString(),'#4ade80');
      clearTimeout(window._saveClear);
      window._saveClear = setTimeout(function(){ setSaveStatus('','var(--muted)'); }, 3000);
    } else {
      setSaveStatus('&#10007; '+(d.error||'Save failed'),'#f87171');
      console.error('Auto-save failed:', d.error, txt);
    }
  }).catch(function(err){
    setSaveStatus('&#10007; Network error','#f87171');
    console.error('Auto-save error:', err);
  });
}

function saveDraft(){ autoSave(); }
function showToast(){}

/* ── LOAD DRAFT / AUTO-POPULATE ── */
(function(){
  // Set vehicle type badge in Section 2 header
  var vtLabel = document.getElementById('vtype-label');
  if(vtLabel) vtLabel.textContent = vehicleType || 'Unknown';

  fetch('<%= ctx %>/jsp/save_testing_draft.jsp?action=load&jobId=<%= selId %>&srcType=<%= selSrc %>')
  .then(function(r){return r.text();}).then(function(txt){
    var data; try{data=JSON.parse(txt);}catch(e){data=null;}
    var hasDraft = data && data.success && data.draft;

    if(hasDraft){
      var d=data.draft;
      if(d.tester_notes){var n=document.getElementById('tsterNotes');if(n)n.value=d.tester_notes;}
      if(d.overall_result){var r=document.getElementById('overallResult');if(r)for(var i=0;i<r.options.length;i++)if(r.options[i].value===d.overall_result){r.selectedIndex=i;break;}}
      if(d.overall_score){var s=document.getElementById('overallScore');if(s)s.value=d.overall_score;}
      if(d.tests_json){
        try{
          /* tests_json comes back as a JS array (inline JSON), not a string */
          var tests = Array.isArray(d.tests_json)
            ? d.tests_json
            : JSON.parse(d.tests_json);
          if(tests && tests.length > 0){
            document.getElementById('testTbody').innerHTML='';
            testRowCount=0;
            buildFixedTestTable(tests);
          } else { buildFixedTestTable(null); }
        }catch(e){ buildFixedTestTable(null); }
      } else { buildFixedTestTable(null); }
      var banner=document.getElementById('draft-restored-banner');
      var hasContent=d.tester_notes||(d.tests_json&&d.tests_json!=='[]');
      if(banner&&hasContent) banner.style.display='flex';
    } else {
      buildFixedTestTable(null);
    }

    // Update subtitle with count
    var total = activeTests ? activeTests.length : 8;
    var sub = document.getElementById('sec2-sub');
    if(sub) sub.textContent = (activeTests?activeTests.length:12)+' standard tests for '+(vehicleType||'this vehicle type')+'. Record result and score for each.';

    calcProgress();
  }).catch(function(){
    buildFixedTestTable(null);
    calcProgress();
  });
})();

/* ── SUBMIT ── */
function submitTesting(action){
  var notes=document.getElementById('tsterNotes');
  if(notes&&notes.value.trim().length<5){alert('Test Engineer Notes are required.');notes.focus();return;}
  var res=document.getElementById('overallResult');
  if(res&&!res.value){alert('Please select an Overall Test Result.');res.focus();return;}
  var tests=collectTests();
  if(tests.length===0){alert('Please add at least one test result.');return;}
  if(action==='testing_failed'){if(!confirm('Mark as Failed and send back to QC?')) return;}
  if(action==='testing_passed'){if(!confirm('Mark as Passed and send to Analytics?')) return;}
  document.getElementById('testsJsonInput').value=JSON.stringify(tests);
  document.getElementById('tstAction').value=action;
  document.getElementById('tstForm').submit();
}

/* ── TABS ── */
function tstTab(id,btn){
  ['form','hist'].forEach(function(t){document.getElementById('tst-'+t).style.display=t===id?'':'none';});
  document.querySelectorAll('.tab-btn').forEach(function(b){b.classList.remove('on');});
  if(btn) btn.classList.add('on');
}
function switchHist(which,btn){
  document.getElementById('hbody-int').style.display=which==='int'?'':'none';
  document.getElementById('hbody-ext').style.display=which==='ext'?'':'none';
  document.querySelectorAll('.htab').forEach(function(t){t.className='htab';});
  if(btn) btn.classList.add(which==='int'?'hi':'he');
}
function prevPhoto(inp){
  var p=document.getElementById('photoPrev'),i=document.getElementById('photoPrevImg');
  if(inp.files&&inp.files[0]){var r=new FileReader();r.onload=function(e){i.src=e.target.result;p.style.display='block';};r.readAsDataURL(inp.files[0]);}
  else p.style.display='none';
}
</script>
<% } // end showDetail script %>
</body>
</html>
