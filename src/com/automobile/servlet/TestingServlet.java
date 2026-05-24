package com.automobile.servlet;

import com.automobile.db.DBConnection;

import javax.servlet.ServletException;
// @WebServlet import removed — mapping handled by web.xml
import javax.servlet.http.*;
import java.io.IOException;
import java.sql.*;

/**
 * TestingServlet — UPGRADED
 * ==========================
 * Handles GET and POST for the Testing module.
 *
 * URL mapping : /testing
 *
 * NEW in this version:
 *   - Reads hidden field "testsJson" — a JSON array of test objects
 *   - Parses JSON manually (no external library needed)
 *   - Does a BATCH INSERT of multiple test rows in one POST
 *   - Each test row now also saves: test_score, test_category
 *
 * JSON format sent by testing_module.jsp:
 * [
 *   { "testType":"Road Performance Test", "category":"Performance",
 *     "status":"pass", "score":"88", "testRemarks":"All good" },
 *   { "testType":"Brake Performance Test", "category":"Safety",
 *     "status":"fail", "score":"42", "testRemarks":"Needs adjustment" }
 * ]
 *
 * UNCHANGED:
 *   - Session / role guard
 *   - Vehicle must be QC-approved (enforced in JSP dropdown)
 *   - Forward back to jsp/testing_module.jsp with success/error
 */
// @WebServlet("/testing") — REMOVED: URL mapping is already defined in web.xml
public class TestingServlet extends HttpServlet {

    // ─────────────────────────────────────────────────
    // GET  →  forward to the JSP
    // ─────────────────────────────────────────────────
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("username") == null) {
            response.sendRedirect("index.jsp");
            return;
        }
        String role = (String) session.getAttribute("role");
        if (!"testing".equals(role) && !"admin".equals(role)) {
            response.sendRedirect("dashboard.jsp");
            return;
        }
        request.getRequestDispatcher("jsp/testing_module.jsp").forward(request, response);
    }

    // ─────────────────────────────────────────────────
    // POST  →  parse JSON + batch INSERT test results
    // ─────────────────────────────────────────────────
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        // ── 1. Session guard ──
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("username") == null) {
            response.sendRedirect("index.jsp");
            return;
        }
        String role     = (String) session.getAttribute("role");
        String testedBy = (String) session.getAttribute("username");

        if (!"testing".equals(role) && !"admin".equals(role)) {
            response.sendRedirect("dashboard.jsp");
            return;
        }

        // ── 2. Read vehicle ID ──
        String vehicleIdStr = request.getParameter("vehicleId");
        if (vehicleIdStr == null || vehicleIdStr.trim().isEmpty()) {
            forwardWithError(request, response, "Invalid vehicle ID.");
            return;
        }
        int vehicleId;
        try {
            vehicleId = Integer.parseInt(vehicleIdStr.trim());
        } catch (NumberFormatException e) {
            forwardWithError(request, response, "Invalid vehicle ID format.");
            return;
        }

        // ── 3. Read testsJson ──
        String testsJson = request.getParameter("testsJson");
        if (testsJson == null || testsJson.trim().isEmpty()) {
            forwardWithError(request, response, "No test data received.");
            return;
        }

        // ── 4. Parse JSON array manually ──
        //    We avoid external dependencies by using a simple custom parser.
        TestEntry[] tests;
        try {
            tests = parseTestsJson(testsJson);
        } catch (Exception e) {
            forwardWithError(request, response, "Failed to parse test data: " + e.getMessage());
            return;
        }

        if (tests == null || tests.length == 0) {
            forwardWithError(request, response, "No test entries found in submitted data.");
            return;
        }

        // ── 5. Validate all entries before inserting any ──
        for (int i = 0; i < tests.length; i++) {
            if (tests[i].testType == null || tests[i].testType.trim().isEmpty()) {
                forwardWithError(request, response,
                    "Row " + (i + 1) + ": Test Type is required.");
                return;
            }
            if (tests[i].status == null ||
               (!tests[i].status.equals("pass") &&
                !tests[i].status.equals("fail") &&
                !tests[i].status.equals("pending"))) {
                forwardWithError(request, response,
                    "Row " + (i + 1) + ": Invalid result status.");
                return;
            }
        }

        // ── 6. Batch INSERT all test rows ──
        int insertedCount = 0;
        try (Connection conn = DBConnection.getConnection()) {

            // Verify the vehicle is QC-approved (security check)
            PreparedStatement checkVehicle = conn.prepareStatement(
                "SELECT id FROM vehicle WHERE id = ? AND status = 'approved'"
            );
            checkVehicle.setInt(1, vehicleId);
            ResultSet checkRs = checkVehicle.executeQuery();
            if (!checkRs.next()) {
                forwardWithError(request, response,
                    "Vehicle is not QC-approved. Testing cannot proceed.");
                return;
            }

            // Prepare INSERT statement
            PreparedStatement insertTest = conn.prepareStatement(
                "INSERT INTO testing_status " +
                "  (vehicle_id, test_type, test_category, status, " +
                "   test_remarks, test_score, tested_by) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)"
            );

            for (TestEntry t : tests) {
                insertTest.setInt   (1, vehicleId);
                insertTest.setString(2, t.testType.trim());
                insertTest.setString(3, t.category  != null ? t.category.trim()  : "");
                insertTest.setString(4, t.status.trim());
                insertTest.setString(5, t.testRemarks != null ? t.testRemarks.trim() : "");
                insertTest.setInt   (6, t.score);
                insertTest.setString(7, testedBy);
                insertTest.addBatch();
                insertedCount++;
            }

            insertTest.executeBatch();

            // ── 7. Update workflow stage → testing_completed ──
            try {
                PreparedStatement updateWorkflow = conn.prepareStatement(
                    "UPDATE customer_requirements " +
                    "SET workflow_stage = 'testing_completed', " +
                    "    current_assignee = 'analytics' " +
                    "WHERE vehicle_id = ? " +
                    "  AND workflow_stage = 'qc_approved'"
                );
                updateWorkflow.setInt(1, vehicleId);
                updateWorkflow.executeUpdate();
            } catch (Exception ignored) {
                // workflow update is best-effort
            }

            // ── 8. Get model name for success message ──
            String modelName = "Vehicle #" + vehicleId;
            try {
                PreparedStatement getModel = conn.prepareStatement(
                    "SELECT model_name FROM vehicle WHERE id = ?"
                );
                getModel.setInt(1, vehicleId);
                ResultSet rs = getModel.executeQuery();
                if (rs.next()) modelName = rs.getString("model_name");
            } catch (Exception ignored) {}

            String successMsg = insertedCount + " test result(s) saved for <strong>"
                              + modelName + "</strong> successfully.";
            request.setAttribute("success", successMsg);
            request.getRequestDispatcher("jsp/testing_module.jsp").forward(request, response);

        } catch (SQLException e) {
            forwardWithError(request, response, "Database error: " + e.getMessage());
        }
    }

    // ═══════════════════════════════════════════════════
    // SIMPLE JSON PARSER — no external library needed
    //
    // Parses this format:
    // [{"testType":"X","category":"Y","status":"pass","score":"85","testRemarks":"Z"}, ...]
    //
    // Strategy: split by },{  then extract each key's value with indexOf
    // ═══════════════════════════════════════════════════
    private TestEntry[] parseTestsJson(String json) {
        json = json.trim();

        // Strip outer [ ]
        if (json.startsWith("[")) json = json.substring(1);
        if (json.endsWith("]"))   json = json.substring(0, json.length() - 1);
        json = json.trim();

        if (json.isEmpty()) return new TestEntry[0];

        // Split into individual objects by },{ boundary
        // We replace },{ with a delimiter that won't appear in data
        String delimiter = "|||SPLIT|||";
        // Handle both },{  and },  {  with optional spaces
        json = json.replaceAll("\\}\\s*,\\s*\\{", delimiter);

        // Remove remaining outer braces
        String[] parts = json.split("\\|\\|\\|SPLIT\\|\\|\\|");
        TestEntry[] entries = new TestEntry[parts.length];

        for (int i = 0; i < parts.length; i++) {
            String obj = parts[i].trim();
            // Remove surrounding { }
            if (obj.startsWith("{")) obj = obj.substring(1);
            if (obj.endsWith("}"))   obj = obj.substring(0, obj.length() - 1);

            TestEntry entry  = new TestEntry();
            entry.testType   = extractJsonValue(obj, "testType");
            entry.category   = extractJsonValue(obj, "category");
            entry.status     = extractJsonValue(obj, "status");
            entry.testRemarks = extractJsonValue(obj, "testRemarks");

            String scoreStr  = extractJsonValue(obj, "score");
            try {
                entry.score  = Integer.parseInt(scoreStr.trim());
                // Clamp between 0 and 100
                if (entry.score < 0)   entry.score = 0;
                if (entry.score > 100) entry.score = 100;
            } catch (NumberFormatException e) {
                entry.score  = 0;
            }

            entries[i] = entry;
        }
        return entries;
    }

    /**
     * Extracts the string value for a given key from a JSON object fragment.
     * e.g. extractJsonValue('"testType":"Road Test","status":"pass"', "testType")
     *      returns "Road Test"
     */
    private String extractJsonValue(String jsonObj, String key) {
        String searchKey = "\"" + key + "\"";
        int keyIdx = jsonObj.indexOf(searchKey);
        if (keyIdx < 0) return "";

        int colonIdx = jsonObj.indexOf(":", keyIdx + searchKey.length());
        if (colonIdx < 0) return "";

        // Skip whitespace after colon
        int valueStart = colonIdx + 1;
        while (valueStart < jsonObj.length() &&
               (jsonObj.charAt(valueStart) == ' ' || jsonObj.charAt(valueStart) == '\t')) {
            valueStart++;
        }
        if (valueStart >= jsonObj.length()) return "";

        char firstChar = jsonObj.charAt(valueStart);

        if (firstChar == '"') {
            // String value — find closing quote, handle escaped quotes
            int valueEnd = valueStart + 1;
            while (valueEnd < jsonObj.length()) {
                char c = jsonObj.charAt(valueEnd);
                if (c == '"' && jsonObj.charAt(valueEnd - 1) != '\\') break;
                valueEnd++;
            }
            String raw = jsonObj.substring(valueStart + 1, valueEnd);
            // Unescape common JSON escapes
            return raw.replace("\\\"", "\"")
                      .replace("\\/",  "/")
                      .replace("\\n",  "\n")
                      .replace("\\r",  "")
                      .replace("\\t",  "\t")
                      .replace("\\\\", "\\");
        } else {
            // Numeric or boolean — read until , or end
            int valueEnd = valueStart;
            while (valueEnd < jsonObj.length()) {
                char c = jsonObj.charAt(valueEnd);
                if (c == ',' || c == '}' || c == ' ') break;
                valueEnd++;
            }
            return jsonObj.substring(valueStart, valueEnd).trim();
        }
    }

    // ─────────────────────────────────────────────────
    // Inner class to hold one parsed test row
    // ─────────────────────────────────────────────────
    private static class TestEntry {
        String testType    = "";
        String category    = "";
        String status      = "pending";
        String testRemarks = "";
        int    score       = 0;
    }

    // ─────────────────────────────────────────────────
    // Helper: forward with error attribute
    // ─────────────────────────────────────────────────
    private void forwardWithError(HttpServletRequest req, HttpServletResponse res, String msg)
            throws ServletException, IOException {
        req.setAttribute("error", msg);
        req.getRequestDispatcher("jsp/testing_module.jsp").forward(req, res);
    }
}
