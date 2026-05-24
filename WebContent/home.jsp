<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoProd — Automobile Manufacturing Management System</title>
    <link href="https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=Epilogue:wght@300;400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.11.3/font/bootstrap-icons.min.css">
    <style>
        :root {
            --primary: #0a6ebd;
            --primary-dark: #054d8a;
            --teal: #00b4a6;
            --teal-dark: #008f83;
            --dark: #0d1b2a;
            --dark2: #1a2b3c;
            --white: #ffffff;
            --gray: #f4f7fb;
            --text: #2c3e50;
            --text-light: #6b7c93;
            --border: #e1e8f0;
        }

        * { margin:0; padding:0; box-sizing:border-box; scroll-behavior:smooth; }

        body { font-family:'Epilogue',sans-serif; color:var(--text); background:var(--white); overflow-x:hidden; }

        /* ── NAVBAR ── */
        .navbar {
            position:fixed; top:0; left:0; right:0; z-index:1000;
            display:flex; align-items:center; justify-content:space-between;
            padding:0 48px; height:70px;
            background:rgba(255,255,255,0.95);
            backdrop-filter:blur(12px);
            border-bottom:1px solid rgba(0,0,0,0.06);
            transition:all 0.3s;
        }

        .navbar.scrolled { box-shadow:0 4px 24px rgba(0,0,0,0.08); }

        .nav-brand {
            display:flex; align-items:center; gap:10px;
            font-family:'Syne',sans-serif; font-weight:800; font-size:1.4rem;
            color:var(--primary); text-decoration:none;
        }

        .nav-brand .logo-icon {
            width:38px; height:38px; background:linear-gradient(135deg,var(--primary),var(--teal));
            border-radius:10px; display:flex; align-items:center; justify-content:center;
            color:#fff; font-size:1.1rem;
        }

        .nav-brand span { color:var(--teal); }

        .nav-links {
            display:flex; align-items:center; gap:4px; list-style:none;
        }

        .nav-links a {
            padding:8px 16px; border-radius:8px; color:var(--text-light);
            text-decoration:none; font-size:0.875rem; font-weight:500; transition:all 0.2s;
        }

        .nav-links a:hover { color:var(--primary); background:#f0f7ff; }

        .nav-actions { display:flex; align-items:center; gap:10px; }

        .btn-staff {
            padding:9px 20px; background:transparent; border:2px solid var(--primary);
            color:var(--primary); border-radius:10px; font-family:'Epilogue',sans-serif;
            font-size:0.875rem; font-weight:600; cursor:pointer; transition:all 0.2s;
            text-decoration:none; display:flex; align-items:center; gap:6px;
        }

        .btn-staff:hover { background:var(--primary); color:#fff; }

        .btn-customer {
            padding:9px 20px; background:linear-gradient(135deg,var(--teal),var(--teal-dark));
            border:none; color:#fff; border-radius:10px; font-family:'Epilogue',sans-serif;
            font-size:0.875rem; font-weight:600; cursor:pointer; transition:all 0.2s;
            text-decoration:none; display:flex; align-items:center; gap:6px;
        }

        .btn-customer:hover { transform:translateY(-1px); box-shadow:0 6px 20px rgba(0,180,166,0.35); }

        .nav-toggle { display:none; background:none; border:none; font-size:1.5rem; cursor:pointer; color:var(--text); }

        /* ── HERO ── */
        .hero {
            min-height:100vh; position:relative; overflow:hidden;
            display:flex; align-items:center; padding-top:70px;
        }

        .hero-slider { position:absolute; inset:0; z-index:0; }

        .slide {
            position:absolute; inset:0; opacity:0; transition:opacity 1.2s ease;
            background-size:cover; background-position:center;
        }

        .slide.active { opacity:1; }

        .slide::after {
            content:''; position:absolute; inset:0;
            background:linear-gradient(to right, rgba(13,27,42,0.85) 0%, rgba(13,27,42,0.5) 50%, rgba(13,27,42,0.2) 100%);
        }

        .slide-1 { background-image:url('https://images.unsplash.com/photo-1565043589221-1a6fd9ae45c7?w=1600&q=80'); }
        .slide-2 { background-image:url('https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=1600&q=80'); }
        .slide-3 { background-image:url('https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?w=1600&q=80'); }

        .hero-content {
            position:relative; z-index:2; max-width:1200px;
            margin:0 auto; padding:0 48px; width:100%;
        }

        .hero-badge {
            display:inline-flex; align-items:center; gap:8px;
            background:rgba(0,180,166,0.15); border:1px solid rgba(0,180,166,0.3);
            color:var(--teal); padding:6px 16px; border-radius:20px;
            font-size:0.8rem; font-weight:600; margin-bottom:24px;
            animation:fadeUp 0.6s ease 0.2s both;
        }

        .hero-title {
            font-family:'Syne',sans-serif; font-size:clamp(2.5rem,6vw,4.5rem);
            font-weight:800; color:#fff; line-height:1.1; margin-bottom:20px;
            animation:fadeUp 0.6s ease 0.4s both;
        }

        .hero-title span { color:var(--teal); }

        .hero-desc {
            font-size:1.1rem; color:rgba(255,255,255,0.75); line-height:1.7;
            max-width:560px; margin-bottom:40px;
            animation:fadeUp 0.6s ease 0.6s both;
        }

        .hero-btns {
            display:flex; gap:14px; flex-wrap:wrap;
            animation:fadeUp 0.6s ease 0.8s both;
        }

        .hero-btn-primary {
            padding:14px 32px; background:linear-gradient(135deg,var(--primary),var(--primary-dark));
            color:#fff; border:none; border-radius:12px;
            font-family:'Syne',sans-serif; font-size:1rem; font-weight:700;
            cursor:pointer; transition:all 0.2s; text-decoration:none;
            display:flex; align-items:center; gap:8px;
        }

        .hero-btn-primary:hover { transform:translateY(-2px); box-shadow:0 8px 28px rgba(10,110,189,0.4); color:#fff; }

        .hero-btn-secondary {
            padding:14px 32px; background:rgba(255,255,255,0.12);
            color:#fff; border:2px solid rgba(255,255,255,0.3); border-radius:12px;
            font-family:'Syne',sans-serif; font-size:1rem; font-weight:700;
            cursor:pointer; transition:all 0.2s; text-decoration:none;
            display:flex; align-items:center; gap:8px; backdrop-filter:blur(8px);
        }

        .hero-btn-secondary:hover { background:rgba(255,255,255,0.2); color:#fff; }

        /* Slider Controls */
        .slider-controls {
            position:absolute; bottom:40px; left:50%; transform:translateX(-50%);
            display:flex; gap:8px; z-index:3;
        }

        .slider-dot {
            width:8px; height:8px; border-radius:4px; background:rgba(255,255,255,0.4);
            cursor:pointer; transition:all 0.3s; border:none;
        }

        .slider-dot.active { width:24px; background:var(--teal); }

        .slider-prev, .slider-next {
            position:absolute; top:50%; transform:translateY(-50%);
            width:48px; height:48px; border-radius:50%;
            background:rgba(255,255,255,0.15); border:2px solid rgba(255,255,255,0.3);
            color:#fff; font-size:1.2rem; cursor:pointer; transition:all 0.2s;
            display:flex; align-items:center; justify-content:center;
            z-index:3; backdrop-filter:blur(8px);
        }

        .slider-prev { left:24px; }
        .slider-next { right:24px; }
        .slider-prev:hover, .slider-next:hover { background:rgba(255,255,255,0.3); }

        /* ── STATS ── */
        .stats-section {
            background:var(--dark); padding:48px;
        }

        .stats-grid {
            max-width:1200px; margin:0 auto;
            display:grid; grid-template-columns:repeat(4,1fr); gap:24px;
        }

        .stat-item { text-align:center; }

        .stat-num {
            font-family:'Syne',sans-serif; font-size:2.5rem; font-weight:800;
            color:var(--teal); margin-bottom:6px;
        }

        .stat-label { color:rgba(255,255,255,0.6); font-size:0.875rem; }

        /* ── SECTION COMMON ── */
        section { padding:96px 48px; }

        .section-tag {
            display:inline-flex; align-items:center; gap:6px;
            background:#f0f7ff; color:var(--primary); padding:6px 14px;
            border-radius:20px; font-size:0.78rem; font-weight:600;
            margin-bottom:16px; text-transform:uppercase; letter-spacing:1px;
        }

        .section-title {
            font-family:'Syne',sans-serif; font-size:clamp(1.8rem,4vw,2.8rem);
            font-weight:800; color:var(--dark); line-height:1.2; margin-bottom:16px;
        }

        .section-title span { color:var(--teal); }

        .section-desc { color:var(--text-light); font-size:1rem; line-height:1.7; max-width:540px; }

        .container { max-width:1200px; margin:0 auto; }

        /* ── ABOUT ── */
        .about-section { background:var(--gray); }

        .about-grid { display:grid; grid-template-columns:1fr 1fr; gap:64px; align-items:center; }

        .about-image {
            position:relative; border-radius:20px; overflow:hidden;
            box-shadow:0 20px 60px rgba(0,0,0,0.12);
        }

        .about-image img { width:100%; height:400px; object-fit:cover; display:block; }

        .about-image .img-badge {
            position:absolute; bottom:24px; left:24px;
            background:#fff; border-radius:12px; padding:16px 20px;
            box-shadow:0 8px 24px rgba(0,0,0,0.12);
            display:flex; align-items:center; gap:12px;
        }

        .img-badge-icon { width:40px; height:40px; background:linear-gradient(135deg,var(--primary),var(--teal)); border-radius:10px; display:flex; align-items:center; justify-content:center; color:#fff; font-size:1.2rem; }
        .img-badge-text .num { font-family:'Syne',sans-serif; font-size:1.3rem; font-weight:800; color:var(--dark); }
        .img-badge-text .lbl { font-size:0.75rem; color:var(--text-light); }

        .about-features { margin-top:32px; display:grid; grid-template-columns:1fr 1fr; gap:16px; }

        .about-feature {
            display:flex; align-items:flex-start; gap:12px;
            background:#fff; padding:16px; border-radius:12px;
            box-shadow:0 2px 12px rgba(0,0,0,0.04);
        }

        .feature-icon { width:36px; height:36px; border-radius:10px; background:linear-gradient(135deg,var(--primary),var(--teal)); display:flex; align-items:center; justify-content:center; color:#fff; flex-shrink:0; }
        .feature-text h4 { font-family:'Syne',sans-serif; font-size:0.9rem; font-weight:700; margin-bottom:2px; }
        .feature-text p { font-size:0.78rem; color:var(--text-light); }

        /* ── MODULES ── */
        .modules-section { background:#fff; }
        .modules-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:24px; margin-top:48px; }

        .module-card {
            background:#fff; border:1.5px solid var(--border); border-radius:16px;
            padding:28px; transition:all 0.3s; position:relative; overflow:hidden;
        }

        .module-card::before {
            content:''; position:absolute; top:0; left:0; right:0; height:3px;
            background:linear-gradient(to right,var(--primary),var(--teal));
            transform:scaleX(0); transition:transform 0.3s;
        }

        .module-card:hover { transform:translateY(-4px); box-shadow:0 16px 48px rgba(10,110,189,0.1); border-color:transparent; }
        .module-card:hover::before { transform:scaleX(1); }

        .module-icon { width:52px; height:52px; border-radius:14px; display:flex; align-items:center; justify-content:center; font-size:1.4rem; margin-bottom:16px; }
        .module-card h3 { font-family:'Syne',sans-serif; font-size:1.05rem; font-weight:700; margin-bottom:8px; }
        .module-card p { font-size:0.85rem; color:var(--text-light); line-height:1.6; }
        .module-tag { display:inline-block; margin-top:12px; padding:4px 10px; border-radius:20px; font-size:0.72rem; font-weight:600; }

        /* ── WORKFLOW ── */
        .workflow-section { background:var(--dark); }
        .workflow-section .section-title { color:#fff; }
        .workflow-section .section-desc { color:rgba(255,255,255,0.6); }
        .workflow-section .section-tag { background:rgba(0,180,166,0.15); color:var(--teal); }

        .workflow-steps { display:grid; grid-template-columns:repeat(6,1fr); gap:0; margin-top:56px; position:relative; }

        .workflow-steps::before {
            content:''; position:absolute; top:36px; left:8%; right:8%; height:2px;
            background:linear-gradient(to right,var(--primary),var(--teal));
        }

        .workflow-step { text-align:center; padding:0 8px; position:relative; z-index:1; }

        .step-circle {
            width:72px; height:72px; border-radius:50%;
            background:linear-gradient(135deg,var(--primary),var(--teal));
            display:flex; align-items:center; justify-content:center;
            font-size:1.5rem; margin:0 auto 16px; position:relative;
            box-shadow:0 8px 24px rgba(10,110,189,0.3);
        }

        .step-circle .step-num {
            position:absolute; top:-4px; right:-4px; width:22px; height:22px;
            background:var(--teal); border-radius:50%; font-size:0.65rem;
            font-weight:800; color:#fff; display:flex; align-items:center; justify-content:center;
            font-family:'Syne',sans-serif;
        }

        .workflow-step h4 { font-family:'Syne',sans-serif; font-size:0.85rem; font-weight:700; color:#fff; margin-bottom:4px; }
        .workflow-step p { font-size:0.75rem; color:rgba(255,255,255,0.5); }

        /* ── PORTAL ACCESS ── */
        .portal-section { background:var(--gray); }

        .portal-grid { display:grid; grid-template-columns:1fr 1fr; gap:32px; margin-top:48px; }

        .portal-card {
            border-radius:20px; padding:40px; position:relative; overflow:hidden;
            transition:all 0.3s;
        }

        .portal-card:hover { transform:translateY(-4px); }

        .portal-staff {
            background:linear-gradient(135deg,var(--primary),var(--primary-dark));
            color:#fff;
        }

        .portal-customer {
            background:linear-gradient(135deg,var(--teal),var(--teal-dark));
            color:#fff;
        }

        .portal-card::after {
            content:''; position:absolute; bottom:-40px; right:-40px;
            width:160px; height:160px; border-radius:50%;
            background:rgba(255,255,255,0.06);
        }

        .portal-icon { font-size:3rem; margin-bottom:20px; display:block; }
        .portal-card h3 { font-family:'Syne',sans-serif; font-size:1.6rem; font-weight:800; margin-bottom:10px; }
        .portal-card p { opacity:0.85; font-size:0.95rem; line-height:1.6; margin-bottom:28px; }

        .portal-features { list-style:none; margin-bottom:32px; }
        .portal-features li { display:flex; align-items:center; gap:8px; padding:5px 0; font-size:0.875rem; opacity:0.9; }
        .portal-features li i { opacity:0.8; }

        .btn-portal {
            display:inline-flex; align-items:center; gap:8px;
            padding:13px 28px; background:rgba(255,255,255,0.2);
            color:#fff; border:2px solid rgba(255,255,255,0.4);
            border-radius:10px; font-family:'Syne',sans-serif;
            font-size:0.95rem; font-weight:700; text-decoration:none;
            transition:all 0.2s; backdrop-filter:blur(8px);
        }

        .btn-portal:hover { background:rgba(255,255,255,0.35); color:#fff; transform:translateX(4px); }

        /* ── COMPANY INFO ── */
        .company-section { background:#fff; }

        .company-grid { display:grid; grid-template-columns:1fr 1fr; gap:64px; align-items:center; }

        .company-info h2 { font-family:'Syne',sans-serif; font-size:2rem; font-weight:800; margin-bottom:16px; color:var(--dark); }
        .company-info p { color:var(--text-light); line-height:1.8; margin-bottom:16px; }

        .company-details { margin-top:28px; display:flex; flex-direction:column; gap:14px; }

        .company-detail {
            display:flex; align-items:center; gap:14px;
            padding:14px 18px; background:var(--gray); border-radius:12px;
        }

        .detail-icon { width:40px; height:40px; background:linear-gradient(135deg,var(--primary),var(--teal)); border-radius:10px; display:flex; align-items:center; justify-content:center; color:#fff; flex-shrink:0; }
        .detail-text .label { font-size:0.72rem; color:var(--text-light); text-transform:uppercase; letter-spacing:0.5px; margin-bottom:2px; }
        .detail-text .value { font-weight:600; font-size:0.9rem; color:var(--dark); }

        .company-image { border-radius:20px; overflow:hidden; box-shadow:0 20px 60px rgba(0,0,0,0.1); }
        .company-image img { width:100%; height:420px; object-fit:cover; display:block; }

        /* ── FOOTER ── */
        footer {
            background:var(--dark); color:rgba(255,255,255,0.6);
            padding:56px 48px 24px;
        }

        .footer-grid { display:grid; grid-template-columns:2fr 1fr 1fr 1fr; gap:48px; max-width:1200px; margin:0 auto 48px; }

        .footer-brand { font-family:'Syne',sans-serif; font-size:1.4rem; font-weight:800; color:#fff; margin-bottom:12px; }
        .footer-brand span { color:var(--teal); }
        .footer-desc { font-size:0.875rem; line-height:1.7; margin-bottom:20px; }

        .footer-social { display:flex; gap:10px; }
        .social-btn { width:36px; height:36px; background:rgba(255,255,255,0.1); border-radius:8px; display:flex; align-items:center; justify-content:center; color:rgba(255,255,255,0.6); text-decoration:none; transition:all 0.2s; }
        .social-btn:hover { background:var(--teal); color:#fff; }

        .footer-col h4 { font-family:'Syne',sans-serif; font-size:0.875rem; font-weight:700; color:#fff; margin-bottom:16px; text-transform:uppercase; letter-spacing:1px; }
        .footer-col ul { list-style:none; }
        .footer-col ul li { margin-bottom:10px; }
        .footer-col ul li a { color:rgba(255,255,255,0.55); text-decoration:none; font-size:0.875rem; transition:color 0.2s; }
        .footer-col ul li a:hover { color:var(--teal); }

        .footer-bottom { max-width:1200px; margin:0 auto; padding-top:24px; border-top:1px solid rgba(255,255,255,0.08); display:flex; align-items:center; justify-content:space-between; font-size:0.8rem; }
        .footer-bottom span { color:var(--teal); font-weight:600; }

        /* ── ANIMATIONS ── */
        @keyframes fadeUp {
            from { transform:translateY(30px); opacity:0; }
            to { transform:translateY(0); opacity:1; }
        }

        .fade-up { opacity:0; transform:translateY(30px); transition:all 0.7s ease; }
        .fade-up.visible { opacity:1; transform:translateY(0); }

        /* ── MOBILE NAV ── */
        @media(max-width:900px) {
            .navbar { padding:0 20px; }
            .nav-links { display:none; position:absolute; top:70px; left:0; right:0; background:#fff; flex-direction:column; padding:16px; box-shadow:0 8px 24px rgba(0,0,0,0.1); gap:4px; }
            .nav-links.open { display:flex; }
            .nav-toggle { display:block; }
            .hero-content { padding:0 20px; }
            .hero-btns { flex-direction:column; width:fit-content; }
            .stats-grid { grid-template-columns:repeat(2,1fr); }
            section { padding:64px 20px; }
            .about-grid, .company-grid, .portal-grid { grid-template-columns:1fr; gap:32px; }
            .modules-grid { grid-template-columns:1fr; }
            .workflow-steps { grid-template-columns:repeat(2,1fr); gap:32px; }
            .workflow-steps::before { display:none; }
            .footer-grid { grid-template-columns:1fr 1fr; gap:32px; }
            .footer-bottom { flex-direction:column; gap:8px; text-align:center; }
            .about-features { grid-template-columns:1fr; }
            .nav-actions { gap:6px; }
            .btn-staff, .btn-customer { padding:8px 12px; font-size:0.8rem; }
        }
    </style>
</head>
<body>

<!-- NAVBAR -->
<nav class="navbar" id="navbar">
    <a href="#" class="nav-brand">
        <div class="logo-icon">🚗</div>
        Auto<span>Prod</span>
    </a>
    <button class="nav-toggle" onclick="document.getElementById('navLinks').classList.toggle('open')">
        <i class="bi bi-list"></i>
    </button>
    <ul class="nav-links" id="navLinks">
        <li><a href="#about">About</a></li>
        <li><a href="#modules">Modules</a></li>
        <li><a href="#workflow">Workflow</a></li>
        <li><a href="#portal">Portal</a></li>
        <li><a href="#company">Contact</a></li>
    </ul>
    <div class="nav-actions">
        <a href="${pageContext.request.contextPath}/index.jsp" class="btn-staff">
            <i class="bi bi-person-badge"></i> Staff Login
        </a>
        <a href="${pageContext.request.contextPath}/customer_login.jsp" class="btn-customer">
            <i class="bi bi-people"></i> Customer Login
        </a>
    </div>
</nav>

<!-- HERO SLIDER -->
<section class="hero">
    <div class="hero-slider">
        <div class="slide slide-1 active"></div>
        <div class="slide slide-2"></div>
        <div class="slide slide-3"></div>
    </div>

    <button class="slider-prev" onclick="changeSlide(-1)"><i class="bi bi-chevron-left"></i></button>
    <button class="slider-next" onclick="changeSlide(1)"><i class="bi bi-chevron-right"></i></button>

    <div class="hero-content">
        <div class="hero-badge"><i class="bi bi-lightning-charge-fill"></i> Automobile Manufacturing Management</div>
        <h1 class="hero-title">
            Driving the Future<br>of <span>Auto Industry</span>
        </h1>
        <p class="hero-desc">
            AutoProd — a complete production workflow system with role-based access, quality control, testing modules, and real-time analytics for modern automobile manufacturing.
        </p>
        <div class="hero-btns">
            <a href="${pageContext.request.contextPath}/customer_login.jsp" class="hero-btn-primary">
                <i class="bi bi-person-plus"></i> Get Started
            </a>
            <a href="#modules" class="hero-btn-secondary">
                <i class="bi bi-grid"></i> Explore Modules
            </a>
        </div>
    </div>

    <div class="slider-controls">
        <button class="slider-dot active" onclick="goToSlide(0)"></button>
        <button class="slider-dot" onclick="goToSlide(1)"></button>
        <button class="slider-dot" onclick="goToSlide(2)"></button>
    </div>
</section>

<!-- STATS -->
<div class="stats-section">
    <div class="stats-grid">
        <div class="stat-item fade-up">
            <div class="stat-num">500+</div>
            <div class="stat-label">Vehicles Produced</div>
        </div>
        <div class="stat-item fade-up">
            <div class="stat-num">98%</div>
            <div class="stat-label">Quality Pass Rate</div>
        </div>
        <div class="stat-item fade-up">
            <div class="stat-num">6</div>
            <div class="stat-label">Production Modules</div>
        </div>
        <div class="stat-item fade-up">
            <div class="stat-num">24/7</div>
            <div class="stat-label">System Monitoring</div>
        </div>
    </div>
</div>

<!-- ABOUT -->
<section class="about-section" id="about">
    <div class="container">
        <div class="about-grid">
            <div class="about-image fade-up">
                <img src="https://images.unsplash.com/photo-1565043589221-1a6fd9ae45c7?w=800&q=80" alt="AutoProd Factory">
                <div class="img-badge">
                    <div class="img-badge-icon"><i class="bi bi-trophy"></i></div>
                    <div class="img-badge-text">
                        <div class="num">10+ Years</div>
                        <div class="lbl">Industry Experience</div>
                    </div>
                </div>
            </div>
            <div class="fade-up">
                <div class="section-tag"><i class="bi bi-info-circle"></i> About Us</div>
                <h2 class="section-title">Revolutionizing <span>Automobile</span> Production</h2>
                <p class="section-desc">AutoProd is a cutting-edge automobile manufacturing management system designed to streamline every stage of vehicle production — from design to final quality approval.</p>
                <p class="section-desc" style="margin-top:12px;">Our platform connects design teams, QC engineers, testing specialists, analytics experts, and administrators in a seamless workflow chain.</p>
                <div class="about-features">
                    <div class="about-feature">
                        <div class="feature-icon"><i class="bi bi-shield-check"></i></div>
                        <div class="feature-text">
                            <h4>Secure Access</h4>
                            <p>Role-based authentication for all team members</p>
                        </div>
                    </div>
                    <div class="about-feature">
                        <div class="feature-icon"><i class="bi bi-graph-up-arrow"></i></div>
                        <div class="feature-text">
                            <h4>Real-time Analytics</h4>
                            <p>Live dashboards and production reports</p>
                        </div>
                    </div>
                    <div class="about-feature">
                        <div class="feature-icon"><i class="bi bi-arrow-repeat"></i></div>
                        <div class="feature-text">
                            <h4>Chain Workflow</h4>
                            <p>Automated process from design to approval</p>
                        </div>
                    </div>
                    <div class="about-feature">
                        <div class="feature-icon"><i class="bi bi-people"></i></div>
                        <div class="feature-text">
                            <h4>Customer Portal</h4>
                            <p>Dedicated portal for client requirements</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>

<!-- MODULES -->
<section class="modules-section" id="modules">
    <div class="container">
        <div class="text-center fade-up">
            <div class="section-tag" style="margin:0 auto 16px;"><i class="bi bi-grid"></i> Our Modules</div>
            <h2 class="section-title" style="text-align:center;">Complete Production <span>Ecosystem</span></h2>
            <p class="section-desc" style="margin:0 auto;">Every module works together in a seamless chain workflow.</p>
        </div>
        <div class="modules-grid">
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#e3f2fd;"><span>🎨</span></div>
                <h3>Vehicle Design</h3>
                <p>Design and configure vehicle models with detailed specifications including fuel type, seating capacity, and battery capacity.</p>
                <span class="module-tag" style="background:#e3f2fd;color:#1565c0;">Design Team</span>
            </div>
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#e8f5e9;"><span>✅</span></div>
                <h3>QC Module</h3>
                <p>Quality control engineers review and approve or reject vehicle designs based on production standards and specifications.</p>
                <span class="module-tag" style="background:#e8f5e9;color:#2e7d32;">QC Team</span>
            </div>
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#fff3e0;"><span>🔬</span></div>
                <h3>Testing Module</h3>
                <p>Comprehensive vehicle testing including road performance, safety & emission tests, and engine stress tests.</p>
                <span class="module-tag" style="background:#fff3e0;color:#e65100;">Testing Team</span>
            </div>
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#f3e5f5;"><span>📊</span></div>
                <h3>Analytics</h3>
                <p>Real-time production analytics with charts, reports, and KPIs to monitor the entire manufacturing pipeline.</p>
                <span class="module-tag" style="background:#f3e5f5;color:#6a1b9a;">Analytics Team</span>
            </div>
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#ffebee;"><span>👑</span></div>
                <h3>Admin Dashboard</h3>
                <p>Full administrative control over users, modules, reports, and system-wide settings and approvals.</p>
                <span class="module-tag" style="background:#ffebee;color:#c62828;">Admin Only</span>
            </div>
            <div class="module-card fade-up">
                <div class="module-icon" style="background:#e0f7fa;"><span>🤝</span></div>
                <h3>Customer Portal</h3>
                <p>Dedicated portal for clients to register, submit project requirements, and track the status of their requests.</p>
                <span class="module-tag" style="background:#e0f7fa;color:#00838f;">Customers</span>
            </div>
        </div>
    </div>
</section>

<!-- WORKFLOW -->
<section class="workflow-section" id="workflow">
    <div class="container">
        <div class="fade-up">
            <div class="section-tag"><i class="bi bi-arrow-repeat"></i> How It Works</div>
            <h2 class="section-title">Production <span>Workflow Chain</span></h2>
            <p class="section-desc">Every customer requirement flows through our structured workflow chain ensuring quality at every step.</p>
        </div>
        <div class="workflow-steps">
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>📋</span><span class="step-num">1</span></div>
                <h4>Customer<br>Submits</h4>
                <p>Client submits project requirements via portal</p>
            </div>
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>🎨</span><span class="step-num">2</span></div>
                <h4>Design<br>Team</h4>
                <p>Designers create vehicle specifications</p>
            </div>
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>✅</span><span class="step-num">3</span></div>
                <h4>QC<br>Review</h4>
                <p>QC team approves or rejects designs</p>
            </div>
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>🔬</span><span class="step-num">4</span></div>
                <h4>Testing<br>Phase</h4>
                <p>Approved vehicles undergo rigorous testing</p>
            </div>
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>📊</span><span class="step-num">5</span></div>
                <h4>Analytics<br>Report</h4>
                <p>Performance data analyzed and reported</p>
            </div>
            <div class="workflow-step fade-up">
                <div class="step-circle"><span>🚗</span><span class="step-num">6</span></div>
                <h4>Final<br>Approval</h4>
                <p>Admin gives final production clearance</p>
            </div>
        </div>
    </div>
</section>

<!-- PORTAL ACCESS -->
<section class="portal-section" id="portal">
    <div class="container">
        <div class="text-center fade-up">
            <div class="section-tag" style="margin:0 auto 16px;"><i class="bi bi-box-arrow-in-right"></i> Access Portal</div>
            <h2 class="section-title" style="text-align:center;">Choose Your <span>Login</span></h2>
            <p class="section-desc" style="margin:0 auto;">Two separate portals for staff and customers, each with dedicated features.</p>
        </div>
        <div class="portal-grid fade-up">
            <div class="portal-card portal-staff">
                <span class="portal-icon">👨‍💼</span>
                <h3>Staff Portal</h3>
                <p>Access for internal team members including admin, designers, QC engineers, testers, and analysts.</p>
                <ul class="portal-features">
                    <li><i class="bi bi-check-circle-fill"></i> Role-based dashboard access</li>
                    <li><i class="bi bi-check-circle-fill"></i> Vehicle design & management</li>
                    <li><i class="bi bi-check-circle-fill"></i> QC approval workflow</li>
                    <li><i class="bi bi-check-circle-fill"></i> Testing & analytics modules</li>
                </ul>
                <a href="${pageContext.request.contextPath}/index.jsp" class="btn-portal">
                    <i class="bi bi-arrow-right-circle"></i> Staff Login →
                </a>
            </div>
            <div class="portal-card portal-customer">
                <span class="portal-icon">🤝</span>
                <h3>Customer Portal</h3>
                <p>Access for external clients to submit project requirements and track their production status.</p>
                <ul class="portal-features">
                    <li><i class="bi bi-check-circle-fill"></i> Easy registration & login</li>
                    <li><i class="bi bi-check-circle-fill"></i> Submit project requirements</li>
                    <li><i class="bi bi-check-circle-fill"></i> Track requirement status</li>
                    <li><i class="bi bi-check-circle-fill"></i> Upload supporting documents</li>
                </ul>
                <a href="${pageContext.request.contextPath}/customer_login.jsp" class="btn-portal">
                    <i class="bi bi-arrow-right-circle"></i> Customer Login →
                </a>
            </div>
        </div>
    </div>
</section>

<!-- COMPANY INFO -->
<section class="company-section" id="company">
    <div class="container">
        <div class="company-grid">
            <div class="fade-up">
                <div class="section-tag"><i class="bi bi-building"></i> Company Info</div>
                <h2 class="section-title">About <span>AutoProd</span></h2>
                <p style="color:var(--text-light);line-height:1.8;margin-bottom:12px;">AutoProd is a leading automobile manufacturing management platform built to handle the complete production lifecycle — from initial design concepts to final vehicle approval and delivery.</p>
                <p style="color:var(--text-light);line-height:1.8;margin-bottom:24px;">Our system brings together all stakeholders — designers, QC engineers, testers, analysts, and customers — on a single unified platform with secure role-based access.</p>
                <div class="company-details">
                    <div class="company-detail">
                        <div class="detail-icon"><i class="bi bi-building"></i></div>
                        <div class="detail-text">
                            <div class="label">Company Name</div>
                            <div class="value">AutoProd Manufacturing Systems Pvt. Ltd.</div>
                        </div>
                    </div>
                    <div class="company-detail">
                        <div class="detail-icon"><i class="bi bi-geo-alt"></i></div>
                        <div class="detail-text">
                            <div class="label">Location</div>
                            <div class="value">Chennai, Tamil Nadu, India</div>
                        </div>
                    </div>
                    <div class="company-detail">
                        <div class="detail-icon"><i class="bi bi-envelope"></i></div>
                        <div class="detail-text">
                            <div class="label">Email</div>
                            <div class="value">contact@autoprod.in</div>
                        </div>
                    </div>
                    <div class="company-detail">
                        <div class="detail-icon"><i class="bi bi-telephone"></i></div>
                        <div class="detail-text">
                            <div class="label">Phone</div>
                            <div class="value">+91 98765 43210</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="company-image fade-up">
                <img src="https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=80" alt="AutoProd Office">
            </div>
        </div>
    </div>
</section>

<!-- FOOTER -->
<footer>
    <div class="footer-grid">
        <div>
            <div class="footer-brand">Auto<span>Prod</span> 🚗</div>
            <p class="footer-desc">Complete automobile manufacturing management system with role-based access, quality control, and real-time analytics.</p>
            <div class="footer-social">
                <a href="#" class="social-btn"><i class="bi bi-linkedin"></i></a>
                <a href="#" class="social-btn"><i class="bi bi-twitter"></i></a>
                <a href="#" class="social-btn"><i class="bi bi-facebook"></i></a>
                <a href="#" class="social-btn"><i class="bi bi-instagram"></i></a>
            </div>
        </div>
        <div class="footer-col">
            <h4>Modules</h4>
            <ul>
                <li><a href="#">Vehicle Design</a></li>
                <li><a href="#">QC Module</a></li>
                <li><a href="#">Testing</a></li>
                <li><a href="#">Analytics</a></li>
                <li><a href="#">Admin Panel</a></li>
            </ul>
        </div>
        <div class="footer-col">
            <h4>Portals</h4>
            <ul>
                <li><a href="${pageContext.request.contextPath}/index.jsp">Staff Login</a></li>
                <li><a href="${pageContext.request.contextPath}/customer_login.jsp">Customer Login</a></li>
                <li><a href="#">Register</a></li>
                <li><a href="#">Status Check</a></li>
            </ul>
        </div>
        <div class="footer-col">
            <h4>Company</h4>
            <ul>
                <li><a href="#about">About Us</a></li>
                <li><a href="#workflow">How It Works</a></li>
                <li><a href="#company">Contact</a></li>
                <li><a href="#">Privacy Policy</a></li>
            </ul>
        </div>
    </div>
    <div class="footer-bottom">
        <p>© 2026 <span>AutoProd</span> Manufacturing Systems. All rights reserved.</p>
        <p>Built with ❤️ for the Auto Industry</p>
    </div>
</footer>

<script>
    // Navbar scroll effect
    window.addEventListener('scroll', () => {
        document.getElementById('navbar').classList.toggle('scrolled', window.scrollY > 50);
    });

    // Image Slider
    let currentSlide = 0;
    const slides = document.querySelectorAll('.slide');
    const dots = document.querySelectorAll('.slider-dot');

    function goToSlide(n) {
        slides[currentSlide].classList.remove('active');
        dots[currentSlide].classList.remove('active');
        currentSlide = (n + slides.length) % slides.length;
        slides[currentSlide].classList.add('active');
        dots[currentSlide].classList.add('active');
    }

    function changeSlide(dir) { goToSlide(currentSlide + dir); }

    // Auto slide every 5 seconds
    setInterval(() => changeSlide(1), 5000);

    // Scroll animations
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(e => { if (e.isIntersecting) e.target.classList.add('visible'); });
    }, { threshold: 0.1 });

    document.querySelectorAll('.fade-up').forEach(el => observer.observe(el));
</script>
</body>
</html>