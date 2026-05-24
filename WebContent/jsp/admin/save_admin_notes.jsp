<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");

    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null
            || !"admin".equals(sess.getAttribute("role"))) {
        out.print("{\"error\":\"Unauthorized\"}");
        return;
    }

    request.setCharacterEncoding("UTF-8");
    String reqIdStr   = request.getParameter("requirementId");
    String adminNotes = request.getParameter("adminNotes");
    String actionType = request.getParameter("actionType");
    String designType = request.getParameter("designType");
    String brandName  = request.getParameter("brandName");
    String techDesc   = request.getParameter("techDescription");
    String orderSource= request.getParameter("orderSource"); // "cr"=customer_requirements, "ext"=external_orders

    if (reqIdStr == null || reqIdStr.trim().isEmpty()) {
        out.print("{\"error\":\"Missing requirement ID\"}");
        return;
    }

    int requirementId;
    try {
        requirementId = Integer.parseInt(reqIdStr.trim());
    } catch (NumberFormatException e) {
        out.print("{\"error\":\"Invalid requirement ID\"}");
        return;
    }

    if (adminNotes == null) adminNotes = "";
    if (actionType == null) actionType = "approve";
    if (designType == null || (!designType.equals("internal") && !designType.equals("external")))
        designType = "external";
    if (brandName == null) brandName = "";
    if (techDesc  == null) techDesc  = "";
    boolean isExtTable = "ext".equals(orderSource); // true → update external_orders table

    try (Connection conn = DBConnection.getConnection()) {

        if ("approve".equals(actionType)) {

            // ── Determine vehicle type ──
            String vtOverride  = request.getParameter("vehicleTypeOverride");
            String vehicleType = null;

            if (vtOverride != null && !vtOverride.trim().isEmpty()) {
                vehicleType = vtOverride.trim();
                // Save override back to the correct table
                try {
                    String vtUpdSql = isExtTable
                        ? "UPDATE external_orders SET vehicle_type=? WHERE id=?"
                        : "UPDATE customer_requirements SET vehicle_type=? WHERE id=?";
                    PreparedStatement vtUpd = conn.prepareStatement(vtUpdSql);
                    vtUpd.setString(1, vehicleType);
                    vtUpd.setInt   (2, requirementId);
                    vtUpd.executeUpdate();
                } catch (Exception ig) {}
            } else {
                try {
                    String vtSelSql = isExtTable
                        ? "SELECT vehicle_type FROM external_orders WHERE id=?"
                        : "SELECT vehicle_type FROM customer_requirements WHERE id=?";
                    PreparedStatement vtq = conn.prepareStatement(vtSelSql);
                    vtq.setInt(1, requirementId);
                    ResultSet vtr = vtq.executeQuery();
                    if (vtr.next()) vehicleType = vtr.getString("vehicle_type");
                } catch (Exception ig) {}
            }

            // ── Round-Robin Designer Assignment (External stream) ──
            String assignedUsername = "design";   // fallback
            String assignedName     = "Design Team";
            int    assignedSlot     = 0;
            int    totalInPool      = 0;
            boolean poolEmpty       = false;

            if (vehicleType != null && !vehicleType.trim().isEmpty()) {
                try {
                    // Count active designers for this vehicle type
                    PreparedStatement cntQ = conn.prepareStatement(
                        "SELECT COUNT(*) FROM vehicle_designers WHERE vehicle_type=? AND is_active=1");
                    cntQ.setString(1, vehicleType);
                    ResultSet cntRs = cntQ.executeQuery();
                    if (cntRs.next()) totalInPool = cntRs.getInt(1);

                    if (totalInPool > 0) {
                        // Get current last_slot_used — EXTERNAL stream counter
                        PreparedStatement rrQ = conn.prepareStatement(
                            "SELECT last_slot_used FROM designer_round_robin WHERE vehicle_type=? AND stream='external'");
                        rrQ.setString(1, vehicleType);
                        ResultSet rrRs = rrQ.executeQuery();
                        int lastSlot = 0;
                        if (rrRs.next()) lastSlot = rrRs.getInt("last_slot_used");

                        // Calculate next slot (round-robin wraps at totalInPool)
                        int nextSlot = (lastSlot % totalInPool) + 1;

                        // Get the designer at that slot
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

                        // Update EXTERNAL stream counter
                        PreparedStatement rrUpd = conn.prepareStatement(
                            "INSERT INTO designer_round_robin (vehicle_type, stream, last_slot_used, total_assigned) " +
                            "VALUES (?, 'external', ?, 1) " +
                            "ON DUPLICATE KEY UPDATE last_slot_used=VALUES(last_slot_used), total_assigned=total_assigned+1");
                        rrUpd.setString(1, vehicleType);
                        rrUpd.setInt   (2, nextSlot);
                        rrUpd.executeUpdate();

                    } else {
                        poolEmpty = true;
                    }
                } catch (Exception ig) {}
            }

            // ── Build final notes ──
            String finalNotes = adminNotes.trim();
            if ("external".equals(designType) && !techDesc.trim().isEmpty()) {
                finalNotes = "TECHNICAL SPECS:\n" + techDesc.trim()
                    + (adminNotes.trim().isEmpty() ? "" : "\n\nADMIN NOTES:\n" + adminNotes.trim());
            }
            String slotLabel = (assignedSlot > 0) ? " (Slot " + assignedSlot + ")" : "";
            if (vehicleType != null && !vehicleType.isEmpty()) {
                String vtLabel = vehicleType.replace("_"," ").toUpperCase();
                String poolNote = poolEmpty ? "\nWARNING: No active designers in pool — assigned to fallback." : "";
                finalNotes = "VEHICLE TYPE: " + vtLabel
                    + "\nROUTED TO: " + assignedName + slotLabel
                    + " [" + vehicleType + " / external stream]"
                    + poolNote
                    + (finalNotes.isEmpty() ? "" : "\n\n" + finalNotes);
            }

            // ── Update correct table ──
            String approveSql = isExtTable
                ? "UPDATE external_orders " +
                  "SET admin_notes=?, workflow_stage='admin_initial_approved', " +
                  "    current_assignee=?, status='in_review' " +
                  "WHERE id=?"
                : "UPDATE customer_requirements " +
                  "SET admin_notes=?, design_type=?, brand_name=?, " +
                  "    workflow_stage='admin_initial_approved', " +
                  "    current_assignee=?, status='in_review' " +
                  "WHERE id=?";

            PreparedStatement ps = conn.prepareStatement(approveSql);
            if (isExtTable) {
                ps.setString(1, finalNotes);
                ps.setString(2, assignedUsername);
                ps.setInt   (3, requirementId);
            } else {
                ps.setString(1, finalNotes);
                ps.setString(2, designType);
                ps.setString(3, brandName.trim());
                ps.setString(4, assignedUsername);
                ps.setInt   (5, requirementId);
            }
            int rows = ps.executeUpdate();

            if (rows == 0) {
                out.print("{\"error\":\"Requirement not found or already processed\"}");
                return;
            }

            // ── FIX: Mirror approved external_orders into customer_requirements ──
            // vehicle_design.jsp only reads customer_requirements + internal_jobs.
            // Disable FK checks so customer_id=0 is accepted without FK violation.
            if (isExtTable) {
                try {
                    conn.createStatement().execute("SET foreign_key_checks = 0");

                    PreparedStatement extQ = conn.prepareStatement(
                        "SELECT * FROM external_orders WHERE id=?");
                    extQ.setInt(1, requirementId);
                    ResultSet extRs = extQ.executeQuery();
                    if (extRs.next()) {
                        String extOrderNum    = extRs.getString("order_number")         != null ? extRs.getString("order_number")         : "EXT-" + requirementId;
                        String extClientName  = extRs.getString("client_name")          != null ? extRs.getString("client_name")          : "Bulk Client";
                        String extVehicleType = extRs.getString("vehicle_type")         != null ? extRs.getString("vehicle_type")         : "car";
                        String extBudget      = extRs.getString("budget")               != null && !extRs.getString("budget").isEmpty()
                                                ? extRs.getString("budget") : "N/A";
                        String extDeadline    = extRs.getString("deadline")             != null ? extRs.getString("deadline")             : "";
                        String extSpecReqs    = extRs.getString("special_requirements") != null ? extRs.getString("special_requirements") : "";
                        String extCompany     = extRs.getString("company_name")         != null ? extRs.getString("company_name")         : "";
                        int    extQtyInt      = extRs.getInt("quantity");
                        if (extQtyInt < 1) extQtyInt = 1;

                        String orgName    = extCompany.isEmpty() ? extClientName : extCompany;
                        String moduleStr  = extVehicleType.replace("_"," ");
                        String titleStr   = "Bulk Order: " + extOrderNum + " — " + orgName;
                        String mirrorDesc = "BULK ORDER: " + extOrderNum
                            + "\nOrganisation: " + orgName
                            + "\nVehicle Type: " + extVehicleType.replace("_"," ").toUpperCase()
                            + "\nQuantity: "     + extQtyInt + " units"
                            + (extDeadline.isEmpty() ? "" : "\nDeadline: " + extDeadline)
                            + (extSpecReqs.isEmpty() ? "" : "\n\nSpecial Requirements:\n" + extSpecReqs);

                        // Check for existing mirror row using req_number=external_orders.id
                        PreparedStatement chkQ = conn.prepareStatement(
                            "SELECT id FROM customer_requirements WHERE portal_type='bulk' AND req_number=?");
                        chkQ.setInt(1, requirementId);
                        ResultSet chkRs = chkQ.executeQuery();

                        if (!chkRs.next()) {
                            // INSERT — customer_id=0 safe because FK checks are OFF
                            PreparedStatement mirQ = conn.prepareStatement(
                                "INSERT INTO customer_requirements " +
                                "(client_name, customer_id, req_number, module_name, " +
                                " req_title, req_desc, vehicle_type, admin_notes, " +
                                " design_type, budget, vehicle_count, deadline, " +
                                " portal_type, status, workflow_stage, current_assignee) " +
                                "VALUES (?, 0, ?, ?, ?, ?, ?, ?, 'external', ?, ?, ?, ?, 'bulk', " +
                                "        'in_review', 'admin_initial_approved', ?)");
                            mirQ.setString(1,  extClientName);
                            mirQ.setInt   (2,  requirementId);
                            mirQ.setString(3,  moduleStr);
                            mirQ.setString(4,  titleStr);
                            mirQ.setString(5,  mirrorDesc);
                            mirQ.setString(6,  extVehicleType);
                            mirQ.setString(7,  finalNotes);
                            mirQ.setString(8,  extBudget);
                            mirQ.setInt   (9,  extQtyInt);
                            mirQ.setString(10, extDeadline);
                            mirQ.setString(11, assignedUsername);
                            mirQ.executeUpdate();
                        } else {
                            // UPDATE existing mirror row on re-approval
                            PreparedStatement mirUpd = conn.prepareStatement(
                                "UPDATE customer_requirements " +
                                "SET admin_notes=?, workflow_stage='admin_initial_approved', " +
                                "    current_assignee=?, status='in_review' " +
                                "WHERE id=?");
                            mirUpd.setString(1, finalNotes);
                            mirUpd.setString(2, assignedUsername);
                            mirUpd.setInt   (3, chkRs.getInt("id"));
                            mirUpd.executeUpdate();
                        }
                    }
                    conn.createStatement().execute("SET foreign_key_checks = 1");

                } catch (Exception mirEx) {
                    try { conn.createStatement().execute("SET foreign_key_checks = 1"); } catch (Exception ig2) {}
                    String errMsg = mirEx.getMessage() != null
                        ? mirEx.getMessage().replace("\"","'").replace("\n"," ").replace("\r","")
                        : "unknown error";
                    out.print("{\"success\":true,"
                        + "\"message\":\"Approved but mirror failed: " + errMsg + "\","
                        + "\"designer\":\"" + assignedName.replace("\"","'") + "\","
                        + "\"slot\":"        + assignedSlot + ","
                        + "\"totalInPool\":" + totalInPool  + ","
                        + "\"vehicleType\":\"" + (vehicleType != null ? vehicleType : "") + "\","
                        + "\"mirrorError\":true}");
                    return;
                }
            }

            // ── Workflow history ──
            try {
                PreparedStatement hist = conn.prepareStatement(
                    "INSERT INTO workflow_history " +
                    "(requirement_id, stage, action, remarks, actioned_by) " +
                    "VALUES (?, 'admin_initial_approved', 'Admin Approval', ?, ?)");
                hist.setInt   (1, requirementId);
                hist.setString(2, "Approved and routed to " + assignedName + slotLabel
                    + (vehicleType != null ? " [" + vehicleType + "]" : ""));
                hist.setString(3, (String) sess.getAttribute("username"));
                hist.executeUpdate();
            } catch (Exception ig) {}

            String safeName = assignedName.replace("\"", "'");
            String safeVt   = vehicleType != null ? vehicleType : "";
            String poolWarn = poolEmpty ? ",\"poolEmpty\":true,\"warning\":\"No active designers found for this vehicle type. Assigned to fallback user.\"" : "";
            out.print("{\"success\":true,"
                + "\"message\":\"Approved and routed to " + safeName + slotLabel + "\","
                + "\"designer\":\"" + safeName + "\","
                + "\"slot\":" + assignedSlot + ","
                + "\"totalInPool\":" + totalInPool + ","
                + "\"vehicleType\":\"" + safeVt + "\""
                + poolWarn + "}");

        } else if ("reject".equals(actionType)) {

            String rejectSql = isExtTable
                ? "UPDATE external_orders " +
                  "SET admin_notes=?, workflow_stage='admin_initial_rejected', " +
                  "    current_assignee='admin', status='rejected' " +
                  "WHERE id=?"
                : "UPDATE customer_requirements " +
                  "SET admin_notes=?, workflow_stage='admin_initial_rejected', " +
                  "    current_assignee='customer', status='rejected' " +
                  "WHERE id=?";

            PreparedStatement ps = conn.prepareStatement(rejectSql);
            ps.setString(1, adminNotes.trim());
            ps.setInt   (2, requirementId);
            ps.executeUpdate();

            try {
                PreparedStatement hist = conn.prepareStatement(
                    "INSERT INTO workflow_history " +
                    "(requirement_id, stage, action, remarks, actioned_by) " +
                    "VALUES (?, 'admin_initial_rejected', 'Admin Rejected', ?, ?)");
                hist.setInt   (1, requirementId);
                hist.setString(2, adminNotes.isEmpty() ? "Rejected by admin" : adminNotes);
                hist.setString(3, (String) sess.getAttribute("username"));
                hist.executeUpdate();
            } catch (Exception ig) {}

            out.print("{\"success\":true,\"message\":\"Requirement rejected\"}");

        } else {
            PreparedStatement ps = conn.prepareStatement(
                "UPDATE customer_requirements SET admin_notes=? WHERE id=?");
            ps.setString(1, adminNotes.trim());
            ps.setInt   (2, requirementId);
            ps.executeUpdate();
            out.print("{\"success\":true,\"message\":\"Notes saved\"}");
        }

    } catch (SQLException e) {
        out.print("{\"error\":\"DB error: " + e.getMessage().replace("\"","'") + "\"}");
    }
%>
