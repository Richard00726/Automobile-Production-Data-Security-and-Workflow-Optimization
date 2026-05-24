<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,
                 com.automobile.util.PasswordUtil,java.util.*" %>
<%
    HttpSession sess=request.getSession(false);
    if(sess==null||sess.getAttribute("username")==null){response.sendRedirect("../../index.jsp");return;}
    if(!"admin".equals(sess.getAttribute("role"))){response.sendRedirect("../../dashboard.jsp");return;}

    String msg="",msgType="",action=request.getParameter("action");

    /* Ensure tables exist */
    try(Connection conn=DBConnection.getConnection()){
        conn.createStatement().execute(
            "CREATE TABLE IF NOT EXISTS module_team_members("+
            "id INT AUTO_INCREMENT PRIMARY KEY,"+
            "module_role VARCHAR(20) NOT NULL,"+
            "vehicle_type VARCHAR(30) NOT NULL DEFAULT 'all',"+
            "slot_number INT NOT NULL DEFAULT 1,"+
            "full_name VARCHAR(100) NOT NULL,"+
            "username VARCHAR(100) NOT NULL,"+
            "is_active TINYINT(1) DEFAULT 1,"+
            "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"+
            "UNIQUE KEY uq_slot(module_role,vehicle_type,slot_number))");
        conn.createStatement().execute(
            "CREATE TABLE IF NOT EXISTS module_round_robin("+
            "id INT AUTO_INCREMENT PRIMARY KEY,"+
            "module_role VARCHAR(20) NOT NULL,"+
            "vehicle_type VARCHAR(30) NOT NULL DEFAULT 'all',"+
            "last_slot_used INT DEFAULT 0,"+
            "total_assigned INT DEFAULT 0,"+
            "UNIQUE KEY uq_rr(module_role,vehicle_type))");
    }catch(Exception ig){}

    /* ADD — now with stream (internal/external) stored in vehicle_type column */
    if("add".equals(action)){
        String fname  = request.getParameter("full_name");
        String uname  = request.getParameter("username");
        String pwd    = request.getParameter("password");
        String stream = request.getParameter("stream"); // "internal" or "external"
        if(stream==null||(!stream.equals("internal")&&!stream.equals("external"))) stream="internal";
        if(fname!=null&&uname!=null&&pwd!=null&&!fname.isEmpty()&&!uname.isEmpty()&&!pwd.isEmpty()){
            try(Connection conn=DBConnection.getConnection()){
                PreparedStatement chk=conn.prepareStatement("SELECT COUNT(*) FROM users WHERE username=?");
                chk.setString(1,uname.trim().toLowerCase());
                ResultSet cr=chk.executeQuery(); int ex=0; if(cr.next()) ex=cr.getInt(1);
                if(ex>0){msg="Username already taken.";msgType="error";}
                else{
                    // Next slot in that specific stream pool
                    int nextSlot=1;
                    PreparedStatement sq=conn.prepareStatement(
                        "SELECT COALESCE(MAX(slot_number),0)+1 AS ns FROM module_team_members "+
                        "WHERE module_role='analytics' AND vehicle_type=?");
                    sq.setString(1,stream);
                    ResultSet sr=sq.executeQuery(); if(sr.next()) nextSlot=sr.getInt("ns");

                    String hp=PasswordUtil.hashPassword(pwd.trim());
                    PreparedStatement pu=conn.prepareStatement(
                        "INSERT INTO users(full_name,username,password,role,is_active) VALUES(?,?,?,?,1)");
                    pu.setString(1,fname.trim()); pu.setString(2,uname.trim().toLowerCase());
                    pu.setString(3,hp); pu.setString(4,"analytics");
                    pu.executeUpdate();

                    // vehicle_type stores the stream: "internal" or "external"
                    PreparedStatement pm=conn.prepareStatement(
                        "INSERT INTO module_team_members(module_role,vehicle_type,slot_number,full_name,username,is_active) "+
                        "VALUES('analytics',?,?,?,?,1)");
                    pm.setString(1,stream); pm.setInt(2,nextSlot);
                    pm.setString(3,fname.trim()); pm.setString(4,uname.trim().toLowerCase());
                    pm.executeUpdate();

                    // Ensure round-robin row exists for this stream
                    conn.prepareStatement(
                        "INSERT IGNORE INTO module_round_robin(module_role,vehicle_type,last_slot_used,total_assigned) "+
                        "VALUES('analytics','"+stream+"',0,0)").executeUpdate();

                    msg=fname.trim()+" added as "+stream.substring(0,1).toUpperCase()+stream.substring(1)
                        +" Analytics — Slot "+nextSlot;
                    msgType="success";
                }
            }catch(Exception e){msg="Error: "+e.getMessage();msgType="error";}
        }else{msg="All fields required.";msgType="error";}
    }

    /* TOGGLE */
    if("toggle".equals(action)){
        String midStr=request.getParameter("mid"); String curStr=request.getParameter("cur");
        if(midStr!=null&&curStr!=null){
            try(Connection conn=DBConnection.getConnection()){
                int mid=Integer.parseInt(midStr); int nv="1".equals(curStr)?0:1;
                PreparedStatement gu=conn.prepareStatement("SELECT username FROM module_team_members WHERE id=?");
                gu.setInt(1,mid); ResultSet ur=gu.executeQuery();
                if(ur.next()){
                    String un=ur.getString("username");
                    conn.prepareStatement("UPDATE module_team_members SET is_active="+nv+" WHERE id="+mid).executeUpdate();
                    PreparedStatement upu=conn.prepareStatement("UPDATE users SET is_active=? WHERE username=?");
                    upu.setInt(1,nv); upu.setString(2,un); upu.executeUpdate();
                }
                msg=nv==1?"Member activated.":"Member deactivated."; msgType="success";
            }catch(Exception e){msg="Error: "+e.getMessage();msgType="error";}
        }
    }

    /* DELETE */
    if("delete".equals(action)){
        String midStr=request.getParameter("mid");
        if(midStr!=null){
            try(Connection conn=DBConnection.getConnection()){
                int mid=Integer.parseInt(midStr);
                PreparedStatement gm=conn.prepareStatement(
                    "SELECT username,vehicle_type FROM module_team_members WHERE id=?");
                gm.setInt(1,mid); ResultSet dr=gm.executeQuery();
                if(dr.next()){
                    String un=dr.getString("username");
                    String st=dr.getString("vehicle_type");
                    conn.prepareStatement("DELETE FROM module_team_members WHERE id="+mid).executeUpdate();
                    // Resequence slots for that stream
                    ResultSet rem=conn.createStatement().executeQuery(
                        "SELECT id FROM module_team_members WHERE module_role='analytics' AND vehicle_type='"+st+"' ORDER BY slot_number");
                    int sn=1;
                    while(rem.next()) conn.prepareStatement(
                        "UPDATE module_team_members SET slot_number="+sn+++" WHERE id="+rem.getInt("id")).executeUpdate();
                    conn.prepareStatement(
                        "UPDATE module_round_robin SET last_slot_used=0 WHERE module_role='analytics' AND vehicle_type='"+st+"'").executeUpdate();
                    conn.prepareStatement("UPDATE users SET is_active=0 WHERE username='"+un.replace("'","''")+"'").executeUpdate();
                }
                msg="Member removed."; msgType="success";
            }catch(Exception e){msg="Error: "+e.getMessage();msgType="error";}
        }
    }

    /* Load both pools separately */
    List<Object[]> internalMembers=new ArrayList<>();
    List<Object[]> externalMembers=new ArrayList<>();
    int intLastSlot=0,intTotalAsgn=0,extLastSlot=0,extTotalAsgn=0;

    try(Connection conn=DBConnection.getConnection()){
        // Internal pool
        PreparedStatement mq=conn.prepareStatement(
            "SELECT m.id,m.slot_number,m.full_name,m.username,m.is_active,m.vehicle_type,u.last_active "+
            "FROM module_team_members m LEFT JOIN users u ON m.username=u.username "+
            "WHERE m.module_role='analytics' AND m.vehicle_type='internal' ORDER BY m.slot_number");
        ResultSet mr=mq.executeQuery();
        while(mr.next()) internalMembers.add(new Object[]{
            mr.getInt("id"),mr.getInt("slot_number"),mr.getString("full_name"),
            mr.getString("username"),mr.getInt("is_active"),mr.getTimestamp("last_active")});

        // External pool
        PreparedStatement mq2=conn.prepareStatement(
            "SELECT m.id,m.slot_number,m.full_name,m.username,m.is_active,m.vehicle_type,u.last_active "+
            "FROM module_team_members m LEFT JOIN users u ON m.username=u.username "+
            "WHERE m.module_role='analytics' AND m.vehicle_type='external' ORDER BY m.slot_number");
        ResultSet mr2=mq2.executeQuery();
        while(mr2.next()) externalMembers.add(new Object[]{
            mr2.getInt("id"),mr2.getInt("slot_number"),mr2.getString("full_name"),
            mr2.getString("username"),mr2.getInt("is_active"),mr2.getTimestamp("last_active")});

        // Round-robin counters
        ResultSet rr1=conn.createStatement().executeQuery(
            "SELECT last_slot_used,total_assigned FROM module_round_robin "+
            "WHERE module_role='analytics' AND vehicle_type='internal'");
        if(rr1.next()){intLastSlot=rr1.getInt("last_slot_used");intTotalAsgn=rr1.getInt("total_assigned");}

        ResultSet rr2=conn.createStatement().executeQuery(
            "SELECT last_slot_used,total_assigned FROM module_round_robin "+
            "WHERE module_role='analytics' AND vehicle_type='external'");
        if(rr2.next()){extLastSlot=rr2.getInt("last_slot_used");extTotalAsgn=rr2.getInt("total_assigned");}

    }catch(Exception ig){}

    int intTotal=internalMembers.size(), extTotal=externalMembers.size();
    int intNextSlot=intTotal>0?(intLastSlot%intTotal)+1:1;
    int extNextSlot=extTotal>0?(extLastSlot%extTotal)+1:1;
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Manage Analytics Team — AutoProd</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
<style>
:root{--sw:260px;--brand:#0f1f5c;--accent:#7c3aed;--bg:#f0f3f9;--border:#e5e9f2;--muted:#6b7280;
      --int:#1a237e;--int-light:#e8eaf6;--ext:#1b5e20;--ext-light:#e8f5e9;}
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:'Segoe UI',sans-serif;color:#1a1f36;}
.sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
.sb-brand{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
.sb-name{font-size:1.1rem;font-weight:800;}
.nl{display:flex;align-items:center;gap:10px;padding:10px 16px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
.nl:hover,.nl.active{color:#fff;background:rgba(255,255,255,.09);border-left-color:#7c3aed;}
.ns{padding:14px 20px 4px;font-size:.6rem;color:rgba(255,255,255,.28);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
.sf{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
.sf a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
.sf a:hover{background:rgba(255,255,255,.07);color:#fff;}
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:#fff;padding:14px 30px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100;box-shadow:0 2px 10px rgba(0,0,0,.04);}
.pb{padding:28px 30px;}
/* Stream cards */
.stream-grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:28px;}
.pool-card{background:#fff;border-radius:16px;border:2px solid var(--border);overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.04);}
.pool-card.internal{border-top:4px solid var(--int);}
.pool-card.external{border-top:4px solid var(--ext);}
.pool-header{padding:16px 20px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);}
.pool-title{font-weight:800;font-size:.95rem;display:flex;align-items:center;gap:8px;}
.pool-title.internal{color:var(--int);}
.pool-title.external{color:var(--ext);}
.pool-stats{display:flex;gap:8px;flex-wrap:wrap;padding:10px 20px;background:#fafbff;border-bottom:1px solid var(--border);}
.stat-pill{padding:3px 12px;border-radius:20px;font-size:.72rem;font-weight:700;}
.stat-pill.int{background:var(--int-light);color:var(--int);}
.stat-pill.ext{background:var(--ext-light);color:var(--ext);}
/* Table */
.dt{width:100%;border-collapse:collapse;font-size:.84rem;}
.dt th{background:#f8f9ff;padding:9px 14px;text-align:left;font-weight:700;font-size:.72rem;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;border-bottom:2px solid var(--border);}
.dt td{padding:10px 14px;border-bottom:1px solid #f0f3f9;vertical-align:middle;}
.dt tr:last-child td{border-bottom:none;}
.dt tr:hover td{background:#fafbff;}
.slot-num{border-radius:50%;width:26px;height:26px;display:inline-flex;align-items:center;justify-content:center;font-size:.72rem;font-weight:800;color:#fff;}
.slot-num.int{background:var(--int);}
.slot-num.ext{background:var(--ext);}
.next-badge{background:#ede9fe;color:#6d28d9;font-size:.62rem;font-weight:800;padding:2px 6px;border-radius:10px;margin-left:5px;}
.p{display:inline-flex;align-items:center;padding:3px 9px;border-radius:20px;font-size:.71rem;font-weight:700;}
.pg{background:#e8f5e9;color:#2e7d32;} .pgy{background:#f5f5f5;color:#757575;}
.dot{width:8px;height:8px;border-radius:50%;display:inline-block;margin-right:4px;}
.dot-g{background:#22c55e;} .dot-y{background:#f59e0b;} .dot-gr{background:#9ca3af;}
/* Buttons */
.abtn{background:linear-gradient(135deg,#1d4ed8,#3b82f6);color:#fff;border:none;border-radius:7px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;}
.tbtn-on{background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;border:none;border-radius:7px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;}
.tbtn-off{background:linear-gradient(135deg,#22c55e,#16a34a);color:#fff;border:none;border-radius:7px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;}
.dbtn{background:linear-gradient(135deg,#e53935,#c62828);color:#fff;border:none;border-radius:7px;padding:5px 10px;font-size:.72rem;font-weight:700;cursor:pointer;}
.sbtn{background:linear-gradient(135deg,#7c3aed,#6d28d9);color:#fff;border:none;border-radius:10px;padding:10px 20px;font-weight:700;font-size:.85rem;cursor:pointer;display:inline-flex;align-items:center;gap:6px;text-decoration:none;}
/* Add form */
.add-form{background:#f8faff;padding:16px 20px;border-top:2px dashed #e5e9f2;}
.add-title{font-size:.76rem;font-weight:800;text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;}
.add-title.int{color:var(--int);}
.add-title.ext{color:var(--ext);}
.add-grid{display:grid;grid-template-columns:1.4fr 1.1fr 1.1fr auto;gap:10px;align-items:end;}
.lbl{font-size:.7rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:4px;}
.ifield{width:100%;padding:8px 11px;border:1.5px solid var(--border);border-radius:8px;font-size:.86rem;outline:none;font-family:inherit;transition:border .2s;}
.ifield:focus{border-color:#7c3aed;}
.msg-s{background:#e8f5e9;border:1px solid #a5d6a7;color:#2e7d32;border-radius:10px;padding:12px 18px;margin-bottom:18px;font-weight:600;font-size:.875rem;}
.msg-e{background:#ffebee;border:1px solid #ef9a9a;color:#c62828;border-radius:10px;padding:12px 18px;margin-bottom:18px;font-weight:600;font-size:.875rem;}
.empty-row{padding:18px 20px;background:#fffde7;display:flex;align-items:center;gap:10px;}
.empty-row .ei{font-size:1.3rem;}
.empty-row .et{font-weight:700;font-size:.86rem;color:#b45309;}
.empty-row .es{font-size:.76rem;color:#92400e;margin-top:2px;}
/* Info banner */
.info-banner{background:#f5f3ff;border:1.5px solid #c4b5fd;border-radius:14px;padding:16px 20px;margin-bottom:24px;display:flex;align-items:flex-start;gap:14px;}
@media(max-width:900px){.stream-grid{grid-template-columns:1fr;}.add-grid{grid-template-columns:1fr 1fr;}}
</style>
</head>
<body>
<div class="sb">
  <div class="sb-brand">
    <div style="font-size:1.4rem;">📊</div>
    <div class="sb-name" style="margin-top:4px;">AutoProd</div>
    <div style="font-size:.68rem;color:rgba(255,255,255,.35);margin-top:2px;">ADMIN PANEL</div>
  </div>
  <div class="ns">Navigation</div>
  <a class="nl" href="admin_dashboard.jsp"><i class="bi bi-grid-1x2-fill"></i> Dashboard</a>
  <a class="nl" href="manage_designers.jsp"><i class="bi bi-pencil-ruler"></i> Design Teams</a>
  <a class="nl" href="manage_qc_team.jsp"><i class="bi bi-shield-check"></i> QC Team</a>
  <a class="nl" href="manage_testing_team.jsp"><i class="bi bi-flask-fill"></i> Testing Team</a>
  <a class="nl active" href="manage_analytics_team.jsp"><i class="bi bi-graph-up-arrow"></i> Analytics Team</a>
  <a class="nl" href="manage_users.jsp"><i class="bi bi-people"></i> Manage Users</a>
  <div class="sf"><a href="../../index.jsp"><i class="bi bi-box-arrow-left"></i> Logout</a></div>
</div>

<div class="main">
  <div class="topbar">
    <div>
      <div style="font-size:1.05rem;font-weight:800;color:#7c3aed;">
        <i class="bi bi-graph-up-arrow"></i> Manage Analytics Team
      </div>
      <div style="font-size:.72rem;color:var(--muted);margin-top:1px;">
        Two separate pools — Internal analysts handle factory jobs · External analysts handle client orders
      </div>
    </div>
    <a href="admin_dashboard.jsp" class="sbtn">
      <i class="bi bi-arrow-left"></i> Back to Dashboard
    </a>
  </div>

  <div class="pb">

    <% if(!msg.isEmpty()){ %>
    <div class="msg-<%= "success".equals(msgType)?"s":"e" %>">
      <%= "success".equals(msgType)?"✅ ":"❌ " %><%= msg %>
    </div>
    <% } %>

    <!-- Info Banner -->
    <div class="info-banner">
      <span style="font-size:1.8rem;">📊</span>
      <div>
        <div style="font-weight:800;color:#7c3aed;font-size:.95rem;margin-bottom:6px;">
          Analytics — Two Separate Streams
        </div>
        <div style="font-size:.83rem;color:#374151;line-height:1.65;">
          <strong style="color:var(--int);">Internal analysts</strong> receive jobs only when a tester submits an
          <strong>internal job</strong> (from internal_jobs table). &nbsp;
          <strong style="color:var(--ext);">External analysts</strong> receive jobs only when a tester submits an
          <strong>external order or customer requirement</strong>. Each pool has its own independent round-robin counter.
        </div>
      </div>
    </div>

    <!-- Two pool cards side by side -->
    <div class="stream-grid">

      <%-- ── INTERNAL POOL ── --%>
      <div class="pool-card internal">
        <div class="pool-header">
          <div class="pool-title internal">🏭 Internal Analytics Pool</div>
          <span style="background:var(--int-light);color:var(--int);padding:3px 12px;border-radius:20px;font-size:.73rem;font-weight:700;">
            <%= intTotal %> member<%= intTotal!=1?"s":"" %>
          </span>
        </div>
        <div class="pool-stats">
          <span class="stat-pill int">Jobs assigned: <%= intTotalAsgn %></span>
          <% if(intTotal>0){ %>
          <span class="stat-pill int">Next → Slot <%= intNextSlot %></span>
          <% } %>
        </div>

        <% if(internalMembers.isEmpty()){ %>
        <div class="empty-row">
          <span class="ei">⚠️</span>
          <div>
            <div class="et">No internal analysts yet</div>
            <div class="es">Add one below — internal jobs will have no analyst until then</div>
          </div>
        </div>
        <% } else { %>
        <table class="dt">
          <thead>
            <tr>
              <th>Slot</th><th>Name</th><th>Username</th><th>Status</th><th>Online</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
          <%
          for(Object[] d : internalMembers){
            int did=(Integer)d[0]; int slot=(Integer)d[1];
            String dname=(String)d[2]; String duname=(String)d[3]; int dact=(Integer)d[4];
            java.sql.Timestamp lastAct=(java.sql.Timestamp)d[5];
            String dotCls="dot-gr",onlineTxt="Offline";
            if(lastAct!=null){long diff=(System.currentTimeMillis()-lastAct.getTime())/60000L;if(diff<=5){dotCls="dot-g";onlineTxt="Online";}else if(diff<=30){dotCls="dot-y";onlineTxt="Away";}}
            boolean isNext=(intTotal>0&&slot==intNextSlot);
          %>
          <tr style="<%= isNext?"background:#e8eaf6;":"" %>">
            <td>
              <span class="slot-num int"><%= slot %></span>
              <% if(isNext){ %><span class="next-badge">NEXT</span><% } %>
            </td>
            <td style="font-weight:700;"><%= dname %></td>
            <td><code style="background:#f5f5f5;padding:2px 7px;border-radius:5px;font-size:.79rem;">@<%= duname %></code></td>
            <td><span class="p <%= dact==1?"pg":"pgy" %>"><%= dact==1?"Active":"Inactive" %></span></td>
            <td><span class="dot <%= dotCls %>"></span><span style="font-size:.77rem;color:var(--muted);"><%= onlineTxt %></span></td>
            <td>
              <div style="display:flex;gap:5px;">
                <form method="post" style="display:inline;">
                  <input type="hidden" name="action" value="toggle">
                  <input type="hidden" name="mid" value="<%= did %>">
                  <input type="hidden" name="cur" value="<%= dact %>">
                  <button type="submit" class="<%= dact==1?"tbtn-on":"tbtn-off" %>">
                    <%= dact==1?"Deactivate":"Activate" %>
                  </button>
                </form>
                <form method="post" style="display:inline;" onsubmit="return confirm('Remove this member?');">
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="mid" value="<%= did %>">
                  <button type="submit" class="dbtn">Remove</button>
                </form>
              </div>
            </td>
          </tr>
          <% } %>
          </tbody>
        </table>
        <% } %>

        <!-- Add Internal Member -->
        <div class="add-form">
          <div class="add-title int">+ Add Internal Analytics Member — will be Slot <%= intTotal+1 %></div>
          <form method="post">
            <input type="hidden" name="action" value="add">
            <input type="hidden" name="stream" value="internal">
            <div class="add-grid">
              <div>
                <div class="lbl">Full Name</div>
                <input type="text" name="full_name" class="ifield" placeholder="e.g. Arjun Kumar" required maxlength="100">
              </div>
              <div>
                <div class="lbl">Username</div>
                <input type="text" name="username" class="ifield" placeholder="e.g. arjun_int01" required maxlength="50" pattern="[a-zA-Z0-9_]+">
              </div>
              <div>
                <div class="lbl">Password</div>
                <input type="password" name="password" class="ifield" placeholder="Set password" required minlength="4">
              </div>
              <div>
                <button type="submit" class="sbtn" style="background:linear-gradient(135deg,#1a237e,#283593);">
                  <i class="bi bi-plus-circle"></i> Add
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>

      <%-- ── EXTERNAL POOL ── --%>
      <div class="pool-card external">
        <div class="pool-header">
          <div class="pool-title external">📦 External Analytics Pool</div>
          <span style="background:var(--ext-light);color:var(--ext);padding:3px 12px;border-radius:20px;font-size:.73rem;font-weight:700;">
            <%= extTotal %> member<%= extTotal!=1?"s":"" %>
          </span>
        </div>
        <div class="pool-stats">
          <span class="stat-pill ext">Jobs assigned: <%= extTotalAsgn %></span>
          <% if(extTotal>0){ %>
          <span class="stat-pill ext">Next → Slot <%= extNextSlot %></span>
          <% } %>
        </div>

        <% if(externalMembers.isEmpty()){ %>
        <div class="empty-row">
          <span class="ei">⚠️</span>
          <div>
            <div class="et">No external analysts yet</div>
            <div class="es">Add one below — external jobs will have no analyst until then</div>
          </div>
        </div>
        <% } else { %>
        <table class="dt">
          <thead>
            <tr>
              <th>Slot</th><th>Name</th><th>Username</th><th>Status</th><th>Online</th><th>Actions</th>
            </tr>
          </thead>
          <tbody>
          <%
          for(Object[] d : externalMembers){
            int did=(Integer)d[0]; int slot=(Integer)d[1];
            String dname=(String)d[2]; String duname=(String)d[3]; int dact=(Integer)d[4];
            java.sql.Timestamp lastAct=(java.sql.Timestamp)d[5];
            String dotCls="dot-gr",onlineTxt="Offline";
            if(lastAct!=null){long diff=(System.currentTimeMillis()-lastAct.getTime())/60000L;if(diff<=5){dotCls="dot-g";onlineTxt="Online";}else if(diff<=30){dotCls="dot-y";onlineTxt="Away";}}
            boolean isNext=(extTotal>0&&slot==extNextSlot);
          %>
          <tr style="<%= isNext?"background:#e8f5e9;":"" %>">
            <td>
              <span class="slot-num ext"><%= slot %></span>
              <% if(isNext){ %><span class="next-badge">NEXT</span><% } %>
            </td>
            <td style="font-weight:700;"><%= dname %></td>
            <td><code style="background:#f5f5f5;padding:2px 7px;border-radius:5px;font-size:.79rem;">@<%= duname %></code></td>
            <td><span class="p <%= dact==1?"pg":"pgy" %>"><%= dact==1?"Active":"Inactive" %></span></td>
            <td><span class="dot <%= dotCls %>"></span><span style="font-size:.77rem;color:var(--muted);"><%= onlineTxt %></span></td>
            <td>
              <div style="display:flex;gap:5px;">
                <form method="post" style="display:inline;">
                  <input type="hidden" name="action" value="toggle">
                  <input type="hidden" name="mid" value="<%= did %>">
                  <input type="hidden" name="cur" value="<%= dact %>">
                  <button type="submit" class="<%= dact==1?"tbtn-on":"tbtn-off" %>">
                    <%= dact==1?"Deactivate":"Activate" %>
                  </button>
                </form>
                <form method="post" style="display:inline;" onsubmit="return confirm('Remove this member?');">
                  <input type="hidden" name="action" value="delete">
                  <input type="hidden" name="mid" value="<%= did %>">
                  <button type="submit" class="dbtn">Remove</button>
                </form>
              </div>
            </td>
          </tr>
          <% } %>
          </tbody>
        </table>
        <% } %>

        <!-- Add External Member -->
        <div class="add-form">
          <div class="add-title ext">+ Add External Analytics Member — will be Slot <%= extTotal+1 %></div>
          <form method="post">
            <input type="hidden" name="action" value="add">
            <input type="hidden" name="stream" value="external">
            <div class="add-grid">
              <div>
                <div class="lbl">Full Name</div>
                <input type="text" name="full_name" class="ifield" placeholder="e.g. Priya Rajan" required maxlength="100">
              </div>
              <div>
                <div class="lbl">Username</div>
                <input type="text" name="username" class="ifield" placeholder="e.g. priya_ext01" required maxlength="50" pattern="[a-zA-Z0-9_]+">
              </div>
              <div>
                <div class="lbl">Password</div>
                <input type="password" name="password" class="ifield" placeholder="Set password" required minlength="4">
              </div>
              <div>
                <button type="submit" class="sbtn" style="background:linear-gradient(135deg,#1b5e20,#2e7d32);">
                  <i class="bi bi-plus-circle"></i> Add
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>

    </div><%-- /stream-grid --%>
  </div><%-- /pb --%>
</div><%-- /main --%>
</body>
</html>
