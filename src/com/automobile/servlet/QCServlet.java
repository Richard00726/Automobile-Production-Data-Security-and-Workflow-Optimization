package com.automobile.servlet;

import com.automobile.db.DBConnection;

import javax.servlet.ServletException;
import javax.servlet.annotation.MultipartConfig;
// @WebServlet import removed — mapping handled by web.xml
import javax.servlet.http.*;
import java.io.*;
import java.sql.*;
import java.util.UUID;

/**
 * QCServlet — UPGRADED
 * =====================
 * Handles GET and POST for the QC module.
 *
 * URL mapping : /qc  (set in web.xml or via @WebServlet below)
 *
 * NEW in this version:
 *   - @MultipartConfig  → enables file upload (qcPhoto)
 *   - Reads: severity, defect_categories (checkbox array), inspector_notes
 *   - Saves uploaded photo to  webapp/uploads/qc/<uuid>.jpg
 *   - INSERTs all new fields into the approvals table
 *
 * UNCHANGED:
 *   - Session / role guard
 *   - UPDATE vehicle SET status = ?
 *   - DELETE + INSERT pattern for approvals
 *   - Forward back to jsp/qc_module.jsp with success/error attribute
 */
// @WebServlet("/qc") — REMOVED: URL mapping is already defined in web.xml
// Keeping both would cause "duplicate url-pattern" error on Tomcat startup
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,      // 1 MB — held in memory below this
    maxFileSize       = 5 * 1024 * 1024,  // 5 MB max per file
    maxRequestSize    = 10 * 1024 * 1024  // 10 MB max total request
)
public class QCServlet extends HttpServlet {

    // ── Folder inside webapp where QC photos are saved ──
    // Make sure this folder exists:  webapp/uploads/qc/
    private static final String UPLOAD_SUBDIR = "uploads/qc";

    // ─────────────────────────────────────────────────
    // GET  →  just forward to the JSP
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
        if (!"qc".equals(role) && !"admin".equals(role)) {
            response.sendRedirect("dashboard.jsp");
            return;
        }
        request.getRequestDispatcher("jsp/qc_module.jsp").forward(request, response);
    }

    // ─────────────────────────────────────────────────
    // POST  →  process QC decision + save to DB
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
        String role    = (String) session.getAttribute("role");
        String qcUser  = (String) session.getAttribute("username");

        if (!"qc".equals(role) && !"admin".equals(role)) {
            response.sendRedirect("dashboard.jsp");
            return;
        }

        // ── 2. Read basic form fields ──
        String vehicleIdStr = request.getParameter("vehicleId");
        String action       = request.getParameter("action");    // "approved" or "rejected"
        String remarks      = request.getParameter("remarks");
        String severity     = request.getParameter("severity");  // None/Minor/Major/Critical
        String inspectorNotes = request.getParameter("inspector_notes");

        // ── 3. Read defect category checkboxes (multi-value) ──
        String[] defectsArr = request.getParameterValues("defects");
        String defectCategories = "";
        if (defectsArr != null && defectsArr.length > 0) {
            defectCategories = String.join(", ", defectsArr);
        }

        // ── 4. Validate required fields ──
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

        if (action == null || (!action.equals("approved") && !action.equals("rejected"))) {
            forwardWithError(request, response, "Invalid action. Must be approved or rejected.");
            return;
        }

        // ── 5. Handle photo upload ──
        String savedPhotoName = "";
        try {
            Part photoPart = request.getPart("qcPhoto");
            if (photoPart != null && photoPart.getSize() > 0) {
                String originalName = getSubmittedFileName(photoPart);
                String ext = getFileExtension(originalName);  // e.g. ".jpg"

                // Validate file type
                if (!isAllowedImageType(ext)) {
                    forwardWithError(request, response,
                        "Invalid photo format. Only JPG, PNG, WEBP allowed.");
                    return;
                }

                // Save file with UUID name to avoid collisions
                savedPhotoName = "qc_" + UUID.randomUUID().toString() + ext;

                // Resolve real upload path on disk
                String uploadDir = getServletContext().getRealPath("") + File.separator + UPLOAD_SUBDIR;
                File uploadFolder = new File(uploadDir);
                if (!uploadFolder.exists()) {
                    uploadFolder.mkdirs();  // Create folder if missing
                }

                String filePath = uploadDir + File.separator + savedPhotoName;
                try (InputStream in    = photoPart.getInputStream();
                     FileOutputStream out = new FileOutputStream(filePath)) {
                    byte[] buffer = new byte[8192];
                    int bytesRead;
                    while ((bytesRead = in.read(buffer)) != -1) {
                        out.write(buffer, 0, bytesRead);
                    }
                }
            }
        } catch (Exception e) {
            // Photo upload failed — non-fatal, continue without photo
            // Log: e.getMessage()
            savedPhotoName = "";
        }

        // ── 6. Defaults for nullable fields ──
        if (remarks       == null) remarks        = "";
        if (severity      == null) severity        = "None";
        if (inspectorNotes== null) inspectorNotes  = "";

        // ── 7. Database operations ──
        try (Connection conn = DBConnection.getConnection()) {

            // a) UPDATE vehicle status (approved or rejected)
            PreparedStatement updateVehicle = conn.prepareStatement(
                "UPDATE vehicle SET status = ? WHERE id = ?"
            );
            updateVehicle.setString(1, action);
            updateVehicle.setInt(2, vehicleId);
            updateVehicle.executeUpdate();

            // b) Remove any previous QC record for this vehicle (re-review case)
            PreparedStatement deleteOld = conn.prepareStatement(
                "DELETE FROM approvals WHERE vehicle_id = ?"
            );
            deleteOld.setInt(1, vehicleId);
            deleteOld.executeUpdate();

            // c) INSERT new approval record with all new fields
            PreparedStatement insertApproval = conn.prepareStatement(
                "INSERT INTO approvals " +
                "  (vehicle_id, action, remarks, inspector_notes, severity, " +
                "   defect_categories, photo_path, qc_user) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            );
            insertApproval.setInt   (1, vehicleId);
            insertApproval.setString(2, action);
            insertApproval.setString(3, remarks);
            insertApproval.setString(4, inspectorNotes);
            insertApproval.setString(5, severity);
            insertApproval.setString(6, defectCategories);
            insertApproval.setString(7, savedPhotoName);
            insertApproval.setString(8, qcUser);
            insertApproval.executeUpdate();

            // d) Update workflow stage in customer_requirements
            //    approved → qc_approved    |    rejected → qc_rejected
            String newStage = "approved".equals(action) ? "qc_approved" : "qc_rejected";
            String newAssignee = "approved".equals(action) ? "testing" : "design";
            try {
                PreparedStatement updateWorkflow = conn.prepareStatement(
                    "UPDATE customer_requirements " +
                    "SET workflow_stage = ?, current_assignee = ? " +
                    "WHERE vehicle_id = ? " +
                    "  AND workflow_stage IN ('design_completed', 'qc_rejected')"
                );
                updateWorkflow.setString(1, newStage);
                updateWorkflow.setString(2, newAssignee);
                updateWorkflow.setInt   (3, vehicleId);
                updateWorkflow.executeUpdate();
            } catch (Exception ignored) {
                // workflow table may not link by vehicle_id in all setups
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

            String successMsg = "<strong>" + modelName + "</strong> has been "
                              + action + " successfully."
                              + (!"None".equals(severity) ? " [Severity: " + severity + "]" : "");

            request.setAttribute("success", successMsg);
            request.getRequestDispatcher("jsp/qc_module.jsp").forward(request, response);

        } catch (SQLException e) {
            forwardWithError(request, response, "Database error: " + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────
    // Helper: forward back to QC page with error message
    // ─────────────────────────────────────────────────
    private void forwardWithError(HttpServletRequest req, HttpServletResponse res, String msg)
            throws ServletException, IOException {
        req.setAttribute("error", msg);
        req.getRequestDispatcher("jsp/qc_module.jsp").forward(req, res);
    }

    // ─────────────────────────────────────────────────
    // Helper: extract filename from Part header
    // ─────────────────────────────────────────────────
    private String getSubmittedFileName(Part part) {
        String contentDisposition = part.getHeader("content-disposition");
        if (contentDisposition == null) return "file";
        for (String token : contentDisposition.split(";")) {
            token = token.trim();
            if (token.startsWith("filename")) {
                String name = token.substring(token.indexOf('=') + 1).trim()
                                   .replace("\"", "");
                // Handle Windows paths
                int lastSlash = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
                return lastSlash >= 0 ? name.substring(lastSlash + 1) : name;
            }
        }
        return "file";
    }

    // ─────────────────────────────────────────────────
    // Helper: get lowercase file extension e.g. ".jpg"
    // ─────────────────────────────────────────────────
    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) return ".jpg";
        return filename.substring(filename.lastIndexOf('.')).toLowerCase();
    }

    // ─────────────────────────────────────────────────
    // Helper: only allow safe image types
    // ─────────────────────────────────────────────────
    private boolean isAllowedImageType(String ext) {
        return ".jpg".equals(ext) || ".jpeg".equals(ext)
            || ".png".equals(ext) || ".webp".equals(ext);
    }
}