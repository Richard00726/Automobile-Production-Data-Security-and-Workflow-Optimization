package com.automobile.servlet;

import com.automobile.db.DBConnection;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.*;
import java.sql.*;
import java.time.LocalDate;

/**
 * SubmitRequirementServlet
 *
 * Routes based on portalType:
 *   "individual"  ->  customer_requirements  (sets portal_type='individual')
 *   "bulk"        ->  external_orders        (auto-generates EXT-YYYY-NNNNN)
 */
@WebServlet("/submitRequirement")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize       = 5 * 1024 * 1024,
    maxRequestSize    = 10 * 1024 * 1024
)
public class SubmitRequirementServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        HttpSession sess = request.getSession(false);
        if (sess == null || sess.getAttribute("customerName") == null) {
            response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
            return;
        }
        String customerName = (String) sess.getAttribute("customerName");
        int    customerId   = (Integer) sess.getAttribute("customerId");

        String portalType = request.getParameter("portalType");
        if (portalType == null) portalType = "individual";

        if ("bulk".equals(portalType)) {
            handleBulkOrder(request, response, sess, customerName, customerId);
        } else {
            handleIndividualOrder(request, response, sess, customerName, customerId);
        }
    }

    // ============================================================
    // INDIVIDUAL ORDER  ->  customer_requirements
    // ============================================================
    private void handleIndividualOrder(HttpServletRequest request,
                                       HttpServletResponse response,
                                       HttpSession sess,
                                       String customerName,
                                       int customerId)
            throws ServletException, IOException {

        String moduleName    = nvl(request.getParameter("moduleName"));
        String reqTitle      = nvl(request.getParameter("reqTitle"));
        String reqDesc       = nvl(request.getParameter("reqDesc"));
        String budget        = nvl(request.getParameter("budget"));
        String fuelType      = nvl(request.getParameter("deadline"));
        String vehicleCountS = nvl(request.getParameter("vehicleCount"));
        String docType       = nvl(request.getParameter("docType"));

        if (moduleName.isEmpty()) { fwdError(request, response, "Please select a Vehicle Category!", "individual"); return; }
        if (reqTitle.isEmpty())   { fwdError(request, response, "Requirement Title is required!", "individual"); return; }
        if (reqDesc.isEmpty())    { fwdError(request, response, "Please provide a Detailed Description!", "individual"); return; }
        if (budget.isEmpty())     { fwdError(request, response, "Please select a Budget Range!", "individual"); return; }
        if (docType.isEmpty())    { fwdError(request, response, "Please select the Document Type!", "individual"); return; }

        int vehicleCount = 1;
        try { vehicleCount = Integer.parseInt(vehicleCountS); } catch (Exception ignored) {}

        String savedFileName = handleFileUpload(request, "attachment");
        if (savedFileName == null) {
            fwdError(request, response, "Company/ID Verification Document is MANDATORY!", "individual");
            return;
        }

        try (Connection conn = DBConnection.getConnection()) {

            // Auto req_number per customer
            int nextReqNumber = 1;
            PreparedStatement cntPs = conn.prepareStatement(
                "SELECT COALESCE(MAX(req_number), 0) + 1 FROM customer_requirements WHERE customer_id = ?");
            cntPs.setInt(1, customerId);
            ResultSet cntRs = cntPs.executeQuery();
            if (cntRs.next()) nextReqNumber = cntRs.getInt(1);
            cntRs.close(); cntPs.close();

            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO customer_requirements " +
                "(customer_id, req_number, client_name, module_name, req_title, req_desc, " +
                " budget, vehicle_count, deadline, doc_type, attachment, portal_type, " +
                " workflow_stage, current_assignee, status) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'individual', " +
                " 'admin_initial_review', 'admin', 'pending')",
                Statement.RETURN_GENERATED_KEYS);
            ps.setInt(1, customerId);
            ps.setInt(2, nextReqNumber);
            ps.setString(3, customerName);
            ps.setString(4, moduleName);
            ps.setString(5, reqTitle);
            ps.setString(6, reqDesc);
            ps.setString(7, budget);
            ps.setInt(8, vehicleCount);
            ps.setString(9, fuelType);
            ps.setString(10, docType);
            ps.setString(11, savedFileName);
            ps.executeUpdate();

            ResultSet keys = ps.getGeneratedKeys();
            int reqId = 0;
            if (keys.next()) reqId = keys.getInt(1);
            keys.close(); ps.close();

            try {
                PreparedStatement wh = conn.prepareStatement(
                    "INSERT INTO workflow_history (requirement_id, stage, action, remarks, actioned_by) " +
                    "VALUES (?, 'admin_initial_review', 'Requirement submitted by customer', " +
                    " 'Individual order - Awaiting Admin review', ?)");
                wh.setInt(1, reqId);
                wh.setString(2, customerName);
                wh.executeUpdate();
                wh.close();
            } catch (Exception ignored) {}

            sess.setAttribute("welcomeMsg",
                "Your Individual Requirement #" + nextReqNumber +
                " was submitted successfully! Awaiting Admin review.");
            response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp?tab=track");

        } catch (Exception e) {
            fwdError(request, response, "Submission failed: " + e.getMessage(), "individual");
        }
    }

    // ============================================================
    // BULK / CONTRACT ORDER  ->  external_orders
    // ============================================================
    private void handleBulkOrder(HttpServletRequest request,
                                 HttpServletResponse response,
                                 HttpSession sess,
                                 String customerName,
                                 int customerId)
            throws ServletException, IOException {

        String clientType    = nvl(request.getParameter("clientType"));
        String orgName       = nvl(request.getParameter("reqTitle"));
        String vehicleType   = nvl(request.getParameter("moduleName"));
        String reqDesc       = nvl(request.getParameter("reqDesc"));
        String budget        = nvl(request.getParameter("budget"));
        String fuelType      = nvl(request.getParameter("deadline"));
        String vehicleCountS = nvl(request.getParameter("vehicleCount"));
        String docType       = nvl(request.getParameter("docType"));

        if (orgName.isEmpty())     { fwdError(request, response, "Organisation name is required!", "bulk"); return; }
        if (vehicleType.isEmpty()) { fwdError(request, response, "Please select a Vehicle Type!", "bulk"); return; }
        if (reqDesc.isEmpty())     { fwdError(request, response, "Please describe your requirements!", "bulk"); return; }
        if (budget.isEmpty())      { fwdError(request, response, "Please select a Budget Range!", "bulk"); return; }
        if (docType.isEmpty())     { fwdError(request, response, "Please select the Document Type!", "bulk"); return; }

        int quantity = 100;
        try { quantity = Integer.parseInt(vehicleCountS); } catch (Exception ignored) {}
        if (quantity < 10) quantity = 10;

        String savedFileName = handleFileUpload(request, "attachment");
        if (savedFileName == null) {
            fwdError(request, response, "Official Organisation Document is MANDATORY for bulk orders!", "bulk");
            return;
        }

        // Map clientType to ENUM values
        String clientTypeEnum = "Company";
        if ("Government".equals(clientType))   clientTypeEnum = "Government";
        else if ("NGO".equals(clientType))      clientTypeEnum = "NGO";
        else if ("Individual".equals(clientType)) clientTypeEnum = "Individual";

        // Build special requirements with fuel type
        String specialReqs = reqDesc;
        if (!fuelType.isEmpty()) {
            specialReqs = "Fuel/Engine: " + fuelType + "\n\n" + reqDesc;
        }

        String orderNumber = generateOrderNumber();

        try (Connection conn = DBConnection.getConnection()) {

            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO external_orders " +
                "(order_number, client_name, client_type, company_name, vehicle_type, quantity, " +
                " budget, special_requirements, contract_file, status, workflow_stage, " +
                " current_assignee, created_by) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'admin_initial_review', 'admin', ?)",
                Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, orderNumber);
            ps.setString(2, customerName);
            ps.setString(3, clientTypeEnum);
            ps.setString(4, orgName);
            ps.setString(5, vehicleType);
            ps.setInt(6, quantity);
            ps.setString(7, budget);
            ps.setString(8, specialReqs);
            ps.setString(9, savedFileName);
            ps.setString(10, customerName);
            ps.executeUpdate();

            ResultSet keys = ps.getGeneratedKeys();
            int orderId = 0;
            if (keys.next()) orderId = keys.getInt(1);
            keys.close(); ps.close();

            // Log to unified_workflow_history
            try {
                PreparedStatement wh = conn.prepareStatement(
                    "INSERT INTO unified_workflow_history " +
                    "(source_type, source_id, stage, action, remarks, actioned_by) " +
                    "VALUES ('external', ?, 'admin_initial_review', " +
                    " 'Bulk order submitted via customer portal', ?, ?)");
                wh.setInt(1, orderId);
                wh.setString(2, "Bulk order from " + customerName + " — " + orgName);
                wh.setString(3, customerName);
                wh.executeUpdate();
                wh.close();
            } catch (Exception ignored) {}

            sess.setAttribute("welcomeMsg",
                "Your Bulk Order " + orderNumber + " was submitted! " +
                "Our Admin team will review and contact you shortly.");
            response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp?tab=track");

        } catch (Exception e) {
            fwdError(request, response, "Bulk order submission failed: " + e.getMessage(), "bulk");
        }
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private String generateOrderNumber() {
        String year = String.valueOf(LocalDate.now().getYear());
        try (Connection conn = DBConnection.getConnection()) {
            conn.prepareStatement(
                "INSERT INTO autoprod_counters (counter_key, counter_value) VALUES ('external_order_seq', 1) " +
                "ON DUPLICATE KEY UPDATE counter_value = counter_value + 1")
                .executeUpdate();
            ResultSet rs = conn.prepareStatement(
                "SELECT counter_value FROM autoprod_counters WHERE counter_key = 'external_order_seq'")
                .executeQuery();
            if (rs.next()) {
                return String.format("EXT-%s-%05d", year, rs.getInt(1));
            }
        } catch (Exception ignored) {}
        return "EXT-" + year + "-" + (System.currentTimeMillis() % 100000);
    }

    private String handleFileUpload(HttpServletRequest request, String fieldName)
            throws IOException, ServletException {
        Part filePart = request.getPart(fieldName);
        if (filePart == null || filePart.getSize() == 0) return null;

        String originalName = filePart.getSubmittedFileName();
        if (originalName == null || originalName.trim().isEmpty()) return null;

        String safeFileName = System.currentTimeMillis() + "_" +
                              originalName.replaceAll("[^a-zA-Z0-9._-]", "_");
        String uploadDir = getServletContext().getRealPath("/uploads");
        File dir = new File(uploadDir);
        if (!dir.exists()) dir.mkdirs();

        try (InputStream in  = filePart.getInputStream();
             OutputStream out = new FileOutputStream(new File(dir, safeFileName))) {
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
        }
        return safeFileName;
    }

    private void fwdError(HttpServletRequest request, HttpServletResponse response,
                          String msg, String tab)
            throws ServletException, IOException {
        request.setAttribute("error", msg);
        request.setAttribute("activeTab", tab);
        request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
    }

    private String nvl(String s) {
        return (s == null) ? "" : s.trim();
    }
}
