package com.automobile.servlet;
 
import com.automobile.db.DBConnection;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.*;
import java.util.Base64;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;
 
@WebServlet("/customerRegister")
public class CustomerRegisterServlet extends HttpServlet {
 
    private static final String GMAIL_USER     = "infantrichart06@gmail.com";
    private static final String GMAIL_PASSWORD = "otos ixhh lqdx cmph";
    private static final String FAST2SMS_KEY   = "your_fast2sms_api_key";
 
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
    }
 
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
 
        String fullName        = request.getParameter("fullName");
        String city            = request.getParameter("city");
        String email           = request.getParameter("email");
        String phone           = request.getParameter("phone");
        String password        = request.getParameter("password");
        String confirmPassword = request.getParameter("confirmPassword");
 
        // ── Validation ──
        if (fullName == null || email == null || phone == null || password == null ||
            fullName.trim().isEmpty() || email.trim().isEmpty() ||
            phone.trim().isEmpty()   || password.trim().isEmpty()) {
            request.setAttribute("error", "All fields are required!");
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            return;
        }
        if (!password.equals(confirmPassword)) {
            request.setAttribute("error", "Passwords do not match!");
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            return;
        }
        if (password.length() < 8) {
            request.setAttribute("error", "Password must be at least 8 characters!");
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            return;
        }
        if (!phone.trim().matches("[0-9]{10}")) {
            request.setAttribute("error", "Please enter a valid 10-digit mobile number!");
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            return;
        }
 
        email    = email.trim().toLowerCase();
        phone    = phone.trim();
        fullName = fullName.trim();
        city     = (city != null && !city.trim().isEmpty()) ? city.trim() : null;
 
        try (Connection conn = DBConnection.getConnection()) {
 
            // ── Check if email already exists ──
            PreparedStatement check = conn.prepareStatement(
                "SELECT id, is_verified FROM customers WHERE email = ?");
            check.setString(1, email);
            ResultSet existing = check.executeQuery();
            if (existing.next()) {
                if (existing.getInt("is_verified") == 1) {
                    request.setAttribute("error", "Account already exists! Please login.");
                    request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
                    return;
                } else {
                    PreparedStatement del = conn.prepareStatement(
                        "DELETE FROM customers WHERE email = ?");
                    del.setString(1, email);
                    del.executeUpdate();
                }
            }
 
            // ── Generate OTPs ──
            String emailOtp  = generateOtp();
            String mobileOtp = generateOtp();
 
            // ── Hash Password ──
            String hashedPassword = hashPassword(password);
 
            // ── OTP expiry — 10 minutes ──
            Timestamp expiry = new Timestamp(System.currentTimeMillis() + (10 * 60 * 1000));
 
            // ── Save to DB — fullName clean, city stored separately ──
            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO customers (full_name, city, email, phone, password, " +
                "email_otp, mobile_otp, otp_expiry, is_verified) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)");
            ps.setString(1, fullName);
            ps.setString(2, city);
            ps.setString(3, email);
            ps.setString(4, phone);
            ps.setString(5, hashedPassword);
            ps.setString(6, emailOtp);
            ps.setString(7, mobileOtp);
            ps.setTimestamp(8, expiry);
            ps.executeUpdate();
 
            // ── Store in session ──
            HttpSession sess = request.getSession(true);
            sess.setAttribute("pendingEmail", email);
            sess.setAttribute("pendingPhone", phone);
 
            // ── Send Email OTP ──
            boolean emailSent = false;
            try {
                sendEmailOtp(email, fullName, emailOtp);
                emailSent = true;
                System.out.println("✅ Email OTP sent to: " + email);
            } catch (Exception e) {
                System.err.println("❌ Email sending failed: " + e.getMessage());
            }
 
            // ── Send Mobile OTP via Fast2SMS ──
            try {
                sendSmsOtp(phone, mobileOtp);
                System.out.println("✅ SMS OTP sent to: " + phone);
            } catch (Exception e) {
                System.err.println("❌ SMS sending failed: " + e.getMessage());
            }
 
            if (!emailSent) {
                sess.setAttribute("devEmailOtp", emailOtp);
            }
            sess.setAttribute("devMobileOtp", mobileOtp);
 
            response.sendRedirect(request.getContextPath() + "/verify_otp.jsp");
 
        } catch (Exception e) {
            request.setAttribute("error", "Registration failed: " + e.getMessage());
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
        }
    }
 
    private String generateOtp() {
        return String.valueOf(100000 + new SecureRandom().nextInt(900000));
    }
 
    private String hashPassword(String password) throws Exception {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        md.update(salt);
        byte[] hash = md.digest(password.getBytes("UTF-8"));
        return Base64.getEncoder().encodeToString(salt) + ":" +
               Base64.getEncoder().encodeToString(hash);
    }
 
    private void sendEmailOtp(String toEmail, String name, String otp) throws Exception {
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
 
        Message msg = new MimeMessage(mailSession);
        msg.setFrom(new InternetAddress(GMAIL_USER, "AutoProd Manufacturing"));
        msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
        msg.setSubject("AutoProd — Email Verification OTP");
 
        String body =
            "<div style='font-family:Arial,sans-serif;max-width:480px;margin:0 auto;'>" +
            "<div style='background:linear-gradient(135deg,#0a6ebd,#00b4a6);padding:28px;text-align:center;border-radius:12px 12px 0 0;'>" +
            "<h2 style='color:#fff;margin:0;'>🚗 AutoProd</h2>" +
            "<p style='color:rgba(255,255,255,.8);margin:4px 0 0;font-size:13px;'>Manufacturing Systems</p>" +
            "</div>" +
            "<div style='background:#fff;padding:28px;border:1px solid #e0e0e0;border-top:none;border-radius:0 0 12px 12px;'>" +
            "<p style='color:#0d1b2a;font-size:15px;'>Hello <strong>" + name + "</strong>,</p>" +
            "<p style='color:#444;font-size:14px;'>Your Email Verification OTP is:</p>" +
            "<div style='background:#f0f7ff;border-radius:12px;padding:20px;text-align:center;margin:20px 0;border:2px dashed #0a6ebd;'>" +
            "<span style='font-size:36px;font-weight:800;letter-spacing:12px;color:#0a6ebd;'>" + otp + "</span>" +
            "</div>" +
            "<p style='color:#6b7c93;font-size:13px;'>⏰ This OTP expires in <strong>10 minutes</strong>.</p>" +
            "<p style='color:#6b7c93;font-size:13px;'>If you did not register on AutoProd, please ignore this email.</p>" +
            "</div></div>";
 
        msg.setContent(body, "text/html; charset=utf-8");
        Transport.send(msg);
    }
 
    private void sendSmsOtp(String phone, String otp) throws Exception {
        String urlStr = "https://www.fast2sms.com/dev/bulkV2" +
            "?authorization=" + FAST2SMS_KEY +
            "&variables_values=" + URLEncoder.encode(otp, "UTF-8") +
            "&route=otp" +
            "&numbers=" + URLEncoder.encode(phone, "UTF-8");
 
        URL url = new URL(urlStr);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        conn.setRequestProperty("cache-control", "no-cache");
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(5000);
        int responseCode = conn.getResponseCode();
        if (responseCode != 200) {
            throw new Exception("Fast2SMS returned code: " + responseCode);
        }
    }
}