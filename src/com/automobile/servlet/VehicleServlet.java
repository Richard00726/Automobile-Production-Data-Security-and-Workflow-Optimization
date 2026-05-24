package com.automobile.servlet;

import com.automobile.db.DBConnection;
import com.automobile.util.ValidationUtil;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * VehicleServlet.java (UPGRADED)
 * ================================
 * IMPROVEMENTS:
 *   ✅ Server-side validation via ValidationUtil (model name, seating, fuel capacity)
 *   ✅ XSS prevention: noHtml() check on text fields
 *   ✅ Role guard: design or admin only
 *   ✅ Supports search param forwarded to vehicle_design.jsp
 *   ✅ action=customerHistory — returns JSON list of all past orders for a customer
 */
public class VehicleServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("username") == null) {
            response.sendRedirect("index.jsp");
            return;
        }

        String action = request.getParameter("action");

        // ── customerHistory: AJAX call from admin Review modal ──
        if ("customerHistory".equals(action)) {

            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");

            String custIdParam = request.getParameter("custId");
            int custId = 0;
            try { custId = Integer.parseInt(custIdParam); } catch (Exception ex) { custId = 0; }

            StringBuilder json = new StringBuilder("[");
            boolean first = true;

            if (custId > 0) {
                String sql = "SELECT req_number, req_title, workflow_stage, submitted_at " +
                             "FROM customer_requirements " +
                             "WHERE customer_id = ? " +
                             "ORDER BY submitted_at DESC";

                try (Connection conn = DBConnection.getConnection();
                     PreparedStatement ps = conn.prepareStatement(sql)) {

                    ps.setInt(1, custId);
                    ResultSet rs = ps.executeQuery();

                    while (rs.next()) {
                        if (!first) json.append(",");
                        first = false;

                        String rn    = rs.getString("req_number");
                        String title = rs.getString("req_title");
                        String stage = rs.getString("workflow_stage");
                        java.sql.Timestamp ts = rs.getTimestamp("submitted_at");

                        if (rn    == null) rn    = "—";
                        if (title == null) title = "—";
                        if (stage == null) stage = "submitted";
                        String date = (ts != null) ? ts.toString().substring(0, 10) : "—";

                        // Escape any quotes so JSON stays valid
                        rn    = rn   .replace("\\", "\\\\").replace("\"", "\\\"");
                        title = title.replace("\\", "\\\\").replace("\"", "\\\"");
                        stage = stage.replace("\\", "\\\\").replace("\"", "\\\"");

                        json.append("{")
                            .append("\"reqNum\":\"").append(rn).append("\",")
                            .append("\"title\":\"").append(title).append("\",")
                            .append("\"stage\":\"").append(stage).append("\",")
                            .append("\"date\":\"").append(date).append("\"")
                            .append("}");
                    }

                } catch (SQLException e) {
                    // On DB error return empty array — modal shows "no history" message
                    json = new StringBuilder("[");
                    first = true;
                }
            }

            json.append("]");
            PrintWriter out = response.getWriter();
            out.write(json.toString());
            out.flush();
            return;
        }

        // ── Default: forward to vehicle design page ──
        request.getRequestDispatcher("jsp/vehicle_design.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("username") == null) {
            response.sendRedirect("index.jsp");
            return;
        }
        String role = (String) session.getAttribute("role");
        if (!"design".equals(role) && !"admin".equals(role)) {
            response.sendRedirect("dashboard.jsp");
            return;
        }

        String modelName  = request.getParameter("modelName");
        String seatingStr = request.getParameter("seatingCapacity");
        String fuelCapStr = request.getParameter("fuelCapacity");
        String fuelType   = request.getParameter("fuelType");
        String addedBy    = (String) session.getAttribute("username");

        // ── Server-side validation ──
        ValidationUtil v = new ValidationUtil();
        v.require("modelName",  modelName,  "Model name is required.")
         .minLength("modelName", modelName, 2, "Model name must be at least 2 characters.")
         .maxLength("modelName", modelName, 100, "Model name too long (max 100 chars).")
         .noHtml("modelName", modelName)
         .require("fuelType", fuelType, "Fuel type is required.")
         .require("seatingCapacity", seatingStr, "Seating capacity is required.")
         .intRange("seatingCapacity", seatingStr != null ? seatingStr : "", 1, 60, "Seating capacity must be 1–60.")
         .require("fuelCapacity", fuelCapStr, "Fuel/Battery capacity is required.")
         .doubleRange("fuelCapacity", fuelCapStr != null ? fuelCapStr : "", 1, 1000, "Fuel capacity must be 1–1000.");

        if (v.hasErrors()) {
            request.setAttribute("error", v.getSummary());
            request.getRequestDispatcher("jsp/vehicle_design.jsp").forward(request, response);
            return;
        }

        try {
            int    seating = Integer.parseInt(seatingStr.trim());
            double fuelCap = Double.parseDouble(fuelCapStr.trim());

            // Validate fuelType enum
            String ft = fuelType.trim();
            if (!ft.equals("Petrol") && !ft.equals("Diesel") && !ft.equals("Electric") && !ft.equals("Hybrid")) {
                request.setAttribute("error", "Invalid fuel type selected.");
                request.getRequestDispatcher("jsp/vehicle_design.jsp").forward(request, response);
                return;
            }

            try (Connection conn = DBConnection.getConnection()) {
                String sql = "INSERT INTO vehicle (model_name, seating_capacity, fuel_battery_capacity, fuel_type, added_by) VALUES (?, ?, ?, ?, ?)";
                PreparedStatement ps = conn.prepareStatement(sql);
                ps.setString(1, modelName.trim());
                ps.setInt   (2, seating);
                ps.setDouble(3, fuelCap);
                ps.setString(4, ft);
                ps.setString(5, addedBy);
                ps.executeUpdate();
                request.setAttribute("success", "Vehicle '" + modelName.trim() + "' added successfully!");
            }
        } catch (NumberFormatException e) {
            request.setAttribute("error", "Numeric values are required for seating and fuel capacity.");
        } catch (SQLException e) {
            request.setAttribute("error", "Database error: " + e.getMessage());
        }

        request.getRequestDispatcher("jsp/vehicle_design.jsp").forward(request, response);
    }
}
