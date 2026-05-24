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
 * SubmitBulkOrderServlet
 * Handles BULK / CONTRACT orders from the customer portal.
 * Inserts into external_orders table with EXT-YYYY-NNNNN numbering.
 */
@WebServlet("/submitBulkOrder")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize       = 5 * 1024 * 1024,
    maxRequestSize    = 10 * 1024 * 1024
)
public class SubmitBulkOrderServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        // ── Session check ──
        HttpSession sess = request.getSession(false);
        if (sess == null || sess.getAttribute("customerName") == null) {
            response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
            return;
        }
        String customerName = (String) sess.getAttribute("customerName");

        // ── Read form fields ──
        String clientType    = nvl(request.getParameter("clientType"));
        String orgName       = nvl(request.getParameter("companyName"));    // organisation name
        String contactPerson = nvl(request.getParameter("contactPerson"));  // contact person
        String orderTitle    = nvl(request.getParameter("orderTitle"));     // order title
        String vehicleType   = nvl(request.getParameter("vehicleType"));    // vehicle_type hidden field (e.g. bus, car)
        String reqDesc       = nvl(request.getParameter("reqDesc"));        // special requirements
        String budget        = nvl(request.getParameter("budget"));
        String fuelType      = nvl(request.getParameter("deadline"));       // fuel field reused
        String vehicleCountS = nvl(request.getParameter("vehicleCount"));
        String docType       = nvl(request.getParameter("docType"));
        String deliveryTL    = nvl(request.getParameter("deliveryTimeline"));

        // ── Validation ──
        if (orgName.isEmpty()) {
            request.setAttribute("error", "Company / Organisation name is required!");
            request.setAttribute("activeTab", "bulk");
            request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
            return;
        }
        if (vehicleType.isEmpty()) {
            // fallback: try moduleName (displayed value)
            vehicleType = nvl(request.getParameter("moduleName"));
        }
        if (vehicleType.isEmpty()) {
            request.setAttribute("error", "Please select a Vehicle Type!");
            request.setAttribute("activeTab", "bulk");
            request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
            return;
        }
        if (reqDesc.isEmpty()) {
            request.setAttribute("error", "Please describe your requirements!");
            request.setAttribute("activeTab", "bulk");
            request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
            return;
        }
        if (budget.isEmpty()) {
            request.setAttribute("error", "Please select a Budget Range!");
            request.setAttribute("activeTab", "bulk");
            request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
            return;
        }

        int quantity = 100;
        try { quantity = Integer.parseInt(vehicleCountS); } catch (Exception ignored) {}
        if (quantity < 10) quantity = 10;

        // ── File upload ──
        String savedFileName = null;
        try {
            Part filePart = request.getPart("attachment");
            if (filePart != null && filePart.getSize() > 0) {
                String originalName = filePart.getSubmittedFileName();
                if (originalName != null && !originalName.trim().isEmpty()) {
                    String safeFileName = System.currentTimeMillis() + "_" +
                                          originalName.replaceAll("[^a-zA-Z0-9._-]", "_");
                    String uploadDir = getServletContext().getRealPath("/uploads");
                    File dir = new File(uploadDir);
                    if (!dir.exists()) dir.mkdirs();
                    try (InputStream in = filePart.getInputStream();
                         OutputStream out = new FileOutputStream(new File(dir, safeFileName))) {
                        byte[] buf = new byte[8192];
                        int n;
                        while ((n = in.read(buf)) != -1) out.write(buf, 0, n);
                    }
                    savedFileName = safeFileName;
                }
            }
        } catch (Exception ignored) {}

        // ── Map client type to ENUM ──
        String clientTypeEnum = "Company";
        if ("Government".equals(clientType))    clientTypeEnum = "Government";
        else if ("NGO".equals(clientType))       clientTypeEnum = "NGO";
        else if ("Individual".equals(clientType)) clientTypeEnum = "Individual";

        // ── Build special requirements (includes fuel type) ──
        String specialReqs = reqDesc;
        if (!fuelType.isEmpty()) {
            specialReqs = "Fuel/Engine: " + fuelType + "\n\n" + reqDesc;
        }

        // ── Generate EXT-YYYY-NNNNN order number ──
        String year = String.valueOf(LocalDate.now().getYear());
        String orderNumber = "EXT-" + year + "-" + (System.currentTimeMillis() % 100000);
        try (Connection ctr = DBConnection.getConnection()) {
            ctr.prepareStatement(
                "INSERT INTO autoprod_counters (counter_key, counter_value) VALUES ('external_order_seq', 1) " +
                "ON DUPLICATE KEY UPDATE counter_value = counter_value + 1").executeUpdate();
            ResultSet rs = ctr.prepareStatement(
                "SELECT counter_value FROM autoprod_counters WHERE counter_key = 'external_order_seq'")
                .executeQuery();
            if (rs.next()) {
                orderNumber = String.format("EXT-%s-%05d", year, rs.getInt(1));
            }
        } catch (Exception ignored) {}

        // ── Insert into external_orders ──
        try (Connection conn = DBConnection.getConnection()) {

            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO external_orders " +
                "(order_number, client_name, client_type, company_name, vehicle_type, quantity, " +
                " budget, special_requirements, contract_file, status, workflow_stage, " +
                " current_assignee, created_by) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'admin_initial_review', 'admin', ?)",
                Statement.RETURN_GENERATED_KEYS);
            ps.setString(1, orderNumber);
            ps.setString(2, contactPerson.isEmpty() ? customerName : contactPerson);
            ps.setString(3, clientTypeEnum);
            ps.setString(4, orgName);
            ps.setString(5, vehicleType);
            ps.setInt(6, quantity);
            ps.setString(7, budget);
            ps.setString(8, specialReqs);
            ps.setString(9, savedFileName != null ? savedFileName : "");
            ps.setString(10, customerName);
            ps.executeUpdate();

            ResultSet keys = ps.getGeneratedKeys();
            int orderId = 0;
            if (keys.next()) orderId = keys.getInt(1);
            keys.close(); ps.close();

            // Log to unified_workflow_history if available
            try {
                PreparedStatement wh = conn.prepareStatement(
                    "INSERT INTO unified_workflow_history " +
                    "(source_type, source_id, stage, action, remarks, actioned_by) " +
                    "VALUES ('external', ?, 'admin_initial_review', " +
                    " 'Bulk order submitted via customer portal', ?, ?)");
                wh.setInt(1, orderId);
                wh.setString(2, "Bulk order: " + orgName + " — " + quantity + " x " + vehicleType);
                wh.setString(3, customerName);
                wh.executeUpdate();
                wh.close();
            } catch (Exception ignored) {}

            sess.setAttribute("welcomeMsg",
                "Bulk Order " + orderNumber + " submitted successfully! " +
                "Our Admin team will review and contact you shortly.");
            response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp?tab=track");

        } catch (Exception e) {
            request.setAttribute("error", "Bulk order submission failed: " + e.getMessage());
            request.setAttribute("activeTab", "bulk");
            request.getRequestDispatcher("/customer_requirements.jsp").forward(request, response);
        }
    }

    private String nvl(String s) {
        return (s == null) ? "" : s.trim();
    }
}
