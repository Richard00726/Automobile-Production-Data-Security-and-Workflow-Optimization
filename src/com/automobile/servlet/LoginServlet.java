package com.automobile.servlet;

import com.automobile.db.DBConnection;
import com.automobile.util.PasswordUtil;
import com.automobile.util.ValidationUtil;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * LoginServlet.java  (UPGRADED)
 * ==============================
 * SECURITY IMPROVEMENTS:
 *   ✅ Password verification via PasswordUtil (salted SHA-256)
 *   ✅ Brute-force protection: 5 attempts then 15-min lockout
 *   ✅ Input validation via ValidationUtil before any DB query
 *   ✅ Session fixation prevention
 *   ✅ Admin → admin_dashboard.jsp, others → dashboard.jsp
 */
public class LoginServlet extends HttpServlet {

    private static final ConcurrentHashMap<String, AtomicInteger> failCounts  = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Long>          lockoutTime = new ConcurrentHashMap<>();
    private static final int  MAX_ATTEMPTS   = 5;
    private static final long LOCKOUT_MILLIS = 15 * 60 * 1000L;

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String username = request.getParameter("username");
        String password = request.getParameter("password");

        ValidationUtil v = new ValidationUtil();
        v.require("username", username, "Username is required.")
         .require("password", password, "Password is required.")
         .safeUsername("username", username);

        if (v.hasErrors()) {
            request.setAttribute("error", v.getFirst());
            request.getRequestDispatcher("index.jsp").forward(request, response);
            return;
        }

        username = username.trim().toLowerCase();

        if (isLockedOut(username)) {
            long remaining = (LOCKOUT_MILLIS - (System.currentTimeMillis() - lockoutTime.get(username))) / 60000;
            request.setAttribute("error", "Account locked. Try again in ~" + remaining + " minute(s).");
            request.getRequestDispatcher("index.jsp").forward(request, response);
            return;
        }

        try (Connection conn = DBConnection.getConnection()) {
            String sql = "SELECT id, username, password, role, full_name FROM users WHERE username = ? AND is_active = 1";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setString(1, username);
            ResultSet rs = ps.executeQuery();

            if (rs.next()) {
                String storedHash = rs.getString("password");
                if (PasswordUtil.verifyPassword(password, storedHash)) {
                    HttpSession old = request.getSession(false);
                    if (old != null) old.invalidate();

                    HttpSession session = request.getSession(true);
                    session.setAttribute("userId",   rs.getInt("id"));
                    session.setAttribute("username", rs.getString("username"));
                    session.setAttribute("role",     rs.getString("role"));
                    session.setAttribute("fullName", rs.getString("full_name"));
                    session.setMaxInactiveInterval(30 * 60);

                    failCounts.remove(username);
                    lockoutTime.remove(username);

                    String role = rs.getString("role");
                    if ("admin".equals(role)) {
                        response.sendRedirect("jsp/admin/admin_dashboard.jsp");
                    } else {
                    	response.sendRedirect(request.getContextPath() + "/dashboard.jsp");
                    }
                } else {
                    recordFailure(username);
                    request.setAttribute("error", buildErrorMessage(username));
                    request.getRequestDispatcher("index.jsp").forward(request, response);
                }
            } else {
                recordFailure(username);
                request.setAttribute("error", "Invalid username or password. Please try again.");
                request.getRequestDispatcher("index.jsp").forward(request, response);
            }
        } catch (SQLException e) {
            request.setAttribute("error", "A system error occurred. Please try again later.");
            request.getRequestDispatcher("index.jsp").forward(request, response);
        }
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.sendRedirect("index.jsp");
    }

    private boolean isLockedOut(String username) {
        Long lockTime = lockoutTime.get(username);
        if (lockTime == null) return false;
        if (System.currentTimeMillis() - lockTime > LOCKOUT_MILLIS) {
            failCounts.remove(username); lockoutTime.remove(username); return false;
        }
        return true;
    }

    private void recordFailure(String username) {
        AtomicInteger count = failCounts.computeIfAbsent(username, k -> new AtomicInteger(0));
        int now = count.incrementAndGet();
        if (now >= MAX_ATTEMPTS) lockoutTime.put(username, System.currentTimeMillis());
    }

    private String buildErrorMessage(String username) {
        AtomicInteger count = failCounts.get(username);
        int remaining = MAX_ATTEMPTS - (count == null ? 0 : count.get());
        if (remaining <= 1) return "Invalid credentials. 1 attempt remaining before lockout.";
        return "Invalid username or password. " + remaining + " attempts remaining.";
    }
}