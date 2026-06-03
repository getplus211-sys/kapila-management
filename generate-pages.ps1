$template = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>__TITLE__</title>
  <link rel="stylesheet" href="styles.css">
  <script src="config.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.1/dist/umd/supabase.min.js"></script>
</head>
<body data-module="__MODULE__" data-title="__TITLE__">
  <main class="module-shell">
    <header class="module-topbar">
      <div>
        <p class="eyebrow">Module</p>
        <h2 id="roleTitle">Login to continue</h2>
        <p class="muted" id="userEmail">Authenticated user</p>
      </div>
      <div class="module-topbar-actions">
        <a href="index.html" class="secondary-btn">Back</a>
        <span class="pill pill-success" id="connectionPill">Disconnected</span>
        <button class="secondary-btn" id="signOutBtn" type="button">Logout</button>
      </div>
    </header>

    <section class="auth-card" id="loginCard">
      <div class="brand">
        <div class="brand-mark">K</div>
        <div>
          <h1>KAPiLA Management System</h1>
          <p>Admin Management Panel</p>
        </div>
      </div>
      <h2>Login</h2>
      <div class="login-grid">
        <input id="emailInput" class="kap-input" type="email" placeholder="Email" autocomplete="email" />
        <input id="passwordInput" class="kap-input" type="password" placeholder="Password" autocomplete="current-password" />
        <button id="loginBtn" class="kap-btn kap-btn-primary" type="button">Login</button>
      </div>
      <p class="kap-msg" id="authNote">Waiting for Supabase connection.</p>
    </section>

    <section class="module-shell hidden" id="moduleShell">
      <div class="module-content">
        <div class="panel">
          <p class="eyebrow">Page</p>
          <h1 id="moduleTitle" style="margin: 4px 0 8px;">__TITLE__</h1>
          <p class="muted" id="moduleSubtitle">Loading...</p>
          <p class="kap-msg" id="pageMessage"></p>
        </div>
      </div>
      <div id="moduleMeta"></div>
      <div id="moduleContent" class="module-content"></div>
    </section>
  </main>

  <script src="module.js"></script>
</body>
</html>
'@

$pages = @(
  @{ file='verification-requests.html'; module='verification-requests'; title='Verification Requests' },
  @{ file='verified-users.html'; module='verified-users'; title='Verified Users' },
  @{ file='moderation-reports.html'; module='moderation-reports'; title='Reports' },
  @{ file='non-educational-reports.html'; module='non-educational-reports'; title='Non-Educational Reports' },
  @{ file='suggestions.html'; module='suggestions'; title='Suggestions' },
  @{ file='feedback-replies.html'; module='feedback-replies'; title='Ask/Feedback Replies' },
  @{ file='affiliate-requests.html'; module='affiliate-requests'; title='Affiliate Requests' },
  @{ file='affiliate-payouts.html'; module='affiliate-payouts'; title='Affiliate Payouts' },
  @{ file='affiliate-commission-rules.html'; module='affiliate-commission-rules'; title='Affiliate Commission Rules' },
  @{ file='subscription-plans.html'; module='subscription-plans'; title='Subscription Plans' },
  @{ file='test-series.html'; module='test-series'; title='Test Series Manager' },
  @{ file='mock-broadcast.html'; module='mock-broadcast'; title='Mock Broadcast' },
  @{ file='notification-broadcast.html'; module='notification-broadcast'; title='Notification Broadcast' },
  @{ file='daily-learning.html'; module='daily-learning'; title='Daily Learning Manager' },
  @{ file='admin-users.html'; module='admin-users'; title='Admin Users' },
  @{ file='audit-logs.html'; module='audit-logs'; title='Audit Logs' },
  @{ file='analytics.html'; module='analytics'; title='App Analytics' },
  @{ file='analytics-revenue.html'; module='analytics-revenue'; title='Revenue Analytics (Owner)' }
)

foreach ($page in $pages) {
  $content = $template.Replace('__TITLE__', $page.title).Replace('__MODULE__', $page.module)
  Set-Content -Path (Join-Path $PSScriptRoot $page.file) -Value $content
}
