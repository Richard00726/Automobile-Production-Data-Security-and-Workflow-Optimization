<%@ page contentType="application/json;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.io.*" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    out.clear();

    HttpSession sess = request.getSession(false);
    if(sess==null||sess.getAttribute("username")==null){ out.print("{\"error\":\"Unauthorized\"}"); return; }
    String role    = (String)sess.getAttribute("role");
    String anaUser = (String)sess.getAttribute("username");
    if(!"analytics".equals(role)&&!"admin".equals(role)){ out.print("{\"error\":\"Access denied\"}"); return; }

    String method = request.getMethod();

    /* ── LOAD (GET) ── */
    if("GET".equalsIgnoreCase(method)){
        String jobIdStr = request.getParameter("jobId");
        String srcType  = request.getParameter("srcType");
        if(jobIdStr==null||srcType==null){ out.print("{\"success\":false}"); return; }
        int jobId=0;
        try{ jobId=Integer.parseInt(jobIdStr.trim()); }catch(Exception e){ out.print("{\"success\":false}"); return; }
        try(Connection conn=DBConnection.getConnection()){
            /* First try analytics_drafts table */
            try{
                PreparedStatement ps=conn.prepareStatement(
                    "SELECT market_segment,cost_estimate,projected_units,roi_pct,risk_level,recommendation,analyst_notes "+
                    "FROM analytics_drafts WHERE job_ref_id=? AND source_type=? AND analyst_user=? "+
                    "ORDER BY saved_at DESC LIMIT 1");
                ps.setInt(1,jobId); ps.setString(2,srcType); ps.setString(3,anaUser);
                ResultSet rs=ps.executeQuery();
                if(rs.next()){
                    out.print("{\"success\":true,\"draft\":{"+
                        "\"market_segment\":\""+je(rs.getString("market_segment"))+"\","+
                        "\"cost_estimate\":\""+je(rs.getString("cost_estimate"))+"\","+
                        "\"projected_units\":\""+je(rs.getString("projected_units"))+"\","+
                        "\"roi_pct\":\""+je(rs.getString("roi_pct"))+"\","+
                        "\"risk_level\":\""+je(rs.getString("risk_level"))+"\","+
                        "\"recommendation\":\""+je(rs.getString("recommendation"))+"\","+
                        "\"analyst_notes\":\""+je(rs.getString("analyst_notes"))+"\""+
                        "}}");
                    return;
                }
            }catch(Exception ig){}
            /* Fallback: check analytics_submissions for existing saved data */
            String tSrc = "internal".equals(srcType)?"internal":("external".equals(srcType)?"external":"cr");
            try{
                PreparedStatement ps2=conn.prepareStatement(
                    "SELECT market_segment,cost_estimate,projected_units,roi_pct,risk_level,recommendation,analyst_notes "+
                    "FROM analytics_submissions WHERE job_ref_id=? AND source_type=? "+
                    "ORDER BY id DESC LIMIT 1");
                ps2.setInt(1,jobId); ps2.setString(2,tSrc);
                ResultSet rs2=ps2.executeQuery();
                if(rs2.next()){
                    out.print("{\"success\":true,\"draft\":{"+
                        "\"market_segment\":\""+je(rs2.getString("market_segment"))+"\","+
                        "\"cost_estimate\":\""+je(rs2.getString("cost_estimate"))+"\","+
                        "\"projected_units\":\""+je(rs2.getString("projected_units"))+"\","+
                        "\"roi_pct\":\""+je(rs2.getString("roi_pct"))+"\","+
                        "\"risk_level\":\""+je(rs2.getString("risk_level"))+"\","+
                        "\"recommendation\":\""+je(rs2.getString("recommendation"))+"\","+
                        "\"analyst_notes\":\""+je(rs2.getString("analyst_notes"))+"\""+
                        "}}");
                    return;
                }
            }catch(Exception ig){}
            out.print("{\"success\":true,\"draft\":null}");
        }catch(Exception e){ out.print("{\"success\":true,\"draft\":null}"); }
        return;
    }

    /* ── SAVE (POST) ── */
    request.setCharacterEncoding("UTF-8");
    StringBuilder sb=new StringBuilder();
    try{
        BufferedReader br=request.getReader();
        char[] buf=new char[4096]; int n;
        while((n=br.read(buf))!=-1) sb.append(buf,0,n);
    }catch(Exception e){ out.print("{\"error\":\"read error\"}"); return; }

    String b=sb.toString().trim();
    if(b.isEmpty()){ out.print("{\"error\":\"empty body\"}"); return; }

    String jobIdStr  = gs(b,"jobId");
    String srcType   = gs(b,"srcType");
    String market    = gs(b,"market_segment");
    String cost      = gs(b,"cost_estimate");
    String units     = gs(b,"projected_units");
    String roi       = gs(b,"roi_pct");
    String risk      = gs(b,"risk_level");
    String rec       = gs(b,"recommendation");
    String notes     = gs(b,"analyst_notes");

    if(jobIdStr==null||jobIdStr.isEmpty()){ out.print("{\"success\":false,\"error\":\"missing jobId\"}"); return; }
    int jobId=0;
    try{ jobId=Integer.parseInt(jobIdStr.trim()); }catch(Exception e){ out.print("{\"success\":false,\"error\":\"bad jobId\"}"); return; }
    if(jobId<=0){ out.print("{\"success\":false,\"error\":\"invalid jobId\"}"); return; }

    try(Connection conn=DBConnection.getConnection()){
        /* Create analytics_drafts table if missing */
        try{ conn.createStatement().executeUpdate(
            "CREATE TABLE IF NOT EXISTS analytics_drafts("+
            "id INT AUTO_INCREMENT PRIMARY KEY,"+
            "job_ref_id INT NOT NULL,source_type VARCHAR(30),analyst_user VARCHAR(100),"+
            "market_segment VARCHAR(200),cost_estimate VARCHAR(30),projected_units VARCHAR(20),"+
            "roi_pct VARCHAR(20),risk_level VARCHAR(30),recommendation VARCHAR(50),"+
            "analyst_notes TEXT,saved_at DATETIME DEFAULT NOW(),"+
            "UNIQUE KEY uq_ad(job_ref_id,source_type,analyst_user)"+
            ")ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        }catch(Exception ig){}

        PreparedStatement ps=conn.prepareStatement(
            "INSERT INTO analytics_drafts(job_ref_id,source_type,analyst_user,market_segment,cost_estimate,projected_units,roi_pct,risk_level,recommendation,analyst_notes,saved_at) "+
            "VALUES(?,?,?,?,?,?,?,?,?,?,NOW()) "+
            "ON DUPLICATE KEY UPDATE market_segment=VALUES(market_segment),cost_estimate=VALUES(cost_estimate),"+
            "projected_units=VALUES(projected_units),roi_pct=VALUES(roi_pct),risk_level=VALUES(risk_level),"+
            "recommendation=VALUES(recommendation),analyst_notes=VALUES(analyst_notes),saved_at=NOW()");
        ps.setInt(1,jobId);
        ps.setString(2,nvl(srcType,"internal"));
        ps.setString(3,anaUser);
        ps.setString(4,nvl(market,""));
        ps.setString(5,nvl(cost,"0"));
        ps.setString(6,nvl(units,"0"));
        ps.setString(7,nvl(roi,"0"));
        ps.setString(8,nvl(risk,"Low"));
        ps.setString(9,nvl(rec,"Approve"));
        ps.setString(10,nvl(notes,""));
        ps.executeUpdate();
        out.print("{\"success\":true}");
    }catch(Exception e){
        String msg=e.getMessage()!=null?e.getMessage().replace("\"","'"):"db error";
        out.print("{\"success\":false,\"error\":\""+msg+"\"}");
    }
%><%!
private String nvl(String s,String d){ return(s!=null&&!s.trim().isEmpty())?s:d; }
private String je(String s){
    if(s==null) return "";
    return s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","").replace("\t","\\t");
}
private String gs(String b, String key){
    String pat="\""+key+"\":";
    int i=b.indexOf(pat); if(i<0) return "";
    int s=i+pat.length();
    while(s<b.length()&&b.charAt(s)==' ') s++;
    if(s>=b.length()) return "";
    if(b.charAt(s)=='"'){
        int e=s+1;
        while(e<b.length()){ if(b.charAt(e)=='"'&&b.charAt(e-1)!='\\') break; e++; }
        return b.substring(s+1,e).replace("\\n","\n").replace("\\\"","\"").replace("\\\\","\\");
    }
    int e=s;
    while(e<b.length()&&b.charAt(e)!=','&&b.charAt(e)!='}') e++;
    return b.substring(s,e).trim().replace("\"","");
}
%>
