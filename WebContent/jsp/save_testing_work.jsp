<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,java.io.*,javax.servlet.http.*,com.automobile.db.DBConnection" %>
<%
    HttpSession sess=request.getSession(false);
    if(sess==null||sess.getAttribute("username")==null){ response.sendRedirect("../index.jsp"); return; }
    String role    =(String)sess.getAttribute("role");
    String tstUser =(String)sess.getAttribute("username");
    if(!"testing".equals(role)&&!"admin".equals(role)){ response.sendRedirect("../dashboard.jsp"); return; }

    String ctx=request.getContextPath();

    String jobIdStr     =request.getParameter("jobId");
    String srcType      =request.getParameter("srcType");
    String action       =request.getParameter("action");
    String notes        =request.getParameter("tester_notes");
    String overallResult=request.getParameter("overall_result");
    String overallScore =request.getParameter("overall_score");
    String testsJson    =request.getParameter("testsJson");

    // Multipart fallback
    if (notes == null || jobIdStr == null) {
        try {
            for (javax.servlet.http.Part part : request.getParts()) {
                String name = part.getName();
                java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
                byte[] buf = new byte[1024]; int n;
                while ((n = part.getInputStream().read(buf)) != -1) baos.write(buf, 0, n);
                String val = baos.toString("UTF-8").trim();
                if      ("jobId".equals(name)          && jobIdStr == null)      jobIdStr = val;
                else if ("srcType".equals(name)         && srcType == null)       srcType = val;
                else if ("action".equals(name)          && action == null)        action = val;
                else if ("tester_notes".equals(name)    && notes == null)         notes = val;
                else if ("overall_result".equals(name)  && overallResult == null) overallResult = val;
                else if ("overall_score".equals(name)   && overallScore == null)  overallScore = val;
                else if ("testsJson".equals(name)       && testsJson == null)     testsJson = val;
            }
        } catch (Exception pe) {
            response.sendRedirect(ctx+"/testing?error="+
                java.net.URLEncoder.encode("Multipart error: "+pe.getMessage(),"UTF-8"));
            return;
        }
    }

    if(jobIdStr==null||srcType==null||action==null||notes==null||notes.trim().isEmpty()){
        request.setAttribute("error","Required fields missing.");
        request.getRequestDispatcher("/jsp/testing_module.jsp?reqId="+jobIdStr+"&src="+srcType).forward(request,response);
        return;
    }
    int jobId=0;
    try{ jobId=Integer.parseInt(jobIdStr.trim()); }
    catch(Exception e){ response.sendRedirect(ctx+"/testing"); return; }

    /* Photo upload */
    String photoName=null;
    try{
        Part photoPart=request.getPart("testPhoto");
        if(photoPart!=null&&photoPart.getSize()>0){
            String orig=photoPart.getSubmittedFileName();
            if(orig!=null&&!orig.isEmpty()){
                String ext=orig.contains(".")?orig.substring(orig.lastIndexOf('.')):".jpg";
                photoName="test_"+jobId+"_"+srcType+"_"+System.currentTimeMillis()+ext;
                String uploadPath=getServletContext().getRealPath("uploads/testing");
                File uploadDir=new File(uploadPath);
                if(!uploadDir.exists()) uploadDir.mkdirs();
                try(InputStream is=photoPart.getInputStream();
                    FileOutputStream fos=new FileOutputStream(new File(uploadDir,photoName))){
                    byte[] buf=new byte[4096]; int n;
                    while((n=is.read(buf))!=-1) fos.write(buf,0,n);
                }
            }
        }
    }catch(Exception pe){}

    /* Determine next stage */
    String newStage,newAssignee;
    if("testing_passed".equals(action)||"testing_conditional".equals(action)){
        newStage="testing_completed"; newAssignee="analytics"; // fallback if pool empty
    } else {
        newStage="testing_failed"; newAssignee="qc";
    }

    /*
     * STREAM-BASED ROUND-ROBIN ANALYTICS ASSIGNMENT
     * -----------------------------------------------
     * Old: looked up analytics pool by vehicle_type (car/bus/bike/truck)
     * New: looks up analytics pool by JOB STREAM:
     *        srcType = "internal"           → analyticsPool = "internal"
     *        srcType = "external" or "cr"   → analyticsPool = "external"
     *
     * Admin creates analytics users with stream tag stored in vehicle_type column:
     *   vehicle_type = "internal"  → handles internal jobs only
     *   vehicle_type = "external"  → handles external + customer requirement jobs only
     */
    if(!"testing_failed".equals(action)){
        try(Connection conn=DBConnection.getConnection()){

            String analyticsPool = "internal".equals(srcType) ? "internal" : "external";

            PreparedStatement poolPs=conn.prepareStatement(
                "SELECT COUNT(*) FROM module_team_members " +
                "WHERE module_role='analytics' AND vehicle_type=? AND is_active=1");
            poolPs.setString(1, analyticsPool);
            ResultSet poolRs=poolPs.executeQuery();
            int poolSize=poolRs.next()?poolRs.getInt(1):0;

            if(poolSize>0){
                conn.setAutoCommit(false);
                try{
                    PreparedStatement rrPs=conn.prepareStatement(
                        "SELECT last_slot_used FROM module_round_robin " +
                        "WHERE module_role='analytics' AND vehicle_type=? FOR UPDATE");
                    rrPs.setString(1, analyticsPool);
                    ResultSet rrRs=rrPs.executeQuery();
                    int lastSlot=rrRs.next()?rrRs.getInt(1):0;
                    int nextSlot=(lastSlot%poolSize)+1;

                    PreparedStatement tPs=conn.prepareStatement(
                        "SELECT username FROM module_team_members " +
                        "WHERE module_role='analytics' AND vehicle_type=? AND slot_number=? AND is_active=1 LIMIT 1");
                    tPs.setString(1, analyticsPool); tPs.setInt(2, nextSlot);
                    ResultSet tRs=tPs.executeQuery();
                    if(tRs.next()){
                        newAssignee=tRs.getString("username");
                        PreparedStatement rrUpd=conn.prepareStatement(
                            "INSERT INTO module_round_robin(module_role,vehicle_type,last_slot_used,total_assigned) "+
                            "VALUES('analytics',?,?,1) ON DUPLICATE KEY UPDATE "+
                            "last_slot_used=VALUES(last_slot_used),total_assigned=total_assigned+1");
                        rrUpd.setString(1, analyticsPool); rrUpd.setInt(2, nextSlot);
                        rrUpd.executeUpdate();
                    }
                    conn.commit();
                }catch(Exception rrEx){
                    try{conn.rollback();}catch(Exception rb){}
                }finally{
                    conn.setAutoCommit(true);
                }
            }
            // if pool empty → newAssignee stays "analytics" as generic fallback

        }catch(Exception rrEx){}
    }

    String successMsg="";
    try(Connection conn=DBConnection.getConnection()){
        conn.setAutoCommit(false);
        try{
            String upSql;
            if("internal".equals(srcType)) upSql="UPDATE internal_jobs SET workflow_stage=?,current_assignee=? WHERE id=?";
            else if("external".equals(srcType)) upSql="UPDATE external_orders SET workflow_stage=?,current_assignee=? WHERE id=?";
            else upSql="UPDATE customer_requirements SET workflow_stage=?,current_assignee=? WHERE id=?";
            PreparedStatement upd=conn.prepareStatement(upSql);
            upd.setString(1,newStage); upd.setString(2,newAssignee); upd.setInt(3,jobId);
            upd.executeUpdate();

            PreparedStatement hist=conn.prepareStatement(
                "INSERT INTO unified_workflow_history(source_type,source_id,stage,action,remarks,actioned_by)"+
                "VALUES(?,?,'testing',?,?,?)");
            hist.setString(1,srcType); hist.setInt(2,jobId); hist.setString(3,action);
            String fullRem=(notes.trim()+"|Result:"+nvl(overallResult)+"|Score:"+nvl(overallScore));
            hist.setString(4,fullRem.substring(0,Math.min(500,fullRem.length())));
            hist.setString(5,tstUser);
            hist.executeUpdate();

            try{
                conn.createStatement().executeUpdate(
                    "CREATE TABLE IF NOT EXISTS testing_results("+
                    "id INT AUTO_INCREMENT PRIMARY KEY,"+
                    "job_ref_id INT NOT NULL,source_type VARCHAR(30),tester_user VARCHAR(100),"+
                    "action VARCHAR(50),overall_result VARCHAR(100),overall_score INT DEFAULT 0,"+
                    "tester_notes TEXT,tests_json MEDIUMTEXT,photo_path VARCHAR(300),"+
                    "tested_at DATETIME DEFAULT NOW())ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
            }catch(Exception ct){}
            try{
                PreparedStatement tr=conn.prepareStatement(
                    "INSERT INTO testing_results(job_ref_id,source_type,tester_user,action,overall_result,overall_score,tester_notes,tests_json,photo_path,tested_at)"+
                    "VALUES(?,?,?,?,?,?,?,?,?,NOW())");
                tr.setInt(1,jobId); tr.setString(2,srcType); tr.setString(3,tstUser);
                tr.setString(4,action); tr.setString(5,nvl(overallResult,""));
                int sc=0; try{sc=Integer.parseInt(nvl(overallScore,"0"));}catch(Exception ig){}
                tr.setInt(6,sc); tr.setString(7,notes.trim());
                tr.setString(8,nvl(testsJson,"[]")); tr.setString(9,photoName!=null?photoName:"");
                tr.executeUpdate();
            }catch(Exception re){}

            conn.commit();
            if("testing_passed".equals(action))      successMsg="Testing passed! Job sent to Analytics team.";
            else if("testing_failed".equals(action)) successMsg="Job marked as failed and sent back to QC team.";
            else                                     successMsg="Conditional pass recorded. Job sent to Analytics.";

        }catch(Exception dbEx){
            try{conn.rollback();}catch(Exception rb){}
            request.setAttribute("error","DB Error: "+dbEx.getMessage());
            request.getRequestDispatcher("/jsp/testing_module.jsp?reqId="+jobId+"&src="+srcType).forward(request,response);
            return;
        }
    }catch(Exception e){
        request.setAttribute("error","Connection Error: "+e.getMessage());
        request.getRequestDispatcher("/jsp/testing_module.jsp?reqId="+jobId+"&src="+srcType).forward(request,response);
        return;
    }

    response.sendRedirect(ctx+"/testing?success="+java.net.URLEncoder.encode(successMsg,"UTF-8"));
%><%!
private String nvl(String s,String d){ return(s!=null&&!s.trim().isEmpty())?s:d; }
private String nvl(String s){ return s!=null?s:""; }
%>
