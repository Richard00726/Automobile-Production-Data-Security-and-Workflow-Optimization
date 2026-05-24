<%@ page contentType="application/json;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,java.io.*,javax.servlet.http.*" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    out.clear();

    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        out.print("{\"error\":\"Unauthorized\"}"); return;
    }
    String role   = (String) sess.getAttribute("role");
    String qcUser = (String) sess.getAttribute("username");
    if (!"qc".equals(role) && !"admin".equals(role)) {
        out.print("{\"error\":\"Access denied\"}"); return;
    }

    /* ══ SINGLE FILE UPLOAD ══ */
    String action = request.getParameter("action");
    if ("upload".equals(action)) {
        try {
            Part filePart = request.getPart("qcDocFile");
            if (filePart == null || filePart.getSize() <= 0) {
                out.print("{\"success\":false,\"error\":\"No file\"}"); return;
            }
            String orig = filePart.getSubmittedFileName();
            if (orig == null || orig.trim().isEmpty()) {
                out.print("{\"success\":false,\"error\":\"No filename\"}"); return;
            }
            String ext  = orig.contains(".") ? orig.substring(orig.lastIndexOf('.')) : "";
            String fname= "qcdoc_"+System.currentTimeMillis()+"_"+Math.abs(orig.hashCode())+ext;
            String uploadPath = getServletContext().getRealPath("uploads/qc");
            File uploadDir = new File(uploadPath);
            if (!uploadDir.exists()) uploadDir.mkdirs();
            try (InputStream is = filePart.getInputStream();
                 FileOutputStream fos = new FileOutputStream(new File(uploadDir, fname))) {
                byte[] buf = new byte[8192]; int n;
                while ((n = is.read(buf)) > 0) fos.write(buf, 0, n);
            }
            /* Also update qc_drafts.qc_doc_files right away */
            String jobIdStr = request.getParameter("jobId");
            String srcType  = request.getParameter("srcType");
            if (jobIdStr != null && srcType != null) {
                int jobId = 0;
                try { jobId = Integer.parseInt(jobIdStr.trim()); } catch (Exception ig) {}
                if (jobId > 0) {
                    try (Connection conn = DBConnection.getConnection()) {
                        /* Add column if missing */
                        try { conn.createStatement().executeUpdate(
                            "ALTER TABLE qc_drafts ADD COLUMN qc_doc_files TEXT"); }
                        catch (Exception ig) {}
                        /* Append to existing list */
                        PreparedStatement sel = conn.prepareStatement(
                            "SELECT qc_doc_files FROM qc_drafts WHERE job_ref_id=? AND source_type=? AND qc_user=?");
                        sel.setInt(1,jobId); sel.setString(2,srcType); sel.setString(3,qcUser);
                        ResultSet rs = sel.executeQuery();
                        String existing = rs.next() ? rs.getString(1) : null;
                        String newVal = (existing!=null&&!existing.isEmpty())
                            ? existing+","+fname+"|"+orig
                            : fname+"|"+orig;
                        PreparedStatement up = conn.prepareStatement(
                            "INSERT INTO qc_drafts(job_ref_id,source_type,qc_user,qc_doc_files,saved_at) "+
                            "VALUES(?,?,?,?,NOW()) ON DUPLICATE KEY UPDATE qc_doc_files=?,saved_at=NOW()");
                        up.setInt(1,jobId); up.setString(2,srcType); up.setString(3,qcUser);
                        up.setString(4,newVal); up.setString(5,newVal);
                        up.executeUpdate();
                    } catch (Exception dbEx) {}
                }
            }
            out.print("{\"success\":true,\"fname\":\""+fname+"\",\"orig\":\""+orig.replace("\"","'")+"\"}");
        } catch (Exception e) {
            out.print("{\"success\":false,\"error\":\""+e.getMessage().replace("\"","'")+"\"}");
        }
        return;
    }
    if ("load".equals(action)) {
        String jobIdStr = request.getParameter("jobId");
        String srcType  = request.getParameter("srcType");
        if (jobIdStr == null || srcType == null) {
            out.print("{\"success\":false}"); return;
        }
        int jobId = 0;
        try { jobId = Integer.parseInt(jobIdStr.trim()); } catch (Exception e) {
            out.print("{\"success\":false}"); return;
        }
        try (Connection conn = DBConnection.getConnection()) {
            PreparedStatement ps = conn.prepareStatement(
                "SELECT inspector_notes,severity,qc_remarks,compliance_checks," +
                "defect_categories,qc_verdicts,part_remarks,measurements,progress_pct " +
                "FROM qc_drafts WHERE job_ref_id=? AND source_type=? AND qc_user=? " +
                "ORDER BY saved_at DESC LIMIT 1");
            ps.setInt(1,jobId); ps.setString(2,srcType); ps.setString(3,qcUser);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                String notes  = nvlJs(rs.getString("inspector_notes"));
                String sev    = nvlJs(rs.getString("severity"));
                String rem    = nvlJs(rs.getString("qc_remarks"));
                String comp   = nvl(rs.getString("compliance_checks"));
                String defs   = nvl(rs.getString("defect_categories"));
                String verd   = safeJson(rs.getString("qc_verdicts"));
                String prems  = safeJson(rs.getString("part_remarks"));
                String meas   = safeJson(rs.getString("measurements"));
                int    pct    = rs.getInt("progress_pct");
                String qdocs  = ""; try{ qdocs=nvlJs(rs.getString("qc_doc_files")); }catch(Exception ig){}
                out.print("{\"success\":true,\"draft\":{" +
                    "\"inspector_notes\":\""+notes+"\"," +
                    "\"severity\":\""+sev+"\"," +
                    "\"remarks\":\""+rem+"\"," +
                    "\"compliance\":\""+comp+"\"," +
                    "\"defects\":\""+defs+"\"," +
                    "\"qc_verdicts\":"+verd+"," +
                    "\"part_remarks\":"+prems+"," +
                    "\"measurements\":"+meas+"," +
                    "\"qc_doc_files\":\""+qdocs+"\"," +
                    "\"progress_pct\":"+pct+"}}");
            } else {
                out.print("{\"success\":true,\"draft\":null}");
            }
        } catch (Exception e) {
            out.print("{\"success\":true,\"draft\":null}");
        }
        return;
    }

    /* ══ SAVE ══ */
    request.setCharacterEncoding("UTF-8");
    StringBuilder sb = new StringBuilder();
    try { BufferedReader br=request.getReader(); String ln;
          while((ln=br.readLine())!=null) sb.append(ln); }
    catch(Exception e){ out.print("{\"error\":\"read failed\"}"); return; }
    String b = sb.toString().trim();
    if(b.isEmpty()){ out.print("{\"error\":\"empty body\"}"); return; }

    /* Extract string fields */
    String jobIdStr    = getStr(b,"jobId");
    String srcType     = getStr(b,"srcType");
    String notes       = getStr(b,"inspector_notes");
    String severity    = getStr(b,"severity");
    String remarks     = getStr(b,"remarks");
    String compliance  = getStr(b,"compliance");
    String defects     = getStr(b,"defects");
    String progressStr = getStr(b,"progress_pct");
    /* Extract JSON object fields */
    String qcVerdicts  = getObj(b,"qcVerdicts");
    String partRemarks = getObj(b,"partRemarks");
    String measurements= getObj(b,"measurements");

    if(jobIdStr==null||jobIdStr.isEmpty()){
        out.print("{\"success\":false,\"error\":\"missing jobId\"}"); return;
    }
    int jobId=0;
    try{ jobId=Integer.parseInt(jobIdStr.trim()); }
    catch(Exception e){ out.print("{\"success\":false,\"error\":\"bad jobId\"}"); return; }
    int pct=0;
    try{ pct=Integer.parseInt(progressStr.trim()); }catch(Exception e){}

    try(Connection conn=DBConnection.getConnection()){
        /* Create table if needed */
        try{ conn.createStatement().executeUpdate(
            "CREATE TABLE IF NOT EXISTS qc_drafts(" +
            "id INT AUTO_INCREMENT PRIMARY KEY," +
            "job_ref_id INT NOT NULL," +
            "source_type VARCHAR(30) NOT NULL," +
            "qc_user VARCHAR(100) NOT NULL," +
            "inspector_notes TEXT," +
            "severity VARCHAR(20) DEFAULT 'None'," +
            "qc_remarks VARCHAR(300)," +
            "compliance_checks VARCHAR(300)," +
            "defect_categories VARCHAR(300)," +
            "qc_verdicts MEDIUMTEXT," +
            "part_remarks MEDIUMTEXT," +
            "measurements TEXT," +
            "progress_pct INT DEFAULT 0," +
            "saved_at DATETIME DEFAULT NOW()," +
            "UNIQUE KEY uq(job_ref_id,source_type,qc_user)" +
            ")ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
        }catch(Exception ig){
            /* Add missing columns to existing table */
            String[] cols={"qc_remarks VARCHAR(300)","part_remarks MEDIUMTEXT","measurements TEXT"};
            for(String col:cols){
                try{ conn.createStatement().executeUpdate("ALTER TABLE qc_drafts ADD COLUMN "+col); }
                catch(Exception ig2){}
            }
        }

        PreparedStatement ps=conn.prepareStatement(
            "INSERT INTO qc_drafts" +
            "(job_ref_id,source_type,qc_user,inspector_notes,severity,qc_remarks," +
            "compliance_checks,defect_categories,qc_verdicts,part_remarks,measurements,progress_pct,saved_at)" +
            "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,NOW())" +
            "ON DUPLICATE KEY UPDATE " +
            "inspector_notes=VALUES(inspector_notes),severity=VALUES(severity)," +
            "qc_remarks=VALUES(qc_remarks),compliance_checks=VALUES(compliance_checks)," +
            "defect_categories=VALUES(defect_categories),qc_verdicts=VALUES(qc_verdicts)," +
            "part_remarks=VALUES(part_remarks),measurements=VALUES(measurements)," +
            "progress_pct=VALUES(progress_pct),saved_at=NOW()");

        ps.setInt(1,jobId);
        ps.setString(2,  nvl(srcType,"internal"));
        ps.setString(3,  qcUser);
        ps.setString(4,  nvl(notes,""));
        ps.setString(5,  nvl(severity,"None"));
        ps.setString(6,  nvl(remarks,""));
        ps.setString(7,  nvl(compliance,""));
        ps.setString(8,  nvl(defects,""));
        ps.setString(9,  nvl(qcVerdicts,"{}"));
        ps.setString(10, nvl(partRemarks,"{}"));
        ps.setString(11, nvl(measurements,"{}"));
        ps.setInt(12,pct);
        ps.executeUpdate();

        out.print("{\"success\":true,\"progress\":"+pct+"}");
    }catch(Exception e){
        String msg=e.getMessage()!=null?e.getMessage().replace("\"","'"):"db error";
        out.print("{\"success\":false,\"error\":\""+msg+"\"}");
    }
%><%!
private String nvl(String s,String d){ return(s!=null&&!s.trim().isEmpty())?s:d; }
private String nvl(String s){ return s!=null?s:""; }
private String nvlJs(String s){
    if(s==null) return "";
    return s.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","").replace("\t","\\t");
}
private String safeJson(String s){
    if(s==null||s.trim().isEmpty()) return "{}";
    String t=s.trim();
    if((t.startsWith("{")&&t.endsWith("}"))||(t.startsWith("[")&&t.endsWith("]"))) return t;
    return "{}";
}
/* Extract a simple string value from JSON */
private String getStr(String b,String key){
    String pat="\""+key+"\":";
    int i=b.indexOf(pat); if(i<0) return "";
    int s=i+pat.length();
    while(s<b.length()&&b.charAt(s)==' ') s++;
    if(s>=b.length()) return "";
    if(b.charAt(s)=='"'){
        int e=s+1;
        while(e<b.length()){
            if(b.charAt(e)=='"'&&b.charAt(e-1)!='\\') break;
            e++;
        }
        return b.substring(s+1,e)
                .replace("\\n","\n").replace("\\\"","\"")
                .replace("\\\\","\\").replace("\\t","\t");
    }
    int e=s;
    while(e<b.length()&&b.charAt(e)!=','&&b.charAt(e)!='}') e++;
    return b.substring(s,e).trim().replace("\"","");
}
/* Extract a JSON object/array value from JSON */
private String getObj(String b,String key){
    String pat="\""+key+"\":";
    int i=b.indexOf(pat); if(i<0) return "{}";
    int s=i+pat.length();
    while(s<b.length()&&b.charAt(s)==' ') s++;
    if(s>=b.length()) return "{}";
    char first=b.charAt(s);
    if(first!='{'&&first!='[') return "{}";
    char open=first, close=(first=='{')?'}':']';
    int depth=0, e=s;
    while(e<b.length()){
        char c=b.charAt(e);
        if(c==open) depth++;
        else if(c==close){ depth--; if(depth==0){e++;break;} }
        e++;
    }
    return b.substring(s,e);
}
%>
