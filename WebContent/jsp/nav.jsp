<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    String currentRole = (String) session.getAttribute("role");
    String fullName    = (String) session.getAttribute("fullName");
    String currentPage = (String) request.getAttribute("currentPage");
    if (currentPage == null) currentPage = "";
    String initial = (fullName != null && !fullName.isEmpty())
                     ? String.valueOf(fullName.charAt(0)).toUpperCase() : "U";
    String ctx = request.getContextPath();

    // Count pending workflow tasks for this role
    int wfPending = 0;
    try {
        java.sql.Connection conn = com.automobile.db.DBConnection.getConnection();

        if ("design".equals(currentRole)) {
            // Design team: count BOTH external requirements AND internal jobs
            java.sql.ResultSet r1 = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements " +
                "WHERE workflow_stage='admin_initial_approved' " +
                "  AND current_assignee NOT IN ('admin','qc','testing','analytics')");
            if (r1.next()) wfPending += r1.getInt(1);
            // Also count internal jobs assigned to this designer
            try {
                String loggedUser = (String) session.getAttribute("username");
                java.sql.PreparedStatement ps = conn.prepareStatement(
                    "SELECT COUNT(*) FROM internal_jobs " +
                    "WHERE current_assignee=? AND workflow_stage NOT IN ('completed','cancelled','design_completed')");
                ps.setString(1, loggedUser != null ? loggedUser : "");
                java.sql.ResultSet r2 = ps.executeQuery();
                if (r2.next()) wfPending += r2.getInt(1);
            } catch (Exception ig) {}

        } else if ("qc".equals(currentRole)) {
            java.sql.ResultSet r = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements " +
                "WHERE current_assignee='qc' AND workflow_stage='design_completed'");
            if (r.next()) wfPending = r.getInt(1);

        } else if ("testing".equals(currentRole)) {
            java.sql.ResultSet r = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements " +
                "WHERE current_assignee='testing' AND workflow_stage='qc_approved'");
            if (r.next()) wfPending = r.getInt(1);

        } else if ("analytics".equals(currentRole)) {
            java.sql.ResultSet r = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements " +
                "WHERE current_assignee='analytics' AND workflow_stage='testing_completed'");
            if (r.next()) wfPending = r.getInt(1);

        } else if ("admin".equals(currentRole)) {
            // Admin: count pending initial reviews + pending final approvals
            java.sql.ResultSet r1 = conn.createStatement().executeQuery(
                "SELECT COUNT(*) FROM customer_requirements " +
                "WHERE current_assignee='admin' " +
                "  AND workflow_stage IN ('admin_initial_review','submitted','in_review')");
            if (r1.next()) wfPending += r1.getInt(1);
            try {
                java.sql.ResultSet r2 = conn.createStatement().executeQuery(
                    "SELECT COUNT(*) FROM customer_requirements " +
                    "WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");
                if (r2.next()) wfPending += r2.getInt(1);
            } catch (Exception ig) {}
        }
        conn.close();
    } catch (Exception ignored) {}
%>
<link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<style>
    .wf-badge {
        margin-left: auto;
        background: #ff6b35;
        color: #fff;
        border-radius: 10px;
        padding: 1px 8px;
        font-size: .65rem;
        font-weight: 700;
    }
</style>

<div class="sidebar">

    <!-- Brand -->
    <div class="sidebar-brand">
        <h3>🚗 AutoProd</h3>
        <span>Security System v2.0</span>
    </div>

    <!-- User -->
    <div class="sidebar-user">
        <div class="user-avatar"><%= initial %></div>
        <div class="user-info">
            <p><%= fullName %></p>
            <span><%= currentRole %></span>
        </div>
    </div>

    <nav class="sidebar-nav">

        <!-- Dashboard -->
        <div class="nav-section-title">MAIN</div>
        <a href="<%= ctx %>/dashboard.jsp"
           class="nav-item <%= "dashboard".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">🏠</span>
            <span>Dashboard</span>
        </a>

        <!-- Vehicle Design — design + admin -->
        <% if ("admin".equals(currentRole) || "design".equals(currentRole)) { %>
        <div class="nav-section-title">MODULES</div>
        <a href="<%= ctx %>/vehicle"
           class="nav-item <%= "vehicle".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">🚙</span>
            <span>Vehicle Design</span>
        </a>
        <% } %>

        <!-- Analytics — analytics + admin -->
        <% if ("admin".equals(currentRole) || "analytics".equals(currentRole)) { %>
        <% if (!"design".equals(currentRole)) { %><div class="nav-section-title">MODULES</div><% } %>
        <a href="<%= ctx %>/jsp/analytics_module.jsp"
           class="nav-item <%= "analytics".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">📊</span>
            <span>Analytics</span>
        </a>
        <% } %>

        <!-- QC — qc + admin -->
        <% if ("admin".equals(currentRole) || "qc".equals(currentRole)) { %>
        <a href="<%= ctx %>/qc"
           class="nav-item <%= "qc".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">✅</span>
            <span>QC Module</span>
        </a>
        <% } %>

        <!-- Testing — testing + admin -->
        <% if ("admin".equals(currentRole) || "testing".equals(currentRole)) { %>
        <a href="<%= ctx %>/testing"
           class="nav-item <%= "testing".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">🔬</span>
            <span>Testing Module</span>
        </a>
        <% } %>

        <!-- Final Report — admin only -->
        <% if ("admin".equals(currentRole)) { %>
        <div class="nav-section-title">REPORTS</div>
        <a href="<%= ctx %>/jsp/final_report.jsp"
           class="nav-item <%= "report".equals(currentPage) ? "active" : "" %>">
            <span class="nav-icon">📋</span>
            <span>Final Report</span>
        </a>
        <% } %>

        <!-- ── WORKFLOW — all roles ── -->
        <div class="nav-section-title">WORKFLOW</div>
        <a href="<%= ctx %>/workflow_dashboard.jsp"
           class="nav-item <%= "workflow".equals(currentPage) ? "active" : "" %>"
           style="display:flex;align-items:center;">
            <span class="nav-icon">🔄</span>
            <span>My Workflow</span>
            <% if (wfPending > 0) { %>
            <span class="wf-badge"><%= wfPending %></span>
            <% } %>
        </a>

    </nav>

    <!-- Logout -->
    <div class="sidebar-footer">
        <a href="<%= ctx %>/logout">
            <span>🚪</span>
            <span>Logout</span>
        </a>
    </div>

</div>

