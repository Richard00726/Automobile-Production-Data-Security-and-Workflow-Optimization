AUTOPROD — AUTOMOBILE PRODUCTION DATA SECURITY AND WORKFLOW OPTIMIZATION
  VERSION: Final (Production-Ready)
  PLATFORM: Java EE (JSP + Servlets) | MySQL | Apache Tomcat 9
===============================================================

SYSTEM OVERVIEW:
  AutoProd is a full-stack web-based production workflow system
  that manages the complete automobile manufacturing lifecycle
  across 7 sequential stages:

  submitted → admin_initial_approved → design_completed →
  qc_approved → testing_completed → analytics_completed → completed

  Supports TWO order streams:
    • Internal Jobs       — Created by Admin
    • External Orders     — Submitted by bulk clients
    • Customer Requirements — Submitted via customer portal (OTP)

═══════════════════════════════════════
  KEY FEATURES IMPLEMENTED
═══════════════════════════════════════
  ✅ OTP-based customer authentication (email verified)
  ✅ Role-based access control via AuthFilter (5 roles)
  ✅ Round-robin task assignment engine (per module + stream)
  ✅ Vehicle Design workbench with autosave drafts
  ✅ QC Inspection workbench with autosave drafts
  ✅ Testing module with 8–12 vehicle-type-specific tests + autosave
  ✅ Analytics workbench (5-tab: Overview, Design, QC, Test, Form)
  ✅ Admin dashboard with full pipeline visibility + team routing
  ✅ Final Approval tab (internal + external grouped, approve/reject)
  ✅ Unified workflow history audit trail
  ✅ Internal / External stream separation for analytics team

═══════════════════════════════════════
  STEP 1 — IMPORT INTO ECLIPSE
═══════════════════════════════════════
  1. File → Import → Existing Projects into Workspace
  2. Select root directory: the folder containing this file
  3. Click "Finish"

  Project name : AutomobileApp_Upgraded
  App URL      : http://localhost:8080/AutomobileApp_Upgraded/

═══════════════════════════════════════
  STEP 2 — ADD REQUIRED JARs
═══════════════════════════════════════
  Copy these JARs into  WebContent/WEB-INF/lib/

    • mysql-connector-java-8.x.xx.jar
        Download: https://dev.mysql.com/downloads/connector/j/
    • javax.servlet-api-4.0.1.jar
        (or use Tomcat's provided scope — already in Tomcat 9 lib)
    • javax.mail.jar  (for email OTP)
        Download: https://javaee.github.io/javamail/

  In Eclipse:
    Right-click project → Build Path → Add External Archives

═══════════════════════════════════════
  STEP 3 — SET UP DATABASE
═══════════════════════════════════════
  1. Open MySQL Workbench or terminal
  2. Create the database:
       CREATE DATABASE automobile_db;
  3. Run the setup script:
       database/database_setup.sql
  4. Run SeedPasswords.java to hash all demo passwords:
       Right-click → Run As → Java Application

  Default DB config (edit DBConnection.java if needed):
     Host     : localhost:3306
     Database : automobile_db
     User     : root
     Password : root

═══════════════════════════════════════
  STEP 4 — CONFIGURE TOMCAT
═══════════════════════════════════════
  1. Window → Show View → Servers
  2. Right-click Servers → New → Server → Apache Tomcat 9.x
  3. Right-click project → Run As → Run on Server
  4. Clear Tomcat work cache if pages show old version:
       Stop Tomcat → delete workspace/.metadata/.plugins/
       org.eclipse.wst.server.core/tmp0/work/
       → Start Tomcat again

═══════════════════════════════════════
  DEMO LOGIN CREDENTIALS
═══════════════════════════════════════

  STAFF LOGIN  →  http://localhost:8080/AutomobileApp_Upgraded/
  ─────────────────────────────────────────────────────────────
  Role         Username          Password       Redirects to
  ─────────────────────────────────────────────────────────────
  Admin        admin             admin123       Admin Dashboard
  Designer     bus_designer_01   design123      Vehicle Design
  Designer     car_designer_001  design123      Vehicle Design
  QC           bus_qc_01         qc123          QC Module
  Tester       bus_tester_01     test123        Testing Module
  Analyst      analyst_int_01    analytics123   Analytics Module
  Analyst      analyst_ext_01    analytics123   Analytics Module
  ─────────────────────────────────────────────────────────────

  CUSTOMER LOGIN  →  http://localhost:8080/AutomobileApp_Upgraded/home.jsp
  ─────────────────────────────────────────────────────────────
  Uses email OTP — enter registered customer email to receive OTP

═══════════════════════════════════════
  WORKFLOW STAGES (in order)
═══════════════════════════════════════
  1. submitted              → Admin reviews and approves
  2. admin_initial_approved → Designer assigned (round-robin)
  3. design_completed       → QC Inspector assigned
  4. qc_approved            → Tester assigned
  5. testing_completed      → Analyst assigned
  6. analytics_completed    → Admin Final Approval
  7. completed              → Production cycle done

  Rejection branches:
    admin_initial_rejected | qc_rejected | final_rejected

═══════════════════════════════════════
  ANALYTICS TEAM STREAM SEPARATION
═══════════════════════════════════════
  Internal analysts  → see only internal_jobs
  External analysts  → see only external_orders + customer_requirements
  Set in: Admin Dashboard → Analytics Routing tab
  Stored in: module_team_members.vehicle_type ('internal' / 'external')

═══════════════════════════════════════
  PROJECT FILE STRUCTURE
═══════════════════════════════════════
  AutomobileApp_Upgraded/
  ├── dashboard.jsp                    ← Staff dashboard (root)
  ├── home.jsp                         ← Customer landing page
  ├── index.jsp                        ← Staff login
  ├── customer_login.jsp               ← Customer email entry
  ├── verify_otp.jsp                   ← OTP verification
  ├── customer_requirements.jsp        ← Customer order form
  ├── workflow_dashboard.jsp           ← Workflow status view
  ├── css/style.css                    ← Legacy styles
  ├── jsp/
  │   ├── nav.jsp                      ← Legacy sidebar
  │   ├── vehicle_design.jsp           ← Designer workbench
  │   ├── qc_module.jsp                ← QC workbench
  │   ├── testing_module.jsp           ← Testing workbench
  │   ├── analytics_module.jsp         ← Analytics workbench (5-tab)
  │   ├── final_report.jsp             ← Final report view
  │   ├── save_design_work.jsp         ← Design submit handler
  │   ├── save_design_draft.jsp        ← Design autosave
  │   ├── save_qc_work.jsp             ← QC submit handler
  │   ├── save_qc_draft.jsp            ← QC autosave
  │   ├── save_testing_work.jsp        ← Testing submit handler
  │   ├── save_testing_draft.jsp       ← Testing autosave
  │   ├── save_analytics_work.jsp      ← Analytics submit handler
  │   ├── save_analytics_draft.jsp     ← Analytics autosave (NEW)
  │   └── admin/
  │       ├── admin_dashboard.jsp      ← Full admin control panel
  │       ├── manage_analytics_team.jsp← Analytics team routing
  │       ├── manage_designers.jsp     ← Designer team routing
  │       ├── manage_qc_team.jsp       ← QC team routing
  │       ├── manage_testing_team.jsp  ← Testing team routing
  │       └── save_admin_notes.jsp     ← Admin approval handler
  └── WEB-INF/
      └── web.xml                      ← Servlet + filter mappings

  src/com/automobile/
  ├── db/DBConnection.java             ← MySQL connection pool
  ├── filter/AuthFilter.java           ← Role-based access control
  ├── util/PasswordUtil.java           ← Salted SHA-256 hashing
  ├── util/ValidationUtil.java         ← Form validation helpers
  ├── util/SeedPasswords.java          ← One-time password seeder
  ├── util/EmailUtil.java              ← OTP email sender
  └── servlet/
      ├── LoginServlet.java
      ├── CustomerLoginServlet.java
      ├── VerifyOtpServlet.java
      ├── VehicleServlet.java
      ├── QCServlet.java
      ├── TestingServlet.java
      ├── WorkflowServlet.java
      └── SubmitRequirementServlet.java

═══════════════════════════════════════
  KEY DATABASE TABLES
═══════════════════════════════════════
  users                    ← Staff accounts + roles
  customers                ← Customer accounts
  module_team_members      ← Team pools per module + stream
  module_round_robin       ← Assignment slot tracker
  internal_jobs            ← Admin-created production jobs
  external_orders          ← Bulk client orders
  customer_requirements    ← Customer portal submissions
  design_submissions       ← Designer work output
  qc_inspections           ← QC inspector decisions
  testing_results          ← Test execution results (+ tests_json)
  testing_drafts           ← Autosave for testing module
  analytics_submissions    ← Analyst final reports
  analytics_drafts         ← Autosave for analytics module
  unified_workflow_history ← Complete audit trail
  vehicle                  ← Vehicle master data

===============================================================
  TROUBLESHOOTING
===============================================================
  ❌ 500 Error on JSP page
     → Clear Tomcat work cache (see Step 4) and restart

  ❌ Cannot resolve variable (e.g. wfF)
     → Variable declared after it is used in JSP
     → Move declaration to top of scriptlet block

  ❌ tests_json not loading in analytics
     → Ensure testing was submitted (not just drafted)
     → tests_json stored in testing_results, not testing_drafts

  ❌ Email OTP not sending
     → Check EmailUtil.java SMTP credentials
     → Verify javax.mail.jar is in WEB-INF/lib/

  ❌ SMS OTP error 401
     → Fast2SMS API key expired or invalid
     → Login to fast2sms.com → Dev API → copy fresh key
     → Or remove SMS call — email OTP is sufficient

  ❌ Analytics analyst sees wrong stream jobs
     → Check module_team_members.vehicle_type for that username
     → Must be 'internal' or 'external' (not null)
     → Set via Admin Dashboard → Analytics Routing tab

===============================================================

