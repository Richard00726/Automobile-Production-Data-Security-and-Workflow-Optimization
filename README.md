# Automobile Production Data Security and Workflow Optimization

A web-based automobile production workflow management system built
using Java EE (JSP and Servlets), MySQL, and Apache Tomcat 9.

## Project Overview
The system manages the complete automobile production lifecycle
including customer order submission, vehicle design, quality control,
performance testing, market analytics, and final approval through a
secure and structured multi-stage workflow pipeline.

## Features
- OTP-based customer authentication
- Role-based access control (Admin, Design, QC, Testing, Analytics)
- Round-robin task assignment engine
- Vehicle design workbench with autosave
- QC inspection module with autosave
- Performance testing module (8-12 vehicle-specific tests)
- Analytics workbench (5-tab interface)
- Admin dashboard with final approval workflow
- Complete workflow audit trail

## Tech Stack
- Frontend  : JSP, HTML, CSS, JavaScript, Bootstrap Icons
- Backend   : Java Servlets, Java EE
- Database  : MySQL 8.0
- Server    : Apache Tomcat 9
- IDE       : Eclipse

## Workflow Stages
submitted → admin_initial_approved → design_completed →
qc_approved → testing_completed → analytics_completed → completed

## How to Run
1. Clone this repository
2. Import into Eclipse as Existing Project
3. Add mysql-connector and javax.mail jar to WEB-INF/lib/
4. Create database: automobile_db
5. Run database/database_setup.sql
6. Run SeedPasswords.java to set up credentials
7. Configure Tomcat 9 and Run on Server
8. Open: http://localhost:8080/AutomobileApp_Upgraded/

## Demo Access
Contact the developer for login credentials and demo access.
- Email: infantrichart@gmail.com
- GitHub: https://github.com/Richard00726

## Developer
- Name       : Infant Richart L
- Register No: 820422205026
- College    : Anjalai Ammal Mahalingam Engineering College
- Degree     : B.Tech Information Technology
- Internship : Gradtwin Services — Full Stack Developer Java Domain

## License
This project is independently developed by Infant Richart L 
as part of B.Tech final year project at 
Anjalai Ammal Mahalingam Engineering College.
All rights reserved © 2026 Infant Richart L
