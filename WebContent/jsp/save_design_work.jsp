<%@ page contentType="application/json;charset=UTF-8" language="java"
         import="java.sql.*,java.io.*,javax.servlet.http.*,com.automobile.db.DBConnection" %>
<%
    response.setContentType("application/json");
    response.setCharacterEncoding("UTF-8");
    out.clear();

    /* ── Auth ── */
    HttpSession sess=request.getSession(false);
    if(sess==null||sess.getAttribute("username")==null){
        out.print("{\"error\":\"Unauthorized\"}"); return;
    }
    String role=(String)sess.getAttribute("role");
    String user=(String)sess.getAttribute("username");
    if(!"design".equals(role)&&!"admin".equals(role)){
        out.print("{\"error\":\"Access denied\"}"); return;
    }

    /* ── Detect multipart vs JSON ── */
    boolean isMultipart = request.getContentType()!=null && request.getContentType().startsWith("multipart/");

    /* ── Read JSON body (only for non-multipart) ── */
    String b = "";
    if(!isMultipart){
        request.setCharacterEncoding("UTF-8");
        StringBuilder body=new StringBuilder();
        try{ BufferedReader br=request.getReader(); String ln; while((ln=br.readLine())!=null) body.append(ln); }
        catch(Exception e){ out.print("{\"error\":\"Cannot read body\"}"); return; }
        b=body.toString().trim();
        if(b.isEmpty()){ out.print("{\"error\":\"Empty body\"}"); return; }
    }

    /* ── Parse fields — inline helper avoids lambda compatibility issues ── */
    String actionType,reqIdStr,sourceType,designTitle,designStatus,remarks,version,
           estDate,subCat,overview,progressPct,engineType,displacement,cylinders,
           maxPower,maxTorque,transmission,lengthMM,widthMM,heightMM,wheelbase,
           kerbWeight,capacity,partNames,partStatuses,featNames,featChecked;

    if(isMultipart){
        actionType   =nvlP(request.getParameter("actionType"));
        reqIdStr     =nvlP(request.getParameter("reqId"));
        sourceType   =nvlP(request.getParameter("sourceType"));
        designTitle  =nvlP(request.getParameter("designTitle"));
        designStatus =nvlP(request.getParameter("designStatus"));
        remarks      =nvlP(request.getParameter("remarks"));
        version      =nvlP(request.getParameter("version"));
        estDate      =nvlP(request.getParameter("estDate"));
        subCat       =nvlP(request.getParameter("subCategory"));
        overview     =nvlP(request.getParameter("overviewNotes"));
        progressPct  =nvlP(request.getParameter("progressPct"));
        engineType   =nvlP(request.getParameter("engineType"));
        displacement =nvlP(request.getParameter("displacement"));
        cylinders    =nvlP(request.getParameter("cylinders"));
        maxPower     =nvlP(request.getParameter("maxPower"));
        maxTorque    =nvlP(request.getParameter("maxTorque"));
        transmission =nvlP(request.getParameter("transmission"));
        lengthMM     =nvlP(request.getParameter("lengthMM"));
        widthMM      =nvlP(request.getParameter("widthMM"));
        heightMM     =nvlP(request.getParameter("heightMM"));
        wheelbase    =nvlP(request.getParameter("wheelbase"));
        kerbWeight   =nvlP(request.getParameter("kerbWeight"));
        capacity     =nvlP(request.getParameter("capacity"));
        partNames    =nvlP(request.getParameter("partNames"));
        partStatuses =nvlP(request.getParameter("partStatuses"));
        featNames    =nvlP(request.getParameter("featNames"));
        featChecked  =nvlP(request.getParameter("featChecked"));
    } else {
        actionType   =gf(b,"actionType");
        reqIdStr     =gf(b,"reqId");
        sourceType   =gf(b,"sourceType");
        designTitle  =gf(b,"designTitle");
        designStatus =gf(b,"designStatus");
        remarks      =gf(b,"remarks");
        version      =gf(b,"version");
        estDate      =gf(b,"estDate");
        subCat       =gf(b,"subCategory");
        overview     =gf(b,"overviewNotes");
        progressPct  =gf(b,"progressPct");
        engineType   =gf(b,"engineType");
        displacement =gf(b,"displacement");
        cylinders    =gf(b,"cylinders");
        maxPower     =gf(b,"maxPower");
        maxTorque    =gf(b,"maxTorque");
        transmission =gf(b,"transmission");
        lengthMM     =gf(b,"lengthMM");
        widthMM      =gf(b,"widthMM");
        heightMM     =gf(b,"heightMM");
        wheelbase    =gf(b,"wheelbase");
        kerbWeight   =gf(b,"kerbWeight");
        capacity     =gf(b,"capacity");
        partNames    =gf(b,"partNames");
        partStatuses =gf(b,"partStatuses");
        featNames    =gf(b,"featNames");
        featChecked  =gf(b,"featChecked");
    }
    if(sourceType==null||sourceType.isEmpty()) sourceType="cr";

    /* ── Handle file uploads (multipart only) ── */
    String blueprintFile="", model3dFile="", extraFiles="";
    if(isMultipart){
        try{
            String uploadPath=getServletContext().getRealPath("uploads/design");
            File uploadDir=new File(uploadPath);
            if(!uploadDir.exists()) uploadDir.mkdirs();
            long ts=System.currentTimeMillis();

            Part bp=request.getPart("blueprintFile");
            if(bp!=null&&bp.getSize()>0){
                String orig=bp.getSubmittedFileName();
                String ext=orig.contains(".")?orig.substring(orig.lastIndexOf(".")):"";
                blueprintFile="design_bp_"+ts+ext;
                try(InputStream is=bp.getInputStream();
                    FileOutputStream fos=new FileOutputStream(new File(uploadDir,blueprintFile))){
                    byte[] buf=new byte[8192]; int n;
                    while((n=is.read(buf))>0) fos.write(buf,0,n);
                }
            }
            Part td=request.getPart("model3dFile");
            if(td!=null&&td.getSize()>0){
                String orig=td.getSubmittedFileName();
                String ext=orig.contains(".")?orig.substring(orig.lastIndexOf(".")):"";
                model3dFile="design_3d_"+ts+ext;
                try(InputStream is=td.getInputStream();
                    FileOutputStream fos=new FileOutputStream(new File(uploadDir,model3dFile))){
                    byte[] buf=new byte[8192]; int n;
                    while((n=is.read(buf))>0) fos.write(buf,0,n);
                }
            }
            java.util.Collection<Part> extraParts=request.getParts();
            StringBuilder extSb=new StringBuilder();
            for(Part ep:extraParts){
                if("extraFiles".equals(ep.getName())&&ep.getSize()>0){
                    String orig=ep.getSubmittedFileName();
                    String ext=orig.contains(".")?orig.substring(orig.lastIndexOf(".")):"";
                    String fname="design_ex_"+ts+"_"+Math.abs(orig.hashCode())+ext;
                    try(InputStream is=ep.getInputStream();
                        FileOutputStream fos=new FileOutputStream(new File(uploadDir,fname))){
                        byte[] buf=new byte[8192]; int n;
                        while((n=is.read(buf))>0) fos.write(buf,0,n);
                    }
                    if(extSb.length()>0) extSb.append(",");
                    extSb.append(fname+"|"+orig);
                }
            }
            extraFiles=extSb.toString();
        }catch(Exception fex){ /* file upload optional */ }
    }

    /* rebuild JSON arrays */
    String partsJson=buildPartsJson(partNames,partStatuses);
    String featsJson=buildFeatsJson(featNames,featChecked);

    /* ── Validate ── */
    if(reqIdStr==null||reqIdStr.trim().isEmpty()){
        out.print("{\"error\":\"Missing job ID\"}"); return;
    }
    int reqId;
    try{ reqId=Integer.parseInt(reqIdStr.trim()); }
    catch(Exception e){ out.print("{\"error\":\"Invalid ID: "+reqIdStr+"\"}"); return; }

    boolean isQC="submit_qc".equals(actionType);
    int pct=0; try{ pct=Integer.parseInt(progressPct.trim()); }catch(Exception ig){}

    if(isQC){
        if(remarks==null||remarks.trim().length()<5){
            out.print("{\"error\":\"Designer Remarks required\"}"); return;
        }
        if(pct<100){
            out.print("{\"error\":\"Parts checklist must be 100% complete. Current: "+pct+"%\"}"); return;
        }
    }

    try(Connection conn=DBConnection.getConnection()){

        /* ── Create table ── */
        try{
            conn.createStatement().execute(
                "CREATE TABLE IF NOT EXISTS design_submissions("+
                "id INT AUTO_INCREMENT PRIMARY KEY,"+
                "job_ref_id INT NOT NULL,"+
                "source_type VARCHAR(30) DEFAULT 'cr',"+
                "designer_username VARCHAR(100) NOT NULL,"+
                "design_title VARCHAR(200),"+
                "design_status VARCHAR(80),"+
                "designer_remarks TEXT,"+
                "design_version VARCHAR(20),"+
                "est_date VARCHAR(30),"+
                "sub_category VARCHAR(100),"+
                "overview_notes TEXT,"+
                "engine_type VARCHAR(100),"+
                "displacement VARCHAR(50),"+"cylinders VARCHAR(30),"+
                "max_power VARCHAR(80),"+
                "max_torque VARCHAR(80),"+
                "transmission VARCHAR(80),"+
                "length_mm VARCHAR(20),"+
                "width_mm VARCHAR(20),"+
                "height_mm VARCHAR(20),"+
                "wheelbase_mm VARCHAR(20),"+
                "kerb_weight_kg VARCHAR(20),"+
                "capacity VARCHAR(20),"+
                "parts_checklist MEDIUMTEXT,"+
                "features_checked TEXT,"+
                "progress_pct INT DEFAULT 0,"+
                "is_submitted TINYINT(1) DEFAULT 0,"+
                "submitted_at TIMESTAMP NULL,"+
                "last_saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,"+
                "UNIQUE KEY uq_job(job_ref_id,source_type,designer_username))");
        }catch(Exception ce){}

        /* ── Add cylinders column if missing (ALTER for existing tables) ── */
        try{
            conn.createStatement().execute(
                "ALTER TABLE design_submissions ADD COLUMN IF NOT EXISTS cylinders VARCHAR(30)");
        }catch(Exception ce2){
            try{ conn.createStatement().execute(
                "ALTER TABLE design_submissions ADD COLUMN cylinders VARCHAR(30)");
            }catch(Exception ce3){}
        }
        /* ── Add file columns if missing ── */
        String[] fileCols={"blueprint_file VARCHAR(300)","model_3d_file VARCHAR(300)","extra_files TEXT"};
        for(String fc:fileCols){
            try{ conn.createStatement().execute("ALTER TABLE design_submissions ADD COLUMN IF NOT EXISTS "+fc); }
            catch(Exception ce4){
                try{ conn.createStatement().execute("ALTER TABLE design_submissions ADD COLUMN "+fc); }
                catch(Exception ce5){}
            }
        }

        /* ── UPSERT ── */
        PreparedStatement ps=conn.prepareStatement(
            "INSERT INTO design_submissions"+
            "(job_ref_id,source_type,designer_username,design_title,design_status,designer_remarks,"+
            "design_version,est_date,sub_category,overview_notes,engine_type,displacement,cylinders,"+
            "max_power,max_torque,transmission,length_mm,width_mm,height_mm,wheelbase_mm,"+
            "kerb_weight_kg,capacity,parts_checklist,features_checked,progress_pct,is_submitted,submitted_at,"+
            "blueprint_file,model_3d_file,extra_files)"+
            " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)"+
            " ON DUPLICATE KEY UPDATE"+
            " design_title=VALUES(design_title),design_status=VALUES(design_status),"+
            " designer_remarks=VALUES(designer_remarks),design_version=VALUES(design_version),"+
            " est_date=VALUES(est_date),sub_category=VALUES(sub_category),"+
            " overview_notes=VALUES(overview_notes),engine_type=VALUES(engine_type),"+
            " displacement=VALUES(displacement),cylinders=VALUES(cylinders),max_power=VALUES(max_power),"+
            " max_torque=VALUES(max_torque),transmission=VALUES(transmission),"+
            " length_mm=VALUES(length_mm),width_mm=VALUES(width_mm),height_mm=VALUES(height_mm),"+
            " wheelbase_mm=VALUES(wheelbase_mm),kerb_weight_kg=VALUES(kerb_weight_kg),"+
            " capacity=VALUES(capacity),parts_checklist=VALUES(parts_checklist),"+
            " features_checked=VALUES(features_checked),progress_pct=VALUES(progress_pct),"+
            " is_submitted=VALUES(is_submitted),submitted_at=VALUES(submitted_at),"+
            " blueprint_file=IF(VALUES(blueprint_file)='',blueprint_file,VALUES(blueprint_file)),"+
            " model_3d_file=IF(VALUES(model_3d_file)='',model_3d_file,VALUES(model_3d_file)),"+
            " extra_files=IF(VALUES(extra_files)='',extra_files,VALUES(extra_files))");

        int i=1;
        ps.setInt(i++,reqId);
        ps.setString(i++,sourceType);
        ps.setString(i++,user);
        ps.setString(i++,designTitle);   ps.setString(i++,designStatus);
        ps.setString(i++,remarks);       ps.setString(i++,version);
        ps.setString(i++,estDate);       ps.setString(i++,subCat);
        ps.setString(i++,overview);      ps.setString(i++,engineType);
        ps.setString(i++,displacement);  ps.setString(i++,cylinders);
        ps.setString(i++,maxPower);      ps.setString(i++,maxTorque);
        ps.setString(i++,transmission);
        ps.setString(i++,lengthMM);      ps.setString(i++,widthMM);
        ps.setString(i++,heightMM);      ps.setString(i++,wheelbase);
        ps.setString(i++,kerbWeight);    ps.setString(i++,capacity);
        ps.setString(i++,partsJson);     ps.setString(i++,featsJson);
        ps.setInt(i++,pct);
        ps.setInt(i++,isQC?1:0);
        if(isQC) ps.setTimestamp(i++,new java.sql.Timestamp(System.currentTimeMillis()));
        else     ps.setNull(i++,java.sql.Types.TIMESTAMP);
        ps.setString(i++,blueprintFile);
        ps.setString(i++,model3dFile);
        ps.setString(i++,extraFiles);
        ps.executeUpdate();

        /* ── Advance workflow on QC submit — with round-robin QC user assignment ── */
        if(isQC){
            // Step 1: Get vehicle_type for this job to find the right QC pool
            String jobVehicleType = null;
            try{
                String vtSql;
                if("internal_job".equals(sourceType))
                    vtSql="SELECT vehicle_type FROM internal_jobs WHERE id=?";
                else if("external_order".equals(sourceType))
                    vtSql="SELECT vehicle_type FROM external_orders WHERE id=?";
                else
                    vtSql="SELECT vehicle_type FROM customer_requirements WHERE id=?";
                PreparedStatement vtPs=conn.prepareStatement(vtSql);
                vtPs.setInt(1,reqId);
                ResultSet vtRs=vtPs.executeQuery();
                if(vtRs.next()) jobVehicleType=vtRs.getString("vehicle_type");
            }catch(Exception ig){}

            // Step 2: Round-robin — find next QC member for this vehicle_type pool
            String assignedQcUser = "qc"; // fallback to role if no specific user found
            if(jobVehicleType!=null && !jobVehicleType.isEmpty()){
                try{
                    // Lock and get current round-robin position
                    conn.setAutoCommit(false);
                    PreparedStatement rrLock=conn.prepareStatement(
                        "SELECT last_slot_used,total_assigned FROM module_round_robin " +
                        "WHERE module_role='qc' AND vehicle_type=? FOR UPDATE");
                    rrLock.setString(1,jobVehicleType);
                    ResultSet rrRs=rrLock.executeQuery();
                    int lastSlot=0, totalAsgn=0;
                    boolean rrRowExists=false;
                    if(rrRs.next()){ lastSlot=rrRs.getInt("last_slot_used"); totalAsgn=rrRs.getInt("total_assigned"); rrRowExists=true; }

                    // Count active QC members in this pool
                    PreparedStatement cntPs=conn.prepareStatement(
                        "SELECT COUNT(*) FROM module_team_members WHERE module_role='qc' AND vehicle_type=? AND is_active=1");
                    cntPs.setString(1,jobVehicleType);
                    ResultSet cntRs=cntPs.executeQuery();
                    int poolSize=cntRs.next()?cntRs.getInt(1):0;

                    if(poolSize>0){
                        // Calculate next slot (1-based, cycles)
                        int nextSlot=(lastSlot%poolSize)+1;
                        // Get the QC user at that slot
                        PreparedStatement memPs=conn.prepareStatement(
                            "SELECT username FROM module_team_members " +
                            "WHERE module_role='qc' AND vehicle_type=? AND is_active=1 " +
                            "ORDER BY slot_number LIMIT 1 OFFSET ?");
                        memPs.setString(1,jobVehicleType);
                        memPs.setInt(2,nextSlot-1);
                        ResultSet memRs=memPs.executeQuery();
                        if(memRs.next()) assignedQcUser=memRs.getString("username");

                        // Update round-robin counter
                        if(rrRowExists){
                            PreparedStatement rrUpd=conn.prepareStatement(
                                "UPDATE module_round_robin SET last_slot_used=?,total_assigned=total_assigned+1 " +
                                "WHERE module_role='qc' AND vehicle_type=?");
                            rrUpd.setInt(1,nextSlot); rrUpd.setString(2,jobVehicleType);
                            rrUpd.executeUpdate();
                        }else{
                            PreparedStatement rrIns=conn.prepareStatement(
                                "INSERT INTO module_round_robin (module_role,vehicle_type,last_slot_used,total_assigned) VALUES ('qc',?,?,1)");
                            rrIns.setString(1,jobVehicleType); rrIns.setInt(2,nextSlot);
                            rrIns.executeUpdate();
                        }
                    }
                    conn.commit();
                    conn.setAutoCommit(true);
                }catch(Exception rrEx){ try{conn.rollback();conn.setAutoCommit(true);}catch(Exception ig){} }
            }

            // Step 3: Update workflow stage with specific assigned QC user
            String wfSql;
            if("internal_job".equals(sourceType))
                wfSql="UPDATE internal_jobs SET workflow_stage='design_completed',current_assignee=? WHERE id=?";
            else if("external_order".equals(sourceType))
                wfSql="UPDATE external_orders SET workflow_stage='design_completed',current_assignee=? WHERE id=?";
            else
                wfSql="UPDATE customer_requirements SET workflow_stage='design_completed',current_assignee=? WHERE id=?";
            try{
                PreparedStatement wf=conn.prepareStatement(wfSql);
                wf.setString(1,assignedQcUser); wf.setInt(2,reqId); wf.executeUpdate();
            }catch(Exception ig){}

            // Step 4: Log to workflow_history
            try{
                PreparedStatement hist=conn.prepareStatement(
                    "INSERT INTO workflow_history(requirement_id,stage,action,remarks,actioned_by)"+
                    " VALUES(?,'design_completed','Design Submitted to QC — Assigned to @"+assignedQcUser+"',?,?)");
                hist.setInt(1,reqId);
                hist.setString(2,remarks.length()>200?remarks.substring(0,200):remarks);
                hist.setString(3,user);
                hist.executeUpdate();
            }catch(Exception ig){}

            // Step 5: Also log to unified_workflow_history
            try{
                String uSrcType="internal_job".equals(sourceType)?"internal":"external_order".equals(sourceType)?"external":"cr";
                PreparedStatement uhist=conn.prepareStatement(
                    "INSERT INTO unified_workflow_history(source_type,source_id,stage,action,remarks,actioned_by)"+
                    " VALUES(?,?,'design_completed','submitted_to_qc',?,?)");
                uhist.setString(1,uSrcType); uhist.setInt(2,reqId);
                uhist.setString(3,"Assigned to @"+assignedQcUser);
                uhist.setString(4,user); uhist.executeUpdate();
            }catch(Exception ig){}
        }

        out.print("{\"success\":true,\"action\":\""+(isQC?"submitted_to_qc":"saved_draft")
            +"\",\"message\":\""+(isQC?"Design submitted to QC successfully!":"Draft saved!")
            +"\",\"progress\":"+pct+"}");

    }catch(SQLException e){
        String em=e.getMessage();
        if(em==null) em="Unknown DB error";
        em=em.replace("\"","'").replace("\n"," ").replace("\r","");
        if(em.length()>200) em=em.substring(0,200);
        out.print("{\"error\":\"DB error: "+em+"\"}");
    }
%>
<%!
private String gf(String json, String key){
    if(json==null||json.isEmpty()) return "";
    String search="\""+key+"\":\"";
    int idx=json.indexOf(search);
    if(idx<0) return "";
    int start=idx+search.length();
    StringBuilder sb=new StringBuilder();
    int pos=start;
    while(pos<json.length()){
        char c=json.charAt(pos);
        if(c=='\\'&&pos+1<json.length()){
            char nx=json.charAt(pos+1);
            if(nx=='"'){sb.append('"');pos+=2;continue;}
            if(nx=='n'){sb.append('\n');pos+=2;continue;}
            if(nx=='\\'){sb.append('\\');pos+=2;continue;}
            if(nx=='r'||nx=='t'){pos+=2;continue;}
        }
        if(c=='"') break;
        sb.append(c); pos++;
    }
    return sb.toString().trim();
}

private String nvlP(String s){ return s!=null?s:""; }

private String buildPartsJson(String names, String statuses){
    if(names==null||names.trim().isEmpty()) return "[]";
    String[] ns=names.split("\\|\\|",-1);
    String[] ss=statuses!=null?statuses.split("\\|\\|",-1):new String[0];
    StringBuilder sb=new StringBuilder("[");
    for(int i=0;i<ns.length;i++){
        if(i>0) sb.append(",");
        String st=(i<ss.length&&!ss[i].isEmpty())?ss[i]:"Not Started";
        sb.append("{\"name\":\"").append(esc(ns[i]))
          .append("\",\"status\":\"").append(esc(st)).append("\"}");
    }
    return sb.append("]").toString();
}

private String buildFeatsJson(String names, String checked){
    if(names==null||names.trim().isEmpty()) return "[]";
    String[] ns=names.split("\\|\\|",-1);
    String[] cs=checked!=null?checked.split("\\|\\|",-1):new String[0];
    StringBuilder sb=new StringBuilder("[");
    for(int i=0;i<ns.length;i++){
        if(i>0) sb.append(",");
        boolean chk=(i<cs.length)&&"1".equals(cs[i].trim());
        sb.append("{\"name\":\"").append(esc(ns[i]))
          .append("\",\"checked\":").append(chk).append("}");
    }
    return sb.append("]").toString();
}

private String esc(String s){
    if(s==null) return "";
    return s.replace("\\","\\\\").replace("\"","'").replace("\n"," ").replace("\r","").trim();
}
%>
