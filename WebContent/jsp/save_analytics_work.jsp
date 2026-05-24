<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection" %>
<%
    /* ═══════════════════════════════════════════════════════════════
       save_analytics_work.jsp
       Saves analytics assessment and advances workflow:
         testing_completed → analytics_completed (current_assignee = 'admin')
    ═══════════════════════════════════════════════════════════════ */
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp"); return;
    }
    String role    = (String) sess.getAttribute("role");
    String anaUser = (String) sess.getAttribute("username");
    if (!"analytics".equals(role) && !"admin".equals(role)) {
        response.sendRedirect("../dashboard.jsp"); return;
    }

    String ctx = request.getContextPath();

    String jobIdStr  = request.getParameter("jobId");
    String srcType   = request.getParameter("srcType");
    String market    = request.getParameter("market_segment");
    String costStr   = request.getParameter("cost_estimate");
    String unitsStr  = request.getParameter("projected_units");
    String roiStr    = request.getParameter("roi_pct");
    String riskLevel = request.getParameter("risk_level");
    String rec       = request.getParameter("recommendation");
    String notes     = request.getParameter("analyst_notes");

    /* Validate required fields */
    if (jobIdStr == null || srcType == null || market == null || market.trim().isEmpty()
        || notes == null || notes.trim().isEmpty()) {
        String backUrl = ctx + "/jsp/analytics_module.jsp?reqId=" + jobIdStr + "&src=" + srcType
                       + "&error=" + java.net.URLEncoder.encode("Required fields missing.", "UTF-8");
        response.sendRedirect(backUrl); return;
    }

    int    jobId = 0;
    double cost  = 0;
    int    units = 0;
    double roi   = 0;
    try { jobId = Integer.parseInt(jobIdStr.trim()); } catch (Exception e) { response.sendRedirect(ctx + "/analytics"); return; }
    try { cost  = Double.parseDouble(costStr.trim()); }  catch (Exception e) {}
    try { units = Integer.parseInt(unitsStr.trim()); }   catch (Exception e) {}
    try { roi   = Double.parseDouble(roiStr.trim()); }   catch (Exception e) {}

    if (riskLevel == null || riskLevel.trim().isEmpty()) riskLevel = "Low";
    if (rec        == null || rec.trim().isEmpty())       rec       = "Approve";

    String successMsg = "";
    String errorMsg   = "";

    try (Connection conn = DBConnection.getConnection()) {
        conn.setAutoCommit(false);
        try {
            /* 1. Upsert analytics_submissions */
            String tSrc = "internal".equals(srcType) ? "internal"
                        : "external".equals(srcType) ? "external" : "cr";

            PreparedStatement chk = conn.prepareStatement(
                "SELECT id FROM analytics_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
            chk.setInt(1, jobId); chk.setString(2, tSrc);
            ResultSet cr = chk.executeQuery();
            if (cr.next()) {
                // Update existing
                int existId = cr.getInt("id");
                PreparedStatement upd = conn.prepareStatement(
                    "UPDATE analytics_submissions SET analyst_user=?,market_segment=?,cost_estimate=?," +
                    "projected_units=?,roi_pct=?,risk_level=?,recommendation=?,analyst_notes=?,submitted_at=NOW() " +
                    "WHERE id=?");
                upd.setString(1, anaUser);
                upd.setString(2, market.trim());
                upd.setDouble(3, cost);
                upd.setInt(4, units);
                upd.setDouble(5, roi);
                upd.setString(6, riskLevel);
                upd.setString(7, rec);
                upd.setString(8, notes.trim());
                upd.setInt(9, existId);
                upd.executeUpdate();
            } else {
                // Insert new
                PreparedStatement ins = conn.prepareStatement(
                    "INSERT INTO analytics_submissions(job_ref_id,source_type,analyst_user,market_segment," +
                    "cost_estimate,projected_units,roi_pct,risk_level,recommendation,analyst_notes,submitted_at) " +
                    "VALUES(?,?,?,?,?,?,?,?,?,?,NOW())");
                ins.setInt(1, jobId);
                ins.setString(2, tSrc);
                ins.setString(3, anaUser);
                ins.setString(4, market.trim());
                ins.setDouble(5, cost);
                ins.setInt(6, units);
                ins.setDouble(7, roi);
                ins.setString(8, riskLevel);
                ins.setString(9, rec);
                ins.setString(10, notes.trim());
                ins.executeUpdate();
            }

            /* 2. Advance workflow stage */
            String newStage    = "analytics_completed";
            String newAssignee = "admin";

            String updSql;
            if ("internal".equals(srcType))
                updSql = "UPDATE internal_jobs SET workflow_stage=?,current_assignee=? WHERE id=?";
            else if ("external".equals(srcType))
                updSql = "UPDATE external_orders SET workflow_stage=?,current_assignee=? WHERE id=?";
            else
                updSql = "UPDATE customer_requirements SET workflow_stage=?,current_assignee=? WHERE id=?";

            PreparedStatement wfUpd = conn.prepareStatement(updSql);
            wfUpd.setString(1, newStage);
            wfUpd.setString(2, newAssignee);
            wfUpd.setInt(3, jobId);
            wfUpd.executeUpdate();

            /* 3. Log to unified_workflow_history */
            try {
                PreparedStatement hist = conn.prepareStatement(
                    "INSERT INTO unified_workflow_history(source_type,source_id,stage,action,remarks,actioned_by) " +
                    "VALUES(?,?,'analytics',?,?,?)");
                hist.setString(1, tSrc);
                hist.setInt(2, jobId);
                hist.setString(3, "analytics_" + rec.toLowerCase().replace(" ","_"));
                String rem = ("Market:" + market + "|Cost:" + cost + "|Units:" + units +
                              "|ROI:" + roi + "%|Risk:" + riskLevel + "|Rec:" + rec);
                hist.setString(4, rem.substring(0, Math.min(500, rem.length())));
                hist.setString(5, anaUser);
                hist.executeUpdate();
            } catch (Exception hEx) { /* non-fatal */ }

            conn.commit();
            successMsg = "Analytics report submitted successfully. Job advanced to admin review.";

        } catch (Exception ex) {
            conn.rollback();
            errorMsg = "Error saving analytics: " + ex.getMessage();
        }
    } catch (Exception ex) {
        errorMsg = "Database error: " + ex.getMessage();
    }

    /* Redirect back */
    if (!errorMsg.isEmpty()) {
        response.sendRedirect(ctx + "/jsp/analytics_module.jsp?reqId=" + jobId + "&src=" + srcType
            + "&error=" + java.net.URLEncoder.encode(errorMsg, "UTF-8"));
    } else {
        // Redirect to the correct stream list
        String stream = "internal".equals(srcType) ? "internal" : "external";
        response.sendRedirect(ctx + "/jsp/analytics_module.jsp?surface=" + stream
            + "&success=" + java.net.URLEncoder.encode(successMsg, "UTF-8"));
    }
%>
