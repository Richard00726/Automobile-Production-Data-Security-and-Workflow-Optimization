package com.automobile.servlet;

import com.automobile.db.DBConnection;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;

@WebServlet("/workflow")
public class WorkflowServlet extends HttpServlet {

    // ── CONFIG — Update these ──
    private static final String GMAIL_USER     = "infantrichart06@gmail.com";
    private static final String GMAIL_PASSWORD = "otosixhhlqdxcmph";
    private static final String COMPANY_NAME   = "AutoProd Manufacturing Systems";
    private static final String PORTAL_URL     = "http://localhost:8080/AutomobileApp_Upgraded/customer_requirements.jsp";

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession sess = request.getSession(false);
        if (sess == null || sess.getAttribute("username") == null) {
            response.sendRedirect(request.getContextPath() + "/index.jsp");
            return;
        }

        String role     = (String) sess.getAttribute("role");
        String fullName = (String) sess.getAttribute("fullName");
        if (fullName == null) fullName = (String) sess.getAttribute("username");

        String action   = request.getParameter("action");
        String reqIdStr = request.getParameter("requirementId");
        String remarks  = request.getParameter("remarks");
        if (remarks == null) remarks = "";
        if (action == null || reqIdStr == null) {
            response.sendRedirect(request.getContextPath() + "/workflow_dashboard.jsp");
            return;
        }

        int requirementId;
        try { requirementId = Integer.parseInt(reqIdStr); }
        catch (Exception e) {
            response.sendRedirect(request.getContextPath() + "/workflow_dashboard.jsp");
            return;
        }

        String  newStage       = "";
        String  newAssignee    = "";
        String  histAction     = "";
        String  newStatus      = "in_review";
        boolean notifyCustomer = false;
        String  emailType      = ""; // type of email to send

        // ════════════════════════════════════════════════
        // ADMIN ACTIONS
        // ════════════════════════════════════════════════
        if ("admin".equals(role)) {

            if ("admin_initial_approve".equals(action)) {
                newStage       = "admin_initial_approved";
                newAssignee    = "design";
                newStatus      = "in_review";
                histAction     = "✅ Admin Initial Approval — Forwarded to Design Team";
                notifyCustomer = true;
                emailType      = "INITIAL_APPROVED";

            } else if ("admin_initial_reject".equals(action)) {
                newStage       = "admin_initial_rejected";
                newAssignee    = "customer";
                newStatus      = "rejected";
                histAction     = "❌ Admin Rejected — " + remarks;
                notifyCustomer = true;
                emailType      = "INITIAL_REJECTED";

            } else if ("admin_final_approve".equals(action)) {
                newStage       = "completed";
                newAssignee    = "customer";
                newStatus      = "completed";
                histAction     = "🎉 Final Admin Approval — Requirement COMPLETED!";
                notifyCustomer = true;
                emailType      = "FINAL_COMPLETED";

            } else if ("admin_final_reject".equals(action)) {
                newStage       = "rejected";
                newAssignee    = "customer";
                newStatus      = "rejected";
                histAction     = "❌ Final Admin Rejection — " + remarks;
                notifyCustomer = true;
                emailType      = "FINAL_REJECTED";
            }
        }

        // ════════════════════════════════════════════════
        // DESIGN TEAM
        // ════════════════════════════════════════════════
        if ("design".equals(role) || "admin".equals(role)) {
            if ("design_complete".equals(action)) {
                newStage    = "design_completed";
                newAssignee = "qc";
                histAction  = "🎨 Design Completed — Forwarded to QC Team";
            }
        }

        // ════════════════════════════════════════════════
        // QC TEAM
        // ════════════════════════════════════════════════
        if ("qc".equals(role) || "admin".equals(role)) {
            if ("qc_approve".equals(action)) {
                newStage    = "qc_approved";
                newAssignee = "testing";
                histAction  = "✅ QC Approved — Forwarded to Testing Team";
            } else if ("qc_reject".equals(action)) {
                newStage    = "qc_rejected";
                newAssignee = "design";
                newStatus   = "in_review";
                histAction  = "❌ QC Rejected — Sent back to Design Team";
            }
        }

        // ════════════════════════════════════════════════
        // TESTING TEAM
        // ════════════════════════════════════════════════
        if ("testing".equals(role) || "admin".equals(role)) {
            if ("testing_complete".equals(action)) {
                newStage    = "testing_completed";
                newAssignee = "analytics";
                histAction  = "🔬 Testing Completed — Forwarded to Analytics Team";
            }
        }

        // ════════════════════════════════════════════════
        // ANALYTICS TEAM
        // ════════════════════════════════════════════════
        if ("analytics".equals(role) || "admin".equals(role)) {
            if ("analytics_complete".equals(action)) {
                newStage    = "analytics_completed";
                newAssignee = "admin";
                histAction  = "📊 Analytics Completed — Forwarded to Admin for Final Approval";
            }
        }

        // ── Save to DB and send email ──
        if (!newStage.isEmpty()) {
            try (Connection conn = DBConnection.getConnection()) {

                // Update requirement
                PreparedStatement ps = conn.prepareStatement(
                    "UPDATE customer_requirements " +
                    "SET workflow_stage=?, current_assignee=?, status=? WHERE id=?");
                ps.setString(1, newStage);
                ps.setString(2, newAssignee);
                ps.setString(3, newStatus);
                ps.setInt   (4, requirementId);
                ps.executeUpdate();

                // Log history
                PreparedStatement log = conn.prepareStatement(
                    "INSERT INTO workflow_history " +
                    "(requirement_id, stage, action, remarks, actioned_by) " +
                    "VALUES (?, ?, ?, ?, ?)");
                log.setInt   (1, requirementId);
                log.setString(2, newStage);
                log.setString(3, histAction);
                log.setString(4, remarks);
                log.setString(5, fullName);
                log.executeUpdate();

                // ── Send email notification to customer ──
                if (notifyCustomer && !emailType.isEmpty()) {
                    try {
                        PreparedStatement getInfo = conn.prepareStatement(
                            "SELECT c.email, c.full_name, cr.req_title, " +
                            "cr.module_name, cr.budget, cr.deadline, cr.submitted_at " +
                            "FROM customer_requirements cr " +
                            "JOIN customers c ON cr.customer_id = c.id " +
                            "WHERE cr.id = ?");
                        getInfo.setInt(1, requirementId);
                        ResultSet rs = getInfo.executeQuery();
                        if (rs.next()) {
                            sendEmail(
                                rs.getString("email"),
                                rs.getString("full_name"),
                                rs.getString("req_title"),
                                rs.getString("module_name"),
                                rs.getString("budget"),
                                rs.getString("deadline"),
                                rs.getTimestamp("submitted_at"),
                                emailType,
                                remarks,
                                requirementId
                            );
                        }
                    } catch (Exception emailEx) {
                        System.err.println("❌ Email failed: " + emailEx.getMessage());
                    }
                }

            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        response.sendRedirect(request.getContextPath() + "/workflow_dashboard.jsp");
    }

    // ════════════════════════════════════════════════
    // SEND EMAIL — Different templates per event
    // ════════════════════════════════════════════════
    private void sendEmail(String toEmail, String name, String reqTitle,
                           String category, String budget, String fuelType,
                           Timestamp submittedAt, String emailType,
                           String remarks, int reqId) throws Exception {

        Properties props = new Properties();
        props.put("mail.smtp.host",            "smtp.gmail.com");
        props.put("mail.smtp.port",            "587");
        props.put("mail.smtp.auth",            "true");
        props.put("mail.smtp.starttls.enable", "true");

        Session mailSession = Session.getInstance(props, new Authenticator() {
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(GMAIL_USER, GMAIL_PASSWORD);
            }
        });

        String subject = "";
        String body    = "";
        String today   = LocalDateTime.now().format(
                         DateTimeFormatter.ofPattern("dd MMM yyyy, hh:mm a"));
        String subDate = submittedAt != null
                       ? submittedAt.toString().substring(0, 10) : "N/A";

        // ── Shared details block ──
        String detailsBlock =
            "<table style='width:100%;border-collapse:collapse;margin:16px 0;'>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;border-radius:6px 0 0 0;font-size:.8rem;color:#6b7c93;font-weight:700;width:40%;'>Requirement ID</td>" +
            "<td style='padding:8px 12px;background:#f0f7ff;font-size:.85rem;font-weight:700;color:#0a6ebd;'>#" + reqId + "</td></tr>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;font-size:.8rem;color:#6b7c93;font-weight:700;'>Title</td>" +
            "<td style='padding:8px 12px;font-size:.85rem;color:#0d1b2a;'>" + reqTitle + "</td></tr>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;font-size:.8rem;color:#6b7c93;font-weight:700;'>Vehicle Category</td>" +
            "<td style='padding:8px 12px;font-size:.85rem;color:#0d1b2a;'>" + category + "</td></tr>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;font-size:.8rem;color:#6b7c93;font-weight:700;'>Fuel Type</td>" +
            "<td style='padding:8px 12px;font-size:.85rem;color:#0d1b2a;'>" + fuelType + "</td></tr>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;font-size:.8rem;color:#6b7c93;font-weight:700;'>Budget</td>" +
            "<td style='padding:8px 12px;font-size:.85rem;color:#0d1b2a;'>" + budget + "</td></tr>" +
            "<tr><td style='padding:8px 12px;background:#f8f9fa;border-radius:0 0 0 6px;font-size:.8rem;color:#6b7c93;font-weight:700;'>Submitted On</td>" +
            "<td style='padding:8px 12px;font-size:.85rem;color:#0d1b2a;'>" + subDate + "</td></tr>" +
            "</table>";

        // ── Shared header ──
        String header =
            "<div style='font-family:Arial,sans-serif;max-width:560px;margin:0 auto;'>" +
            "<div style='background:linear-gradient(135deg,#0a6ebd,#00b4a6);padding:32px;text-align:center;border-radius:14px 14px 0 0;'>" +
            "<h1 style='color:#fff;font-size:1.6rem;margin:0 0 4px;'>🚗 AutoProd</h1>" +
            "<p style='color:rgba(255,255,255,.8);margin:0;font-size:.875rem;'>Manufacturing Systems</p>" +
            "</div>" +
            "<div style='background:#fff;padding:32px;border:1px solid #e0e0e0;border-top:none;border-radius:0 0 14px 14px;'>";

        // ── Shared footer ──
        String footer =
            "<hr style='border:none;border-top:1px solid #eee;margin:24px 0 16px;'>" +
            "<p style='color:#aaa;font-size:.75rem;text-align:center;margin:0;'>" +
            "© 2026 " + COMPANY_NAME + "<br>" +
            "This is an automated email. Please do not reply.</p>" +
            "</div></div>";

        // ── Shared track button ──
        String trackBtn =
            "<div style='text-align:center;margin:20px 0;'>" +
            "<a href='" + PORTAL_URL + "' style='background:linear-gradient(135deg,#0a6ebd,#00b4a6);" +
            "color:#fff;padding:13px 32px;border-radius:10px;text-decoration:none;" +
            "font-weight:700;font-size:.9rem;display:inline-block;'>🔍 Track My Requirement</a>" +
            "</div>";

        // ════════ EMAIL TEMPLATES ════════

        if ("INITIAL_APPROVED".equals(emailType)) {
            subject = "✅ Your Requirement is Approved! — AutoProd #" + reqId;
            body = header +
                "<p style='font-size:1rem;color:#0d1b2a;margin:0 0 6px;'>Hello <strong>" + name + "</strong>,</p>" +
                "<p style='font-size:.9rem;color:#444;margin:0 0 20px;'>Great news! Your vehicle requirement has been <strong style='color:#2e7d32;'>approved by our Admin team</strong> and has been forwarded to our Design team. Work has officially started! 🎉</p>" +
                "<div style='background:#e8f5e9;border-radius:12px;padding:16px 20px;border-left:4px solid #2e7d32;margin-bottom:20px;'>" +
                "<p style='color:#2e7d32;font-weight:700;margin:0 0 4px;font-size:.9rem;'>✅ Admin Approved</p>" +
                "<p style='color:#444;font-size:.85rem;margin:0;'>Your requirement is now with the Design team.</p>" +
                "</div>" +
                detailsBlock +
                "<p style='font-size:.85rem;color:#6b7c93;margin:0 0 16px;'>You can track the full progress of your requirement in the Customer Portal at any time.</p>" +
                trackBtn + footer;

        } else if ("INITIAL_REJECTED".equals(emailType)) {
            subject = "❌ Requirement Update — AutoProd #" + reqId;
            body = header +
                "<p style='font-size:1rem;color:#0d1b2a;margin:0 0 6px;'>Hello <strong>" + name + "</strong>,</p>" +
                "<p style='font-size:.9rem;color:#444;margin:0 0 20px;'>We regret to inform you that your vehicle requirement could not be approved at this time.</p>" +
                "<div style='background:#ffebee;border-radius:12px;padding:16px 20px;border-left:4px solid #c62828;margin-bottom:20px;'>" +
                "<p style='color:#c62828;font-weight:700;margin:0 0 4px;font-size:.9rem;'>❌ Not Approved</p>" +
                "<p style='color:#444;font-size:.85rem;margin:0;'><strong>Reason:</strong> " +
                (remarks.isEmpty() ? "Does not meet current criteria." : remarks) + "</p>" +
                "</div>" +
                detailsBlock +
                "<p style='font-size:.85rem;color:#6b7c93;margin:0 0 8px;'>Please feel free to submit a revised requirement or contact our team for assistance.</p>" +
                trackBtn + footer;

        } else if ("FINAL_COMPLETED".equals(emailType)) {
            subject = "🎉 Your Requirement is COMPLETED! — AutoProd #" + reqId;
            body = header +
                "<p style='font-size:1rem;color:#0d1b2a;margin:0 0 6px;'>Hello <strong>" + name + "</strong>,</p>" +
                "<p style='font-size:.9rem;color:#444;margin:0 0 20px;'>Congratulations! 🎊 We are delighted to inform you that your vehicle requirement has been <strong style='color:#2e7d32;'>fully processed and COMPLETED</strong> by our team!</p>" +

                "<div style='background:linear-gradient(135deg,#e8f5e9,#f0fff4);border-radius:14px;padding:20px 24px;text-align:center;margin:20px 0;border:2px solid #a5d6a7;'>" +
                "<div style='font-size:3rem;margin-bottom:8px;'>🚗</div>" +
                "<h2 style='color:#2e7d32;font-size:1.3rem;margin:0 0 6px;'>Requirement Completed!</h2>" +
                "<p style='color:#444;font-size:.85rem;margin:0;'>Completed on <strong>" + today + "</strong></p>" +
                "</div>" +

                detailsBlock +

                "<div style='background:#f0f7ff;border-radius:12px;padding:16px 20px;border-left:4px solid #0a6ebd;margin:16px 0;'>" +
                "<p style='color:#0a6ebd;font-weight:700;font-size:.9rem;margin:0 0 6px;'>📞 What happens next?</p>" +
                "<p style='color:#444;font-size:.85rem;margin:0;'>Our representative will contact you shortly to discuss the delivery and next steps. Please keep your phone accessible.</p>" +
                "</div>" +

                "<p style='font-size:.85rem;color:#6b7c93;margin:16px 0;'>Thank you for choosing <strong>AutoProd Manufacturing Systems</strong>. We look forward to serving you again!</p>" +
                trackBtn + footer;

        } else if ("FINAL_REJECTED".equals(emailType)) {
            subject = "❌ Final Review Update — AutoProd #" + reqId;
            body = header +
                "<p style='font-size:1rem;color:#0d1b2a;margin:0 0 6px;'>Hello <strong>" + name + "</strong>,</p>" +
                "<p style='font-size:.9rem;color:#444;margin:0 0 20px;'>We regret to inform you that your requirement was not approved at the final review stage.</p>" +
                "<div style='background:#ffebee;border-radius:12px;padding:16px 20px;border-left:4px solid #c62828;margin-bottom:20px;'>" +
                "<p style='color:#c62828;font-weight:700;margin:0 0 4px;font-size:.9rem;'>❌ Final Review — Not Approved</p>" +
                "<p style='color:#444;font-size:.85rem;margin:0;'><strong>Reason:</strong> " +
                (remarks.isEmpty() ? "Did not meet final quality standards." : remarks) + "</p>" +
                "</div>" +
                detailsBlock +
                "<p style='font-size:.85rem;color:#6b7c93;margin:0 0 8px;'>Please contact our team for more information or to submit a revised requirement.</p>" +
                trackBtn + footer;
        }

        // ── Send ──
        if (!subject.isEmpty()) {
            Message msg = new MimeMessage(mailSession);
            msg.setFrom(new InternetAddress(GMAIL_USER, COMPANY_NAME));
            msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            msg.setSubject(subject);
            msg.setContent(body, "text/html; charset=utf-8");
            Transport.send(msg);
            System.out.println("✅ Email sent [" + emailType + "] to: " + toEmail);
        }
    }
}
