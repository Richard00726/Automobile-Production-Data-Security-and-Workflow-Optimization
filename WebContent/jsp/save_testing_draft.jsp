<%@ page contentType="application/json;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.io.*" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    out.clear();

    HttpSession sess = request.getSession(false);
    if(sess==null||sess.getAttribute("username")==null){ out.print("{\"error\":\"Unauthorized\"}"); return; }
    String role    = (String)sess.getAttribute("role");
    String tstUser = (String)sess.getAttribute("username");
    if(!"testing".equals(role)&&!"admin".equals(role)){ out.print("{\"error\":\"Access denied\"}"); return; }

    /* ══ Determine GET vs POST ══
       LOAD uses GET with ?action=load&jobId=X&srcType=Y — safe to use getParameter()
       SAVE uses POST with JSON body  — must NOT call getParameter() before getReader()  */
    String method = request.getMethod();

    /* ══ LOAD (GET) ══ */
    if("GET".equalsIgnoreCase(method)){
        String jobIdStr = request.getParameter("jobId");
        String srcType  = request.getParameter("srcType");
        if(jobIdStr==null||srcType==null){ out.print("{\"success\":false}"); return; }
        int jobId=0;
        try{ jobId=Integer.parseInt(jobIdStr.trim()); }catch(Exception e){ out.print("{\"success\":false}"); return; }
        try(Connection conn=DBConnection.getConnection()){
            PreparedStatement ps=conn.prepareStatement(
                "SELECT tester_notes,overall_result,overall_score,tests_json,progress_pct " +
                "FROM testing_drafts WHERE job_ref_id=? AND source_type=? AND tester_user=? " +
                "ORDER BY saved_at DESC LIMIT 1");
            ps.setInt(1,jobId); ps.setString(2,srcType); ps.setString(3,tstUser);
            ResultSet rs=ps.executeQuery();
            if(rs.next()){
                String notes = je(rs.getString("tester_notes"));
                String res   = je(rs.getString("overall_result"));
                String sc    = je(rs.getString("overall_score"));
                String tests = rs.getString("tests_json"); if(tests==null) tests="[]";
                int pct      = rs.getInt("progress_pct");
                out.print("{\"success\":true,\"draft\":{"+
                    "\"tester_notes\":\""+notes+"\","+
                    "\"overall_result\":\""+res+"\","+
                    "\"overall_score\":\""+sc+"\","+
                    "\"tests_json\":"+safeArr(tests)+","+
                    "\"progress_pct\":"+pct+"}}");
            } else {
                out.print("{\"success\":true,\"draft\":null}");
            }
        }catch(Exception e){ out.print("{\"success\":true,\"draft\":null}"); }
        return;
    }

    /* ══ SAVE (POST) — read body FIRST, never call getParameter() ══ */
    request.setCharacterEncoding("UTF-8");
    StringBuilder sb = new StringBuilder();
    try{
        BufferedReader br = request.getReader();
        char[] buf = new char[4096]; int n;
        while((n=br.read(buf))!=-1) sb.append(buf,0,n);
    }catch(Exception e){ out.print("{\"error\":\"read error: "+e.getMessage()+"\"}"); return; }

    String b = sb.toString().trim();
    if(b.isEmpty()){ out.print("{\"error\":\"empty body\"}"); return; }

    String jobIdStr  = gs(b,"jobId");
    String srcType   = gs(b,"srcType");
    String notes     = gs(b,"tester_notes");
    String res       = gs(b,"overall_result");
    String sc        = gs(b,"overall_score");
    String testsJson = go(b,"testsJson");
    String pctStr    = gs(b,"progress_pct");

    if(jobIdStr==null||jobIdStr.isEmpty()){ out.print("{\"success\":false,\"error\":\"missing jobId, body="+b.substring(0,Math.min(100,b.length())).replace("\"","'").replace("\n"," ")+"\"}"); return; }
    int jobId=0;
    try{ jobId=Integer.parseInt(jobIdStr.trim()); }catch(Exception e){ out.print("{\"success\":false,\"error\":\"bad jobId: "+jobIdStr+"\"}"); return; }
    if(jobId<=0){ out.print("{\"success\":false,\"error\":\"invalid jobId: "+jobId+"\"}"); return; }
    int pct=0; try{ pct=Integer.parseInt(pctStr.trim()); }catch(Exception e){}

    try(Connection conn=DBConnection.getConnection()){
        /* Auto-create table if missing */
        try{ conn.createStatement().executeUpdate(
            "CREATE TABLE IF NOT EXISTS testing_drafts("+
            "id INT AUTO_INCREMENT PRIMARY KEY,"+
            "job_ref_id INT NOT NULL,"+
            "source_type VARCHAR(30) NOT NULL,"+
            "tester_user VARCHAR(100) NOT NULL,"+
            "tester_notes TEXT,"+
            "overall_result VARCHAR(100),"+
            "overall_score VARCHAR(10),"+
            "tests_json MEDIUMTEXT,"+
            "progress_pct INT DEFAULT 0,"+
            "saved_at DATETIME DEFAULT NOW(),"+
            "UNIQUE KEY uq_tst(job_ref_id,source_type,tester_user)"+
            ")ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        }catch(Exception ig){}

        PreparedStatement ps=conn.prepareStatement(
            "INSERT INTO testing_drafts"+
            "(job_ref_id,source_type,tester_user,tester_notes,overall_result,overall_score,tests_json,progress_pct,saved_at)"+
            " VALUES(?,?,?,?,?,?,?,?,NOW())"+
            " ON DUPLICATE KEY UPDATE"+
            " tester_notes=VALUES(tester_notes),overall_result=VALUES(overall_result),"+
            " overall_score=VALUES(overall_score),tests_json=VALUES(tests_json),"+
            " progress_pct=VALUES(progress_pct),saved_at=NOW()");
        ps.setInt(1,jobId);
        ps.setString(2, nvl(srcType,"internal"));
        ps.setString(3, tstUser);
        ps.setString(4, nvl(notes,""));
        ps.setString(5, nvl(res,""));
        ps.setString(6, nvl(sc,""));
        ps.setString(7, nvl(testsJson,"[]"));
        ps.setInt(8, pct);
        ps.executeUpdate();
        out.print("{\"success\":true,\"progress\":"+pct+"}");
    }catch(Exception e){
        String msg = e.getMessage()!=null ? e.getMessage().replace("\"","'") : "db error";
        out.print("{\"success\":false,\"error\":\""+msg+"\"}");
    }
%><%!
private String nvl(String s,String d){ return(s!=null&&!s.trim().isEmpty())?s:d; }
private String je(String s){
    if(s==null) return "";
    return s.replace("\\","\\\\").replace("\"","\\\"")
             .replace("\n","\\n").replace("\r","").replace("\t","\\t");
}
private String safeArr(String s){
    if(s==null||s.trim().isEmpty()) return "[]";
    String t=s.trim();
    return (t.startsWith("[")&&t.endsWith("]")) ? t : "[]";
}
private String gs(String b, String key){
    String pat="\""+key+"\":";
    int i=b.indexOf(pat); if(i<0) return "";
    int s=i+pat.length();
    while(s<b.length()&&b.charAt(s)==' ') s++;
    if(s>=b.length()) return "";
    if(b.charAt(s)=='"'){
        /* string value — find closing quote, skip escaped quotes */
        int e=s+1;
        while(e<b.length()){
            if(b.charAt(e)=='"'&&b.charAt(e-1)!='\\') break;
            e++;
        }
        return b.substring(s+1,e)
                .replace("\\n","\n").replace("\\\"","\"").replace("\\\\","\\");
    }
    /* number / boolean / null */
    int e=s;
    while(e<b.length()&&b.charAt(e)!=','&&b.charAt(e)!='}') e++;
    return b.substring(s,e).trim().replace("\"","");
}
private String go(String b, String key){
    String pat="\""+key+"\":";
    int i=b.indexOf(pat); if(i<0) return "[]";
    int s=i+pat.length();
    while(s<b.length()&&b.charAt(s)==' ') s++;
    if(s>=b.length()) return "[]";
    char first=b.charAt(s);
    if(first!='['&&first!='{') return "[]";
    int depth=0,e=s;
    while(e<b.length()){
        char c=b.charAt(e);
        if(c=='['||c=='{') depth++;
        else if(c==']'||c=='}'){depth--;if(depth==0){e++;break;}}
        e++;
    }
    return b.substring(s,e);
}
%>
