<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.io.*,javax.servlet.*,javax.servlet.http.*" %>
<%--
  save_qc_work.jsp — QC Decision Save Endpoint
  =============================================
  Handles QC approve / reject / conditional approval for:
    - internal_jobs      (srcType = 'internal')
    - external_orders    (srcType = 'external')
    - customer_requirements (srcType = 'cr')

  POST params:
    jobId         — int, PK of the job/order/requirement
    srcType       — 'internal' | 'external' | 'cr'
    action        — 'approved' | 'qc_rejected' | 'qc_conditional'
    remarks       — selected remark text
    severity      — None | Minor | Major | Critical
    inspector_notes — textarea (required)
    defects       — multi-value checkbox
    qcVerdicts    — JSON string of per-part verdicts
    complianceChecks — comma-separated compliance values
    meas_*        — measurement fields
    qcPhoto       — file upload (optional)

  On approve:    workflow_stage='qc_approved',  current_assignee='testing'
  On reject:     workflow_stage='qc_rejected',  current_assignee=<original designer>
  On conditional:workflow_stage='qc_approved',  current_assignee='testing'  (with condition notes)

  Logs to unified_workflow_history then redirects back to qc_module.jsp
--%>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../index.jsp"); return;
    }
    String role   = (String) sess.getAttribute("role");
    String qcUser = (String) sess.getAttribute("username");
    if (!"qc".equals(role) && !"admin".equals(role)) {
        response.sendRedirect("../dashboard.jsp"); return;
    }

    String jobIdStr  = request.getParameter("jobId");
    String srcType   = request.getParameter("srcType");
    String action    = request.getParameter("action");
    String remarks   = request.getParameter("remarks");
    String severity  = request.getParameter("severity");
    String notes     = request.getParameter("inspector_notes");
    String verdicts  = request.getParameter("qcVerdicts");
    String compliance= request.getParameter("complianceChecks");
    String[] defectsArr = request.getParameterValues("defects");
    String defects   = defectsArr != null ? String.join(", ", defectsArr) : "";

    // Measurement fields
    String measLength   = request.getParameter("meas_length");
    String measWidth    = request.getParameter("meas_width");
    String measHeight   = request.getParameter("meas_height");
    String measWheelbase= request.getParameter("meas_wheelbase");
    String measWeight   = request.getParameter("meas_weight");
    String measDisp     = request.getParameter("meas_disp");

    // If multipart not parsed (null params) try reading raw parts
    if (notes == null || jobIdStr == null) {
        try {
            for (javax.servlet.http.Part part : request.getParts()) {
                String name = part.getName();
                // Java 8 compatible byte reading
                java.io.InputStream is = part.getInputStream();
                java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
                byte[] buf = new byte[1024]; int n;
                while ((n = is.read(buf)) != -1) baos.write(buf, 0, n);
                String val = baos.toString("UTF-8").trim();
                if      ("inspector_notes".equals(name)  && notes == null)      notes = val;
                else if ("jobId".equals(name)            && jobIdStr == null)    jobIdStr = val;
                else if ("srcType".equals(name)          && srcType == null)     srcType = val;
                else if ("action".equals(name)           && action == null)      action = val;
                else if ("remarks".equals(name)          && remarks == null)     remarks = val;
                else if ("severity".equals(name)         && severity == null)    severity = val;
                else if ("qcVerdicts".equals(name)       && verdicts == null)    verdicts = val;
                else if ("complianceChecks".equals(name) && compliance == null)  compliance = val;
                else if ("defects".equals(name) && !val.isEmpty())
                    defects = defects.isEmpty() ? val : defects + ", " + val;
                else if ("meas_length".equals(name))    measLength    = val;
                else if ("meas_width".equals(name))     measWidth     = val;
                else if ("meas_height".equals(name))    measHeight    = val;
                else if ("meas_wheelbase".equals(name)) measWheelbase = val;
                else if ("meas_weight".equals(name))    measWeight    = val;
                else if ("meas_disp".equals(name))      measDisp      = val;
            }
        } catch (Exception pe) {
            // Last resort — redirect with actual error so we can diagnose
            response.sendRedirect(request.getContextPath()+"/qc?error="+
                java.net.URLEncoder.encode("Multipart parse error: "+pe.getMessage(),"UTF-8"));
            return;
        }
    }

    // Validate required fields
    if (jobIdStr == null || srcType == null || action == null || notes == null || notes.trim().isEmpty()) {
        String surf = "internal".equals(srcType) ? "internal" : "external";
        response.sendRedirect(request.getContextPath()+"/qc?reqId="+jobIdStr+"&src="+srcType+"&surface="+surf+"&error="+java.net.URLEncoder.encode("Required fields missing. Please fill Inspector Notes and try again.","UTF-8"));
        return;
    }

    int jobId = 0;
    try { jobId = Integer.parseInt(jobIdStr.trim()); }
    catch (NumberFormatException e) {
        response.sendRedirect(request.getContextPath()+"/qc?error="+java.net.URLEncoder.encode("Invalid Job ID.","UTF-8"));
        return;
    }

    if (!("approved".equals(action) || "qc_rejected".equals(action) || "qc_conditional".equals(action))) {
        String surf = "internal".equals(srcType) ? "internal" : "external";
        response.sendRedirect(request.getContextPath()+"/qc?reqId="+jobId+"&src="+srcType+"&surface="+surf+"&error="+java.net.URLEncoder.encode("Invalid action.","UTF-8"));
        return;
    }

    // Map display srcType to design_submissions source_type column values
    String dsSrcType = "internal".equals(srcType) ? "internal_job"
                     : "external".equals(srcType)  ? "external_order"
                     : srcType; // 'cr' stays as 'cr'

    // Determine new workflow stage and assignee
    String newStage, newAssignee;
    if ("approved".equals(action) || "qc_conditional".equals(action)) {
        newStage    = "qc_approved";
        newAssignee = "testing"; // will be replaced by round-robin below
    } else {
        newStage    = "qc_rejected";
        newAssignee = "design";
    }

    // For rejection, look up the designer to send back to
    String designerUsername = null;
    if ("qc_rejected".equals(action)) {
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement ds = conn.prepareStatement(
                "SELECT designer_username FROM design_submissions WHERE job_ref_id=? AND source_type=? ORDER BY id DESC LIMIT 1");
            ds.setInt(1, jobId); ds.setString(2, dsSrcType);
            ResultSet dr = ds.executeQuery();
            if (dr.next()) designerUsername = dr.getString("designer_username");
        } catch (Exception e) {}
        if (designerUsername == null || designerUsername.isEmpty()) designerUsername = "design";
        newAssignee = designerUsername;
    }

    // Round-robin testing user assignment (only for approve/conditional)
    if ("approved".equals(action) || "qc_conditional".equals(action)) {
        try (Connection conn = DBConnection.getConnection()) {
            // Get vehicle_type for this job
            String vtSql;
            if ("internal".equals(srcType)) vtSql="SELECT vehicle_type FROM internal_jobs WHERE id=?";
            else if ("external".equals(srcType)) vtSql="SELECT vehicle_type FROM external_orders WHERE id=?";
            else vtSql="SELECT vehicle_type FROM customer_requirements WHERE id=?";
            String vehicleType = null;
            PreparedStatement vtPs = conn.prepareStatement(vtSql);
            vtPs.setInt(1, jobId);
            ResultSet vtRs = vtPs.executeQuery();
            if (vtRs.next()) vehicleType = vtRs.getString("vehicle_type");

            if (vehicleType != null) {
                // Lock round-robin row and get pool size
                PreparedStatement rrPs = conn.prepareStatement(
                    "SELECT last_slot_used, total_assigned FROM module_round_robin " +
                    "WHERE module_role='testing' AND vehicle_type=? FOR UPDATE");
                rrPs.setString(1, vehicleType);
                ResultSet rrRs = rrPs.executeQuery();

                int lastSlot = 0, poolSize = 0;
                // Get pool size
                PreparedStatement poolPs = conn.prepareStatement(
                    "SELECT COUNT(*) FROM module_team_members " +
                    "WHERE module_role='testing' AND vehicle_type=? AND is_active=1");
                poolPs.setString(1, vehicleType);
                ResultSet poolRs = poolPs.executeQuery();
                if (poolRs.next()) poolSize = poolRs.getInt(1);

                if (poolSize > 0) {
                    if (rrRs.next()) lastSlot = rrRs.getInt("last_slot_used");
                    int nextSlot = (lastSlot % poolSize) + 1;

                    // Get tester at that slot
                    PreparedStatement tPs = conn.prepareStatement(
                        "SELECT username FROM module_team_members " +
                        "WHERE module_role='testing' AND vehicle_type=? AND slot_number=? AND is_active=1 LIMIT 1");
                    tPs.setString(1, vehicleType); tPs.setInt(2, nextSlot);
                    ResultSet tRs = tPs.executeQuery();
                    if (tRs.next()) {
                        newAssignee = tRs.getString("username");
                        // Update round-robin counter
                        PreparedStatement rrUpd = conn.prepareStatement(
                            "INSERT INTO module_round_robin(module_role,vehicle_type,last_slot_used,total_assigned) " +
                            "VALUES('testing',?,?,1) ON DUPLICATE KEY UPDATE " +
                            "last_slot_used=VALUES(last_slot_used),total_assigned=total_assigned+1");
                        rrUpd.setString(1, vehicleType); rrUpd.setInt(2, nextSlot);
                        rrUpd.executeUpdate();
                    }
                }
            }
        } catch (Exception rrEx) { /* fallback to 'testing' role */ }
    }

    // Build full remarks string including measurement summary
    StringBuilder fullRemarks = new StringBuilder();
    fullRemarks.append(remarks != null ? remarks : "");
    if (compliance != null && !compliance.isEmpty())
        fullRemarks.append(" | Compliance: ").append(compliance);
    if (defects != null && !defects.isEmpty())
        fullRemarks.append(" | Defects: ").append(defects);
    if (severity != null && !"None".equals(severity))
        fullRemarks.append(" | Severity: ").append(severity);
    String fullRemarksStr = fullRemarks.toString();

    // Photo upload handling (optional)
    String photoName = null;
    try {
        Part photoPart = request.getPart("qcPhoto");
        if (photoPart != null && photoPart.getSize() > 0) {
            String origName = photoPart.getSubmittedFileName();
            if (origName != null && !origName.isEmpty()) {
                String ext = origName.contains(".") ? origName.substring(origName.lastIndexOf('.')) : ".jpg";
                photoName = "qc_" + jobId + "_" + srcType + "_" + System.currentTimeMillis() + ext;
                String uploadPath = getServletContext().getRealPath("uploads/qc");
                File uploadDir = new File(uploadPath);
                if (!uploadDir.exists()) uploadDir.mkdirs();
                File outFile = new File(uploadDir, photoName);
                try (InputStream is = photoPart.getInputStream();
                     FileOutputStream fos = new FileOutputStream(outFile)) {
                    byte[] buf = new byte[4096]; int n;
                    while ((n = is.read(buf)) != -1) fos.write(buf, 0, n);
                }
            }
        }
    } catch (Exception photoEx) { /* photo upload optional - ignore error */ }

    // QC reference documents upload (optional - multiple files)
    StringBuilder qcDocsSb = new StringBuilder();
    try {
        String uploadPath = getServletContext().getRealPath("uploads/qc");
        File uploadDir = new File(uploadPath);
        if (!uploadDir.exists()) uploadDir.mkdirs();
        long ts = System.currentTimeMillis();
        for (Part p : request.getParts()) {
            if (!"qcDocFiles".equals(p.getName())) continue;
            if (p.getSize() <= 0) continue;
            String orig = p.getSubmittedFileName();
            if (orig == null || orig.trim().isEmpty()) continue;
            String ext = orig.contains(".") ? orig.substring(orig.lastIndexOf('.')) : "";
            String fname = "qcdoc_" + jobId + "_" + ts + "_" + Math.abs(orig.hashCode()) + ext;
            try (InputStream is = p.getInputStream();
                 FileOutputStream fos = new FileOutputStream(new File(uploadDir, fname))) {
                byte[] buf = new byte[8192]; int n;
                while ((n = is.read(buf)) > 0) fos.write(buf, 0, n);
            }
            if (qcDocsSb.length() > 0) qcDocsSb.append(",");
            qcDocsSb.append(fname).append("|").append(orig);
        }
    } catch (Exception docEx) { /* optional - ignore */ }
    String qcDocsStr = qcDocsSb.toString();

    // ── DATABASE UPDATE ──
    String successMsg = "";
    String errorMsg   = "";

    try (Connection conn = DBConnection.getConnection()) {
        conn.setAutoCommit(false);
        try {
            // 1. Update workflow stage in the source table
            String updateSql;
            if ("internal".equals(srcType)) {
                updateSql = "UPDATE internal_jobs SET workflow_stage=?, current_assignee=? WHERE id=?";
            } else if ("external".equals(srcType)) {
                updateSql = "UPDATE external_orders SET workflow_stage=?, current_assignee=? WHERE id=?";
            } else {
                updateSql = "UPDATE customer_requirements SET workflow_stage=?, current_assignee=? WHERE id=?";
            }
            PreparedStatement upd = conn.prepareStatement(updateSql);
            upd.setString(1, newStage);
            upd.setString(2, newAssignee);
            upd.setInt(3, jobId);
            upd.executeUpdate();

            // 2. Update design_submissions status
            String dsStatus = "approved".equals(action) || "qc_conditional".equals(action)
                ? "QC Approved" : "QC Rejected";
            PreparedStatement dsUpd = conn.prepareStatement(
                "UPDATE design_submissions SET design_status=? WHERE job_ref_id=? AND source_type=?");
            dsUpd.setString(1, dsStatus); dsUpd.setInt(2, jobId); dsUpd.setString(3, dsSrcType);
            dsUpd.executeUpdate();

            // 3. Insert into unified_workflow_history
            PreparedStatement hist = conn.prepareStatement(
                "INSERT INTO unified_workflow_history " +
                "(source_type, source_id, stage, action, remarks, actioned_by) " +
                "VALUES (?, ?, 'design_completed', ?, ?, ?)");
            hist.setString(1, srcType);
            hist.setInt(2, jobId);
            hist.setString(3, action);
            hist.setString(4, (notes.trim() + " | " + fullRemarksStr).substring(0, Math.min(500, (notes.trim() + " | " + fullRemarksStr).length())));
            hist.setString(5, qcUser);
            hist.executeUpdate();

            // 4. Insert QC inspection record into qc_inspections table (if exists)
            //    Build measurement summary JSON
            String measSummary = "{" +
                "\"length\":\"" + (measLength!=null?measLength:"") + "\"," +
                "\"width\":\""  + (measWidth!=null?measWidth:"")   + "\"," +
                "\"height\":\"" + (measHeight!=null?measHeight:"") + "\"," +
                "\"wheelbase\":\""+(measWheelbase!=null?measWheelbase:"") + "\"," +
                "\"weight\":\"" + (measWeight!=null?measWeight:"") + "\"," +
                "\"displacement\":\""+(measDisp!=null?measDisp:"")+ "\"" +
                "}";

            // 4a. Save QC docs to qc_drafts if any were uploaded
            if (!qcDocsStr.isEmpty()) {
                try {
                    conn.createStatement().executeUpdate(
                        "ALTER TABLE qc_drafts ADD COLUMN IF NOT EXISTS qc_doc_files TEXT");
                } catch (Exception ig) {
                    try { conn.createStatement().executeUpdate(
                        "ALTER TABLE qc_drafts ADD COLUMN qc_doc_files TEXT"); } catch (Exception ig2) {}
                }
                try {
                    PreparedStatement qdUpd = conn.prepareStatement(
                        "UPDATE qc_drafts SET qc_doc_files=? WHERE job_ref_id=? AND source_type=? AND qc_user=?");
                    qdUpd.setString(1, qcDocsStr);
                    qdUpd.setInt(2, jobId);
                    qdUpd.setString(3, srcType);
                    qdUpd.setString(4, qcUser);
                    qdUpd.executeUpdate();
                } catch (Exception qdEx) { /* optional */ }
            }

            try {
                PreparedStatement qci = conn.prepareStatement(
                    "INSERT INTO qc_inspections " +
                    "(job_ref_id, source_type, qc_user, action, severity, defect_categories, " +
                    " inspector_notes, qc_verdicts, compliance_checks, measurements, photo_path, " +
                    " full_remarks, inspected_at) " +
                    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NOW())");
                qci.setInt(1, jobId);
                qci.setString(2, srcType);
                qci.setString(3, qcUser);
                qci.setString(4, action);
                qci.setString(5, severity != null ? severity : "None");
                qci.setString(6, defects);
                qci.setString(7, notes.trim());
                qci.setString(8, verdicts != null ? verdicts : "");
                qci.setString(9, compliance != null ? compliance : "");
                qci.setString(10, measSummary);
                qci.setString(11, photoName != null ? photoName : "");
                qci.setString(12, fullRemarksStr);
                qci.executeUpdate();
            } catch (Exception qciEx) {
                // qc_inspections table may not exist yet — safe to ignore
                // The workflow_history insert above is the critical one
            }

            conn.commit();

            // Build success message
            String actionLabel = "approved".equals(action) ? "Approved — sent to Testing"
                               : "qc_conditional".equals(action) ? "Conditionally Approved — sent to Testing"
                               : "Rejected — sent back to Designer (@" + newAssignee + ")";
            successMsg = "QC Decision saved: <strong>" + actionLabel + "</strong>"
                       + (severity != null && !"None".equals(severity) ? " [Severity: " + severity + "]" : "");

        } catch (Exception txEx) {
            conn.rollback();
            errorMsg = "Database error: " + txEx.getMessage();
        }
    } catch (Exception connEx) {
        errorMsg = "Connection error: " + connEx.getMessage();
    }

    if (!errorMsg.isEmpty()) {
        String surf = "internal".equals(srcType) ? "internal" : "external";
        response.sendRedirect(request.getContextPath()+"/qc?reqId="+jobId+"&src="+srcType+"&surface="+surf+"&error="+java.net.URLEncoder.encode(errorMsg,"UTF-8"));
        return;
    }

    // Redirect back to QC module with success
    response.sendRedirect(request.getContextPath()+"/qc?success=" + java.net.URLEncoder.encode(successMsg, "UTF-8"));
%>
