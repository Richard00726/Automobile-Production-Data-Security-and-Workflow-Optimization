package com.automobile.servlet;

import com.automobile.db.DBConnection;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.sql.*;

@WebServlet("/verifyOtp")
public class VerifyOtpServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession sess = request.getSession(false);
        if (sess == null || sess.getAttribute("pendingEmail") == null) {
            response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
            return;
        }

        String pendingEmail = (String) sess.getAttribute("pendingEmail");
        String emailOtp     = request.getParameter("emailOtp");
        String mobileOtp    = request.getParameter("mobileOtp");

        if (emailOtp  == null || emailOtp.trim().isEmpty() ||
            mobileOtp == null || mobileOtp.trim().isEmpty()) {
            request.setAttribute("error", "Please enter both Email and Mobile OTPs!");
            request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
            return;
        }

        emailOtp  = emailOtp.trim();
        mobileOtp = mobileOtp.trim();

        try (Connection conn = DBConnection.getConnection()) {

            // ── Fetch stored OTPs ──
            PreparedStatement ps = conn.prepareStatement(
                "SELECT id, full_name, email, phone, email_otp, mobile_otp, otp_expiry " +
                "FROM customers WHERE email = ? AND is_verified = 0");
            ps.setString(1, pendingEmail);
            ResultSet rs = ps.executeQuery();

            if (!rs.next()) {
                request.setAttribute("error", "Account not found or already verified! Please register again.");
                request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
                return;
            }

            String storedEmailOtp  = rs.getString("email_otp");
            String storedMobileOtp = rs.getString("mobile_otp");
            Timestamp expiry       = rs.getTimestamp("otp_expiry");
            int customerId         = rs.getInt("id");
            String fullName        = rs.getString("full_name");

            // ── Check expiry ──
            if (expiry != null && expiry.before(new Timestamp(System.currentTimeMillis()))) {
                request.setAttribute("error", "OTP has expired! Please register again.");
                request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
                return;
            }

            // ── Check Email OTP ──
            if (!emailOtp.equals(storedEmailOtp)) {
                request.setAttribute("error", "❌ Incorrect Email OTP! Please check and try again.");
                request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
                return;
            }

            // ── Check Mobile OTP ──
            if (!mobileOtp.equals(storedMobileOtp)) {
                request.setAttribute("error", "❌ Incorrect Mobile OTP! Please check and try again.");
                request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
                return;
            }

            // ── Both OTPs correct — activate account ──
            PreparedStatement activate = conn.prepareStatement(
                "UPDATE customers SET is_verified=1, email_otp=NULL, mobile_otp=NULL, otp_expiry=NULL WHERE id=?");
            activate.setInt(1, customerId);
            activate.executeUpdate();

            // ── Clear pending session ──
            sess.removeAttribute("pendingEmail");
            sess.removeAttribute("pendingPhone");
            sess.removeAttribute("devEmailOtp");
            sess.removeAttribute("devMobileOtp");

            // ── Auto login after verification ──
            sess.setAttribute("customerId",    customerId);
            sess.setAttribute("customerName",  fullName);
            sess.setAttribute("customerEmail", pendingEmail);

            // ── Redirect to portal with success ──
            sess.setAttribute("welcomeMsg", "🎉 Account verified successfully! Welcome to AutoProd, " + fullName + "!");
            response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp");

        } catch (Exception e) {
            request.setAttribute("error", "Verification failed: " + e.getMessage());
            request.getRequestDispatcher("/verify_otp.jsp").forward(request, response);
        }
    }
}

