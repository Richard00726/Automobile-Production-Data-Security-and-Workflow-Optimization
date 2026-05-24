package com.automobile.servlet;

import com.automobile.db.DBConnection;
import javax.servlet.annotation.WebServlet;
import javax.servlet.ServletException;
import javax.servlet.http.*;
import java.io.IOException;
import java.security.MessageDigest;
import java.sql.*;
import java.util.Base64;

@WebServlet("/customerLogin")
public class CustomerLoginServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String email    = request.getParameter("email");
        String password = request.getParameter("password");

        // ── Validation ──
        if (email == null || password == null ||
            email.trim().isEmpty() || password.trim().isEmpty()) {
            request.setAttribute("error", "Email and password are required!");
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            return;
        }

        try (Connection conn = DBConnection.getConnection()) {

            // ── Only allow VERIFIED accounts to login ──
            PreparedStatement ps = conn.prepareStatement(
                "SELECT id, full_name, email, password, is_verified " +
                "FROM customers WHERE email = ?");
            ps.setString(1, email.trim().toLowerCase());
            ResultSet rs = ps.executeQuery();

            if (rs.next()) {

                // ── Check if account is verified ──
                int isVerified = rs.getInt("is_verified");
                if (isVerified == 0) {
                    request.setAttribute("error",
                        "⚠️ Your account is not verified! " +
                        "Please register again and complete OTP verification.");
                    request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
                    return;
                }

                // ── Verify password ──
                String storedHash = rs.getString("password");
                if (verifyPassword(password, storedHash)) {
                    HttpSession sess = request.getSession(true);
                    sess.setAttribute("customerId",    rs.getInt("id"));
                    sess.setAttribute("customerName",  rs.getString("full_name"));
                    sess.setAttribute("customerEmail", rs.getString("email"));
                    response.sendRedirect(request.getContextPath() + "/customer_requirements.jsp");
                } else {
                    request.setAttribute("error", "❌ Invalid email or password!");
                    request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
                }

            } else {
                request.setAttribute("error",
                    "No account found with this email! " +
                    "<a href='" + request.getContextPath() + "/customer_register.jsp'>Register here</a>");
                request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
            }

        } catch (Exception e) {
            request.setAttribute("error", "Login failed: " + e.getMessage());
            request.getRequestDispatcher("/customer_login.jsp").forward(request, response);
        }
    }

    // ── Password verification with SHA-256 + salt ──
    private boolean verifyPassword(String plainText, String stored) {
        try {
            if (stored == null || !stored.contains(":"))
                return stored != null && stored.equals(plainText);
            String[] parts      = stored.split(":", 2);
            byte[]   salt       = Base64.getDecoder().decode(parts[0]);
            byte[]   storedHash = Base64.getDecoder().decode(parts[1]);
            MessageDigest md    = MessageDigest.getInstance("SHA-256");
            md.update(salt);
            byte[] computed = md.digest(plainText.getBytes("UTF-8"));
            if (storedHash.length != computed.length) return false;
            int diff = 0;
            for (int i = 0; i < storedHash.length; i++) diff |= (storedHash[i] ^ computed[i]);
            return diff == 0;
        } catch (Exception e) { return false; }
    }
}
