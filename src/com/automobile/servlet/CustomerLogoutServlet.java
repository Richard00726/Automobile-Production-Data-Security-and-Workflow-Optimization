package com.automobile.servlet;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.*;
import java.io.IOException;

@WebServlet("/customerLogout")
public class CustomerLogoutServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        HttpSession sess = request.getSession(false);
        if (sess != null) {
            sess.removeAttribute("customerId");
            sess.removeAttribute("customerName");
            sess.removeAttribute("customerEmail");
        }
        response.sendRedirect(request.getContextPath() + "/customer_login.jsp");
    }
}
