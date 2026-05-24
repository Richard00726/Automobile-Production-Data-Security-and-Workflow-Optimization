<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || !"admin".equals(sess.getAttribute("role"))) {
        response.sendRedirect("admin_dashboard.jsp");
        return;
    }

    String[] vtypes = {"two_wheeler","three_wheeler","car","van","bus","lorry","heavy_vehicle","special"};
    int saved = 0;

    try(Connection conn = DBConnection.getConnection()){
        for(String vt : vtypes){
            String val = request.getParameter("assign_" + vt);
            if(val == null) continue;
            String username = "";
            String fullName = "";
            Integer userId  = null;
            if(!val.trim().isEmpty()){
                String[] parts = val.split("\\|",2);
                username = parts[0].trim();
                fullName = parts.length>1 ? parts[1].trim() : username;
                // Get user id
                try{
                    PreparedStatement uq = conn.prepareStatement(
                        "SELECT id FROM users WHERE username=?");
                    uq.setString(1, username);
                    ResultSet ur = uq.executeQuery();
                    if(ur.next()) userId = ur.getInt("id");
                }catch(Exception ig){}
            }
            // Upsert into vehicle_type_assignments
            PreparedStatement ps = conn.prepareStatement(
                "INSERT INTO vehicle_type_assignments (vehicle_type,vehicle_label,vehicle_icon,assigned_user_id,assigned_username,assigned_name) " +
                "VALUES (?,?,?,?,?,?) " +
                "ON DUPLICATE KEY UPDATE " +
                "assigned_user_id=VALUES(assigned_user_id)," +
                "assigned_username=VALUES(assigned_username)," +
                "assigned_name=VALUES(assigned_name)," +
                "updated_at=CURRENT_TIMESTAMP"
            );
            ps.setString(1, vt);
            ps.setString(2, vt.replace("_"," "));
            ps.setString(3, "🚗");
            if(userId != null) ps.setInt(4, userId); else ps.setNull(4, java.sql.Types.INTEGER);
            ps.setString(5, username.isEmpty() ? null : username);
            ps.setString(6, fullName.isEmpty()  ? null : fullName);
            ps.executeUpdate();
            saved++;
        }
    }catch(Exception e){
        session.setAttribute("routingMsg","Error: " + e.getMessage());
        response.sendRedirect("admin_dashboard.jsp?tab=designer_assign");
        return;
    }
    session.setAttribute("routingMsg","✅ Designer assignments saved successfully!");
    response.sendRedirect("admin_dashboard.jsp?tab=designer_assign");
%>
