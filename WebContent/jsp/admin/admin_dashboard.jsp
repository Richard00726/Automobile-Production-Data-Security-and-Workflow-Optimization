<%@ page contentType="text/html;charset=UTF-8" language="java"
         import="java.sql.*,com.automobile.db.DBConnection,
                 java.time.LocalDateTime,java.time.format.DateTimeFormatter" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("username") == null) {
        response.sendRedirect("../../index.jsp"); return;
    }
    String role = (String) sess.getAttribute("role");
    if (!"admin".equals(role)) { response.sendRedirect("../../index.jsp"); return; }
    String fullName = (String) sess.getAttribute("fullName");
    String initial  = (fullName!=null&&!fullName.isEmpty()) ? String.valueOf(fullName.charAt(0)).toUpperCase() : "A";

    // ── Designer pool POST actions (add / toggle / delete) ──
    String dsgMsg     = "";
    String dsgMsgType = "";
    String dsgAction  = request.getParameter("dsgAction");
    if (dsgAction != null) {
        try (Connection connD = DBConnection.getConnection()) {

            if ("add".equals(dsgAction)) {
                String vtA  = request.getParameter("vt");
                String fnA  = request.getParameter("fn");
                String unA  = request.getParameter("un");
                String pwA  = request.getParameter("pw");
                if (vtA!=null && fnA!=null && unA!=null && pwA!=null
                        && !vtA.trim().isEmpty() && !fnA.trim().isEmpty()
                        && !unA.trim().isEmpty() && !pwA.trim().isEmpty()) {
                    // Check username unique
                    PreparedStatement chk = connD.prepareStatement(
                        "SELECT COUNT(*) FROM users WHERE username=?");
                    chk.setString(1, unA.trim().toLowerCase());
                    ResultSet chkR = chk.executeQuery();
                    int uExists = chkR.next() ? chkR.getInt(1) : 0;
                    if (uExists > 0) {
                        dsgMsg = "Username already taken. Choose another.";
                        dsgMsgType = "error";
                    } else {
                        connD.setAutoCommit(false);
                        try {
                        // Lock round-robin row first to prevent duplicate slot race condition
                        PreparedStatement lockQ = connD.prepareStatement(
                            "SELECT last_slot_used FROM designer_round_robin WHERE vehicle_type=? AND stream='internal' FOR UPDATE");
                        lockQ.setString(1, vtA.trim());
                        lockQ.executeQuery();
                        // Now safely get next slot
                        PreparedStatement slotQ = connD.prepareStatement(
                            "SELECT COALESCE(MAX(slot_number),0)+1 AS ns FROM vehicle_designers WHERE vehicle_type=?");
                        slotQ.setString(1, vtA.trim());
                        ResultSet slotR = slotQ.executeQuery();
                        int nextSlotA = slotR.next() ? slotR.getInt("ns") : 1;
                        // Hash password: salt:hash format using PasswordUtil
                        String hashedPw;
                        try {
                            hashedPw = com.automobile.util.PasswordUtil.hashPassword(pwA.trim());
                        } catch (Exception pe) {
                            // fallback manual SHA-256 if PasswordUtil unavailable
                            java.security.SecureRandom srA = new java.security.SecureRandom();
                            byte[] saltBytesA = new byte[16]; srA.nextBytes(saltBytesA);
                            String saltB64A = java.util.Base64.getEncoder().encodeToString(saltBytesA);
                            java.security.MessageDigest mdA = java.security.MessageDigest.getInstance("SHA-256");
                            mdA.update(saltBytesA);
                            byte[] hashBytesA = mdA.digest(pwA.trim().getBytes("UTF-8"));
                            StringBuilder sbA = new StringBuilder();
                            for (byte b : hashBytesA) sbA.append(String.format("%02x", b));
                            hashedPw = saltB64A + ":" + sbA.toString();
                        }
                        // Insert user
                        PreparedStatement pu = connD.prepareStatement(
                            "INSERT INTO users (full_name,username,password,role,is_active) VALUES (?,?,?,'design',1)");
                        pu.setString(1, fnA.trim());
                        pu.setString(2, unA.trim().toLowerCase());
                        pu.setString(3, hashedPw);
                        pu.executeUpdate();
                        // Insert designer
                        PreparedStatement pd = connD.prepareStatement(
                            "INSERT INTO vehicle_designers (vehicle_type,slot_number,full_name,username,is_active) VALUES (?,?,?,?,1)");
                        pd.setString(1, vtA.trim());
                        pd.setInt   (2, nextSlotA);
                        pd.setString(3, fnA.trim());
                        pd.setString(4, unA.trim().toLowerCase());
                        pd.executeUpdate();
                        // Ensure round-robin rows exist for both streams
                        PreparedStatement prA = connD.prepareStatement(
                            "INSERT IGNORE INTO designer_round_robin (vehicle_type,stream,last_slot_used,total_assigned) VALUES (?,?,0,0)");
                        prA.setString(1, vtA.trim()); prA.setString(2, "internal"); prA.executeUpdate();
                        prA.setString(1, vtA.trim()); prA.setString(2, "external"); prA.executeUpdate();
                        connD.commit();
                        dsgMsg = fnA.trim() + " added as Slot " + nextSlotA + " in " + vtA.trim().replace("_"," ").toUpperCase() + " pool.";
                        dsgMsgType = "success";
                        } catch (Exception txEx) {
                            try { connD.rollback(); } catch (Exception ignored2) {}
                            dsgMsg = "Error adding designer: " + txEx.getMessage();
                            dsgMsgType = "error";
                        } finally {
                            try { connD.setAutoCommit(true); } catch (Exception ignored2) {}
                        }
                    }
                } else {
                    dsgMsg = "All fields required to add a designer.";
                    dsgMsgType = "error";
                }
            }

            if ("toggle".equals(dsgAction)) {
                String didT = request.getParameter("did");
                String curT = request.getParameter("cur");
                if (didT != null && curT != null) {
                    int newVal = "1".equals(curT.trim()) ? 0 : 1;
                    PreparedStatement guT = connD.prepareStatement(
                        "SELECT username FROM vehicle_designers WHERE id=?");
                    guT.setInt(1, Integer.parseInt(didT.trim()));
                    ResultSet urT = guT.executeQuery();
                    if (urT.next()) {
                        String unT = urT.getString("username");
                        PreparedStatement upd = connD.prepareStatement(
                            "UPDATE vehicle_designers SET is_active=? WHERE id=?");
                        upd.setInt(1, newVal); upd.setInt(2, Integer.parseInt(didT.trim()));
                        upd.executeUpdate();
                        PreparedStatement upu = connD.prepareStatement(
                            "UPDATE users SET is_active=? WHERE username=?");
                        upu.setInt(1, newVal); upu.setString(2, unT);
                        upu.executeUpdate();
                    }
                    dsgMsg = newVal==1 ? "Designer activated." : "Designer deactivated.";
                    dsgMsgType = "success";
                }
            }

            if ("delete".equals(dsgAction)) {
                String didDel = request.getParameter("did");
                if (didDel != null) {
                    PreparedStatement guDel = connD.prepareStatement(
                        "SELECT username,vehicle_type FROM vehicle_designers WHERE id=?");
                    guDel.setInt(1, Integer.parseInt(didDel.trim()));
                    ResultSet drDel = guDel.executeQuery();
                    if (drDel.next()) {
                        String unDel = drDel.getString("username");
                        String vtDel = drDel.getString("vehicle_type");
                        connD.createStatement().executeUpdate(
                            "DELETE FROM vehicle_designers WHERE id=" + Integer.parseInt(didDel.trim()));
                        // Re-number slots
                        ResultSet remR = connD.createStatement().executeQuery(
                            "SELECT id FROM vehicle_designers WHERE vehicle_type='"
                            + vtDel.replace("'","''") + "' ORDER BY slot_number");
                        int slotN = 1;
                        while (remR.next()) {
                            PreparedStatement rnu = connD.prepareStatement(
                                "UPDATE vehicle_designers SET slot_number=? WHERE id=?");
                            rnu.setInt(1, slotN++); rnu.setInt(2, remR.getInt("id"));
                            rnu.executeUpdate();
                        }
                        // Reset round-robin for both streams
                        PreparedStatement rrRst = connD.prepareStatement(
                            "UPDATE designer_round_robin SET last_slot_used=0 WHERE vehicle_type=?");
                        rrRst.setString(1, vtDel);
                        rrRst.executeUpdate();
                        // Deactivate user
                        PreparedStatement duDel = connD.prepareStatement(
                            "UPDATE users SET is_active=0 WHERE username=?");
                        duDel.setString(1, unDel);
                        duDel.executeUpdate();
                    }
                    dsgMsg = "Designer removed from pool.";
                    dsgMsgType = "success";
                }
            }

        } catch (Exception dsgEx) {
            dsgMsg = "Error: " + dsgEx.getMessage();
            dsgMsgType = "error";
        }
        // After POST, redirect to same tab to prevent form resubmission
        response.sendRedirect("admin_dashboard.jsp?tab=designer_assign&dsgmsg=" +
            java.net.URLEncoder.encode(dsgMsg, "UTF-8") + "&dsgtype=" + dsgMsgType);
        return;
    }
    // Pick up redirect message if any
    if (dsgMsg.isEmpty() && request.getParameter("dsgmsg") != null) {
        dsgMsg     = request.getParameter("dsgmsg");
        dsgMsgType = request.getParameter("dsgtype") != null ? request.getParameter("dsgtype") : "success";
    }

    // ── All stats ──
    int totalVehicles=0,approvedCount=0,rejectedCount=0,pendingCount=0;
    int testPass=0,testFail=0,testPending=0,totalUsers=0,activeUsers=0;
    int totalCustomers=0,totalReqs=0,pendingReqs=0,completedReqs=0;
    int internalReqs=0,externalReqs=0,qcApprovals=0,qcRejections=0,pendingBulkReqs=0,pendingIndivReqs=0;

    try (Connection conn = DBConnection.getConnection()) {
        ResultSet r;
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle"); if(r.next()) totalVehicles=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='approved'"); if(r.next()) approvedCount=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='rejected'"); if(r.next()) rejectedCount=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM vehicle WHERE status='pending'"); if(r.next()) pendingCount=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='pass'"); if(r.next()) testPass=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='fail'"); if(r.next()) testFail=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM testing_status WHERE status='pending'"); if(r.next()) testPending=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM users"); if(r.next()) totalUsers=r.getInt(1);
        r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM users WHERE is_active=1"); if(r.next()) activeUsers=r.getInt(1);
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customers"); if(r.next()) totalCustomers=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements"); if(r.next()) totalReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='admin' AND workflow_stage IN ('admin_initial_review','submitted','in_review')"); if(r.next()) pendingReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE portal_type='individual' AND workflow_stage IN ('admin_initial_review','submitted','in_review')"); if(r.next()) pendingIndivReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE portal_type='bulk' AND workflow_stage IN ('admin_initial_review','submitted','in_review')"); if(r.next()) pendingBulkReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE status='FINAL_COMPLETED' OR workflow_stage='completed'"); if(r.next()) completedReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE portal_type='individual' OR portal_type IS NULL"); if(r.next()) internalReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE portal_type='bulk'"); if(r.next()) externalReqs=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE status='pending' OR workflow_stage='admin_initial_review'"); if(r.next()) externalReqs=externalReqs+r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM approvals WHERE action='approved'"); if(r.next()) qcApprovals=r.getInt(1);}catch(Exception ig){}
        try{r=conn.createStatement().executeQuery("SELECT COUNT(*) FROM approvals WHERE action='rejected'"); if(r.next()) qcRejections=r.getInt(1);}catch(Exception ig){}
    } catch (Exception ignored) {}

    String activeTab = request.getParameter("tab");
    if (activeTab == null) activeTab = "overview";
    if ("requirements".equals(activeTab)) activeTab = "external"; // requirements merged into external

    /* wfF — final approval count — needed early for nav badge */
    int wfF = 0;
    try(Connection _wfConn = com.automobile.db.DBConnection.getConnection()){
        java.sql.ResultSet _wp;
        _wp=_wfConn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(_wp.next())wfF+=_wp.getInt(1);
        try{_wp=_wfConn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(_wp.next())wfF+=_wp.getInt(1);}catch(Exception _ig){}
        try{_wp=_wfConn.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(_wp.next())wfF+=_wp.getInt(1);}catch(Exception _ig){}
    }catch(Exception _ig){}
    String searchQ = request.getParameter("search");
    if (searchQ == null) searchQ = "";
    String now = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd MMM yyyy, HH:mm"));
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Admin Dashboard — AutoProd</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Syne:wght@700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
<style>
:root { --sw:260px; --brand:#0f1f5c; --accent:#e53935; --bg:#f0f3f9; --border:#e5e9f2; --muted:#6b7280; --text:#1a1f36; }
*{margin:0;padding:0;box-sizing:border-box;}
body{background:var(--bg);font-family:'Plus Jakarta Sans',sans-serif;color:var(--text);}
/* SIDEBAR */
.sb{position:fixed;top:0;left:0;height:100vh;width:var(--sw);background:linear-gradient(170deg,#0a1240,#0f1f5c,#1a2f7a);color:#fff;display:flex;flex-direction:column;z-index:1000;overflow-y:auto;}
.sb-brand{padding:22px 20px 16px;border-bottom:1px solid rgba(255,255,255,.08);}
.sb-brand-row{display:flex;align-items:center;gap:10px;}
.sb-icon{width:36px;height:36px;background:linear-gradient(135deg,var(--accent),#ff8a65);border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:18px;flex-shrink:0;box-shadow:0 4px 12px rgba(229,57,53,.35);}
.sb-name{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;}
.sb-sub{font-size:.64rem;color:rgba(255,255,255,.32);letter-spacing:.5px;margin-top:2px;}
.sb-user{padding:14px 20px;border-bottom:1px solid rgba(255,255,255,.08);display:flex;align-items:center;gap:12px;}
.av{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,var(--accent),#ff8a65);display:flex;align-items:center;justify-content:center;font-weight:800;font-size:.9rem;flex-shrink:0;box-shadow:0 3px 10px rgba(229,57,53,.3);}
.uname{font-size:.84rem;font-weight:700;}.urole{font-size:.66rem;color:rgba(255,255,255,.38);text-transform:uppercase;letter-spacing:.8px;}
.dot{width:7px;height:7px;background:#22c55e;border-radius:50%;display:inline-block;margin-right:4px;box-shadow:0 0 5px #22c55e;}
.ns{padding:16px 20px 5px;font-size:.6rem;color:rgba(255,255,255,.26);letter-spacing:1.5px;text-transform:uppercase;font-weight:700;}
.nl{display:flex;align-items:center;gap:10px;padding:10px 20px;color:rgba(255,255,255,.65);text-decoration:none;transition:.2s;border-left:3px solid transparent;font-size:.83rem;font-weight:500;margin:1px 8px 1px 0;border-radius:0 8px 8px 0;}
.nl i{font-size:.95rem;flex-shrink:0;}.nl:hover{background:rgba(255,255,255,.07);color:#fff;}
.nl.active{background:rgba(255,255,255,.12);color:#fff;border-left-color:var(--accent);}
.nb{margin-left:auto;background:var(--accent);color:#fff;border-radius:20px;padding:2px 8px;font-size:.6rem;font-weight:800;}
.sf{margin-top:auto;padding:16px 20px;border-top:1px solid rgba(255,255,255,.08);}
.sf a{color:rgba(255,255,255,.5);text-decoration:none;display:flex;align-items:center;gap:8px;font-size:.82rem;padding:8px 10px;border-radius:8px;transition:.2s;}
.sf a:hover{background:rgba(255,255,255,.07);color:#fff;}
/* MAIN */
.main{margin-left:var(--sw);min-height:100vh;}
.topbar{background:#fff;padding:14px 30px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100;box-shadow:0 2px 10px rgba(0,0,0,.04);}
.topbar-t{font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;color:var(--brand);}
.topbar-s{font-size:.72rem;color:var(--muted);margin-top:1px;}
.ap{background:linear-gradient(135deg,var(--accent),#ff5252);color:#fff;padding:5px 14px;border-radius:20px;font-size:.72rem;font-weight:800;text-transform:uppercase;letter-spacing:1px;}
.tc{font-size:.78rem;color:var(--muted);background:var(--bg);border:1px solid var(--border);padding:5px 12px;border-radius:20px;}
.pb{padding:28px 30px;}
/* ALERT */
.pa{background:linear-gradient(135deg,#ff6b35,#e65100);border-radius:14px;padding:18px 24px;margin-bottom:22px;display:flex;align-items:center;justify-content:space-between;gap:16px;box-shadow:0 8px 24px rgba(230,81,0,.25);}
.pa h6{margin:0 0 3px;font-weight:800;color:#fff;font-size:.95rem;}.pa p{margin:0;color:rgba(255,255,255,.8);font-size:.8rem;}
.btn-rev{background:rgba(255,255,255,.22);color:#fff;border:2px solid rgba(255,255,255,.4);border-radius:10px;padding:9px 20px;font-weight:700;font-size:.82rem;text-decoration:none;transition:.2s;white-space:nowrap;}
.btn-rev:hover{background:rgba(255,255,255,.35);color:#fff;}
/* TABS */
.tab-bar{display:flex;gap:4px;background:#fff;border:1px solid var(--border);border-radius:14px;padding:5px;margin-bottom:26px;box-shadow:0 2px 8px rgba(0,0,0,.04);overflow-x:auto;}
.tb{padding:9px 18px;border-radius:10px;font-size:.82rem;font-weight:700;cursor:pointer;border:none;background:transparent;color:var(--muted);transition:.2s;white-space:nowrap;display:flex;align-items:center;gap:6px;}
.tb.active{background:var(--brand);color:#fff;box-shadow:0 3px 12px rgba(15,31,92,.25);}
.tb .tbb{background:var(--accent);color:#fff;border-radius:20px;padding:1px 7px;font-size:.6rem;font-weight:800;}.tb.active .tbb{background:rgba(255,255,255,.3);}
/* PANELS */
.tp{display:none;animation:fu .3s ease;}.tp.active{display:block;}
@keyframes blink{0%,100%{opacity:1;transform:scale(1);}50%{opacity:.5;transform:scale(1.15);}}
@keyframes fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
/* STATS */
.sg{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:14px;margin-bottom:22px;}
.sc{background:#fff;border-radius:14px;padding:18px 20px;box-shadow:0 2px 10px rgba(0,0,0,.05);border:1px solid var(--border);position:relative;overflow:hidden;transition:all .25s;}
.sc:hover{transform:translateY(-3px);box-shadow:0 8px 22px rgba(0,0,0,.09);}
.sc::after{content:'';position:absolute;bottom:0;left:0;right:0;height:3px;}
.si{width:44px;height:44px;border-radius:11px;display:flex;align-items:center;justify-content:center;font-size:1.3rem;margin-bottom:12px;}
.sn{font-family:'Syne',sans-serif;font-size:1.75rem;font-weight:800;line-height:1;}
.sl{font-size:.72rem;color:var(--muted);margin-top:3px;font-weight:500;}
.c-bl .si{background:#e8f0ff;}.c-bl::after{background:#3b82f6;}
.c-gr .si{background:#e8f5e9;}.c-gr::after{background:#22c55e;}
.c-or .si{background:#fff3e0;}.c-or::after{background:#f97316;}
.c-rd .si{background:#ffebee;}.c-rd::after{background:#ef4444;}
.c-pu .si{background:#f3e5f5;}.c-pu::after{background:#a855f7;}
.c-te .si{background:#e0f7f5;}.c-te::after{background:#14b8a6;}
.c-in .si{background:#e8eaf6;}.c-in::after{background:#6366f1;}
.c-pk .si{background:#fce4ec;}.c-pk::after{background:#ec4899;}
/* SECTION CARD */
.card{background:#fff;border-radius:16px;border:1px solid var(--border);box-shadow:0 2px 10px rgba(0,0,0,.04);margin-bottom:22px;overflow:hidden;}
.ch{padding:16px 22px;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;}
.ct{font-weight:800;font-size:.92rem;color:var(--text);display:flex;align-items:center;gap:8px;}
/* TABLE */
.dt{width:100%;border-collapse:collapse;font-size:.84rem;}
.dt th{padding:10px 14px;background:#f8faff;font-size:.7rem;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:.6px;border-bottom:2px solid var(--border);white-space:nowrap;}
.dt td{padding:12px 14px;border-bottom:1px solid #f5f5f5;vertical-align:middle;}
.dt tr:last-child td{border-bottom:none;}
.dt tr:hover td{background:#fafbff;}
.p{padding:3px 11px;border-radius:20px;font-size:.72rem;font-weight:700;display:inline-block;}
.pg{background:#e8f5e9;color:#2e7d32;}.pr{background:#ffebee;color:#c62828;}
.po{background:#fff3e0;color:#e65100;}.pb2{background:#e3f2fd;color:#1565c0;}
.pp{background:#f3e5f5;color:#6a1b9a;}.pt{background:#e0f7f5;color:#00695c;}
.pgy{background:#f5f5f5;color:#666;}
/* PIPELINE */
.pipe{display:flex;gap:10px;overflow-x:auto;padding-bottom:6px;margin-bottom:22px;}
.ps{background:#fff;border:1px solid var(--border);border-radius:14px;padding:16px 18px;min-width:145px;flex-shrink:0;text-align:center;position:relative;}
.ps:not(:last-child)::after{content:'→';position:absolute;right:-14px;top:50%;transform:translateY(-50%);font-size:16px;color:var(--muted);}
.pi{font-size:1.6rem;margin-bottom:8px;}.pn{font-size:.75rem;font-weight:700;color:var(--text);margin-bottom:4px;}
.pc{font-family:'Syne',sans-serif;font-size:1.4rem;font-weight:800;}.pl{font-size:.65rem;color:var(--muted);}
/* MODAL */
.mo{display:none;position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:99999;align-items:center;justify-content:center;padding:20px 20px 20px calc(var(--sw) + 20px);}
.mo.open{display:flex;}
.mb{background:#fff;border-radius:18px;width:100%;max-width:640px;max-height:90vh;overflow-y:auto;box-shadow:0 24px 60px rgba(0,0,0,.25);animation:su .25s ease;}
@keyframes su{from{transform:translateY(24px);opacity:0}to{transform:translateY(0);opacity:1}}
.mh{padding:20px 24px;border-radius:18px 18px 0 0;color:#fff;display:flex;align-items:center;justify-content:space-between;background:linear-gradient(135deg,var(--brand),#1a2f7a);}
.mh h5{margin:0;font-weight:800;font-size:1rem;}
.mc{background:rgba(255,255,255,.15);border:none;color:#fff;width:32px;height:32px;border-radius:50%;cursor:pointer;font-size:1rem;display:flex;align-items:center;justify-content:center;}
.mbody{padding:24px;}
.dg{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:18px;}
.di{background:#f8f9ff;border:1px solid #dce3ed;border-radius:10px;padding:12px 14px;}
.dl{font-size:.7rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;}
.dv{font-size:.88rem;font-weight:700;color:var(--text);}
.dbox{background:#f8f9ff;border:1px solid #dce3ed;border-radius:10px;padding:14px;font-size:.875rem;color:#333;line-height:1.6;margin-bottom:18px;max-height:120px;overflow-y:auto;}
.trg{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px;}
.trc{border:2px solid var(--border);border-radius:12px;padding:14px 16px;cursor:pointer;transition:.2s;display:flex;align-items:flex-start;gap:10px;}
.trc input{accent-color:#6c63ff;width:16px;height:16px;flex-shrink:0;margin-top:2px;}
.trc.si2{border-color:#6c63ff;background:#f0eeff;}.trc.se2{border-color:#00b4a6;background:#e0f7f5;}
.bi2{width:100%;border:1.5px solid #e0e0e0;border-radius:10px;padding:10px 14px;font-size:.88rem;font-family:inherit;outline:none;transition:.2s;}
.bi2:focus{border-color:var(--brand);box-shadow:0 0 0 3px rgba(15,31,92,.08);}
.na{width:100%;border:1.5px solid #e0e0e0;border-radius:10px;padding:12px 14px;font-size:.875rem;font-family:inherit;min-height:110px;resize:vertical;outline:none;transition:.2s;}
.na:focus{border-color:var(--brand);box-shadow:0 0 0 3px rgba(15,31,92,.08);}
.mar{display:flex;gap:10px;padding-top:4px;}
.mar button{flex:1;padding:11px;border:none;border-radius:10px;font-weight:700;font-size:.88rem;cursor:pointer;transition:.2s;}
.bap{background:linear-gradient(135deg,#2e7d32,#388e3c);color:#fff;}.bap:hover{transform:translateY(-1px);}
.brj{background:linear-gradient(135deg,#b71c1c,#c62828);color:#fff;}.brj:hover{transform:translateY(-1px);}
.bcn{background:#f0f0f0;color:#555;flex:0.6!important;}
.sm{margin-top:14px;padding:11px 14px;border-radius:9px;font-size:.875rem;font-weight:700;display:none;}
/* SEARCH */
.sw{display:flex;gap:10px;margin-bottom:16px;}
.si3{flex:1;border:1.5px solid var(--border);border-radius:10px;padding:10px 16px;font-size:.875rem;outline:none;font-family:inherit;transition:.2s;background:#fafbff;}
.si3:focus{border-color:var(--brand);background:#fff;}
.sbtn{padding:10px 22px;background:var(--brand);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer;transition:.2s;font-size:.875rem;}
.sbtn:hover{background:#1a2f7a;}
.es{text-align:center;padding:44px 20px;color:var(--muted);}
.es .ei{font-size:2.8rem;opacity:.35;margin-bottom:10px;}
.es p{font-size:.875rem;}
@media(max-width:768px){.sb{transform:translateX(-100%)}.main{margin-left:0}}
</style>
</head>
<body>

<!-- SIDEBAR -->
<div class="sb">
    <div class="sb-brand">
        <div class="sb-brand-row">
            <div class="sb-icon">🚗</div>
            <div><div class="sb-name">AutoProd</div><div class="sb-sub">ADMIN CONTROL PANEL</div></div>
        </div>
    </div>
    <div class="sb-user">
        <div class="av"><%= initial %></div>
        <div style="flex:1;min-width:0;">
            <div class="uname"><%= fullName %></div>
            <div class="urole"><span class="dot"></span>Administrator</div>
        </div>
    </div>
    <%
    boolean isTeamPage = "designer_assign".equals(activeTab)||"qc_assign".equals(activeTab)||"testing_assign".equals(activeTab)||"analytics_assign".equals(activeTab);
    %>
    <div class="ns">Dashboard</div>
    <a class="nl <%= "overview".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=overview"><i class="bi bi-speedometer2"></i> Overview</a>
    <a class="nl <%= "workflow".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=workflow"><i class="bi bi-arrow-repeat"></i> Workflow Status</a>

    <div class="ns">Production</div>
    <a class="nl <%= "internal".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=internal"><i class="bi bi-hammer"></i> Internal Jobs<% if(internalReqs>0){%><span class="nb2"><%= internalReqs %></span><%}%></a>
    <a class="nl <%= "external".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=external"><i class="bi bi-people-fill"></i> Customer Orders<% if(pendingIndivReqs+pendingBulkReqs>0){%><span class="nb2 red"><%= pendingIndivReqs+pendingBulkReqs %></span><%}%></a>

    <div class="ns">Reports</div>
    <a class="nl <%= "vehicles".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=vehicles"><i class="bi bi-truck-front-fill"></i> Vehicles</a>
    <a class="nl <%= "qc".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=qc"><i class="bi bi-shield-check"></i> QC History</a>
    <a class="nl <%= "testing".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=testing"><i class="bi bi-flask-fill"></i> Testing History</a>
    <a class="nl <%= "customers".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=customers"><i class="bi bi-person-lines-fill"></i> Customers</a>
    <a class="nl <%= "final_report".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=final_report"><i class="bi bi-file-earmark-bar-graph-fill"></i> Final Report</a>
    <a class="nl <%= "final_approval".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=final_approval"><i class="bi bi-check2-circle"></i> Final Approval<% if(wfF>0){%><span class="nb2 red"><%= wfF %></span><%}%></a>

    <div class="ns">Admin Tools</div>
    <a class="nl <%= "all_users".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=all_users"><i class="bi bi-people-fill"></i> All Users</a>

    <div class="ns">Routing</div>
    <a class="nl <%= "designer_assign".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=designer_assign"><i class="bi bi-diagram-3"></i> Design Routing</a>
    <a class="nl <%= "qc_assign".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=qc_assign"><i class="bi bi-shield-check"></i> QC Routing</a>
    <a class="nl <%= "testing_assign".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=testing_assign"><i class="bi bi-flask-fill"></i> Testing Routing</a>
    <a class="nl <%= "analytics_assign".equals(activeTab)?"active":"" %>" href="admin_dashboard.jsp?tab=analytics_assign"><i class="bi bi-graph-up-arrow"></i> Analytics Routing</a>

    <div class="sf"><a href="${pageContext.request.contextPath}/logout"><i class="bi bi-box-arrow-left"></i> Logout</a></div>
</div>

<!-- MAIN -->
<div class="main">
<div class="topbar">
    <div><div class="topbar-t">Admin Dashboard</div><div class="topbar-s">AutoProd &rsaquo; Control Panel</div></div>
    <div style="display:flex;align-items:center;gap:12px;">
        <div class="tc"><i class="bi bi-clock me-1"></i><%= now %></div>
        <div class="ap"><i class="bi bi-shield-fill me-1"></i>Admin</div>
    </div>
</div>
<div class="pb">

<% if(pendingBulkReqs>0){ %>
<div style="display:flex;flex-direction:column;gap:10px;margin-bottom:4px;">
<div class="pa" style="background:linear-gradient(135deg,#f0fdfa,#ccfbf1);border:1.5px solid #5eead4;">
    <div style="display:flex;align-items:center;gap:14px;">
        <span style="font-size:2rem;animation:blink 1.2s ease-in-out infinite;">🏢</span>
        <div>
            <h6 style="color:#0f766e;"><%= pendingBulkReqs %> Bulk / Contract order<%= pendingBulkReqs>1?"s":"" %> waiting for review!</h6>
            <p style="color:#0d9488;">Bulk portal submissions — review organisation documents and approve to Design Team.</p>
        </div>
    </div>
    <a href="admin_dashboard.jsp?tab=external" class="btn-rev" style="background:linear-gradient(135deg,#0f766e,#0d9488);"><i class="bi bi-eye me-1"></i> Review Bulk</a>
</div>
</div>
<% } %>

<!-- TAB BAR -->
<div class="tab-bar">
    <button class="tb <%= "overview".equals(activeTab)?"active":"" %>" onclick="swTab('overview')"><i class="bi bi-grid-1x2-fill"></i> Overview</button>
    <button class="tb <%= "workflow".equals(activeTab)?"active":"" %>" onclick="swTab('workflow')"><i class="bi bi-arrow-repeat"></i> Workflow</button>
    <button class="tb <%= "internal".equals(activeTab)?"active":"" %>" onclick="swTab('internal')"><i class="bi bi-hammer"></i> 🏭 Internal</button>
    <button class="tb <%= "external".equals(activeTab)?"active":"" %>" onclick="swTab('external')"><i class="bi bi-people-fill"></i> Customer Orders<% if(!"external".equals(activeTab)&&(pendingIndivReqs>0||pendingBulkReqs>0)){%><span style="display:inline-block;width:8px;height:8px;background:#ef4444;border-radius:50%;margin-left:5px;animation:blink 1.2s infinite;vertical-align:middle;"></span><%}%></button>
    <button class="tb <%= "vehicles".equals(activeTab)?"active":"" %>" onclick="swTab('vehicles')"><i class="bi bi-truck-front-fill"></i> Vehicles</button>
    <button class="tb <%= "qc".equals(activeTab)?"active":"" %>" onclick="swTab('qc')"><i class="bi bi-shield-check"></i> QC History</button>
    <button class="tb <%= "testing".equals(activeTab)?"active":"" %>" onclick="swTab('testing')"><i class="bi bi-flask-fill"></i> Testing</button>
    <button class="tb <%= "customers".equals(activeTab)?"active":"" %>" onclick="swTab('customers')"><i class="bi bi-people-fill"></i> Customers</button>
    <button class="tb <%= "designer_assign".equals(activeTab)?"active":"" %>" onclick="swTab('designer_assign')"><i class="bi bi-diagram-3"></i> Designer</button>
    <button class="tb <%= "qc_assign".equals(activeTab)?"active":"" %>" onclick="swTab('qc_assign')" style="<%= "qc_assign".equals(activeTab)?"background:#22c55e22;color:#16a34a;border-color:#22c55e;":"" %>"><i class="bi bi-shield-check"></i> QC Routing</button>
    <button class="tb <%= "testing_assign".equals(activeTab)?"active":"" %>" onclick="swTab('testing_assign')" style="<%= "testing_assign".equals(activeTab)?"background:#f59e0b22;color:#d97706;border-color:#f59e0b;":"" %>"><i class="bi bi-flask-fill"></i> Testing Routing</button>
    <button class="tb <%= "analytics_assign".equals(activeTab)?"active":"" %>" onclick="swTab('analytics_assign')" style="<%= "analytics_assign".equals(activeTab)?"background:#8b5cf622;color:#7c3aed;border-color:#8b5cf6;":"" %>"><i class="bi bi-graph-up-arrow"></i> Analytics Routing</button>
    <button class="tb <%= "final_approval".equals(activeTab)?"active":"" %>" onclick="swTab('final_approval')" style="<%= "final_approval".equals(activeTab)?"background:#ef444422;color:#dc2626;border-color:#ef4444;":"" %>"><i class="bi bi-check2-circle"></i> Final Approval<% if(wfF>0){%><span style="display:inline-block;width:8px;height:8px;background:#ef4444;border-radius:50%;margin-left:5px;animation:blink 1.2s infinite;vertical-align:middle;"></span><%}%></button>
</div>

<!-- ═══ TAB: OVERVIEW ═══ -->
<div id="tab-overview" class="tp <%= "overview".equals(activeTab)?"active":"" %>">
<div style="background:linear-gradient(135deg,#0a1240,#0f1f5c,#1a2f7a);border-radius:16px;padding:26px 30px;margin-bottom:22px;color:#fff;position:relative;overflow:hidden;">
    <div style="position:absolute;top:-40px;right:-40px;width:180px;height:180px;border-radius:50%;background:radial-gradient(circle,rgba(229,57,53,.2),transparent 70%);"></div>
    <div style="font-family:'Syne',sans-serif;font-size:1.4rem;font-weight:800;margin-bottom:5px;">Welcome, <%= fullName %>! 🛡️</div>
    <div style="font-size:.875rem;color:rgba(255,255,255,.6);margin-bottom:20px;">Full system overview — all modules, all data, all history. You have read-only access to all module data.</div>
    <div style="display:flex;gap:28px;flex-wrap:wrap;">
        <div><div style="font-family:'Syne',sans-serif;font-size:1.5rem;font-weight:800;"><%= totalVehicles %></div><div style="font-size:.68rem;color:rgba(255,255,255,.45);text-transform:uppercase;letter-spacing:.8px;">Total Vehicles</div></div>
        <div style="width:1px;background:rgba(255,255,255,.12);"></div>
        <div><div style="font-family:'Syne',sans-serif;font-size:1.5rem;font-weight:800;"><%= totalReqs %></div><div style="font-size:.68rem;color:rgba(255,255,255,.45);text-transform:uppercase;letter-spacing:.8px;">Total Requirements</div></div>
        <div style="width:1px;background:rgba(255,255,255,.12);"></div>
        <div><div style="font-family:'Syne',sans-serif;font-size:1.5rem;font-weight:800;"><%= activeUsers %></div><div style="font-size:.68rem;color:rgba(255,255,255,.45);text-transform:uppercase;letter-spacing:.8px;">Active Staff</div></div>
        <div style="width:1px;background:rgba(255,255,255,.12);"></div>
        <div><div style="font-family:'Syne',sans-serif;font-size:1.5rem;font-weight:800;color:<%= pendingReqs>0?"#ff8a65":"#4ade80" %>"><%= pendingReqs %></div><div style="font-size:.68rem;color:rgba(255,255,255,.45);text-transform:uppercase;letter-spacing:.8px;">Pending Review</div></div>
    </div>
</div>
<div class="sg">
    <div class="sc c-bl"><div class="si">🚗</div><div class="sn"><%= totalVehicles %></div><div class="sl">Total Vehicles</div></div>
    <div class="sc c-gr"><div class="si">✅</div><div class="sn"><%= approvedCount %></div><div class="sl">QC Approved</div></div>
    <div class="sc c-or"><div class="si">⏳</div><div class="sn"><%= pendingCount %></div><div class="sl">QC Pending</div></div>
    <div class="sc c-rd"><div class="si">❌</div><div class="sn"><%= rejectedCount %></div><div class="sl">QC Rejected</div></div>
    <div class="sc c-pu"><div class="si">🔬</div><div class="sn"><%= testPass %></div><div class="sl">Tests Passed</div></div>
    <div class="sc c-rd"><div class="si">⚠️</div><div class="sn"><%= testFail %></div><div class="sl">Tests Failed</div></div>
    <div class="sc c-in"><div class="si">👥</div><div class="sn"><%= activeUsers %></div><div class="sl">Active Staff</div></div>
    <div class="sc c-te"><div class="si">📋</div><div class="sn"><%= totalReqs %></div><div class="sl">Total Requirements</div></div>
    <div class="sc c-gr"><div class="si">🏁</div><div class="sn"><%= completedReqs %></div><div class="sl">Completed Jobs</div></div>
    <div class="sc c-pk"><div class="si">👤</div><div class="sn"><%= totalCustomers %></div><div class="sl">Customers</div></div>
</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:22px;">
    <div class="sc" style="border:2px solid #0a6ebd;"><div class="si" style="background:#eff6ff;">🚗</div><div><div class="sn" style="color:#0a6ebd;"><%= internalReqs %></div><div class="sl">Individual Orders</div></div></div>
    <div class="sc" style="border:2px solid #00b4a6;"><div class="si" style="background:#e0f7f5;">🏢</div><div><div class="sn" style="color:#00b4a6;"><%= externalReqs %></div><div class="sl">Bulk / Contract Orders</div></div></div>
</div>
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-people-fill" style="color:var(--brand);"></i> Staff Members</div><a href="manage_users.jsp" style="font-size:.8rem;color:var(--brand);text-decoration:none;font-weight:700;">Manage →</a></div>
    <table class="dt">
        <thead><tr><th>#</th><th>Name</th><th>Username</th><th>Role</th><th>Status</th></tr></thead>
        <tbody>
        <%try(Connection conn=DBConnection.getConnection()){ResultSet ru=conn.createStatement().executeQuery("SELECT * FROM users ORDER BY role,id LIMIT 10");int un=0;while(ru.next()){un++;int ia=ru.getInt("is_active");String ur=ru.getString("role");String rp="admin".equals(ur)?"pr":"design".equals(ur)?"pb2":"qc".equals(ur)?"pg":"testing".equals(ur)?"po":"pp";%>
        <tr><td style="color:var(--muted);font-size:.78rem;"><%= un %></td><td style="font-weight:700;"><%= ru.getString("full_name") %></td><td><code style="background:#f5f5f5;padding:2px 8px;border-radius:6px;font-size:.8rem;"><%= ru.getString("username") %></code></td><td><span class="p <%= rp %>"><%= ur.toUpperCase() %></span></td><td><span class="p <%= ia==1?"pg":"pgy" %>"><%= ia==1?"Active":"Inactive" %></span></td></tr>
        <%}}catch(Exception e){%><tr><td colspan="5" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /overview -->


<!-- ═══ TAB: WORKFLOW ═══ -->
<div id="tab-workflow" class="tp <%= "workflow".equals(activeTab)?"active":"" %>">
<%
int wfD=0,wfQ=0,wfT=0,wfA=0,wfDone=0; wfF=0; // reset and recount
int wfIntTotal=0,wfCustTotal=0;
try(Connection conn=DBConnection.getConnection()){
    ResultSet wp;
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='design'");if(wp.next())wfD=wp.getInt(1);
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='qc'");if(wp.next())wfQ=wp.getInt(1);
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='testing'");if(wp.next())wfT=wp.getInt(1);
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='analytics'");if(wp.next())wfA=wp.getInt(1);
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(wp.next())wfF+=wp.getInt(1);
    try{wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(wp.next())wfF+=wp.getInt(1);}catch(Exception ig){}
    try{wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE current_assignee='admin' AND workflow_stage='analytics_completed'");if(wp.next())wfF+=wp.getInt(1);}catch(Exception ig){}
    wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE workflow_stage='completed'");if(wp.next())wfDone=wp.getInt(1);
    try{wp=conn.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs");if(wp.next())wfIntTotal=wp.getInt(1);}catch(Exception ig){}
    wfCustTotal=wfD+wfQ+wfT+wfA+wfF+wfDone;
}catch(Exception ig){}
%>
<!-- Pipeline Summary -->
<div class="pipe" style="margin-bottom:22px;">
    <div class="ps"><div class="pi">🏭</div><div class="pn">Design</div><div class="pc" style="color:#6c63ff;"><%= wfD %></div><div class="pl">in design</div></div>
    <div class="ps"><div class="pi">🛡️</div><div class="pn">QC Check</div><div class="pc" style="color:#f97316;"><%= wfQ %></div><div class="pl">awaiting QC</div></div>
    <div class="ps"><div class="pi">🔬</div><div class="pn">Testing</div><div class="pc" style="color:#a855f7;"><%= wfT %></div><div class="pl">in testing</div></div>
    <div class="ps"><div class="pi">📊</div><div class="pn">Analytics</div><div class="pc" style="color:#14b8a6;"><%= wfA %></div><div class="pl">analysing</div></div>
    <div class="ps" style="border-color:var(--accent);"><div class="pi">📌</div><div class="pn">Final Review</div><div class="pc" style="color:var(--accent);"><%= wfF %></div><div class="pl">needs approval</div></div>
    <div class="ps" style="border-color:#22c55e;"><div class="pi">🏁</div><div class="pn">Completed</div><div class="pc" style="color:#22c55e;"><%= wfDone %></div><div class="pl">done</div></div>
</div>

<!-- ══ Section: Customer Orders Workflow ══ -->
<div class="card" style="margin-bottom:22px;">
    <div class="ch">
        <div class="ct"><i class="bi bi-people-fill" style="color:#0a6ebd;"></i> 🚗 Customer Orders — Workflow Tracker</div>
        <span class="p pb2"><%= wfCustTotal %> active</span>
    </div>
    <table class="dt">
        <thead>
            <tr>
                <th>#</th>
                <th>Order No.</th>
                <th>Customer</th>
                <th>Title</th>
                <th>Type</th>
                <th>Progress</th>
                <th>Current Stage</th>
                <th>Assigned To</th>
                <th>Days at Stage</th>
                <th>View</th>
            </tr>
        </thead>
        <tbody>
        <%
        boolean awCust=false;int wn=0;
        try(Connection conn=DBConnection.getConnection()){
            ResultSet wf=conn.createStatement().executeQuery(
                "SELECT cr.*,c.full_name AS cname FROM customer_requirements cr " +
                "LEFT JOIN customers c ON cr.customer_id=c.id " +
                "WHERE cr.workflow_stage NOT IN ('submitted','admin_initial_review','in_review') " +
                "OR cr.workflow_stage IS NOT NULL " +
                "ORDER BY cr.submitted_at DESC");
            while(wf.next()){
                awCust=true; wn++;
                String ws=wf.getString("workflow_stage"); if(ws==null)ws="submitted";
                String ca=wf.getString("current_assignee"); if(ca==null)ca="admin";
                String dt3="individual";try{dt3=wf.getString("portal_type")!=null?wf.getString("portal_type"):"individual";}catch(Exception ig){}
                String cn2=wf.getString("cname")!=null?wf.getString("cname"):wf.getString("client_name");
                String reqNo=wf.getString("req_number")!=null?wf.getString("req_number"):"REQ-"+wf.getInt("id");
                String title=wf.getString("req_title")!=null?wf.getString("req_title"):wf.getString("module_name");
                if(title==null)title="—";
                // Stage index for progress
                int stageIdx=0;
                if(ws.contains("submitted")||ws.contains("in_review")||ws.contains("admin_initial_review"))stageIdx=0;
                else if(ws.contains("admin_initial_approved")||"design".equals(ca))stageIdx=1;
                else if("qc".equals(ca)||ws.contains("design_completed"))stageIdx=2;
                else if("testing".equals(ca)||ws.contains("qc_approved"))stageIdx=3;
                else if("analytics".equals(ca)||ws.contains("testing_completed"))stageIdx=4;
                else if(ws.contains("analytics_completed"))stageIdx=5;
                else if(ws.contains("completed"))stageIdx=6;
                // Days at current stage
                long daysAtStage=0;
                try{
                    java.sql.Timestamp sat=wf.getTimestamp("submitted_at");
                    if(sat!=null){daysAtStage=(System.currentTimeMillis()-sat.getTime())/(1000*60*60*24);}
                }catch(Exception ig){}
                // Stage label and color
                String stageLabel;
                if("submitted".equals(ws)||"admin_initial_review".equals(ws)||"in_review".equals(ws)) stageLabel="⏳ Awaiting Admin";
                else if("admin_initial_approved".equals(ws))  stageLabel="🔧 In Design";
                else if("design_completed".equals(ws))         stageLabel="🔍 In QC";
                else if("qc_approved".equals(ws))              stageLabel="🔬 In Testing";
                else if("qc_rejected".equals(ws))              stageLabel="❌ QC Rejected";
                else if("testing_completed".equals(ws))        stageLabel="📊 In Analytics";
                else if("analytics_completed".equals(ws))      stageLabel="📋 Final Review";
                else if("completed".equals(ws))                stageLabel="✅ Completed";
                else                                           stageLabel=ws.replace("_"," ");
                String stageBg=stageIdx==6?"#e8f5e9":stageIdx>=4?"#f0fdfa":stageIdx>=2?"#fff8e1":"#eff6ff";
                String stageColor=stageIdx==6?"#2e7d32":stageIdx>=4?"#0f766e":stageIdx>=2?"#b45309":"#1d4ed8";
                String assignedColor="design".equals(ca)?"#6c63ff":"qc".equals(ca)?"#f97316":"testing".equals(ca)?"#a855f7":"analytics".equals(ca)?"#14b8a6":"#0a6ebd";
                // Days color
                String daysColor=daysAtStage>7?"#e53935":daysAtStage>3?"#f59e0b":"#2e7d32";
                // JS escaped values for modal
                String jsTitle=title.replace("'","&#39;").replace("\"","&quot;");
                String jsCust=cn2.replace("'","&#39;");
                String jsReqNo=reqNo.replace("'","&#39;");
                String jsWs=ws.replace("'","&#39;");
                String jsCa=ca.replace("'","&#39;");
                String jsType=dt3;
        %>
        <tr>
            <td style="color:var(--muted);font-size:.78rem;"><%= wn %></td>
            <td><code style="color:#0a6ebd;font-weight:700;background:#eff6ff;padding:2px 8px;border-radius:6px;font-size:.78rem;"><%= reqNo %></code></td>
            <td style="font-weight:600;font-size:.84rem;max-width:110px;"><%= cn2 %></td>
            <td style="font-size:.82rem;max-width:110px;"><%= title.length()>30?title.substring(0,30)+"...":title %></td>
            <td><span class="p <%= "bulk".equals(dt3)?"pt":"pb2" %>" style="font-size:.68rem;"><%= "bulk".equals(dt3)?"🏢 Bulk":"🚗 Indiv" %></span></td>
            <td style="min-width:130px;">
                <div style="display:flex;align-items:center;gap:6px;">
                    <div style="flex:1;background:#e5e7eb;border-radius:20px;height:7px;overflow:hidden;">
                        <div style="width:<%= (stageIdx*100/6) %>%;height:100%;border-radius:20px;background:linear-gradient(90deg,#0a6ebd,#00b4a6);transition:width .4s;"></div>
                    </div>
                    <span style="font-size:.68rem;font-weight:700;color:#0a6ebd;white-space:nowrap;"><%= stageIdx %>/6</span>
                </div>
            </td>
            <td><span style="font-size:.7rem;font-weight:700;background:<%= stageBg %>;color:<%= stageColor %>;padding:3px 9px;border-radius:8px;"><%= stageLabel %></span></td>
            <td><span style="font-size:.72rem;font-weight:700;color:<%= assignedColor %>;background:#f8f9fa;padding:3px 9px;border-radius:8px;"><%= ca.toUpperCase() %></span></td>
            <td style="font-size:.8rem;font-weight:700;color:<%= daysColor %>;text-align:center;"><%= daysAtStage %>d</td>
            <td><button class="sbtn" style="padding:5px 12px;font-size:.75rem;" onclick="openWfModal('<%= jsReqNo %>','<%= jsCust %>','<%= jsTitle %>','<%= jsType %>','<%= jsWs %>','<%= jsCa %>','<%= stageIdx %>','<%= daysAtStage %>')"><i class="bi bi-diagram-3 me-1"></i>View</button></td>
        </tr>
        <% } if(!awCust){%><tr><td colspan="10"><div class="es"><div class="ei">🔄</div><p>No active customer workflows.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="10" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>

<!-- ══ Section: Internal Jobs Workflow ══ -->
<div class="card">
    <div class="ch">
        <div class="ct"><i class="bi bi-hammer" style="color:#6c63ff;"></i> 🏭 Internal Jobs — Workflow Tracker</div>
        <span class="p" style="background:#f3f0ff;color:#6c63ff;"><%= wfIntTotal %> jobs</span>
    </div>
    <table class="dt">
        <thead>
            <tr>
                <th>#</th>
                <th>Job No.</th>
                <th>Brand / Model</th>
                <th>Progress</th>
                <th>Current Stage</th>
                <th>Assigned To</th>
                <th>Days at Stage</th>
                <th>View</th>
            </tr>
        </thead>
        <tbody>
        <%
        boolean awInt=false;int in2=0;
        try(Connection conn=DBConnection.getConnection()){
            ResultSet wi=conn.createStatement().executeQuery("SELECT * FROM internal_jobs ORDER BY created_at DESC");
            while(wi.next()){
                awInt=true; in2++;
                String ws=wi.getString("workflow_stage"); if(ws==null)ws="pending";
                String ca=wi.getString("current_assignee"); if(ca==null)ca="admin";
                String orderNo=wi.getString("job_number")!=null?wi.getString("job_number"):"INT-"+wi.getInt("id");
                String brand="";try{brand=wi.getString("brand_name")!=null?wi.getString("brand_name"):"";}catch(Exception ig){}if(brand==null)brand="—";
                String vtype="";try{vtype=wi.getString("vehicle_type")!=null?wi.getString("vehicle_type"):"";}catch(Exception ig){}
                String model="";try{model=wi.getString("model_name")!=null?wi.getString("model_name"):"";}catch(Exception ig){}
                String displayBrand=brand.isEmpty()?(model.isEmpty()?"—":model):brand+(model.isEmpty()?"":" – "+model);
                int stageIdx=0;
                if("pending".equals(ws)||ws.isEmpty())                                stageIdx=0;
                else if(ws.equals("admin_initial_approved")||"design".equals(ca))     stageIdx=1;
                else if(ws.equals("design_completed")||"qc".equals(ca))               stageIdx=2;
                else if(ws.equals("qc_approved")||"testing".equals(ca))               stageIdx=3;
                else if(ws.equals("testing_completed")||"analytics".equals(ca))       stageIdx=4;
                else if(ws.equals("analytics_completed"))                              stageIdx=5;
                else if(ws.equals("completed"))                                        stageIdx=6;
                long daysAtStage=0;
                try{java.sql.Timestamp cat=wi.getTimestamp("created_at");if(cat!=null){daysAtStage=(System.currentTimeMillis()-cat.getTime())/(1000*60*60*24);}}catch(Exception ig){}
                String stageBg=stageIdx==6?"#e8f5e9":stageIdx>=4?"#f3f0ff":stageIdx>=2?"#fff8e1":"#f0fdfa";
                String stageColor=stageIdx==6?"#2e7d32":stageIdx>=4?"#6c63ff":stageIdx>=2?"#b45309":"#0f766e";
                String daysColor2=daysAtStage>7?"#e53935":daysAtStage>3?"#f59e0b":"#2e7d32";
                String jsOrderNo=orderNo.replace("'","&#39;");
                String jsBrand=displayBrand.replace("'","&#39;");
                String jsVtype=vtype.replace("'","&#39;");
                String jsWs2=ws.replace("'","&#39;");
                String jsCa2=ca.replace("'","&#39;");
        %>
        <tr>
            <td style="color:var(--muted);font-size:.78rem;"><%= in2 %></td>
            <td><code style="color:#6c63ff;font-weight:700;background:#f3f0ff;padding:2px 8px;border-radius:6px;font-size:.78rem;"><%= orderNo %></code></td>
            <td style="font-weight:600;font-size:.84rem;"><%= displayBrand %><% if(!vtype.isEmpty()){%><br><span style="font-size:.7rem;color:var(--muted);"><%= vtype.replace("_"," ") %></span><%}%></td>
            <td style="min-width:130px;">
                <div style="display:flex;align-items:center;gap:6px;">
                    <div style="flex:1;background:#e5e7eb;border-radius:20px;height:7px;overflow:hidden;">
                        <div style="width:<%= (stageIdx*100/6) %>%;height:100%;border-radius:20px;background:linear-gradient(90deg,#6c63ff,#a855f7);transition:width .4s;"></div>
                    </div>
                    <span style="font-size:.68rem;font-weight:700;color:#6c63ff;white-space:nowrap;"><%= stageIdx %>/6</span>
                </div>
            </td>
            <td><span style="font-size:.7rem;font-weight:700;background:<%= stageBg %>;color:<%= stageColor %>;padding:3px 9px;border-radius:8px;"><%
                if("pending".equals(ws)||ws.isEmpty())                   out.print("⏳ Pending");
                else if("admin_initial_approved".equals(ws))             out.print("🔧 In Design");
                else if("design_completed".equals(ws))                   out.print("🔍 In QC");
                else if("qc_approved".equals(ws))                        out.print("🔬 In Testing");
                else if("qc_rejected".equals(ws))                        out.print("❌ QC Rejected");
                else if("testing_completed".equals(ws))                  out.print("📊 In Analytics");
                else if("analytics_completed".equals(ws))                out.print("📋 Final Review");
                else if("completed".equals(ws))                          out.print("✅ Completed");
                else                                                     out.print(ws.replace("_"," "));
            %></span></td>
            <td><span style="font-size:.72rem;font-weight:700;color:#6c63ff;background:#f3f0ff;padding:3px 9px;border-radius:8px;"><%= ca.toUpperCase() %></span></td>
            <td style="font-size:.8rem;font-weight:700;color:<%= daysColor2 %>;text-align:center;"><%= daysAtStage %>d</td>
            <td><button class="sbtn" style="padding:5px 12px;font-size:.75rem;background:linear-gradient(135deg,#6c63ff,#a855f7);" onclick="openWfModal('<%= jsOrderNo %>','<%= jsBrand %>','<%= jsVtype %>','internal','<%= jsWs2 %>','<%= jsCa2 %>','<%= stageIdx %>','<%= daysAtStage %>')"><i class="bi bi-diagram-3 me-1"></i>View</button></td>
        </tr>
        <%}if(!awInt){%><tr><td colspan="8"><div class="es"><div class="ei">🏭</div><p>No internal jobs in workflow.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="8" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>

<!-- ══ Workflow View Modal ══ -->
<div id="wfModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:9999;align-items:center;justify-content:center;padding:20px;">
    <div style="background:#fff;border-radius:20px;width:100%;max-width:580px;box-shadow:0 24px 64px rgba(0,0,0,.2);overflow:hidden;">
        <div id="wfModalHeader" style="background:linear-gradient(135deg,#0a6ebd,#00b4a6);padding:20px 24px;color:#fff;display:flex;align-items:center;justify-content:space-between;">
            <div>
                <div style="font-size:.72rem;opacity:.8;text-transform:uppercase;letter-spacing:.5px;" id="wfModalType"></div>
                <div style="font-weight:800;font-size:1.05rem;margin-top:2px;" id="wfModalTitle"></div>
                <div style="font-size:.8rem;opacity:.85;margin-top:2px;" id="wfModalSub"></div>
            </div>
            <button onclick="document.getElementById('wfModal').style.display='none'" style="background:rgba(255,255,255,.2);border:none;color:#fff;width:32px;height:32px;border-radius:50%;cursor:pointer;font-size:1rem;">✕</button>
        </div>
        <div style="padding:24px;">
            <!-- Info row -->
            <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;margin-bottom:20px;">
                <div style="background:#f0f7ff;border-radius:10px;padding:10px;text-align:center;">
                    <div style="font-size:.68rem;color:#6b7c93;text-transform:uppercase;letter-spacing:.4px;">Current Stage</div>
                    <div style="font-weight:800;color:#0a6ebd;font-size:.85rem;margin-top:3px;" id="wfInfoStage"></div>
                </div>
                <div style="background:#f0fdfa;border-radius:10px;padding:10px;text-align:center;">
                    <div style="font-size:.68rem;color:#6b7c93;text-transform:uppercase;letter-spacing:.4px;">Assigned To</div>
                    <div style="font-weight:800;color:#0f766e;font-size:.85rem;margin-top:3px;" id="wfInfoAssigned"></div>
                </div>
                <div style="background:#fff8e1;border-radius:10px;padding:10px;text-align:center;">
                    <div style="font-size:.68rem;color:#6b7c93;text-transform:uppercase;letter-spacing:.4px;">Days Elapsed</div>
                    <div style="font-weight:800;font-size:.85rem;margin-top:3px;" id="wfInfoDays"></div>
                </div>
            </div>
            <!-- Progress bar -->
            <div style="margin-bottom:20px;">
                <div style="display:flex;justify-content:space-between;font-size:.72rem;color:#6b7c93;margin-bottom:6px;">
                    <span>Overall Progress</span>
                    <span id="wfProgressTxt"></span>
                </div>
                <div style="background:#e5e7eb;border-radius:20px;height:10px;overflow:hidden;">
                    <div id="wfProgressBar" style="height:100%;border-radius:20px;background:linear-gradient(90deg,#0a6ebd,#00b4a6);transition:width .6s;"></div>
                </div>
            </div>
            <!-- Timeline -->
            <div style="font-size:.72rem;font-weight:700;color:#6b7c93;text-transform:uppercase;letter-spacing:.5px;margin-bottom:12px;">Workflow Timeline</div>
            <div id="wfTimeline" style="display:flex;flex-direction:column;gap:0;"></div>
        </div>
    </div>
</div>

</div><!-- /workflow -->


<!-- ═══ TAB: VEHICLES HISTORY ═══ -->
<div id="tab-vehicles" class="tp <%= "vehicles".equals(activeTab)?"active":"" %>">
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-truck-front-fill" style="color:var(--brand);"></i> All Vehicles — Full History</div><span style="font-size:.78rem;color:var(--muted);">Read-only view</span></div>
    <div style="padding:16px 22px 0;">
        <form method="get" class="sw"><input type="hidden" name="tab" value="vehicles"><input type="text" name="search" class="si3" placeholder="Search model name or fuel type..." value="<%= searchQ %>"><button type="submit" class="sbtn"><i class="bi bi-search me-1"></i>Search</button><% if(!searchQ.isEmpty()){%><a href="admin_dashboard.jsp?tab=vehicles" style="padding:10px 16px;border:1.5px solid var(--border);border-radius:10px;color:var(--muted);text-decoration:none;font-size:.85rem;display:flex;align-items:center;"><i class="bi bi-x"></i></a><%}%></form>
    </div>
    <table class="dt">
        <thead><tr><th>#</th><th>Model Name</th><th>Seats</th><th>Fuel/Battery</th><th>Type</th><th>Added By</th><th>QC Status</th><th>Added On</th></tr></thead>
        <tbody>
        <%try(Connection conn=DBConnection.getConnection()){String sq2=searchQ.isEmpty()?"":"WHERE model_name LIKE '%"+searchQ.replace("'","''")+ "%' OR fuel_type LIKE '%"+searchQ.replace("'","''")+ "%'";ResultSet vv=conn.createStatement().executeQuery("SELECT * FROM vehicle "+sq2+" ORDER BY created_at DESC");int vn=0;boolean av=false;while(vv.next()){av=true;vn++;String vs=vv.getString("status");String vp="approved".equals(vs)?"pg":"rejected".equals(vs)?"pr":"po";%>
        <tr><td style="color:var(--muted);font-size:.78rem;"><%= vn %></td><td style="font-weight:700;"><%= vv.getString("model_name") %></td><td><%= vv.getInt("seating_capacity") %></td><td><%= vv.getDouble("fuel_battery_capacity") %> L/kWh</td><td><span class="p pgy" style="font-size:.7rem;"><%= vv.getString("fuel_type") %></span></td><td style="font-size:.83rem;"><%= vv.getString("added_by") %></td><td><span class="p <%= vp %>"><%= vs %></span></td><td style="font-size:.78rem;color:var(--muted);"><%= vv.getTimestamp("created_at")!=null?vv.getTimestamp("created_at").toString().substring(0,10):"—" %></td></tr>
        <%}if(!av){%><tr><td colspan="8"><div class="es"><div class="ei">🚗</div><p>No vehicles found.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="8" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /vehicles -->

<!-- ═══ TAB: QC HISTORY ═══ -->
<div id="tab-qc" class="tp <%= "qc".equals(activeTab)?"active":"" %>">
<div style="display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:20px;">
    <div class="sc c-gr"><div class="si">✅</div><div class="sn"><%= qcApprovals %></div><div class="sl">Total QC Approvals</div></div>
    <div class="sc c-rd"><div class="si">❌</div><div class="sn"><%= qcRejections %></div><div class="sl">Total QC Rejections</div></div>
</div>
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-shield-check" style="color:#2e7d32;"></i> QC Decision History</div><span style="font-size:.78rem;color:var(--muted);">Read-only</span></div>
    <table class="dt">
        <thead><tr><th>#</th><th>Vehicle</th><th>Decision</th><th>Severity</th><th>Defects</th><th>Inspector Notes</th><th>QC Officer</th><th>Date</th></tr></thead>
        <tbody>
        <%try(Connection conn=DBConnection.getConnection()){ResultSet qa=conn.createStatement().executeQuery("SELECT a.*,v.model_name FROM approvals a JOIN vehicle v ON a.vehicle_id=v.id ORDER BY a.id DESC");int qn=0;boolean aq=false;while(qa.next()){aq=true;qn++;String act=qa.getString("action");String sev="None";try{sev=qa.getString("severity")!=null?qa.getString("severity"):"None";}catch(Exception ig){}String defects="—";try{defects=qa.getString("defect_categories")!=null?qa.getString("defect_categories"):"—";}catch(Exception ig){}String inotes="—";try{String tmp=qa.getString("inspector_notes");inotes=tmp!=null&&!tmp.isEmpty()?tmp:"—";}catch(Exception ig){}String sp="Critical".equals(sev)?"pr":"Major".equals(sev)?"po":"Minor".equals(sev)?"pb2":"pgy";%>
        <tr><td style="color:var(--muted);font-size:.78rem;"><%= qn %></td><td style="font-weight:700;"><%= qa.getString("model_name") %></td><td><span class="p <%= "approved".equals(act)?"pg":"pr" %>"><%= act %></span></td><td><span class="p <%= sp %>"><%= sev %></span></td><td style="font-size:.78rem;max-width:130px;"><%= defects %></td><td style="font-size:.78rem;max-width:180px;color:var(--muted);"><%= inotes.length()>60?inotes.substring(0,60)+"...":inotes %></td><td style="font-size:.82rem;"><%= qa.getString("qc_user") %></td><td style="font-size:.78rem;color:var(--muted);white-space:nowrap;"><%= qa.getTimestamp("action_date")!=null?qa.getTimestamp("action_date").toString().substring(0,16):"—" %></td></tr>
        <%}if(!aq){%><tr><td colspan="8"><div class="es"><div class="ei">🛡️</div><p>No QC decisions yet.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="8" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /qc -->

<!-- ═══ TAB: TESTING HISTORY ═══ -->
<div id="tab-testing" class="tp <%= "testing".equals(activeTab)?"active":"" %>">
<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:20px;">
    <div class="sc c-gr"><div class="si">✅</div><div class="sn"><%= testPass %></div><div class="sl">Tests Passed</div></div>
    <div class="sc c-rd"><div class="si">❌</div><div class="sn"><%= testFail %></div><div class="sl">Tests Failed</div></div>
    <div class="sc c-or"><div class="si">⏳</div><div class="sn"><%= testPending %></div><div class="sl">Tests Pending</div></div>
</div>
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-flask-fill" style="color:#a855f7;"></i> All Testing Records</div><span style="font-size:.78rem;color:var(--muted);">Read-only</span></div>
    <table class="dt">
        <thead><tr><th>#</th><th>Vehicle</th><th>Test Type</th><th>Category</th><th>Result</th><th>Score</th><th>Remarks</th><th>Tested By</th><th>Date</th></tr></thead>
        <tbody>
        <%try(Connection conn=DBConnection.getConnection()){ResultSet ts=conn.createStatement().executeQuery("SELECT t.*,v.model_name FROM testing_status t JOIN vehicle v ON t.vehicle_id=v.id ORDER BY t.id DESC");int tn=0;boolean at=false;while(ts.next()){at=true;tn++;String tst=ts.getString("status");String tp2="pass".equals(tst)?"pg":"fail".equals(tst)?"pr":"po";int sc=0;try{sc=ts.getInt("test_score");}catch(Exception ig){}String cat="—";try{cat=ts.getString("test_category")!=null?ts.getString("test_category"):"—";}catch(Exception ig){}String sc2=sc>=75?"color:#2e7d32":sc>=50?"color:#e65100":"color:#c62828";%>
        <tr><td style="color:var(--muted);font-size:.78rem;"><%= tn %></td><td style="font-weight:700;"><%= ts.getString("model_name") %></td><td style="font-size:.82rem;"><%= ts.getString("test_type") %></td><td><span class="p pgy" style="font-size:.7rem;"><%= cat %></span></td><td><span class="p <%= tp2 %>"><%= tst %></span></td><td style="font-weight:700;font-size:.88rem;<%= sc2 %>"><%= sc>0?sc+"/100":"—" %></td><td style="font-size:.78rem;color:var(--muted);max-width:150px;"><%= ts.getString("test_remarks") %></td><td style="font-size:.82rem;"><%= ts.getString("tested_by") %></td><td style="font-size:.78rem;color:var(--muted);white-space:nowrap;"><%= ts.getTimestamp("test_date")!=null?ts.getTimestamp("test_date").toString().substring(0,16):"—" %></td></tr>
        <%}if(!at){%><tr><td colspan="9"><div class="es"><div class="ei">🔬</div><p>No test records yet.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="10" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /testing -->

<!-- ═══ TAB: CUSTOMERS ═══ -->
<div id="tab-customers" class="tp <%= "customers".equals(activeTab)?"active":"" %>">
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-people-fill" style="color:#ec4899;"></i> Registered Customers</div><span class="p" style="background:#fce4ec;color:#ad1457;"><%= totalCustomers %> total</span></div>
    <table class="dt">
        <thead><tr><th>#</th><th>Full Name</th><th>Email</th><th>Phone</th><th>📍 Location</th><th>Verified</th><th>Requirements</th></tr></thead>
        <tbody>
        <%try(Connection conn=DBConnection.getConnection()){ResultSet cs=conn.createStatement().executeQuery("SELECT c.*,(SELECT COUNT(*) FROM customer_requirements WHERE customer_id=c.id) AS req_count FROM customers c ORDER BY c.id DESC");int cn=0;boolean ac=false;while(cs.next()){ac=true;cn++;int iv=cs.getInt("is_verified");int rc=cs.getInt("req_count");String city="—";try{city=cs.getString("city")!=null&&!cs.getString("city").isEmpty()?cs.getString("city"):"—";}catch(Exception ig){}%>
        <tr><td style="color:var(--muted);font-size:.78rem;"><%= cn %></td><td style="font-weight:700;"><%= cs.getString("full_name") %></td><td style="font-size:.83rem;"><%= cs.getString("email") %></td><td style="font-size:.83rem;"><%= cs.getString("phone")!=null?cs.getString("phone"):"—" %></td><td style="font-size:.83rem;"><span style="display:inline-flex;align-items:center;gap:4px;background:#f0f7ff;padding:3px 10px;border-radius:8px;color:#0a6ebd;font-weight:600;"><i class="bi bi-geo-alt-fill" style="font-size:.7rem;"></i><%= city %></span></td><td><span class="p <%= iv==1?"pg":"po" %>"><%= iv==1?"✅ Verified":"⏳ Pending" %></span></td><td><span class="p pb2"><%= rc %> req<%= rc!=1?"s":"" %></span></td></tr>
        <%}if(!ac){%><tr><td colspan="7"><div class="es"><div class="ei">👤</div><p>No customers registered.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="7" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /customers -->

<!-- ═══ TAB: DESIGNER ROUTING ═══ -->
<div id="tab-designer_assign" class="tp <%= "designer_assign".equals(activeTab)?"active":"" %>">

<!-- ══ Design Team Routing Banner ══ -->
<div style="background:linear-gradient(135deg,#eff6ff,#dbeafe);border:2px solid #93c5fd;border-radius:14px;padding:22px 26px;margin-bottom:20px;display:flex;align-items:center;gap:12px;">
  <i class="bi bi-pencil-ruler" style="font-size:1.5rem;color:#1d4ed8;"></i>
  <div>
    <div style="font-family:'Syne',sans-serif;font-size:1.2rem;font-weight:800;color:#1e3a8a;">Design Team Routing</div>
    <div style="font-size:.82rem;color:#1d4ed8;">Round-robin per vehicle type — 8 specialist designer pools</div>
  </div>
  <a href="manage_designers.jsp" style="margin-left:auto;background:#1d4ed8;color:#fff;padding:8px 16px;border-radius:9px;font-size:.82rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;">
    <i class="bi bi-person-plus-fill"></i> Manage Design Team
  </a>
</div>

<%-- Designer action message --%>
<% if (!dsgMsg.isEmpty()) { %>
<div style="background:<%= "success".equals(dsgMsgType)?"#e8f5e9":"#ffebee" %>;border:1px solid <%= "success".equals(dsgMsgType)?"#a5d6a7":"#ef9a9a" %>;color:<%= "success".equals(dsgMsgType)?"#2e7d32":"#c62828" %>;border-radius:10px;padding:12px 18px;margin-bottom:16px;font-weight:700;font-size:.875rem;">
    <%= "success".equals(dsgMsgType) ? "&#10003; " : "&#10007; " %><%= dsgMsg %>
</div>
<% } %>

<%
String[][] dsgVtypes = {
    {"two_wheeler",   "Two Wheeler",    "Bike, Scooter, Electric 2W",          "&#128693;"},
    {"three_wheeler", "Three Wheeler",  "Auto, Electric Auto, Cargo 3W",        "&#128666;"},
    {"car",           "Car",            "Hatchback, Sedan, SUV, EV",            "&#128664;"},
    {"van",           "Van",            "Minivan, Cargo Van, Staff Van",         "&#128656;"},
    {"bus",           "Bus",            "Mini, Standard, Luxury, Electric Bus", "&#128652;"},
    {"lorry",         "Lorry / Truck",  "Light/Heavy Truck, Tipper, Tanker",    "&#128667;"},
    {"heavy_vehicle", "Heavy Vehicle",  "Tractor, JCB, Excavator, Crane",       "&#128668;"},
    {"special",       "Special Purpose","Ambulance, Fire Engine, Defence",       "&#128657;"}
};
try (Connection connDsg = DBConnection.getConnection()) {
    for (String[] dvt : dsgVtypes) {
        String dvtKey   = dvt[0];
        String dvtLabel = dvt[1];
        String dvtSub   = dvt[2];
        String dvtIcon  = dvt[3];

        java.util.List<Object[]> dsgList = new java.util.ArrayList<>();
        String dsgLoadError = null;
        try {
            PreparedStatement dlq = connDsg.prepareStatement(
                "SELECT vd.id, vd.slot_number, vd.full_name, vd.username, vd.is_active, u.last_active " +
                "FROM vehicle_designers vd LEFT JOIN users u ON CONVERT(vd.username USING utf8mb4) = CONVERT(u.username USING utf8mb4) " +
                "WHERE vd.vehicle_type=? ORDER BY vd.slot_number");
            dlq.setString(1, dvtKey);
            ResultSet dlr = dlq.executeQuery();
            while (dlr.next()) {
                dsgList.add(new Object[]{
                    dlr.getInt("id"), dlr.getInt("slot_number"),
                    dlr.getString("full_name") != null ? dlr.getString("full_name") : "",
                    dlr.getString("username")  != null ? dlr.getString("username")  : "",
                    dlr.getInt("is_active"), dlr.getTimestamp("last_active")
                });
            }
        } catch (Exception dsgEx) { dsgLoadError = dsgEx.getMessage(); }

        int dsgLastSlotInt = 0; int dsgTotalInt = 0;
        int dsgLastSlotExt = 0; int dsgTotalExt = 0;
        try {
            PreparedStatement rrq = connDsg.prepareStatement(
                "SELECT stream, last_slot_used, total_assigned FROM designer_round_robin WHERE vehicle_type=?");
            rrq.setString(1, dvtKey);
            ResultSet rrr = rrq.executeQuery();
            while (rrr.next()) {
                String st = rrr.getString("stream");
                if ("internal".equals(st)) { dsgLastSlotInt=rrr.getInt("last_slot_used"); dsgTotalInt=rrr.getInt("total_assigned"); }
                else                        { dsgLastSlotExt=rrr.getInt("last_slot_used"); dsgTotalExt=rrr.getInt("total_assigned"); }
            }
        } catch (Exception ig) {}

        int dsgTotal       = dsgList.size();
        // Next slot is based on INTERNAL counter (shown in header; each stream cycles independently)
        int dsgNextSlotInt = dsgTotal > 0 ? (dsgLastSlotInt % dsgTotal) + 1 : 1;
        int dsgNextSlotExt = dsgTotal > 0 ? (dsgLastSlotExt % dsgTotal) + 1 : 1;
        // For the NEXT badge in the table, highlight whichever slot is next for internal (admin just created job)
        int dsgNextSlot    = dsgNextSlotInt;
%>
<div style="background:#fff;border-radius:12px;border:1px solid #e5e9f2;margin-bottom:14px;overflow:hidden;">
    <div style="padding:12px 18px;background:#f8f9ff;border-bottom:1px solid #e5e9f2;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;">
        <div style="font-weight:700;font-size:.88rem;color:#1a1f36;display:flex;align-items:center;gap:8px;">
            <span style="font-size:1.2rem;"><%= dvtIcon %></span> <%= dvtLabel %>
        </div>
        <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
            <span style="background:#dbeafe;color:#1d4ed8;border:1px solid #93c5fd;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= dsgTotal %> member<%= dsgTotal!=1?"s":"" %></span>
            <% if (dsgTotal > 0) { %>
            <span style="background:#e8f0fe;color:#1a56db;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">&#127981; <%= dsgTotalInt %> internal</span>
            <span style="background:#e8f5e9;color:#2e7d32;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">&#129309; <%= dsgTotalExt %> external</span>
            <span style="background:#eff6ff;color:#1d4ed8;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">&#127981; Next &rarr; Slot <%= dsgNextSlotInt %></span>
            <span style="background:#f3e8ff;color:#7c3aed;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">&#129309; Next &rarr; Slot <%= dsgNextSlotExt %></span>
            <% } %>
        </div>
    </div>
    <% if (dsgList.isEmpty()) { %>
    <div style="padding:14px 18px;font-size:.82rem;color:#9ca3af;font-style:italic;">
        No designers for <%= dvtLabel %> yet &mdash;
        <a href="manage_designers.jsp" style="color:#1d4ed8;font-weight:700;">Add member</a>
    </div>
    <% } else { %>
    <table style="width:100%;border-collapse:collapse;font-size:.85rem;">
        <thead>
            <tr style="background:#f8f9ff;">
                <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Slot</th>
                <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Name</th>
                <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Username</th>
                <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Status</th>
                <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Online</th>
            </tr>
        </thead>
        <tbody>
        <% for (Object[] drow : dsgList) {
            int    drowSlot   = (Integer)   drow[1];
            String drowName   = (String)    drow[2];
            String drowUname  = (String)    drow[3];
            int    drowActive = (Integer)   drow[4];
            java.sql.Timestamp drowLast = (java.sql.Timestamp) drow[5];
            String dotColor = "#9ca3af"; String onlineTxt = "Offline";
            if (drowLast != null) {
                long diffM = (System.currentTimeMillis() - drowLast.getTime()) / 60000L;
                if      (diffM <= 5)  { dotColor = "#22c55e"; onlineTxt = "Online"; }
                else if (diffM <= 30) { dotColor = "#f59e0b"; onlineTxt = "Away (" + diffM + "m)"; }
            }
            boolean drowIsNext = (dsgTotal > 0 && drowSlot == dsgNextSlot);
        %>
        <tr style="border-bottom:1px solid #f0f3f9;<%= drowIsNext?"background:#eff6ff;":"" %>">
            <td style="padding:9px 14px;">
                <span style="display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border-radius:50%;background:#1d4ed8;color:#fff;font-weight:800;font-size:.75rem;"><%= drowSlot %></span>
                <% if (drowIsNext) { %><span style="font-size:.62rem;color:#1d4ed8;margin-left:5px;font-weight:700;background:#dbeafe;padding:1px 6px;border-radius:8px;">NEXT</span><% } %>
            </td>
            <td style="padding:9px 14px;font-weight:600;"><%= drowName %></td>
            <td style="padding:9px 14px;"><code style="background:#f1f5f9;padding:2px 7px;border-radius:5px;font-size:.78rem;">@<%= drowUname %></code></td>
            <td style="padding:9px 14px;">
                <span style="background:<%= drowActive==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 8px;border-radius:10px;font-size:.7rem;font-weight:700;">
                    <%= drowActive==1?"&#9679; Active":"&#9675; Inactive" %>
                </span>
            </td>
            <td style="padding:9px 14px;">
                <span style="width:8px;height:8px;border-radius:50%;background:<%= dotColor %>;display:inline-block;margin-right:5px;vertical-align:middle;"></span>
                <span style="font-size:.78rem;color:#6b7280;"><%= onlineTxt %></span>
            </td>
        </tr>
        <% } %>
        </tbody>
    </table>
    <% } %>
</div>
<%
    }
} catch (Exception dsgPageEx) { %>
<div style="background:#ffebee;padding:14px 18px;border-radius:10px;color:#c62828;font-weight:700;">
    Designer Tab Error: <%= dsgPageEx.getMessage() %>
</div>
<% } %>
</div><!-- /designer_assign -->

<!-- ═══ TAB: QC ROUTING ═══ -->
<div id="tab-qc_assign" class="tp <%= "qc_assign".equals(activeTab)?"active":"" %>">
<div style="background:linear-gradient(135deg,#f0fdf4,#dcfce7);border:2px solid #86efac;border-radius:14px;padding:22px 26px;margin-bottom:20px;display:flex;align-items:center;gap:12px;">
  <i class="bi bi-shield-check" style="font-size:1.5rem;color:#16a34a;"></i>
  <div>
    <div style="font-family:'Syne',sans-serif;font-size:1.2rem;font-weight:800;color:#14532d;">QC Team Routing</div>
    <div style="font-size:.82rem;color:#16a34a;">Round-robin per vehicle type — 8 specialist QC pools</div>
  </div>
  <a href="manage_qc_team.jsp" style="margin-left:auto;background:#16a34a;color:#fff;padding:8px 16px;border-radius:9px;font-size:.82rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;">
    <i class="bi bi-person-plus-fill"></i> Manage QC Team
  </a>
</div>
<%
String[][] rTabVt={{"two_wheeler","Two Wheeler"},{"three_wheeler","Three Wheeler"},{"car","Car"},{"van","Van"},{"bus","Bus"},{"lorry","Lorry / Truck"},{"heavy_vehicle","Heavy Vehicle"},{"special","Special Purpose"}};
try(Connection qcConn=DBConnection.getConnection()){
  for(String[] vt:rTabVt){
    String vtk=vt[0],vtl=vt[1];
    PreparedStatement qcRRq=qcConn.prepareStatement("SELECT last_slot_used,total_assigned FROM module_round_robin WHERE module_role='qc' AND vehicle_type=?");
    qcRRq.setString(1,vtk); ResultSet qcRR=qcRRq.executeQuery();
    int qcLast=0,qcTotalAsgn=0;
    if(qcRR.next()){qcLast=qcRR.getInt(1);qcTotalAsgn=qcRR.getInt(2);}
    PreparedStatement qcMq=qcConn.prepareStatement("SELECT * FROM module_team_members WHERE module_role='qc' AND vehicle_type=? ORDER BY slot_number");
    qcMq.setString(1,vtk); ResultSet qcM=qcMq.executeQuery();
    java.util.List<Object[]> qcList=new java.util.ArrayList<>();
    while(qcM.next()) qcList.add(new Object[]{qcM.getInt("id"),qcM.getInt("slot_number"),qcM.getString("full_name"),qcM.getString("username"),qcM.getInt("is_active")});
    int qcTotal=qcList.size(); int qcNext=qcTotal>0?(qcLast%qcTotal)+1:1;
%>
<div style="background:#fff;border-radius:12px;border:1px solid #e5e9f2;margin-bottom:14px;overflow:hidden;">
  <div style="padding:12px 18px;background:#f8f9ff;border-bottom:1px solid #e5e9f2;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;">
    <div style="font-weight:700;font-size:.88rem;color:#1a1f36;"><%= vtl %></div>
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
      <span style="background:#dcfce7;color:#15803d;border:1px solid #86efac;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= qcTotal %> member<%= qcTotal!=1?"s":"" %></span>
      <% if(qcTotal>0){ %>
      <span style="background:#f0fdf4;color:#15803d;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">Next &rarr; Slot <%= qcNext %></span>
      <span style="background:#f0fdf4;color:#15803d;border:1px solid #86efac;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= qcTotalAsgn %> routed</span>
      <% } %>
    </div>
  </div>
  <% if(qcList.isEmpty()){ %>
  <div style="padding:14px 18px;font-size:.82rem;color:#9ca3af;font-style:italic;">
    No QC members for <%= vtl %> yet &mdash; <a href="manage_qc_team.jsp" style="color:#16a34a;font-weight:700;">Add member</a>
  </div>
  <% } else { %>
  <table style="width:100%;border-collapse:collapse;font-size:.85rem;">
    <thead>
      <tr style="background:#f8f9ff;">
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Slot</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Name</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Username</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Status</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Online</th>
      </tr>
    </thead>
    <tbody>
    <% for(Object[] m:qcList){
        int sl=(Integer)m[1]; String fn=(String)m[2]; String un=(String)m[3]; int ia=(Integer)m[4];
        boolean nx=(sl==qcNext);
    %>
    <tr style="border-bottom:1px solid #f0f3f9;<%= nx?"background:#f0fdf4;":"" %>">
      <td style="padding:9px 14px;">
        <span style="display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border-radius:50%;background:#16a34a;color:#fff;font-weight:800;font-size:.75rem;"><%= sl %></span>
        <% if(nx){ %><span style="font-size:.62rem;color:#15803d;margin-left:5px;font-weight:700;background:#dcfce7;padding:1px 6px;border-radius:8px;">NEXT</span><% } %>
      </td>
      <td style="padding:9px 14px;font-weight:600;"><%= fn %></td>
      <td style="padding:9px 14px;"><code style="background:#f1f5f9;padding:2px 7px;border-radius:5px;font-size:.78rem;">@<%= un %></code></td>
      <td style="padding:9px 14px;"><span style="background:<%= ia==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 8px;border-radius:10px;font-size:.7rem;font-weight:700;"><%= ia==1?"&#9679; Active":"&#9675; Inactive" %></span></td>
      <td style="padding:9px 14px;"><span style="width:8px;height:8px;border-radius:50%;background:#9ca3af;display:inline-block;margin-right:5px;vertical-align:middle;"></span><span style="font-size:.78rem;color:#6b7280;">Offline</span></td>
    </tr>
    <% } %>
    </tbody>
  </table>
  <% } %>
</div>
<% } }catch(Exception qcEx){ %><div style="color:red;padding:12px;">Error: <%= qcEx.getMessage() %></div><% } %>
</div><!-- /qc_assign -->

<div id="tab-testing_assign" class="tp <%= "testing_assign".equals(activeTab)?"active":"" %>">
<div style="background:linear-gradient(135deg,#fffbeb,#fef3c7);border:2px solid #fde68a;border-radius:14px;padding:22px 26px;margin-bottom:20px;display:flex;align-items:center;gap:12px;">
  <i class="bi bi-flask-fill" style="font-size:1.5rem;color:#d97706;"></i>
  <div>
    <div style="font-family:'Syne',sans-serif;font-size:1.2rem;font-weight:800;color:#78350f;">Testing Team Routing</div>
    <div style="font-size:.82rem;color:#d97706;">Round-robin per vehicle type — 8 specialist testing pools</div>
  </div>
  <a href="manage_testing_team.jsp" style="margin-left:auto;background:#d97706;color:#fff;padding:8px 16px;border-radius:9px;font-size:.82rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;">
    <i class="bi bi-person-plus-fill"></i> Manage Testing Team
  </a>
</div>
<%
try(Connection tConn=DBConnection.getConnection()){
  for(String[] vt:rTabVt){
    String vtk=vt[0],vtl=vt[1];
    PreparedStatement tRRq=tConn.prepareStatement("SELECT last_slot_used,total_assigned FROM module_round_robin WHERE module_role='testing' AND vehicle_type=?");
    tRRq.setString(1,vtk); ResultSet tRR=tRRq.executeQuery();
    int tLast=0,tTotalAsgn=0;
    if(tRR.next()){tLast=tRR.getInt(1);tTotalAsgn=tRR.getInt(2);}
    PreparedStatement tMq=tConn.prepareStatement("SELECT * FROM module_team_members WHERE module_role='testing' AND vehicle_type=? ORDER BY slot_number");
    tMq.setString(1,vtk); ResultSet tM=tMq.executeQuery();
    java.util.List<Object[]> tList=new java.util.ArrayList<>();
    while(tM.next()) tList.add(new Object[]{tM.getInt("id"),tM.getInt("slot_number"),tM.getString("full_name"),tM.getString("username"),tM.getInt("is_active")});
    int tTotal=tList.size(); int tNext=tTotal>0?(tLast%tTotal)+1:1;
%>
<div style="background:#fff;border-radius:12px;border:1px solid #e5e9f2;margin-bottom:14px;overflow:hidden;">
  <div style="padding:12px 18px;background:#f8f9ff;border-bottom:1px solid #e5e9f2;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:8px;">
    <div style="font-weight:700;font-size:.88rem;color:#1a1f36;"><%= vtl %></div>
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
      <span style="background:#fef3c7;color:#92400e;border:1px solid #fde68a;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= tTotal %> member<%= tTotal!=1?"s":"" %></span>
      <% if(tTotal>0){ %>
      <span style="background:#fffbeb;color:#b45309;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;">Next &rarr; Slot <%= tNext %></span>
      <span style="background:#fffbeb;color:#b45309;border:1px solid #fde68a;padding:2px 10px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= tTotalAsgn %> routed</span>
      <% } %>
    </div>
  </div>
  <% if(tList.isEmpty()){ %>
  <div style="padding:14px 18px;font-size:.82rem;color:#9ca3af;font-style:italic;">
    No Testing members for <%= vtl %> yet &mdash; <a href="manage_testing_team.jsp" style="color:#d97706;font-weight:700;">Add member</a>
  </div>
  <% } else { %>
  <table style="width:100%;border-collapse:collapse;font-size:.85rem;">
    <thead>
      <tr style="background:#f8f9ff;">
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Slot</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Name</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Username</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Status</th>
        <th style="padding:8px 14px;text-align:left;font-size:.7rem;text-transform:uppercase;color:#9ca3af;">Online</th>
      </tr>
    </thead>
    <tbody>
    <% for(Object[] m:tList){
        int sl=(Integer)m[1]; String fn=(String)m[2]; String un=(String)m[3]; int ia=(Integer)m[4];
        boolean nx=(sl==tNext);
    %>
    <tr style="border-bottom:1px solid #f0f3f9;<%= nx?"background:#fffbeb;":"" %>">
      <td style="padding:9px 14px;">
        <span style="display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border-radius:50%;background:#d97706;color:#fff;font-weight:800;font-size:.75rem;"><%= sl %></span>
        <% if(nx){ %><span style="font-size:.62rem;color:#92400e;margin-left:5px;font-weight:700;background:#fef3c7;padding:1px 6px;border-radius:8px;">NEXT</span><% } %>
      </td>
      <td style="padding:9px 14px;font-weight:600;"><%= fn %></td>
      <td style="padding:9px 14px;"><code style="background:#f1f5f9;padding:2px 7px;border-radius:5px;font-size:.78rem;">@<%= un %></code></td>
      <td style="padding:9px 14px;"><span style="background:<%= ia==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 8px;border-radius:10px;font-size:.7rem;font-weight:700;"><%= ia==1?"&#9679; Active":"&#9675; Inactive" %></span></td>
      <td style="padding:9px 14px;"><span style="width:8px;height:8px;border-radius:50%;background:#9ca3af;display:inline-block;margin-right:5px;vertical-align:middle;"></span><span style="font-size:.78rem;color:#6b7280;">Offline</span></td>
    </tr>
    <% } %>
    </tbody>
  </table>
  <% } %>
</div>
<% } }catch(Exception tEx){ %><div style="color:red;padding:12px;">Error: <%= tEx.getMessage() %></div><% } %>
</div><!-- /testing_assign -->

<div id="tab-analytics_assign" class="tp <%= "analytics_assign".equals(activeTab)?"active":"" %>">
<div style="background:linear-gradient(135deg,#f5f3ff,#ede9fe);border:2px solid #c4b5fd;border-radius:14px;padding:18px 22px;margin-bottom:20px;display:flex;align-items:center;gap:12px;">
  <i class="bi bi-graph-up-arrow" style="font-size:1.5rem;color:#7c3aed;"></i>
  <div>
    <div style="font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;color:#4c1d95;">Analytics Team Routing</div>
    <div style="font-size:.8rem;color:#7c3aed;margin-top:2px;">Two separate pools — Internal analysts handle factory jobs · External analysts handle client orders</div>
  </div>
  <a href="manage_analytics_team.jsp" style="margin-left:auto;background:#7c3aed;color:#fff;padding:8px 16px;border-radius:9px;font-size:.82rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;white-space:nowrap;">
    <i class="bi bi-person-plus-fill"></i> Manage Team
  </a>
</div>

<%
try(Connection aConn=DBConnection.getConnection()){
  /* Internal pool */
  int aIntLast=0,aIntTotal2=0;
  try{ ResultSet r=aConn.createStatement().executeQuery("SELECT last_slot_used,total_assigned FROM module_round_robin WHERE module_role='analytics' AND vehicle_type='internal'");if(r.next()){aIntLast=r.getInt(1);aIntTotal2=r.getInt(2);} }catch(Exception ig){}
  java.util.List<Object[]> aIntList=new java.util.ArrayList<>();
  try{ ResultSet r=aConn.createStatement().executeQuery("SELECT id,slot_number,full_name,username,is_active FROM module_team_members WHERE module_role='analytics' AND vehicle_type='internal' ORDER BY slot_number");while(r.next())aIntList.add(new Object[]{r.getInt(1),r.getInt(2),r.getString(3),r.getString(4),r.getInt(5)}); }catch(Exception ig){}
  int aIntTotal=aIntList.size(); int aIntNext=aIntTotal>0?(aIntLast%aIntTotal)+1:1;

  /* External pool */
  int aExtLast=0,aExtTotal2=0;
  try{ ResultSet r=aConn.createStatement().executeQuery("SELECT last_slot_used,total_assigned FROM module_round_robin WHERE module_role='analytics' AND vehicle_type='external'");if(r.next()){aExtLast=r.getInt(1);aExtTotal2=r.getInt(2);} }catch(Exception ig){}
  java.util.List<Object[]> aExtList=new java.util.ArrayList<>();
  try{ ResultSet r=aConn.createStatement().executeQuery("SELECT id,slot_number,full_name,username,is_active FROM module_team_members WHERE module_role='analytics' AND vehicle_type='external' ORDER BY slot_number");while(r.next())aExtList.add(new Object[]{r.getInt(1),r.getInt(2),r.getString(3),r.getString(4),r.getInt(5)}); }catch(Exception ig){}
  int aExtTotal=aExtList.size(); int aExtNext=aExtTotal>0?(aExtLast%aExtTotal)+1:1;
%>

<div style="display:grid;grid-template-columns:1fr 1fr;gap:18px;">

  <%-- INTERNAL POOL --%>
  <div style="background:#fff;border-radius:12px;border:1px solid #e5e9f2;border-top:3px solid #1a237e;overflow:hidden;">
    <div style="padding:11px 16px;background:#e8eaf6;border-bottom:1px solid #c5cae9;display:flex;align-items:center;justify-content:space-between;">
      <div style="font-weight:800;font-size:.88rem;color:#1a237e;">🏭 Internal Analytics Pool</div>
      <div style="display:flex;gap:6px;">
        <span style="background:#c5cae9;color:#1a237e;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;"><%= aIntTotal %> members</span>
        <span style="background:#c5cae9;color:#1a237e;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;"><%= aIntTotal2 %> assigned</span>
        <% if(aIntTotal>0){ %><span style="background:#1a237e;color:#fff;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;">Next → Slot <%= aIntNext %></span><% } %>
      </div>
    </div>
    <% if(aIntList.isEmpty()){ %>
    <div style="padding:14px 16px;font-size:.81rem;color:#9ca3af;font-style:italic;">
      No internal analysts yet — <a href="manage_analytics_team.jsp" style="color:#1a237e;font-weight:700;">Add member</a>
    </div>
    <% } else { %>
    <table style="width:100%;border-collapse:collapse;font-size:.83rem;">
      <thead><tr style="background:#f8f9ff;">
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Slot</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Name</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Username</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Status</th>
      </tr></thead>
      <tbody>
      <% for(Object[] m:aIntList){ int sl=(Integer)m[1];String fn=(String)m[2];String un=(String)m[3];int ia=(Integer)m[4];boolean nx=(aIntTotal>0&&sl==aIntNext); %>
      <tr style="border-bottom:1px solid #f0f3f9;<%= nx?"background:#e8eaf6;":"" %>">
        <td style="padding:8px 12px;">
          <span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border-radius:50%;background:#1a237e;color:#fff;font-weight:800;font-size:.7rem;"><%= sl %></span>
          <% if(nx){ %><span style="font-size:.6rem;color:#1a237e;margin-left:4px;font-weight:800;">NEXT</span><% } %>
        </td>
        <td style="padding:8px 12px;font-weight:700;font-size:.83rem;"><%= fn %></td>
        <td style="padding:8px 12px;"><code style="background:#f1f5f9;padding:2px 6px;border-radius:4px;font-size:.76rem;">@<%= un %></code></td>
        <td style="padding:8px 12px;"><span style="background:<%= ia==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 7px;border-radius:8px;font-size:.69rem;font-weight:700;"><%= ia==1?"● Active":"○ Inactive" %></span></td>
      </tr>
      <% } %>
      </tbody>
    </table>
    <% } %>
  </div>

  <%-- EXTERNAL POOL --%>
  <div style="background:#fff;border-radius:12px;border:1px solid #e5e9f2;border-top:3px solid #1b5e20;overflow:hidden;">
    <div style="padding:11px 16px;background:#e8f5e9;border-bottom:1px solid #c8e6c9;display:flex;align-items:center;justify-content:space-between;">
      <div style="font-weight:800;font-size:.88rem;color:#1b5e20;">📦 External Analytics Pool</div>
      <div style="display:flex;gap:6px;">
        <span style="background:#c8e6c9;color:#1b5e20;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;"><%= aExtTotal %> members</span>
        <span style="background:#c8e6c9;color:#1b5e20;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;"><%= aExtTotal2 %> assigned</span>
        <% if(aExtTotal>0){ %><span style="background:#1b5e20;color:#fff;padding:2px 9px;border-radius:10px;font-size:.69rem;font-weight:700;">Next → Slot <%= aExtNext %></span><% } %>
      </div>
    </div>
    <% if(aExtList.isEmpty()){ %>
    <div style="padding:14px 16px;font-size:.81rem;color:#9ca3af;font-style:italic;">
      No external analysts yet — <a href="manage_analytics_team.jsp" style="color:#1b5e20;font-weight:700;">Add member</a>
    </div>
    <% } else { %>
    <table style="width:100%;border-collapse:collapse;font-size:.83rem;">
      <thead><tr style="background:#f8f9ff;">
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Slot</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Name</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Username</th>
        <th style="padding:7px 12px;text-align:left;font-size:.68rem;text-transform:uppercase;color:#9ca3af;">Status</th>
      </tr></thead>
      <tbody>
      <% for(Object[] m:aExtList){ int sl=(Integer)m[1];String fn=(String)m[2];String un=(String)m[3];int ia=(Integer)m[4];boolean nx=(aExtTotal>0&&sl==aExtNext); %>
      <tr style="border-bottom:1px solid #f0f3f9;<%= nx?"background:#e8f5e9;":"" %>">
        <td style="padding:8px 12px;">
          <span style="display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;border-radius:50%;background:#1b5e20;color:#fff;font-weight:800;font-size:.7rem;"><%= sl %></span>
          <% if(nx){ %><span style="font-size:.6rem;color:#1b5e20;margin-left:4px;font-weight:800;">NEXT</span><% } %>
        </td>
        <td style="padding:8px 12px;font-weight:700;font-size:.83rem;"><%= fn %></td>
        <td style="padding:8px 12px;"><code style="background:#f1f5f9;padding:2px 6px;border-radius:4px;font-size:.76rem;">@<%= un %></code></td>
        <td style="padding:8px 12px;"><span style="background:<%= ia==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 7px;border-radius:8px;font-size:.69rem;font-weight:700;"><%= ia==1?"● Active":"○ Inactive" %></span></td>
      </tr>
      <% } %>
      </tbody>
    </table>
    <% } %>
  </div>

</div><%-- /grid --%>
<% }catch(Exception aEx){ %><div style="color:red;padding:12px;">Error: <%= aEx.getMessage() %></div><% } %>
</div><!-- /analytics_assign -->
<!-- ═══ TAB: ALL USERS ═══ -->
<div id="tab-all_users" class="tp <%= "all_users".equals(activeTab)?"active":"" %>">
<div class="card">
  <div class="ch">
    <div class="ct"><i class="bi bi-people-fill" style="color:var(--brand);"></i> All Registered Users</div>
    <div style="font-size:.78rem;color:var(--muted);">View all system users and their roles</div>
  </div>
  <div style="overflow-x:auto;">
    <table style="width:100%;border-collapse:collapse;font-size:.86rem;">
      <thead><tr style="background:#f8f9ff;">
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">#</th>
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">Full Name</th>
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">Username</th>
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">Role</th>
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">Status</th>
        <th style="padding:10px 16px;text-align:left;font-weight:700;font-size:.73rem;text-transform:uppercase;color:#6b7280;border-bottom:2px solid #e5e9f2;">Created</th>
      </tr></thead>
      <tbody>
      <%try(Connection conn=DBConnection.getConnection()){
          ResultSet ru=conn.createStatement().executeQuery("SELECT * FROM users ORDER BY role,id");
          int n=0;
          while(ru.next()){n++;
            String uRole=ru.getString("role"); int active=ru.getInt("is_active");
            String roleBg="admin".equals(uRole)?"#fee2e2;color:#991b1b":"design".equals(uRole)?"#eff6ff;color:#1d4ed8":"qc".equals(uRole)?"#f0fdf4;color:#15803d":"testing".equals(uRole)?"#fffbeb;color:#d97706":"analytics".equals(uRole)?"#f5f3ff;color:#6d28d9":"#f1f5f9;color:#475569";
      %>
        <tr style="border-bottom:1px solid #f0f3f9;">
          <td style="padding:10px 16px;color:#9ca3af;font-size:.78rem;"><%= n %></td>
          <td style="padding:10px 16px;font-weight:700;"><%= ru.getString("full_name") %></td>
          <td style="padding:10px 16px;"><code style="background:#f1f5f9;padding:2px 8px;border-radius:5px;font-size:.8rem;"><%= ru.getString("username") %></code></td>
          <td style="padding:10px 16px;"><span style="background:<%= roleBg %>;padding:2px 9px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= uRole.toUpperCase() %></span></td>
          <td style="padding:10px 16px;"><span style="background:<%= active==1?"#dcfce7;color:#15803d":"#fee2e2;color:#b91c1c" %>;padding:2px 9px;border-radius:12px;font-size:.72rem;font-weight:700;"><%= active==1?"● Active":"○ Inactive" %></span></td>
          <td style="padding:10px 16px;font-size:.78rem;color:#9ca3af;"><%= ru.getTimestamp("created_at")!=null?ru.getTimestamp("created_at").toString().substring(0,10):"—" %></td>
        </tr>
      <%}if(n==0){%><tr><td colspan="6" style="text-align:center;padding:40px;color:#9ca3af;font-style:italic;">No users found.</td></tr>
      <%}}catch(Exception e){%><tr><td colspan="6" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
      </tbody>
    </table>
  </div>
</div>
</div><!-- /all_users -->

<!-- ═══ TAB: FINAL REPORT ═══ -->
<div id="tab-final_report" class="tp <%= "final_report".equals(activeTab)?"active":"" %>">
<div class="card" style="text-align:center;padding:40px 20px;">
  <i class="bi bi-file-earmark-bar-graph-fill" style="font-size:3rem;color:var(--brand);opacity:.6;"></i>
  <div style="font-family:'Syne',sans-serif;font-size:1.2rem;font-weight:800;color:var(--brand);margin:12px 0 6px;">Final Production Report</div>
  <div style="font-size:.85rem;color:var(--muted);margin-bottom:20px;">View complete production analytics and final approval report</div>
  <a href="${pageContext.request.contextPath}/jsp/final_report.jsp" target="_blank"
     style="display:inline-flex;align-items:center;gap:8px;background:linear-gradient(135deg,var(--brand),#1a3a8f);color:#fff;padding:12px 28px;border-radius:10px;text-decoration:none;font-weight:700;font-size:.9rem;">
    <i class="bi bi-box-arrow-up-right"></i> Open Final Report
  </a>
</div>
</div><!-- /final_report -->

<!-- ═══ TAB: FINAL APPROVAL ═══ -->
<div id="tab-final_approval" class="tp <%= "final_approval".equals(activeTab)?"active":"" %>">
<%
/* ── FINAL APPROVAL ACTION HANDLER ── */
String faAction  = request.getParameter("faAction");
String faJobId   = request.getParameter("faJobId");
String faSrcType = request.getParameter("faSrcType");
String faMsg     = "";
String faMsgType = "";
if(faAction!=null && faJobId!=null && faSrcType!=null){
    try(Connection faConn=DBConnection.getConnection()){
        int fid=Integer.parseInt(faJobId.trim());
        String newStage = "approved".equals(faAction)?"completed":"final_rejected";
        String updSql;
        if("internal".equals(faSrcType)) updSql="UPDATE internal_jobs SET workflow_stage=?,current_assignee='admin' WHERE id=?";
        else if("external".equals(faSrcType)) updSql="UPDATE external_orders SET workflow_stage=?,current_assignee='admin' WHERE id=?";
        else updSql="UPDATE customer_requirements SET workflow_stage=?,current_assignee='admin' WHERE id=?";
        PreparedStatement fap=faConn.prepareStatement(updSql);
        fap.setString(1,newStage); fap.setInt(2,fid); fap.executeUpdate();
        try{
            PreparedStatement fah=faConn.prepareStatement("INSERT INTO unified_workflow_history(source_type,source_id,stage,action,remarks,actioned_by) VALUES(?,?,'final_approval',?,?,?)");
            fah.setString(1,faSrcType); fah.setInt(2,fid); fah.setString(3,faAction);
            fah.setString(4,"Final "+faAction+" by admin"); fah.setString(5,(String)session.getAttribute("username"));
            fah.executeUpdate();
        }catch(Exception ig){}
        faMsg="approved".equals(faAction)?"Job approved and marked as completed.":"Job rejected at final review.";
        faMsgType="approved".equals(faAction)?"success":"error";
    }catch(Exception fe){faMsg="Error: "+fe.getMessage();faMsgType="error";}
}
%>

<% if(!faMsg.isEmpty()){ %>
<div style="padding:10px 16px;border-radius:10px;margin-bottom:18px;font-size:.85rem;font-weight:700;
  background:<%= "success".equals(faMsgType)?"#dcfce7":"#fee2e2" %>;
  color:<%= "success".equals(faMsgType)?"#166534":"#991b1b" %>;
  border:1px solid <%= "success".equals(faMsgType)?"#a7f3d0":"#fca5a5" %>;">
  <%= "success".equals(faMsgType)?"✅ ":"❌ " %><%= faMsg %>
</div>
<% } %>

<%
/* ── LOAD ALL ANALYTICS_COMPLETED JOBS (internal + external + cr) ── */
java.util.List<Object[]> faJobs = new java.util.ArrayList<>();
try(Connection faConn=DBConnection.getConnection()){
    /* Internal jobs */
    try{
        ResultSet fir=faConn.createStatement().executeQuery(
            "SELECT ij.id,'internal' AS src,COALESCE(ij.job_number,CONCAT('INT-',ij.id)) AS ref,"+
            "COALESCE(ij.model_name,'—') AS title,COALESCE(ij.vehicle_type,'—') AS vtype,"+
            "COALESCE(ij.brand_name,'—') AS client,"+
            "COALESCE(a.market_segment,'—') AS market,"+
            "COALESCE(a.cost_estimate,0) AS cost,COALESCE(a.projected_units,0) AS units,"+
            "COALESCE(a.roi_pct,0) AS roi,COALESCE(a.risk_level,'—') AS risk,"+
            "COALESCE(a.recommendation,'—') AS rec,COALESCE(a.analyst_user,'—') AS analyst,"+
            "COALESCE(a.analyst_notes,'') AS notes,"+
            "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres "+
            "FROM internal_jobs ij "+
            "LEFT JOIN analytics_submissions a ON a.job_ref_id=ij.id AND a.source_type='internal' "+
            "LEFT JOIN testing_results tr ON tr.job_ref_id=ij.id AND tr.source_type='internal' "+
            "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=ij.id AND source_type='internal' ORDER BY id DESC LIMIT 1) "+
            "WHERE ij.workflow_stage='analytics_completed' ORDER BY ij.id DESC");
        while(fir.next()) faJobs.add(new Object[]{
            fir.getInt("id"),fir.getString("src"),fir.getString("ref"),fir.getString("title"),
            fir.getString("vtype"),fir.getString("client"),fir.getString("market"),
            fir.getDouble("cost"),fir.getInt("units"),fir.getDouble("roi"),
            fir.getString("risk"),fir.getString("rec"),fir.getString("analyst"),
            fir.getString("notes"),fir.getInt("tscore"),fir.getString("tres")
        });
    }catch(Exception ig){}
    /* External orders */
    try{
        ResultSet fer=faConn.createStatement().executeQuery(
            "SELECT eo.id,'external' AS src,COALESCE(eo.order_number,CONCAT('EXT-',eo.id)) AS ref,"+
            "CONCAT(eo.client_name,' — Bulk') AS title,COALESCE(eo.vehicle_type,'—') AS vtype,"+
            "COALESCE(eo.client_name,'—') AS client,"+
            "COALESCE(a.market_segment,'—') AS market,"+
            "COALESCE(a.cost_estimate,0) AS cost,COALESCE(a.projected_units,0) AS units,"+
            "COALESCE(a.roi_pct,0) AS roi,COALESCE(a.risk_level,'—') AS risk,"+
            "COALESCE(a.recommendation,'—') AS rec,COALESCE(a.analyst_user,'—') AS analyst,"+
            "COALESCE(a.analyst_notes,'') AS notes,"+
            "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres "+
            "FROM external_orders eo "+
            "LEFT JOIN analytics_submissions a ON a.job_ref_id=eo.id AND a.source_type='external' "+
            "LEFT JOIN testing_results tr ON tr.job_ref_id=eo.id AND tr.source_type='external' "+
            "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=eo.id AND source_type='external' ORDER BY id DESC LIMIT 1) "+
            "WHERE eo.workflow_stage='analytics_completed' ORDER BY eo.id DESC");
        while(fer.next()) faJobs.add(new Object[]{
            fer.getInt("id"),fer.getString("src"),fer.getString("ref"),fer.getString("title"),
            fer.getString("vtype"),fer.getString("client"),fer.getString("market"),
            fer.getDouble("cost"),fer.getInt("units"),fer.getDouble("roi"),
            fer.getString("risk"),fer.getString("rec"),fer.getString("analyst"),
            fer.getString("notes"),fer.getInt("tscore"),fer.getString("tres")
        });
    }catch(Exception ig){}
    /* Customer requirements */
    try{
        ResultSet fcr=faConn.createStatement().executeQuery(
            "SELECT cr.id,'cr' AS src,CONCAT('CR-',cr.id) AS ref,COALESCE(cr.req_title,'—') AS title,"+
            "COALESCE(cr.vehicle_type,'—') AS vtype,COALESCE(c.full_name,cr.client_name,'—') AS client,"+
            "COALESCE(a.market_segment,'—') AS market,"+
            "COALESCE(a.cost_estimate,0) AS cost,COALESCE(a.projected_units,0) AS units,"+
            "COALESCE(a.roi_pct,0) AS roi,COALESCE(a.risk_level,'—') AS risk,"+
            "COALESCE(a.recommendation,'—') AS rec,COALESCE(a.analyst_user,'—') AS analyst,"+
            "COALESCE(a.analyst_notes,'') AS notes,"+
            "COALESCE(tr.overall_score,0) AS tscore,COALESCE(tr.overall_result,'—') AS tres "+
            "FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id "+
            "LEFT JOIN analytics_submissions a ON a.job_ref_id=cr.id AND a.source_type='cr' "+
            "LEFT JOIN testing_results tr ON tr.job_ref_id=cr.id AND tr.source_type='cr' "+
            "  AND tr.id=(SELECT id FROM testing_results WHERE job_ref_id=cr.id AND source_type='cr' ORDER BY id DESC LIMIT 1) "+
            "WHERE cr.workflow_stage='analytics_completed' ORDER BY cr.id DESC");
        while(fcr.next()) faJobs.add(new Object[]{
            fcr.getInt("id"),fcr.getString("src"),fcr.getString("ref"),fcr.getString("title"),
            fcr.getString("vtype"),fcr.getString("client"),fcr.getString("market"),
            fcr.getDouble("cost"),fcr.getInt("units"),fcr.getDouble("roi"),
            fcr.getString("risk"),fcr.getString("rec"),fcr.getString("analyst"),
            fcr.getString("notes"),fcr.getInt("tscore"),fcr.getString("tres")
        });
    }catch(Exception ig){}
}catch(Exception ig){}
%>

<!-- Header -->
<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
  <div>
    <div style="font-family:'Syne',sans-serif;font-size:1.1rem;font-weight:800;color:#0f1f5c;">
      <i class="bi bi-check2-circle" style="color:#dc2626;"></i> Final Approval Queue
    </div>
    <div style="font-size:.78rem;color:var(--muted);margin-top:3px;">
      Jobs completed by analytics — review and give final approval or rejection
    </div>
  </div>
  <span style="background:#fee2e2;color:#dc2626;border:1px solid #fca5a5;padding:5px 14px;border-radius:20px;font-size:.76rem;font-weight:700;">
    <%= faJobs.size() %> pending approval
  </span>
</div>

<% if(faJobs.isEmpty()){ %>
<div class="card" style="text-align:center;padding:48px 20px;">
  <i class="bi bi-check2-all" style="font-size:2.5rem;color:#22c55e;opacity:.5;display:block;margin-bottom:12px;"></i>
  <div style="font-weight:700;font-size:.95rem;color:#1a1f36;margin-bottom:5px;">All clear</div>
  <div style="font-size:.82rem;color:var(--muted);">No jobs pending final approval right now.</div>
</div>
<% } else {

/* Group by stream */
java.util.List<Object[]> intJobs=new java.util.ArrayList<>(), extJobs=new java.util.ArrayList<>();
for(Object[] j:faJobs){ if("internal".equals(j[1])) intJobs.add(j); else extJobs.add(j); }

/* Render a stream section */
java.util.List<java.util.List<Object[]>> streams = new java.util.ArrayList<>();
streams.add(intJobs); streams.add(extJobs);
String[] streamLabels={"🏭 Internal Jobs","📦 External & Customer Orders"};
String[] streamKeys={"internal","external"};
String[] streamColors={"#1a237e","#1b5e20"};
String[] streamBg={"#e8eaf6","#e8f5e9"};

for(int si=0;si<2;si++){
    java.util.List<Object[]> sJobs=streams.get(si);
    if(sJobs.isEmpty()) continue;
%>

<div style="margin-bottom:28px;">
  <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;">
    <div style="font-size:.8rem;font-weight:800;color:<%= streamColors[si] %>;text-transform:uppercase;letter-spacing:.06em;
      background:<%= streamBg[si] %>;border-radius:20px;padding:4px 14px;">
      <%= streamLabels[si] %> — <%= sJobs.size() %> pending
    </div>
    <div style="flex:1;height:1px;background:#eee;"></div>
  </div>

  <% for(Object[] j:sJobs){
    int fid=(Integer)j[0]; String fsrc=(String)j[1],fref=(String)j[2],ftitle=(String)j[3];
    String fvtype=(String)j[4],fclient=(String)j[5],fmarket=(String)j[6];
    double fcost=(Double)j[7]; int funits=(Integer)j[8]; double froi=(Double)j[9];
    String frisk=(String)j[10],frec=(String)j[11],fanalyst=(String)j[12];
    String fnotes=(String)j[13]; int ftscore=(Integer)j[14]; String ftres=(String)j[15];
    String recColor="Approve".equals(frec)?"#166534":"Reject".equals(frec)?"#991b1b":"#854d0e";
    String recBg="Approve".equals(frec)?"#dcfce7":"Reject".equals(frec)?"#fee2e2":"#fef9c3";
    String riskColor="High".equals(frisk)?"#991b1b":"Medium".equals(frisk)?"#854d0e":"#166534";
    String riskBg="High".equals(frisk)?"#fee2e2":"Medium".equals(frisk)?"#fef9c3":"#dcfce7";
    String scoreColor=ftscore>=75?"#166534":ftscore>=50?"#854d0e":"#991b1b";
  %>
  <div style="background:#fff;border:1px solid #eee;border-radius:16px;margin-bottom:16px;overflow:hidden;
    border-left:4px solid <%= streamColors[si] %>;box-shadow:0 2px 10px rgba(0,0,0,.05);">

    <%-- Header row --%>
    <div style="padding:14px 20px;display:flex;align-items:center;gap:14px;border-bottom:1px solid #f5f5f5;">
      <div style="background:<%= streamBg[si] %>;color:<%= streamColors[si] %>;border-radius:9px;padding:6px 12px;
        font-size:.75rem;font-weight:800;font-family:'Syne',sans-serif;letter-spacing:.5px;">
        <%= fref %>
      </div>
      <div style="flex:1;">
        <div style="font-weight:800;font-size:.95rem;color:#1a1f36;"><%= ftitle %></div>
        <div style="font-size:.76rem;color:var(--muted);margin-top:2px;">
          <%= fvtype.replace("_"," ").toUpperCase() %> &nbsp;·&nbsp;
          <%= "internal".equals(fsrc)?"Brand":"Client" %>: <%= fclient %> &nbsp;·&nbsp;
          Analyst: <%= fanalyst %>
        </div>
      </div>
      <span style="background:<%= recBg %>;color:<%= recColor %>;padding:5px 14px;border-radius:20px;
        font-size:.76rem;font-weight:800;border:1px solid <%= recColor %>22;">
        Analyst: <%= "Approve".equals(frec)?"✓ Approve":"Reject".equals(frec)?"✗ Reject":"⚠ Conditional" %>
      </span>
    </div>

    <%-- Analytics data row --%>
    <div style="padding:14px 20px;display:grid;grid-template-columns:repeat(5,1fr);gap:14px;background:#fafbff;border-bottom:1px solid #f0f0f0;">
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Market Segment</div>
        <div style="font-size:.83rem;font-weight:700;color:#1a1f36;"><%= fmarket %></div>
      </div>
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Cost Estimate</div>
        <div style="font-size:.83rem;font-weight:700;color:#1a237e;">₹<%= String.format("%,.0f",fcost) %></div>
      </div>
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Projected Units</div>
        <div style="font-size:.83rem;font-weight:700;color:#1a1f36;"><%= funits %></div>
      </div>
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Expected ROI</div>
        <div style="font-size:.83rem;font-weight:700;color:<%= froi>=15?"#166534":froi>=0?"#854d0e":"#991b1b" %>"><%= froi %>%</div>
      </div>
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Risk Level</div>
        <span style="background:<%= riskBg %>;color:<%= riskColor %>;padding:2px 10px;border-radius:12px;font-size:.73rem;font-weight:700;">
          <%= frisk %>
        </span>
      </div>
    </div>

    <%-- Test score + Analyst notes row --%>
    <div style="padding:14px 20px;display:grid;grid-template-columns:160px 1fr;gap:18px;border-bottom:1px solid #f0f0f0;">
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;">Test Score</div>
        <div style="display:flex;align-items:center;gap:10px;">
          <div style="font-size:1.6rem;font-weight:900;color:<%= scoreColor %>;font-family:'Syne',sans-serif;"><%= ftscore %>%</div>
          <div>
            <div style="width:80px;height:6px;background:#eee;border-radius:3px;overflow:hidden;margin-bottom:3px;">
              <div style="width:<%= ftscore %>%;height:100%;background:<%= scoreColor %>;border-radius:3px;"></div>
            </div>
            <div style="font-size:.72rem;color:var(--muted);"><%= ftres %></div>
          </div>
        </div>
      </div>
      <div>
        <div style="font-size:.68rem;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px;">Analyst Notes</div>
        <div style="font-size:.82rem;color:#374151;line-height:1.6;background:#f9fafb;border-radius:8px;padding:10px 12px;border-left:3px solid <%= streamColors[si] %>;">
          <%= fnotes.length()>300?fnotes.substring(0,300)+"…":fnotes.isEmpty()?"No notes provided.":fnotes %>
        </div>
      </div>
    </div>

    <%-- Action buttons --%>
    <div style="padding:14px 20px;display:flex;align-items:center;gap:12px;background:#fafbff;">
      <span style="font-size:.78rem;color:var(--muted);flex:1;">
        <i class="bi bi-info-circle"></i>
        Approving marks this job as <strong>completed</strong>. Rejecting sends it back for review.
      </span>
      <form method="post" action="admin_dashboard.jsp?tab=final_approval" style="display:inline;">
        <input type="hidden" name="faAction"  value="rejected">
        <input type="hidden" name="faJobId"   value="<%= fid %>">
        <input type="hidden" name="faSrcType" value="<%= fsrc %>">
        <button type="submit"
          onclick="return confirm('Reject this job and send back for review?')"
          style="background:#fff;border:1.5px solid #ef4444;color:#dc2626;border-radius:9px;padding:8px 20px;
            font-weight:700;font-size:.82rem;cursor:pointer;display:flex;align-items:center;gap:6px;transition:all .15s;"
          onmouseover="this.style.background='#fee2e2'" onmouseout="this.style.background='#fff'">
          <i class="bi bi-x-circle-fill"></i> Reject
        </button>
      </form>
      <form method="post" action="admin_dashboard.jsp?tab=final_approval" style="display:inline;">
        <input type="hidden" name="faAction"  value="approved">
        <input type="hidden" name="faJobId"   value="<%= fid %>">
        <input type="hidden" name="faSrcType" value="<%= fsrc %>">
        <button type="submit"
          onclick="return confirm('Approve this job and mark as COMPLETED?')"
          style="background:linear-gradient(135deg,#16a34a,#22c55e);border:none;color:#fff;border-radius:9px;padding:8px 24px;
            font-weight:700;font-size:.82rem;cursor:pointer;display:flex;align-items:center;gap:6px;transition:opacity .15s;"
          onmouseover="this.style.opacity='.88'" onmouseout="this.style.opacity='1'">
          <i class="bi bi-check2-circle"></i> Approve & Complete
        </button>
      </form>
    </div>

  </div>
  <% } %>
</div>
<% } } %>

</div><!-- /final_approval -->



<!-- ═══ TAB: INTERNAL JOBS ═══ -->
<div id="tab-internal" class="tp <%= "internal".equals(activeTab)?"active":"" %>">
<div class="card">
    <div class="ch">
        <div class="ct"><i class="bi bi-hammer" style="color:#6c63ff;"></i> 🏭 Internal Manufacturing Jobs</div>
        <a href="create_internal_job.jsp" style="background:linear-gradient(135deg,#5b52e0,#6c63ff);color:#fff;padding:8px 16px;border-radius:10px;font-size:.8rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;">
            <i class="bi bi-plus-circle"></i> Create New Job
        </a>
    </div>
    <%
    // Summary stats for internal
    int intTotal=0,intPending=0,intInDesign=0,intCompleted=0;
    try(Connection cInt=DBConnection.getConnection()){
        ResultSet ri;
        try{ri=cInt.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs");if(ri.next())intTotal=ri.getInt(1);}catch(Exception ig){}
        try{ri=cInt.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE status='pending'");if(ri.next())intPending=ri.getInt(1);}catch(Exception ig){}
        try{ri=cInt.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE workflow_stage='in_design' OR current_assignee='design'");if(ri.next())intInDesign=ri.getInt(1);}catch(Exception ig){}
        try{ri=cInt.createStatement().executeQuery("SELECT COUNT(*) FROM internal_jobs WHERE status='completed'");if(ri.next())intCompleted=ri.getInt(1);}catch(Exception ig){}
    }catch(Exception ig){}
    %>
    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px;padding:16px 0 20px;">
        <div style="background:#f0eeff;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#6c63ff;"><%= intTotal %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Total Jobs</div>
        </div>
        <div style="background:#fff8e1;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#f59e0b;"><%= intPending %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Pending</div>
        </div>
        <div style="background:#dbeafe;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#2563eb;"><%= intInDesign %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">In Design</div>
        </div>
        <div style="background:#dcfce7;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#16a34a;"><%= intCompleted %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Completed</div>
        </div>
    </div>
    <table class="dt">
        <thead><tr><th>#</th><th>Job No.</th><th>Brand</th><th>Vehicle Category</th><th>Model</th><th>Qty</th><th>Vehicle Type</th><th>Stage</th><th>Target Date</th><th>Created</th></tr></thead>
        <tbody>
        <%
        boolean anyInt=false;
        try(Connection cInt2=DBConnection.getConnection()){
            ResultSet rInt=cInt2.createStatement().executeQuery("SELECT * FROM internal_jobs ORDER BY id DESC");
            int inum=0;
            while(rInt.next()){
                anyInt=true; inum++;
                String iStage=rInt.getString("workflow_stage"); if(iStage==null)iStage="admin_created";
                String iVtype="";try{iVtype=rInt.getString("vehicle_type")!=null?rInt.getString("vehicle_type"):"";iVtype=iVtype.replace("_"," ");}catch(Exception ig){}
                String iStageCls=iStage.contains("completed")?"pg":iStage.contains("rejected")?"pr":iStage.contains("design")?"pb2":"po";
        %>
        <tr>
            <td style="color:var(--muted);font-size:.78rem;"><%= inum %></td>
            <td><code style="color:#6c63ff;font-weight:700;background:#f0eeff;padding:2px 8px;border-radius:6px;font-size:.78rem;"><%= rInt.getString("job_number") %></code></td>
            <td><span class="p" style="background:#f0eeff;color:#6c63ff;font-size:.76rem;">🏭 <%= rInt.getString("brand_name") %></span></td>
            <td style="font-size:.82rem;"><%= rInt.getString("vehicle_category") %></td>
            <td style="font-weight:600;font-size:.84rem;"><%= rInt.getString("model_name") %></td>
            <td style="font-weight:700;color:#6c63ff;"><%= rInt.getInt("quantity") %></td>
            <td><span class="p pb2" style="font-size:.68rem;background:#e0f2fe;color:#0369a1;"><%= iVtype.isEmpty()?"—":iVtype.toUpperCase() %></span></td>
            <td><span class="p <%= iStageCls %>" style="font-size:.72rem;"><%= iStage.replace("_"," ") %></span></td>
            <td style="font-size:.8rem;color:var(--muted);"><%= rInt.getString("target_date")!=null?rInt.getString("target_date"):"—" %></td>
            <td style="font-size:.78rem;color:var(--muted);"><%= rInt.getTimestamp("created_at")!=null?rInt.getTimestamp("created_at").toString().substring(0,10):"—" %></td>
        </tr>
        <% } if(!anyInt){ %><tr><td colspan="10"><div class="es"><div class="ei">🏭</div><p>No internal jobs yet. <a href="create_internal_job.jsp" style="color:#6c63ff;font-weight:700;">Create your first job →</a></p></div></td></tr><% } }catch(Exception e){%><tr><td colspan="10" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /internal -->

<!-- ═══ TAB: EXTERNAL ORDERS ═══ -->
<div id="tab-external" class="tp <%= "external".equals(activeTab)?"active":"" %>">
<div class="card">
    <div class="ch">
        <div class="ct"><i class="bi bi-people-fill" style="color:#0d9488;"></i> 👥 Customer Orders — Individual &amp; Bulk</div>
        <a href="create_external_order.jsp" style="background:linear-gradient(135deg,#042f2e,#0d9488);color:#fff;padding:8px 16px;border-radius:10px;font-size:.8rem;font-weight:700;text-decoration:none;display:flex;align-items:center;gap:6px;">
            <i class="bi bi-plus-circle"></i> Create Bulk Order
        </a>
    </div>
    <%
    int extTotal=0,extPending=0,extCompleted=0,bulkPortalPending=0;
    try(Connection cExt=DBConnection.getConnection()){
        ResultSet re2;
        try{re2=cExt.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders");if(re2.next())extTotal=re2.getInt(1);}catch(Exception ig){}
        try{re2=cExt.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE status='pending'");if(re2.next())extPending=re2.getInt(1);}catch(Exception ig){}
        try{re2=cExt.createStatement().executeQuery("SELECT COUNT(*) FROM external_orders WHERE status='completed'");if(re2.next())extCompleted=re2.getInt(1);}catch(Exception ig){}
        try{re2=cExt.createStatement().executeQuery("SELECT COUNT(*) FROM customer_requirements WHERE portal_type='bulk' AND workflow_stage IN ('admin_initial_review','submitted','in_review')");if(re2.next())bulkPortalPending=re2.getInt(1);}catch(Exception ig){}
    }catch(Exception ig){}
    int totalBulkPending = extPending + bulkPortalPending;
    %>
    <!-- ══ Section: Pending Notifications (Bulk only) ══ -->
    <% if(pendingBulkReqs>0){ %>
    <div style="display:flex;gap:12px;margin-bottom:16px;flex-wrap:wrap;">
    <div style="flex:1;min-width:220px;background:linear-gradient(135deg,#f0fdfa,#ccfbf1);border:1.5px solid #5eead4;border-radius:14px;padding:13px 16px;display:flex;align-items:center;justify-content:space-between;gap:10px;">
        <div style="display:flex;align-items:center;gap:10px;">
            <span style="font-size:1.4rem;animation:blink 1.2s ease-in-out infinite;">🏢</span>
            <div>
                <div style="font-weight:800;color:#0f766e;font-size:.88rem;"><%= pendingBulkReqs %> Bulk order<%= pendingBulkReqs>1?"s":"" %> awaiting review</div>
                <div style="font-size:.73rem;color:#0d9488;margin-top:2px;">Bulk / company portal submissions</div>
            </div>
        </div>
        <span style="background:#0f766e;color:#fff;padding:4px 11px;border-radius:20px;font-size:.72rem;font-weight:700;animation:blink 1.2s infinite;white-space:nowrap;">● PENDING</span>
    </div>
    </div>
    <% } %>
    <!-- ══ Section: Individual Customer Orders ══ -->
    <div style="font-size:.8rem;font-weight:800;color:#1d4ed8;text-transform:uppercase;letter-spacing:.5px;padding:4px 0 10px;display:flex;align-items:center;gap:8px;">
        <span style="background:#eff6ff;border:1px solid #93c5fd;border-radius:6px;padding:3px 10px;">🚗 Individual Customer Orders</span>
        <span style="color:var(--muted);font-weight:400;font-size:.74rem;">— personal and small-business vehicle requirements</span>
    </div>
<div class="card">
    <div class="ch"><div class="ct"><i class="bi bi-clipboard-check" style="color:var(--brand);"></i> Individual Customer Requirements</div><% if(pendingIndivReqs>0){%><span class="p po" style="animation:blink 1.2s infinite;"><%= pendingIndivReqs %> pending review</span><%}%></div>
    <table class="dt">
        <thead><tr><th>#</th><th>Req No.</th><th>Customer</th><th>Vehicle Type</th><th>Qty &amp; Fuel / Doc</th><th>Budget</th><th>Stage</th><th>Action</th></tr></thead>
        <tbody>
        <%boolean anyR=false;try(Connection conn=DBConnection.getConnection()){ResultSet rq=conn.createStatement().executeQuery("SELECT cr.*,c.full_name AS cname,c.email AS cemail FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id WHERE cr.portal_type='individual' OR cr.portal_type IS NULL ORDER BY cr.submitted_at DESC");int rn=0;while(rq.next()){anyR=true;rn++;
String ws=rq.getString("workflow_stage");
boolean ip="admin_initial_review".equals(ws)||"submitted".equals(ws)||"in_review".equals(ws);
String sp=ip?"po":(ws!=null&&ws.contains("completed"))?"pg":(ws!=null&&ws.contains("rejected"))?"pr":"pb2";
String sl=ip?"⏳ Pending":(ws!=null?ws.replace("_"," "):"—");
String dt="";try{dt=rq.getString("portal_type")!=null?rq.getString("portal_type"):"individual";}catch(Exception ig){}
String cname=rq.getString("cname")!=null?rq.getString("cname"):rq.getString("client_name");
if(cname==null)cname="";
String reqNum=rq.getString("req_number")!=null?rq.getString("req_number"):"REQ-"+rq.getInt("id");
String reqTitle=rq.getString("req_title")!=null?rq.getString("req_title"):"";
String reqBudget=rq.getString("budget")!=null?rq.getString("budget"):"";
String reqDesc=rq.getString("req_desc")!=null?rq.getString("req_desc"):"";
String reqNotes="";try{reqNotes=rq.getString("admin_notes")!=null?rq.getString("admin_notes"):"";}catch(Exception ig){}
String jsVt="";try{String vt2=rq.getString("vehicle_type");jsVt=vt2!=null?vt2:"";}catch(Exception ig){}
String iVehicleCat=jsVt.isEmpty()?"":jsVt.replace("_"," ").toUpperCase();
if(iVehicleCat.isEmpty()){try{String mn=rq.getString("module_name");iVehicleCat=mn!=null?mn:"";}catch(Exception ig){}}
String jsAttI="";try{String at2=rq.getString("attachment");jsAttI=at2!=null?at2:"";}catch(Exception ig){}
int iQty=0;try{iQty=rq.getInt("vehicle_count");}catch(Exception ig){}
String jsD=reqDesc.replace("&","&amp;").replace("<","&lt;");
String dCust=cname.replace("&","&amp;");
String dTitle=reqTitle.replace("&","&amp;");
String dNotes=reqNotes.replace("&","&amp;");
String dBudget=reqBudget;
String iEmail="";try{String em=rq.getString("cemail");iEmail=em!=null?em:"";}catch(Exception ig){}
String iDocType="";try{String idt=rq.getString("doc_type");iDocType=idt!=null?idt:"";}catch(Exception ig){}
String iFuelType="";try{String ift=rq.getString("deadline");iFuelType=ift!=null?ift:"";}catch(Exception ig){}
String iSubmitted="";try{java.sql.Timestamp its=rq.getTimestamp("submitted_at");iSubmitted=its!=null?its.toString().substring(0,10):"";}catch(Exception ig){}
int iCustId=0;try{iCustId=rq.getInt("customer_id");}catch(Exception ig){}
String iQtyFuel=(iQty>0?iQty+" unit"+(iQty>1?"s":""):"—")+(iFuelType.isEmpty()?"":" · "+iFuelType);
%>
        <tr>
        <td style="color:var(--muted);font-size:.78rem;text-align:center;"><%= rn %></td>
        <td>
            <code style="color:var(--brand);font-weight:700;background:#e8eaf6;padding:2px 7px;border-radius:6px;font-size:.76rem;display:block;"><%= reqNum %></code>
            <% if(!iSubmitted.isEmpty()){ %><div style="font-size:.7rem;color:var(--muted);margin-top:3px;"><%= iSubmitted %></div><% } %>
        </td>
        <td>
            <div style="font-weight:700;font-size:.84rem;"><%= cname.isEmpty()?"—":cname %></div>
            <% if(!iEmail.isEmpty()){ %><div style="font-size:.72rem;color:var(--muted);margin-top:2px;"><i class="bi bi-envelope" style="font-size:.65rem;"></i> <%= iEmail %></div><% } %>
            <% if(!iDocType.isEmpty()){ %><div style="font-size:.68rem;color:#6366f1;margin-top:2px;font-weight:600;"><i class="bi bi-card-text" style="font-size:.62rem;"></i> <%= iDocType %></div><% } %>
        </td>
        <td><span class="p pgy" style="font-size:.68rem;white-space:nowrap;"><%= iVehicleCat.isEmpty()?"—":iVehicleCat %></span></td>
        <td style="font-size:.8rem;white-space:nowrap;"><%= iQtyFuel %></td>
        <td style="font-size:.82rem;font-weight:600;"><%= reqBudget.isEmpty()?"—":reqBudget %></td>
        <td><span class="p <%= sp %>" style="font-size:.7rem;"><%= sl %></span></td>
        <td><button class="sbtn rev-btn" style="padding:6px 12px;font-size:.76rem;"
            data-id="<%= rq.getInt("id") %>"
            data-custid="<%= iCustId %>"
            data-cust="<%= dCust %>"
            data-email="<%= iEmail.replace("\"","&quot;") %>"
            data-vcat="<%= iVehicleCat %>"
            data-budget="<%= dBudget %>"
            data-title="<%= dTitle %>"
            data-desc="<%= jsD %>"
            data-notes="<%= dNotes %>"
            data-pending="<%= ip %>"
            data-ptype="<%= dt %>"
            data-source="cr"
            data-att="<%= jsAttI %>"
            data-qty="<%= iQty %>"
            data-vtype="<%= jsVt %>"
            ><i class="bi bi-<%= ip?"eye":"search" %> me-1"></i><%= ip?"Review":"View" %></button></td>
        </tr>
        <%}if(!anyR){%><tr><td colspan="8"><div class="es"><div class="ei">📋</div><p>No requirements yet.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="8" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>


    <hr style="border:none;border-top:2px dashed #e0f7f5;margin:22px 0;">
    <!-- ══ Section: Bulk / Contract Orders ══ -->
    <!-- Bulk pending notification inside tab -->
    <% if(totalBulkPending>0){ %>
    <div style="background:linear-gradient(135deg,#f0fdfa,#ccfbf1);border:1.5px solid #5eead4;border-radius:14px;padding:14px 18px;display:flex;align-items:center;justify-content:space-between;margin-bottom:18px;flex-wrap:wrap;gap:10px;">
        <div style="display:flex;align-items:center;gap:12px;">
            <span style="font-size:1.6rem;animation:blink 1.2s ease-in-out infinite;">🏢</span>
            <div>
                <div style="font-weight:800;color:#0f766e;font-size:.92rem;"><%= totalBulkPending %> Bulk order<%= totalBulkPending>1?"s":"" %> awaiting your review</div>
                <div style="font-size:.76rem;color:#0d9488;margin-top:2px;">Review organisation documents, add technical specs, approve to Design Team</div>
            </div>
        </div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <span style="background:#0d9488;color:#fff;padding:5px 14px;border-radius:20px;font-size:.76rem;font-weight:700;animation:blink 1.2s infinite;">● <%= totalBulkPending %> PENDING</span>
        </div>
    </div>
    <% } %>
    <!-- Stats -->
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;padding:0 0 16px;">
        <div style="background:#f0fdfa;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#0d9488;"><%= extTotal %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Admin-Created Orders</div>
        </div>
        <div style="background:#fff8e1;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#f59e0b;"><%= totalBulkPending %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Pending Review</div>
        </div>
        <div style="background:#e8f5e9;border-radius:12px;padding:14px;text-align:center;">
            <div style="font-size:1.4rem;font-weight:800;color:#2e7d32;"><%= extCompleted %></div>
            <div style="font-size:.74rem;color:#888;margin-top:3px;">Completed</div>
        </div>
    </div>
    <!-- Section: Bulk Orders -->
    <div style="font-size:.8rem;font-weight:800;color:#0d9488;text-transform:uppercase;letter-spacing:.5px;padding:8px 0;display:flex;align-items:center;gap:8px;">
        <span style="background:#f0fdfa;border:1px solid #99f6e4;border-radius:6px;padding:3px 10px;">🏢 Bulk / Contract Orders</span>
        <span style="color:var(--muted);font-weight:400;font-size:.74rem;">— portal bulk submissions + admin-created orders</span>
    </div>
    <table class="dt">
        <thead><tr><th>#</th><th>Order No.</th><th>Organisation</th><th>Contact Person</th><th>Vehicle · Qty · Fuel</th><th>Budget</th><th>Stage</th><th>Action</th></tr></thead>
        <tbody>
        <%
        boolean anyExt=false;
        boolean anyCustBulk=false;
        try(Connection cBulk=DBConnection.getConnection()){
            ResultSet rBulk=cBulk.createStatement().executeQuery("SELECT cr.*,c.full_name AS cname,c.email AS cemail FROM customer_requirements cr LEFT JOIN customers c ON cr.customer_id=c.id WHERE cr.portal_type='bulk' ORDER BY cr.submitted_at DESC");
            int bn=0;
            while(rBulk.next()){
                anyExt=true; anyCustBulk=true; bn++;
                String bws=rBulk.getString("workflow_stage"); if(bws==null)bws="submitted";
                boolean bpend="admin_initial_review".equals(bws)||"submitted".equals(bws)||"in_review".equals(bws);
                String bsp=bpend?"po":bws.contains("completed")?"pg":bws.contains("rejected")?"pr":"pb2";
                String bcname=rBulk.getString("cname")!=null?rBulk.getString("cname"):rBulk.getString("client_name");
                if(bcname==null)bcname="";
                String bReqTitle="";try{String bt=rBulk.getString("req_title");bReqTitle=bt!=null?bt:"";}catch(Exception ig){}
                String bReqDesc="";try{String bd=rBulk.getString("req_desc");bReqDesc=bd!=null?bd:"";}catch(Exception ig){}
                String bReqNotes="";try{String bn2=rBulk.getString("admin_notes");bReqNotes=bn2!=null?bn2:"";}catch(Exception ig){}
                String bReqBudget="";try{String bb=rBulk.getString("budget");bReqBudget=bb!=null?bb:"";}catch(Exception ig){}
                String bClientName="";try{String bcl=rBulk.getString("client_name");bClientName=bcl!=null?bcl:bcname;}catch(Exception ig){}
                String bVehicleCat="";
                String bVtRaw="";
                try{String bvtmp=rBulk.getString("vehicle_type");bVtRaw=bvtmp!=null?bvtmp:"";
                    bVehicleCat=!bVtRaw.isEmpty()?bVtRaw.replace("_"," ").toUpperCase():(rBulk.getString("module_name")!=null?rBulk.getString("module_name"):"");}catch(Exception ig){}
                if(bVehicleCat==null)bVehicleCat="";
                int bVehicleCount=0; try{bVehicleCount=rBulk.getInt("vehicle_count");}catch(Exception ig){}
                String bjsAtt="";try{String ba=rBulk.getString("attachment");bjsAtt=ba!=null?ba:"";}catch(Exception ig){}
                String bDCust=bcname.replace("&","&amp;");
                String bDTitle=bReqTitle.replace("&","&amp;");
                String bDDesc=bReqDesc.replace("&","&amp;").replace("<","&lt;");
                String bDNotes=bReqNotes.replace("&","&amp;");
                String bDVtype=bVtRaw.toLowerCase();
                String bEmail="";try{String be=rBulk.getString("cemail");bEmail=be!=null?be:"";}catch(Exception ig){}
                String bDocType="";try{String bdt=rBulk.getString("doc_type");bDocType=bdt!=null?bdt:"";}catch(Exception ig){}
                String bFuelType="";try{String bft=rBulk.getString("deadline");bFuelType=bft!=null?bft:"";}catch(Exception ig){}
                String bSubmitted="";try{java.sql.Timestamp bts=rBulk.getTimestamp("submitted_at");bSubmitted=bts!=null?bts.toString().substring(0,10):"";}catch(Exception ig){}
                int bCustId=0;try{bCustId=rBulk.getInt("customer_id");}catch(Exception ig){}
                String bOrderNum=rBulk.getString("req_number")!=null?rBulk.getString("req_number"):"BULK-"+rBulk.getInt("id");
                String bVQF=bVehicleCat.isEmpty()?"—":bVehicleCat;
                if(bVehicleCount>0) bVQF+=" · "+bVehicleCount+" unit"+(bVehicleCount>1?"s":"");
                if(!bFuelType.isEmpty()) bVQF+=" · "+bFuelType;
        %>
        <tr style="background:#fafffe;">
            <td style="color:var(--muted);font-size:.78rem;text-align:center;"><%= bn %></td>
            <td>
                <code style="color:#0d9488;font-weight:700;background:#f0fdfa;padding:2px 7px;border-radius:6px;font-size:.76rem;display:block;"><%= bOrderNum %></code>
                <% if(!bSubmitted.isEmpty()){ %><div style="font-size:.7rem;color:var(--muted);margin-top:3px;"><%= bSubmitted %></div><% } %>
            </td>
            <td>
                <div style="font-weight:700;font-size:.84rem;color:#0f766e;"><%= bClientName.isEmpty()?bcname:bClientName %></div>
                <% if(!bDocType.isEmpty()){ %><div style="font-size:.68rem;color:#6366f1;margin-top:2px;font-weight:600;"><i class="bi bi-building" style="font-size:.62rem;"></i> <%= bDocType %></div><% } %>
            </td>
            <td>
                <div style="font-weight:600;font-size:.83rem;"><%= bcname.isEmpty()?"—":bcname %></div>
                <% if(!bEmail.isEmpty()){ %><div style="font-size:.72rem;color:var(--muted);margin-top:2px;"><i class="bi bi-envelope" style="font-size:.65rem;"></i> <%= bEmail %></div><% } %>
            </td>
            <td style="font-size:.8rem;"><%= bVQF %></td>
            <td style="font-size:.82rem;font-weight:600;"><%= bReqBudget.isEmpty()?"—":bReqBudget %></td>
            <td><span class="p <%= bsp %>" style="font-size:.72rem;"><%= bpend?"Pending":bws.replace("_"," ") %></span></td>
            <td><button class="sbtn rev-btn" style="padding:6px 12px;font-size:.76rem;"
                data-id="<%= rBulk.getInt("id") %>"
                data-custid="<%= bCustId %>"
                data-cust="<%= bDCust %>"
                data-email="<%= bEmail.replace("\"","&quot;") %>"
                data-vcat="<%= bVehicleCat %>"
                data-budget="<%= bReqBudget %>"
                data-title="<%= bDTitle %>"
                data-desc="<%= bDDesc %>"
                data-notes="<%= bDNotes %>"
                data-pending="<%= bpend %>"
                data-ptype="bulk"
                data-source="cr"
                data-att="<%= bjsAtt %>"
                data-qty="<%= bVehicleCount %>"
                data-vtype="<%= bDVtype %>"
                ><i class="bi bi-<%= bpend?"eye":"search" %> me-1"></i><%= bpend?"Review":"View" %></button></td>
        </tr>
        <% }
        } catch(Exception eBulk){ %>
        <tr><td colspan="8" style="color:red;padding:12px;">DB Error (bulk): <%= eBulk.getMessage() %></td></tr>
        <% } %>
        <%
        try(Connection cExt2=DBConnection.getConnection()){
            ResultSet rExt=cExt2.createStatement().executeQuery("SELECT * FROM external_orders ORDER BY id DESC");
            int enum2=0;
            while(rExt.next()){
                anyExt=true; enum2++;
                String eStage=rExt.getString("workflow_stage"); if(eStage==null)eStage="admin_created";
                boolean epend="admin_initial_review".equals(eStage)||"admin_created".equals(eStage);
                String eStageCls=eStage.contains("completed")?"pg":eStage.contains("rejected")?"pr":eStage.contains("design")?"pb2":"po";
                String eType=rExt.getString("client_type"); if(eType==null)eType="Company";
                String eClientName="";try{String ec=rExt.getString("client_name");eClientName=ec!=null?ec:"";}catch(Exception ig){}
                String eVtRaw="";try{String ev=rExt.getString("vehicle_type");eVtRaw=ev!=null?ev:"";}catch(Exception ig){}
                String eVehicleCat=eVtRaw.isEmpty()?"":eVtRaw.replace("_"," ").toUpperCase();
                String eBudget="";try{String eb=rExt.getString("budget");eBudget=eb!=null?eb:"";}catch(Exception ig){}
                String eCompany="";try{String eco=rExt.getString("company_name");eCompany=eco!=null?eco:"";}catch(Exception ig){}
                String eSpec="";try{String es=rExt.getString("special_requirements");eSpec=es!=null?es:"";}catch(Exception ig){}
                String eNotes="";try{String en=rExt.getString("admin_notes");eNotes=en!=null?en:"";}catch(Exception ig){}
                String eAtt="";try{String ea=rExt.getString("contract_file");eAtt=ea!=null?ea:"";}catch(Exception ig){}
                int ejsQty=0;try{ejsQty=rExt.getInt("quantity");}catch(Exception ig){}
                String eTitle=eCompany.isEmpty()?eVehicleCat:eCompany;
                String eOrderNum="";try{String eo=rExt.getString("order_number");eOrderNum=eo!=null?eo:"EXT-"+rExt.getInt("id");}catch(Exception ig){}
                String eDCust=eClientName.replace("&","&amp;");
                String eDTitle=eTitle.replace("&","&amp;");
                String eDDesc=eSpec.replace("&","&amp;").replace("<","&lt;");
                String eDNotes=eNotes.replace("&","&amp;");
                String eVQF=eVehicleCat.isEmpty()?"—":eVehicleCat;
                if(ejsQty>0) eVQF+=" · "+ejsQty+" unit"+(ejsQty>1?"s":"");
        %>
        <tr>
            <td style="color:var(--muted);font-size:.78rem;text-align:center;"><%= enum2 %></td>
            <td>
                <code style="color:#0d9488;font-weight:700;background:#f0fdfa;padding:2px 7px;border-radius:6px;font-size:.76rem;display:block;"><%= eOrderNum %></code>
            </td>
            <td>
                <div style="font-weight:700;font-size:.84rem;color:#0f766e;"><%= eCompany.isEmpty()?"—":eCompany %></div>
                <div style="font-size:.68rem;color:#6366f1;margin-top:2px;font-weight:600;"><i class="bi bi-building" style="font-size:.62rem;"></i> <%= eType %></div>
            </td>
            <td>
                <div style="font-weight:600;font-size:.83rem;"><%= eClientName.isEmpty()?"—":eClientName %></div>
            </td>
            <td style="font-size:.8rem;"><%= eVQF %></td>
            <td style="font-size:.82rem;font-weight:600;"><%= eBudget.isEmpty()?"—":eBudget %></td>
            <td><span class="p <%= eStageCls %>" style="font-size:.72rem;"><%= eStage.replace("_"," ") %></span></td>
            <td><button class="sbtn rev-btn" style="padding:6px 12px;font-size:.76rem;"
                data-id="<%= rExt.getInt("id") %>"
                data-custid="0"
                data-cust="<%= eDCust %>"
                data-email=""
                data-vcat="<%= eVehicleCat %>"
                data-budget="<%= eBudget %>"
                data-title="<%= eDTitle %>"
                data-desc="<%= eDDesc %>"
                data-notes="<%= eDNotes %>"
                data-pending="<%= epend %>"
                data-ptype="bulk"
                data-source="ext"
                data-att="<%= eAtt %>"
                data-qty="<%= ejsQty %>"
                data-vtype="<%= eVtRaw %>"
                ><i class="bi bi-<%= epend?"eye":"search" %> me-1"></i><%= epend?"Review":"View" %></button></td>
        </tr>
        <% } if(!anyExt){%><tr><td colspan="8"><div class="es"><div class="ei">🏢</div><p>No bulk orders yet.</p></div></td></tr><%}}catch(Exception e){%><tr><td colspan="8" style="color:red;padding:12px;">DB Error: <%= e.getMessage() %></td></tr><%}%>
        </tbody>
    </table>
</div>
</div><!-- /external -->

</div></div><!-- /pb /main -->

<!-- MODAL -->
<div id="reqModal" class="mo">
<div class="mb" style="max-width:660px;">

    <!-- Header -->
    <div class="mh" id="mhead" style="background:linear-gradient(135deg,var(--brand),#1a2f7a);">
        <div>
            <div style="font-size:.7rem;opacity:.75;text-transform:uppercase;letter-spacing:.5px;" id="mModalType">Customer Requirement</div>
            <h5 style="margin:2px 0 0;">📋 Review Order</h5>
        </div>
        <button class="mc" onclick="closeM()">✕</button>
    </div>

    <div class="mbody">

        <!-- ── ORDER TYPE BANNER ── -->
        <div id="orderTypeBanner" style="margin-bottom:16px;border-radius:10px;padding:9px 14px;display:flex;align-items:center;gap:10px;font-size:.82rem;font-weight:700;"></div>

        <!-- ── SECTION 1: CUSTOMER INFO ── -->
        <div style="font-size:.7rem;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:10px;">
            👤 Customer Information
        </div>
        <div class="dg" style="margin-bottom:16px;">
            <div class="di"><div class="dl">👤 Customer</div><div class="dv" id="mc"></div></div>
            <div class="di" id="mEmailRow" style="display:none;"><div class="dl">📧 Email</div><div class="dv" id="mEmail"></div></div>
            <div class="di"><div class="dl">💰 Budget</div><div class="dv" id="mb2"></div></div>
            <div class="di" id="mQtyRow" style="display:none;"><div class="dl">🚌 Quantity</div><div class="dv" id="mQty"></div></div>
            <div class="di"><div class="dl">🚗 Vehicle Category</div><div class="dv" id="mm"></div></div>
        </div>

        <!-- ── SECTION 2: CUSTOMER DESCRIPTION ── -->
        <div style="font-size:.7rem;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:8px;">
            📝 Customer Description / Requirement
        </div>
        <div class="dbox" id="mdesc" style="margin-bottom:16px;min-height:44px;">—</div>

        <!-- ── SECTION 3: CUSTOMER ORDER HISTORY (NEW) ── -->
        <div id="mHistorySec" style="display:none;margin-bottom:16px;">
            <div style="font-size:.7rem;font-weight:800;color:#7c3aed;text-transform:uppercase;letter-spacing:1.5px;margin-bottom:8px;">
                📋 All Past Orders from This Customer
            </div>
            <div id="mHistoryBody" style="background:#faf5ff;border:1px solid #ddd6fe;border-radius:10px;padding:12px 14px;font-size:.8rem;min-height:36px;">
                <span style="color:#aaa;">Loading...</span>
            </div>
        </div>

        <!-- ── SECTION 3: UPLOADED DOCUMENT ── -->
        <div id="mDocSec" style="display:none;margin-bottom:16px;
             background:linear-gradient(135deg,#fff8e1,#fffde7);
             border:1.5px solid #ffc107;border-radius:10px;padding:12px 16px;">
            <div style="font-size:.7rem;font-weight:800;color:#b45309;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">
                📎 Uploaded Verification Document
            </div>
            <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
                <a id="mDocLink" href="#" target="_blank"
                   style="display:inline-flex;align-items:center;gap:7px;
                          background:#e65100;color:#fff;padding:7px 16px;
                          border-radius:8px;font-size:.82rem;font-weight:700;text-decoration:none;transition:background .2s;"
                   onmouseover="this.style.background='#bf360c'"
                   onmouseout="this.style.background='#e65100'">
                    <i class="bi bi-file-earmark-arrow-down"></i> View / Download Document
                </a>
                <a id="mDocDownload" href="#" download
                   style="display:inline-flex;align-items:center;gap:7px;
                          background:#1565c0;color:#fff;padding:7px 14px;
                          border-radius:8px;font-size:.82rem;font-weight:700;text-decoration:none;">
                    <i class="bi bi-download"></i> Save File
                </a>
                <span id="mDocName" style="font-size:.75rem;color:#6b7280;font-style:italic;"></span>
            </div>
        </div>

        <!-- ── PENDING: Admin Action Section ── -->
        <div id="pendSec">

            <div style="border-top:1px solid #e5e7eb;margin-bottom:14px;"></div>
            <div style="font-size:.7rem;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:1.5px;margin-bottom:12px;">
                ⚙️ Admin Actions
            </div>

            <!-- STEP 1: Vehicle Type (routes job to correct designer pool) -->
            <div style="background:#f0f7ff;border:1.5px solid #93c5fd;border-radius:10px;padding:14px 16px;margin-bottom:12px;">
                <div style="font-size:.75rem;font-weight:800;color:#1d4ed8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">
                    🚗 Step 1 — Select Vehicle Type
                    <span style="font-size:.65rem;font-weight:600;color:#3b82f6;text-transform:none;letter-spacing:0;margin-left:6px;">Routes job to the correct designer pool</span>
                </div>
                <select id="adminVehicleType"
                    style="width:100%;padding:9px 12px;border:1.5px solid #93c5fd;border-radius:8px;font-size:.875rem;outline:none;background:#fff;font-family:inherit;">
                    <option value="">— Select Vehicle Type —</option>
                    <option value="two_wheeler">🏍️ Two Wheeler (Bike / Scooter)</option>
                    <option value="three_wheeler">🛺 Three Wheeler (Auto / Cargo)</option>
                    <option value="car">🚗 Car (Hatchback / Sedan / SUV)</option>
                    <option value="van">🚐 Van / Minivan</option>
                    <option value="bus">🚌 Bus (Mini / Standard / Luxury)</option>
                    <option value="lorry">🚛 Lorry / Truck</option>
                    <option value="heavy_vehicle">🚜 Heavy Vehicle (Tractor / JCB)</option>
                    <option value="special">🚑 Special Purpose (Ambulance / Fire etc.)</option>
                </select>
                <div id="vtRoutingHint" style="display:none;margin-top:8px;font-size:.75rem;padding:6px 10px;background:#dbeafe;color:#1e40af;border-radius:6px;font-weight:600;"></div>
            </div>

            <!-- STEP 2: Admin Instructions to Designer (optional) -->
            <div style="background:#fafafa;border:1px solid #e5e7eb;border-radius:10px;padding:14px 16px;margin-bottom:12px;">
                <div style="font-size:.75rem;font-weight:800;color:#374151;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">
                    📌 Step 2 — Admin Instructions to Designer
                    <span style="font-size:.65rem;font-weight:400;color:#9ca3af;text-transform:none;letter-spacing:0;margin-left:6px;">(optional)</span>
                </div>
                <div style="font-size:.72rem;color:#6b7280;margin-bottom:8px;">
                    Priority level, special requirements, deadlines, or anything the designer needs to know before starting.
                </div>
                <textarea class="na" id="nIn"
                    placeholder="e.g. HIGH priority. Client expects draft in 3 days. Focus on safety features. Wheelchair accessible mandatory."></textarea>
            </div>

            <!-- Action Buttons -->
            <div class="mar">
                <button class="bap" onclick="subR('approve')">✅ Approve &amp; Send to Design</button>
                <button class="brj" onclick="subR('reject')">❌ Reject</button>
                <button class="bcn" onclick="closeM()">Cancel</button>
            </div>
        </div>

        <!-- ── ALREADY PROCESSED ── -->
        <div id="viewSec" style="display:none;">
            <div id="savedBadge" style="margin-bottom:12px;"></div>
            <div style="font-size:.75rem;font-weight:700;color:var(--muted);margin-bottom:8px;">📌 Admin Instructions Sent to Designer </div>
            <div style="background:#fffde7;border:1px solid #ffc107;border-radius:10px;padding:14px;font-size:.875rem;color:#333;line-height:1.6;" id="sNotes"></div>
        </div>

        <div class="sm" id="sMsg"></div>
        <div id="doneB" style="display:none;margin-top:14px;">
            <button onclick="location.reload()"
                style="width:100%;padding:11px;background:var(--brand);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer;font-size:.88rem;">
                ✓ Done — Refresh Page
            </button>
        </div>

    </div><!-- /mbody -->
</div><!-- /mb -->
</div><!-- /reqModal -->

<script>

var appCtx = '<%= request.getContextPath() %>';
/* ── Tab Switching ── */
function swTab(t){
    document.querySelectorAll('.tp').forEach(function(p){ p.classList.remove('active'); });
    var panel = document.getElementById('tab-' + t);
    if(panel) panel.classList.add('active');
    document.querySelectorAll('.tb').forEach(function(b){
        b.classList.remove('active');
        var oc = b.getAttribute('onclick');
        if(oc && oc.indexOf("'" + t + "'") >= 0) b.classList.add('active');
    });
    var url = new URL(window.location.href);
    url.searchParams.set('tab', t);
    window.history.replaceState({}, '', url);
}

/* ── Review Button: read data-* attributes ── */
document.addEventListener('DOMContentLoaded', function(){

    document.querySelectorAll('.rev-btn').forEach(function(btn){
        btn.addEventListener('click', function(){
            var id      = this.getAttribute('data-id');
            var custId  = this.getAttribute('data-custid') || '0';
            var cust    = this.getAttribute('data-cust')    || '';
            var email   = this.getAttribute('data-email')   || '';
            var vcat    = this.getAttribute('data-vcat')    || '';
            var budget  = this.getAttribute('data-budget')  || '';
            var title   = this.getAttribute('data-title')   || '';
            var desc    = this.getAttribute('data-desc')    || '';
            var notes   = this.getAttribute('data-notes')   || '';
            var pending = this.getAttribute('data-pending') === 'true';
            var ptype   = this.getAttribute('data-ptype')   || 'individual';
            var source  = this.getAttribute('data-source')  || 'cr';
            var att     = this.getAttribute('data-att')     || '';
            var qty     = parseInt(this.getAttribute('data-qty') || '0');
            var vtype   = this.getAttribute('data-vtype')   || '';
            openModal(id, custId, cust, email, vcat, budget, title, desc, notes, pending, ptype, source, att, qty, vtype);
        });
    });

    /* Vehicle type dropdown change → routing hint */
    var vtSel = document.getElementById('adminVehicleType');
    if(vtSel) vtSel.addEventListener('change', function(){ updateVtHint(this.value); });
});

var vtLabels = {
    'two_wheeler':'🏍️ Two Wheeler','three_wheeler':'🛺 Three Wheeler',
    'car':'🚗 Car','van':'🚐 Van','bus':'🚌 Bus',
    'lorry':'🚛 Lorry / Truck','heavy_vehicle':'🚜 Heavy Vehicle','special':'🚑 Special Purpose'
};
function updateVtHint(vt){
    var hint = document.getElementById('vtRoutingHint');
    if(!hint) return;
    if(vt && vtLabels[vt]){
        hint.style.display = 'block';
        hint.innerHTML = '✅ Will be routed to <strong>' + vtLabels[vt] + '</strong> specialist designer';
    } else {
        hint.style.display = 'none';
    }
}

var cid = null, cPortalType = 'individual', cSource = 'cr';

function openModal(id, custId, cust, email, vcat, budget, title, desc, notes, pending, ptype, source, att, qty, vtype){
    cid = id;
    cPortalType = ptype;
    cSource = source || 'cr';

    /* Info grid */
    document.getElementById('mc').textContent  = cust   || '—';
    document.getElementById('mm').textContent  = vcat   || '—';
    document.getElementById('mb2').textContent = budget || '—';

    /* Email row */
    var emailRow = document.getElementById('mEmailRow');
    var emailEl  = document.getElementById('mEmail');
    if(emailRow && emailEl){
        if(email){ emailEl.textContent = email; emailRow.style.display = ''; }
        else { emailRow.style.display = 'none'; }
    }

    /* Quantity row */
    var qtyRow = document.getElementById('mQtyRow');
    if(qtyRow){
        if(qty > 0){ qtyRow.style.display=''; document.getElementById('mQty').textContent = qty + ' vehicles'; }
        else        { qtyRow.style.display='none'; }
    }

    /* Customer history */
    var histSec  = document.getElementById('mHistorySec');
    var histBody = document.getElementById('mHistoryBody');
    var cIdNum   = parseInt(custId || '0');
    if(histSec && histBody){
        if(cIdNum > 0){
            histSec.style.display = 'block';
            histBody.innerHTML = '<span style="color:#aaa;font-size:.78rem;">Loading history...</span>';
            fetch(appCtx + '/vehicle?action=customerHistory&custId=' + cIdNum)
            .then(function(r){ return r.json(); })
            .then(function(data){
                if(data && data.length > 0){
                    var html = '<table style="width:100%;border-collapse:collapse;">';
                    html += '<tr style="font-size:.7rem;color:#7c3aed;font-weight:700;border-bottom:1px solid #ddd6fe;">';
                    html += '<td style="padding:4px 8px;">Req No.</td><td style="padding:4px 8px;">Title</td><td style="padding:4px 8px;">Stage</td><td style="padding:4px 8px;">Date</td></tr>';
                    data.forEach(function(r){
                        var stageColor = r.stage && r.stage.indexOf('complete')>=0 ? '#2e7d32' : r.stage && r.stage.indexOf('reject')>=0 ? '#c62828' : '#1d4ed8';
                        html += '<tr style="border-bottom:1px solid #ede9fe;font-size:.76rem;">';
                        html += '<td style="padding:5px 8px;"><code style="background:#ede9fe;color:#6d28d9;padding:1px 6px;border-radius:4px;font-size:.72rem;">' + (r.reqNum||'—') + '</code></td>';
                        html += '<td style="padding:5px 8px;color:#374151;">' + (r.title||'—') + '</td>';
                        html += '<td style="padding:5px 8px;"><span style="color:' + stageColor + ';font-weight:600;font-size:.72rem;">' + (r.stage||'—').replace(/_/g,' ') + '</span></td>';
                        html += '<td style="padding:5px 8px;color:#6b7280;">' + (r.date||'—') + '</td>';
                        html += '</tr>';
                    });
                    html += '</table>';
                    histBody.innerHTML = html;
                } else {
                    histBody.innerHTML = '<span style="color:#aaa;font-size:.78rem;">No previous orders found for this customer.</span>';
                }
            })
            .catch(function(){
                histBody.innerHTML = '<span style="color:#aaa;font-size:.78rem;">Could not load history.</span>';
            });
        } else {
            histSec.style.display = 'none';
        }
    }

    /* Document attachment */
    var docSec  = document.getElementById('mDocSec');
    var docLink = document.getElementById('mDocLink');
    var docName = document.getElementById('mDocName');
    if(docSec){
        var cleanAtt = att ? att.trim() : '';
        if(cleanAtt){
            if(docLink){ docLink.href = appCtx + '/uploads/' + cleanAtt; }
            var dlLink = document.getElementById('mDocDownload');
            if(dlLink){ dlLink.href = appCtx + '/uploads/' + cleanAtt; dlLink.download = cleanAtt; }
            if(docName) docName.textContent = cleanAtt;
            docSec.style.display = 'block';
        } else {
            docSec.style.display = 'none';
        }
    }

    /* Description */
    var rawDesc = desc ? desc.replace(/\n/g,'<br>').replace(/\r/g,'') : '<em style="color:#aaa">No description provided.</em>';
    document.getElementById('mdesc').innerHTML = rawDesc;

    /* Show/hide pending vs viewed sections */
    document.getElementById('pendSec').style.display  = pending ? 'block' : 'none';
    document.getElementById('viewSec').style.display  = pending ? 'none'  : 'block';
    document.getElementById('sMsg').style.display     = 'none';
    document.getElementById('doneB').style.display    = 'none';

    /* Order type banner */
    var banner = document.getElementById('orderTypeBanner');
    if(banner){
        var isBulk = (ptype === 'bulk');
        banner.innerHTML = isBulk
            ? '<span style="font-size:1.3rem;">🏢</span><div><div style="font-weight:800;">Bulk / Contract Order</div><div style="font-size:.72rem;font-weight:400;opacity:.7;margin-top:1px;">Government, Corporate or large-scale fleet order</div></div>'
            : '<span style="font-size:1.3rem;">🚗</span><div><div style="font-weight:800;">Individual Order</div><div style="font-size:.72rem;font-weight:400;opacity:.7;margin-top:1px;">Personal or small business vehicle requirement</div></div>';
        banner.style.cssText = isBulk
            ? 'margin-bottom:14px;border-radius:12px;padding:10px 16px;display:flex;align-items:center;gap:10px;font-size:.84rem;background:linear-gradient(135deg,#f0fdfa,#e0f2fe);border:1px solid #99f6e4;color:#0f766e;'
            : 'margin-bottom:14px;border-radius:12px;padding:10px 16px;display:flex;align-items:center;gap:10px;font-size:.84rem;background:linear-gradient(135deg,#eff6ff,#e0f2fe);border:1px solid #bae6fd;color:#1d4ed8;';
    }

    if(pending){
        /* Pre-select vehicle type */
        var vtSel = document.getElementById('adminVehicleType');
        if(vtSel){
            var vtClean = vtype ? vtype.trim().toLowerCase().replace(/ /g,'_') : '';
            vtSel.value = vtClean;
            updateVtHint(vtClean);
        }
        document.getElementById('nIn').value = notes || '';
    } else {
        var isBulkV = (ptype === 'bulk');
        var badge = isBulkV
            ? '<span style="background:#f0fdfa;color:#0f766e;padding:4px 14px;border-radius:20px;font-size:.8rem;font-weight:700;">🏢 Bulk / Contract Order</span>'
            : '<span style="background:#eff6ff;color:#1d4ed8;padding:4px 14px;border-radius:20px;font-size:.8rem;font-weight:700;">🚗 Individual Order</span>';
        document.getElementById('savedBadge').innerHTML = badge;
        document.getElementById('sNotes').innerHTML = notes
            ? notes.replace(/\n/g,'<br>')
            : '<em style="color:#aaa">No admin instructions recorded.</em>';
    }

    document.getElementById('reqModal').classList.add('open');
}

function closeM(){ document.getElementById('reqModal').classList.remove('open'); cid = null; }

function subR(at){
    if(!cid) return;
    var notes    = document.getElementById('nIn').value;
    var sm       = document.getElementById('sMsg');
    // techDesc = admin instructions (Step 2 in review modal)
    var techDesc   = notes.trim();

    var vtSel      = document.getElementById('adminVehicleType');
    var selectedVt = vtSel ? vtSel.value : '';

    document.querySelectorAll('.mar button').forEach(function(b){ b.disabled = true; });
    sm.style.display='block'; sm.style.background='#e3f2fd'; sm.style.color='#1565c0';
    sm.innerHTML = '⏳ Saving...';

    var fd = new URLSearchParams();
    fd.append('requirementId',       cid);
    fd.append('adminNotes',          notes);
    fd.append('actionType',          at);
    fd.append('designType',          cPortalType === 'individual' ? 'external' : 'external');
    fd.append('brandName',           '');
    fd.append('techDescription',     techDesc);
    fd.append('vehicleTypeOverride', selectedVt);
    fd.append('orderSource',         cSource);

    fetch('save_admin_notes.jsp', { method:'POST',
        headers:{'Content-Type':'application/x-www-form-urlencoded'},
        body:fd.toString() })
    .then(function(r){ return r.json(); })
    .then(function(data){
        if(data.success){
            sm.style.background = '#e8f5e9'; sm.style.color = '#2e7d32';
            var designer = data.designer || 'Design Team';
            var slotTxt  = data.slot > 0 ? ' — Slot ' + data.slot + ' of ' + data.totalInPool : '';
            var vtTxt    = data.vehicleType ? ' [' + data.vehicleType.replace(/_/g,' ').toUpperCase() + ']' : '';
            if(at === 'approve'){
                sm.innerHTML = '✅ Approved! Routed to <strong>' + designer + '</strong>' + slotTxt + vtTxt + '.<br><span style="font-size:.74rem;color:#4b7a52;">Refreshing page in 2 seconds...</span>';
                if(data.poolEmpty){
                    sm.style.background = '#fffbeb';
                    sm.style.color      = '#92400e';
                    sm.innerHTML += '<br><span style="color:#b45309;font-size:.76rem;">⚠️ ' + (data.warning||'No active designers in pool for this vehicle type.') + '</span>';
                }
            } else {
                sm.innerHTML = '✅ Rejected.<br><span style="font-size:.74rem;color:#4b7a52;">Refreshing page in 2 seconds...</span>';
            }
            /* Switch modal to view mode immediately so admin can see it processed */
            document.getElementById('pendSec').style.display = 'none';
            document.getElementById('doneB').style.display   = 'none';
            /* Show viewSec with the assigned notes */
            var viewSec = document.getElementById('viewSec');
            if(viewSec){
                viewSec.style.display = 'block';
                var savedBadge = document.getElementById('savedBadge');
                var sNotes     = document.getElementById('sNotes');
                if(savedBadge) savedBadge.innerHTML = at === 'approve'
                    ? '<span style="background:#e8f5e9;color:#2e7d32;padding:4px 14px;border-radius:20px;font-size:.8rem;font-weight:700;">✅ Approved — Routed to ' + designer + slotTxt + '</span>'
                    : '<span style="background:#ffebee;color:#c62828;padding:4px 14px;border-radius:20px;font-size:.8rem;font-weight:700;">❌ Rejected</span>';
                if(sNotes) sNotes.innerHTML = document.getElementById('nIn')
                    ? (document.getElementById('nIn').value||'').replace(/\n/g,'<br>') || '<em style="color:#aaa">No admin instructions recorded.</em>'
                    : '<em style="color:#aaa">Processed.</em>';
            }
            /* Auto-reload after 2 seconds */
            setTimeout(function(){ location.reload(); }, 2000);
        } else {
            sm.style.background = '#ffebee'; sm.style.color = '#c62828';
            sm.innerHTML = '❌ ' + (data.error || 'Save failed');
            document.querySelectorAll('.mar button').forEach(function(b){ b.disabled = false; });
        }
    })
    .catch(function(){
        sm.style.background = '#ffebee'; sm.style.color = '#c62828';
        sm.innerHTML = '❌ Network error. Please try again.';
        document.querySelectorAll('.mar button').forEach(function(b){ b.disabled = false; });
    });
}

document.getElementById('reqModal').addEventListener('click', function(e){ if(e.target===this) closeM(); });
document.querySelectorAll('.sc').forEach(function(c,i){ c.style.opacity='0'; c.style.transform='translateY(14px)'; setTimeout(function(){ c.style.transition='opacity .35s ease,transform .35s ease'; c.style.opacity='1'; c.style.transform='translateY(0)'; }, 60+i*45); });
document.querySelectorAll('.sc').forEach(function(c,i){c.style.opacity='0';c.style.transform='translateY(14px)';setTimeout(function(){c.style.transition='opacity .35s ease,transform .35s ease';c.style.opacity='1';c.style.transform='translateY(0)';},60+i*45);});
</script>

<script>
var wfStages = [
    {icon:'📋', label:'Admin Review',   desc:'Order submitted and reviewed by admin'},
    {icon:'🏭', label:'Design',         desc:'Technical design and blueprint creation'},
    {icon:'🛡️', label:'QC Check',       desc:'Quality control inspection and approval'},
    {icon:'🔬', label:'Testing',        desc:'Performance and safety testing'},
    {icon:'📊', label:'Analytics',      desc:'Cost analysis and production analytics'},
    {icon:'📌', label:'Final Review',   desc:'Final admin approval before completion'},
    {icon:'🏁', label:'Completed',      desc:'Order fulfilled and delivered'}
];

function openWfModal(orderNo, name, title, type, stage, assigned, stageIdx, days) {
    var idx = parseInt(stageIdx);
    var d   = parseInt(days);
    var isInt = (type === 'internal');

    document.getElementById('wfModalType').textContent  = isInt ? '🏭 Internal Job' : (type==='bulk'?'🏢 Bulk Order':'🚗 Individual Order');
    document.getElementById('wfModalTitle').textContent = orderNo;
    document.getElementById('wfModalSub').textContent   = name + (title && title!==name ? ' — ' + title : '');
    document.getElementById('wfInfoStage').textContent  = stage.replace(/_/g,' ');
    document.getElementById('wfInfoAssigned').textContent = assigned.toUpperCase();

    var dEl = document.getElementById('wfInfoDays');
    dEl.textContent = d + ' day' + (d!==1?'s':'');
    dEl.style.color = d>7?'#e53935':d>3?'#f59e0b':'#2e7d32';

    var pct = Math.round(idx*100/6);
    document.getElementById('wfProgressBar').style.width = pct + '%';
    document.getElementById('wfProgressTxt').textContent = idx + ' / 6 stages (' + pct + '%)';

    if(isInt){
        document.getElementById('wfModalHeader').style.background = 'linear-gradient(135deg,#6c63ff,#a855f7)';
        document.getElementById('wfProgressBar').style.background = 'linear-gradient(90deg,#6c63ff,#a855f7)';
    } else {
        document.getElementById('wfModalHeader').style.background = 'linear-gradient(135deg,#0a6ebd,#00b4a6)';
        document.getElementById('wfProgressBar').style.background = 'linear-gradient(90deg,#0a6ebd,#00b4a6)';
    }

    var tl = document.getElementById('wfTimeline');
    tl.innerHTML = '';
    wfStages.forEach(function(s, i) {
        var done    = i < idx;
        var current = i === idx;
        var pending = i > idx;
        var dot = done ? '#22c55e' : current ? '#0a6ebd' : '#d1d5db';
        var line = i < wfStages.length-1 ? '<div style="width:2px;height:22px;background:' + (done?'#22c55e':'#e5e7eb') + ';margin-left:15px;"></div>' : '';
        var row = '<div style="display:flex;align-items:flex-start;gap:12px;">' +
            '<div style="display:flex;flex-direction:column;align-items:center;">' +
            '<div style="width:30px;height:30px;border-radius:50%;background:' + dot + ';display:flex;align-items:center;justify-content:center;font-size:.8rem;flex-shrink:0;border:2px solid ' + (current?'#0a6ebd':'transparent') + ';box-shadow:' + (current?'0 0 0 3px rgba(10,110,189,.2)':'none') + ';">' +
            (done ? '✓' : current ? '<span style="color:#fff;font-size:.6rem;font-weight:900;">▶</span>' : '<span style="color:#9ca3af;font-size:.6rem;">○</span>') +
            '</div>' + line + '</div>' +
            '<div style="padding-bottom:16px;flex:1;">' +
            '<div style="display:flex;align-items:center;gap:8px;">' +
            '<span style="font-size:.9rem;">' + s.icon + '</span>' +
            '<span style="font-weight:700;font-size:.85rem;color:' + (pending?'#9ca3af':done?'#2e7d32':current?'#0a6ebd':'#0d1b2a') + ';">' + s.label + '</span>' +
            (current ? '<span style="background:#eff6ff;color:#0a6ebd;font-size:.62rem;font-weight:700;padding:2px 8px;border-radius:20px;animation:blink 1.2s infinite;">● CURRENT</span>' : '') +
            (done    ? '<span style="background:#e8f5e9;color:#2e7d32;font-size:.62rem;font-weight:700;padding:2px 8px;border-radius:20px;">✓ DONE</span>' : '') +
            '</div>' +
            '<div style="font-size:.75rem;color:#6b7c93;margin-top:2px;">' + s.desc + '</div>' +
            '</div></div>';
        tl.innerHTML += row;
    });

    var m = document.getElementById('wfModal');
    m.style.display = 'flex';
}
document.getElementById('wfModal').addEventListener('click', function(e){
    if(e.target===this) this.style.display='none';
});
</script>
<script>
function markChanged(sel) {
    var key = sel.name.replace("assign_","");
    var statusEl = document.getElementById("status_" + key);
    if(statusEl) {
        var val = sel.value;
        if(val) {
            var name = val.split("|")[1] || val;
            statusEl.className = "p po";
            statusEl.textContent = "⏳ Save to confirm — " + name;
        } else {
            statusEl.className = "p pgy";
            statusEl.textContent = "⬜ Unassigned";
        }
    }
}
</script>

<!-- ── Designer Detail Modal ── -->
<div id="designerModal" style="display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.55);z-index:9999;align-items:center;justify-content:center;">
    <div style="background:#fff;border-radius:18px;padding:0;width:420px;max-width:95vw;box-shadow:0 20px 60px rgba(0,0,0,0.3);overflow:hidden;">
        <!-- Modal Header -->
        <div style="background:linear-gradient(135deg,#6c63ff,#4f46e5);padding:22px 26px;position:relative;">
            <div style="font-size:1.1rem;font-weight:800;color:#fff;letter-spacing:.5px;" id="dm-title">Designer Details</div>
            <div style="font-size:.8rem;color:rgba(255,255,255,0.75);margin-top:3px;" id="dm-category"></div>
            <button onclick="closeDesignerModal()" style="position:absolute;top:16px;right:18px;background:rgba(255,255,255,0.2);border:none;color:#fff;width:28px;height:28px;border-radius:50%;font-size:1rem;cursor:pointer;font-weight:700;">&times;</button>
        </div>
        <!-- Avatar + Name -->
        <div style="padding:24px 26px 0;display:flex;align-items:center;gap:16px;">
            <div id="dm-avatar" style="width:56px;height:56px;border-radius:50%;background:linear-gradient(135deg,#6c63ff,#a78bfa);display:flex;align-items:center;justify-content:center;font-size:1.4rem;font-weight:800;color:#fff;flex-shrink:0;"></div>
            <div>
                <div id="dm-name" style="font-size:1.05rem;font-weight:800;color:#1e293b;"></div>
                <div id="dm-username" style="font-size:.82rem;color:#64748b;margin-top:2px;"></div>
            </div>
        </div>
        <!-- Detail rows -->
        <div style="padding:18px 26px 24px;display:flex;flex-direction:column;gap:12px;">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
                <div style="background:#f8faff;border-radius:10px;padding:12px 14px;">
                    <div style="font-size:.68rem;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Slot Number</div>
                    <div id="dm-slot" style="font-size:1.1rem;font-weight:800;color:#6c63ff;"></div>
                </div>
                <div style="background:#f8faff;border-radius:10px;padding:12px 14px;">
                    <div style="font-size:.68rem;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Status</div>
                    <div id="dm-status" style="font-size:.9rem;font-weight:700;"></div>
                </div>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
                <div style="background:#f8faff;border-radius:10px;padding:12px 14px;">
                    <div style="font-size:.68rem;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Vehicle Category</div>
                    <div id="dm-vtype" style="font-size:.88rem;font-weight:700;color:#1e293b;"></div>
                </div>
                <div style="background:#f8faff;border-radius:10px;padding:12px 14px;">
                    <div style="font-size:.68rem;font-weight:700;color:#94a3b8;text-transform:uppercase;letter-spacing:.5px;margin-bottom:4px;">Online</div>
                    <div id="dm-online" style="font-size:.88rem;font-weight:700;"></div>
                </div>
            </div>
            <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:12px 14px;font-size:.82rem;color:#1d4ed8;">
                <i class="bi bi-info-circle"></i>
                &nbsp;Orders are auto-assigned to this designer via the round-robin system based on their slot number.
            </div>
        </div>
    </div>
</div>

<script>
function showDesignerDetail(name, username, vtype, slot, status, online, id) {
    var initials = name.split(" ").map(function(w){ return w[0]; }).join("").substring(0,2).toUpperCase();
    document.getElementById("dm-avatar").textContent   = initials;
    document.getElementById("dm-title").textContent    = name;
    document.getElementById("dm-category").textContent = vtype + " Designer Pool";
    document.getElementById("dm-name").textContent     = name;
    document.getElementById("dm-username").textContent = "@" + username + "  (ID: " + id + ")";
    document.getElementById("dm-slot").textContent     = "Slot " + slot;
    document.getElementById("dm-vtype").textContent    = vtype;
    var statusEl = document.getElementById("dm-status");
    if (status === "Active") {
        statusEl.textContent = "Active";
        statusEl.style.color = "#16a34a";
    } else {
        statusEl.textContent = "Inactive";
        statusEl.style.color = "#dc2626";
    }
    var onlineEl = document.getElementById("dm-online");
    if (online === "Online") {
        onlineEl.innerHTML = "<span style='color:#16a34a;'>&#9679; Online</span>";
    } else if (online.indexOf("Away") !== -1) {
        onlineEl.innerHTML = "<span style='color:#d97706;'>&#9679; " + online + "</span>";
    } else {
        onlineEl.innerHTML = "<span style='color:#9ca3af;'>&#9679; Offline</span>";
    }
    var modal = document.getElementById("designerModal");
    modal.style.display = "flex";
}
function closeDesignerModal() {
    document.getElementById("designerModal").style.display = "none";
}
document.getElementById("designerModal").addEventListener("click", function(e) {
    if (e.target === this) closeDesignerModal();
});
</script>
</body>
</html>
