package com.automobile.servlet;

import com.automobile.db.DBConnection;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

/**
 * LogoutServlet.java
 * Clears last_active in DB so admin sees designer as Offline immediately.
 */
public class LogoutServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        if (session != null) {
            // ── Clear last_active so admin sees this user as Offline instantly ──
            String username = (String) session.getAttribute("username");
            if (username != null && !username.isEmpty()) {
                try (Connection conn = DBConnection.getConnection()) {
                    PreparedStatement ps = conn.prepareStatement(
                        "UPDATE users SET last_active = NULL WHERE username = ?");
                    ps.setString(1, username);
                    ps.executeUpdate();
                } catch (Exception ignored) {}
            }
            session.invalidate();
        }

        response.sendRedirect("index.jsp");
    }
}
