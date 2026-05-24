package com.automobile.filter;

import com.automobile.db.DBConnection;
import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

/**
 * AuthFilter.java (UPGRADED)
 * --------------------------
 * Added: updates last_active timestamp on every authenticated request.
 * This powers the online/offline designer status in Admin Dashboard.
 */
public class AuthFilter implements Filter {

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  request  = (HttpServletRequest)  req;
        HttpServletResponse response = (HttpServletResponse) res;

        String uri = request.getRequestURI();
        String ctx = request.getContextPath();

        // Public resources that don't need authentication
        boolean isPublic =
            uri.equals(ctx + "/")                  ||
            uri.equals(ctx + "/index.jsp")         ||
            uri.equals(ctx + "/home.jsp")          ||
            uri.startsWith(ctx + "/login")         ||
            uri.startsWith(ctx + "/logout")        ||
            uri.startsWith(ctx + "/css/")          ||
            uri.startsWith(ctx + "/js/")           ||
            uri.startsWith(ctx + "/images/")       ||
            uri.startsWith(ctx + "/uploads/")      ||
            uri.startsWith(ctx + "/customer_login")||
            uri.startsWith(ctx + "/customer_register")||
            uri.startsWith(ctx + "/customerLogin")||
            uri.startsWith(ctx + "/customerRegister");

        if (isPublic) {
            chain.doFilter(req, res);
            return;
        }

        // Check for valid session — accept both staff (username) and customer (customerId) sessions
        HttpSession session  = request.getSession(false);
        boolean     isLoggedIn = (session != null) &&
                                 (session.getAttribute("username") != null ||
                                  session.getAttribute("customerId") != null);

        if (!isLoggedIn) {
            response.sendRedirect(ctx + "/index.jsp");
            return;
        }

        // Update last_active for online/offline status tracking
        try {
            String username = (String) session.getAttribute("username");
            if (username != null) {
                try (Connection conn = DBConnection.getConnection()) {
                    PreparedStatement ps = conn.prepareStatement(
                        "UPDATE users SET last_active = NOW() WHERE username = ?");
                    ps.setString(1, username);
                    ps.executeUpdate();
                }
            }
        } catch (Exception ignored) {
            // Never block request if last_active update fails
        }

        // Prevent browser caching of authenticated pages
        response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        response.setHeader("Pragma",        "no-cache");
        response.setDateHeader("Expires",   0);

        chain.doFilter(req, res);
    }

    @Override public void init(FilterConfig cfg) {}
    @Override public void destroy() {}
}
