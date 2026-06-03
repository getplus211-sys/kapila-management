const config = window.ADMIN_PANEL_CONFIG || {}
const supabaseUrl = config.supabaseUrl || ''
const supabaseAnonKey = config.supabaseAnonKey || ''

const moduleKey = document.body.dataset.module || ''
const loginCard = document.getElementById('loginCard')
const moduleShell = document.getElementById('moduleShell')
const authNote = document.getElementById('authNote')
const connectionPill = document.getElementById('connectionPill')
const emailInput = document.getElementById('emailInput')
const passwordInput = document.getElementById('passwordInput')
const loginBtn = document.getElementById('loginBtn')
const signOutBtn = document.getElementById('signOutBtn')
const moduleTitle = document.getElementById('moduleTitle')
const moduleSubtitle = document.getElementById('moduleSubtitle')
const moduleMeta = document.getElementById('moduleMeta')
const moduleContent = document.getElementById('moduleContent')
const roleTitle = document.getElementById('roleTitle')
const userEmail = document.getElementById('userEmail')
const pageMessage = document.getElementById('pageMessage')

let supabase = null
let currentRole = null

const ROLE_GROUPS = {
  moderation: ['owner', 'admin', 'moderator'],
  sales: ['owner', 'admin', 'sales_manager', 'sales_agent'],
  ownerAdmin: ['owner', 'admin'],
  ownerOnly: ['owner'],
}

function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

function setMessage(message, isError = true) {
  if (authNote) authNote.textContent = message || (isError ? 'Action needed.' : 'Connected.')
  if (pageMessage) pageMessage.textContent = message || '-'
}

function setConnectionStatus(connected, message) {
  if (connectionPill) {
    connectionPill.textContent = connected ? 'Connected' : 'Disconnected'
    connectionPill.className = `pill ${connected ? 'pill-success' : 'pill-danger'}`
  }
  setMessage(message, !connected)
}

async function getCurrentUser() {
  const { data: sessionData } = await supabase.auth.getSession()
  if (sessionData.session?.user) return sessionData.session.user
  const { data: authData } = await supabase.auth.getUser()
  return authData.user ?? null
}

async function getAdminAccess() {
  const user = await getCurrentUser()
  if (!user) return { user: null, role: null }

  const { data, error } = await supabase
    .from('ngm_admin_roles')
    .select('role,is_active')
    .eq('user_id', user.id)
    .maybeSingle()

  if (error || !data || data.is_active !== true) {
    return { user, role: null, error }
  }

  return { user, role: data.role || null, error: null }
}

function hasAccess(role, allowedRoles) {
  return allowedRoles.includes(role || '')
}

function setVisible(visible) {
  if (loginCard) loginCard.classList.toggle('hidden', visible)
  if (moduleShell) moduleShell.classList.toggle('hidden', !visible)
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function fmt(value) {
  if (value === null || value === undefined || value === '') return '-'
  if (typeof value === 'object') return escapeHtml(JSON.stringify(value))
  return escapeHtml(value)
}

function renderCards(cards) {
  if (!cards?.length) return ''
  return `<div class="module-summary-grid">${cards
    .map(
      (card) => `
        <div class="summary-card">
          <span>${escapeHtml(card.label)}</span>
          <strong>${escapeHtml(card.value)}</strong>
          ${card.note ? `<p>${escapeHtml(card.note)}</p>` : ''}
        </div>`
    )
    .join('')}</div>`
}

function renderTable(rows, options = {}) {
  if (!rows?.length) {
    return `<div class="panel"><p>${escapeHtml(options.emptyText || 'No rows found.')}</p></div>`
  }
  const columns = options.columns || Object.keys(rows[0])
  const headers = columns.map((key) => `<th>${escapeHtml(options.labels?.[key] || key.replaceAll('_', ' '))}</th>`).join('')
  const body = rows
    .map(
      (row) => `<tr>${columns
        .map((key) => `<td>${fmt(row[key])}</td>`)
        .join('')}</tr>`
    )
    .join('')
  return `
    <div class="panel table-card">
      ${options.title ? `<h3 style="margin:0 0 10px 0">${escapeHtml(options.title)}</h3>` : ''}
      <table>
        <thead><tr>${headers}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>`
}

function renderList(items, options = {}) {
  if (!items?.length) return `<div class="panel"><p>${escapeHtml(options.emptyText || 'No items found.')}</p></div>`
  return `
    <div class="panel">
      ${options.title ? `<h3 style="margin:0 0 10px 0">${escapeHtml(options.title)}</h3>` : ''}
      <div class="list-grid">
        ${items
          .map(
            (item) => `
              <div class="list-row">
                <strong>${escapeHtml(item.title)}</strong>
                <span>${escapeHtml(item.detail)}</span>
              </div>`
          )
          .join('')}
      </div>
    </div>`
}

async function loadVerificationRequests() {
  const [reqRes, userRes] = await Promise.all([
    supabase
      .from('ngm_verification_requests')
      .select('request_id,user_id,status,created_at')
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(20),
    supabase.from('ngm_users').select('user_id,username,full_name,email,mobile').limit(500),
  ])

  if (reqRes.error) throw reqRes.error
  if (userRes.error) throw userRes.error

  const userMap = new Map((userRes.data || []).map((user) => [user.user_id, user]))
  const rows = (reqRes.data || []).map((row) => {
    const user = userMap.get(row.user_id)
    return {
      request_id: row.request_id,
      user: user?.full_name || user?.username || user?.email || row.user_id,
      status: row.status,
      created_at: row.created_at,
    }
  })

  return {
    title: 'Verification Requests',
    subtitle: 'Pending approvals from ngm_verification_requests.',
    cards: [{ label: 'Pending', value: rows.length }],
    body: renderTable(rows, {
      title: 'Pending requests',
      columns: ['request_id', 'user', 'status', 'created_at'],
      labels: { request_id: 'Request ID', user: 'User', status: 'Status', created_at: 'Created' },
      emptyText: 'No pending verification requests.',
    }),
  }
}

async function loadVerifiedUsers() {
  const { data, error } = await supabase
    .from('ngm_users')
    .select('user_id,username,full_name,email,mobile,district,is_verified')
    .eq('is_verified', true)
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  const rows = (data || []).map((row) => ({
    user_id: row.user_id,
    name: row.full_name || row.username || row.email || row.user_id,
    mobile: row.mobile || '-',
    district: row.district || '-',
  }))
  return {
    title: 'Verified Users',
    subtitle: 'Approved creators and users.',
    cards: [{ label: 'Verified', value: rows.length }],
    body: renderTable(rows, {
      title: 'Verified users',
      columns: ['user_id', 'name', 'mobile', 'district'],
      labels: { user_id: 'User ID', name: 'Name', mobile: 'Mobile', district: 'District' },
      emptyText: 'No verified users found.',
    }),
  }
}

async function loadModerationReports() {
  const [postRes, quizRes, pollRes, userRes] = await Promise.all([
    supabase.from('ngm_post_reports').select('report_id,post_id,reported_by,report_reason,status,created_at').eq('status', 'pending').limit(20),
    supabase.from('ngm_quiz_reports').select('report_id,quiz_id,reported_by,report_reason,status,created_at').eq('status', 'pending').limit(20),
    supabase.from('ngm_poll_reports').select('report_id,poll_id,reported_by,report_reason,status,created_at').eq('status', 'pending').limit(20),
    supabase.from('ngm_user_reports').select('report_id,reported_user_id,reporter_user_id,report_reason,status,created_at').eq('status', 'pending').limit(20),
  ])
  const firstErr = postRes.error ?? quizRes.error ?? pollRes.error ?? userRes.error
  if (firstErr) throw firstErr
  const rows = [
    ...((postRes.data || []).map((row) => ({ source: 'post', id: row.post_id, reported_by: row.reported_by, reason: row.report_reason, created_at: row.created_at }))),
    ...((quizRes.data || []).map((row) => ({ source: 'quiz', id: row.quiz_id, reported_by: row.reported_by, reason: row.report_reason, created_at: row.created_at }))),
    ...((pollRes.data || []).map((row) => ({ source: 'poll', id: row.poll_id, reported_by: row.reported_by, reason: row.report_reason, created_at: row.created_at }))),
    ...((userRes.data || []).map((row) => ({ source: 'user', id: row.reported_user_id, reported_by: row.reporter_user_id, reason: row.report_reason, created_at: row.created_at }))),
  ].slice(0, 50)
  return {
    title: 'Reports',
    subtitle: 'Pending moderation reports across posts, quizzes, polls and users.',
    cards: [{ label: 'Pending', value: rows.length }],
    body: renderTable(rows, {
      title: 'Latest reports',
      columns: ['source', 'id', 'reported_by', 'reason', 'created_at'],
      labels: { source: 'Source', id: 'Content ID', reported_by: 'Reported By', reason: 'Reason', created_at: 'Created' },
      emptyText: 'No pending reports.',
    }),
  }
}

async function loadNonEducationalReports() {
  const { data, error } = await supabase.rpc('ngm_admin_list_pending_non_educational_reports_by_type', {
    p_report_type: null,
    p_limit: 50,
    p_offset: 0,
  })
  if (error) throw error
  const rows = (data || []).map((row) => ({
    report_type: row.report_type,
    report_id: row.report_id,
    content_id: row.content_id,
    reporter_user_id: row.reporter_user_id,
    report_reason: row.report_reason,
    created_at: row.created_at,
  }))
  return {
    title: 'Non-Educational Reports',
    subtitle: 'RPC-powered pending reports.',
    cards: [{ label: 'Pending', value: rows.length }],
    body: renderTable(rows, {
      title: 'Pending non-educational reports',
      columns: ['report_type', 'report_id', 'content_id', 'reporter_user_id', 'report_reason', 'created_at'],
      labels: {
        report_type: 'Type',
        report_id: 'Report ID',
        content_id: 'Content ID',
        reporter_user_id: 'Reporter',
        report_reason: 'Reason',
        created_at: 'Created',
      },
      emptyText: 'No non-educational reports.',
    }),
  }
}

async function loadSuggestions() {
  const { data, error } = await supabase
    .from('kls_questions')
    .select('id,quiz_id,chapter_code,subject_id,suggestion,created_at')
    .not('suggestion', 'is', null)
    .neq('suggestion', '')
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  const rows = (data || []).map((row) => ({
    id: row.id,
    quiz_id: row.quiz_id,
    chapter_code: row.chapter_code || '-',
    suggestion: row.suggestion,
    created_at: row.created_at,
  }))
  return {
    title: 'Suggestions',
    subtitle: 'Rows from kls_questions with suggestion text.',
    cards: [{ label: 'Suggestions', value: rows.length }],
    body: renderTable(rows, {
      title: 'Suggestion rows',
      columns: ['id', 'quiz_id', 'chapter_code', 'suggestion', 'created_at'],
      labels: { id: 'Question ID', quiz_id: 'Quiz ID', chapter_code: 'Chapter', suggestion: 'Suggestion', created_at: 'Created' },
      emptyText: 'No suggestion rows found.',
    }),
  }
}

async function loadFeedbackReplies() {
  const [threadRes, messageRes] = await Promise.all([
    supabase.from('ngm_feedback_threads').select('thread_id,user_id,status,created_at').order('created_at', { ascending: false }).limit(20),
    supabase.from('ngm_feedback_messages').select('message_id,thread_id,user_id,admin_user_id,message_text,created_at').order('created_at', { ascending: false }).limit(50),
  ])
  const firstErr = threadRes.error ?? messageRes.error
  if (firstErr) throw firstErr
  return {
    title: 'Ask/Feedback Replies',
    subtitle: 'Feedback threads and replies.',
    cards: [{ label: 'Threads', value: (threadRes.data || []).length }, { label: 'Messages', value: (messageRes.data || []).length }],
    body: [
      renderTable(threadRes.data || [], {
        title: 'Threads',
        columns: ['thread_id', 'user_id', 'status', 'created_at'],
        labels: { thread_id: 'Thread ID', user_id: 'User', status: 'Status', created_at: 'Created' },
        emptyText: 'No feedback threads.',
      }),
      renderTable(messageRes.data || [], {
        title: 'Messages',
        columns: ['message_id', 'thread_id', 'user_id', 'admin_user_id', 'message_text', 'created_at'],
        labels: { message_id: 'Message ID', thread_id: 'Thread', user_id: 'User', admin_user_id: 'Admin', message_text: 'Message', created_at: 'Created' },
        emptyText: 'No feedback messages.',
      }),
    ].join(''),
  }
}

async function loadAffiliateRequests() {
  const { data, error } = await supabase
    .from('kls_affiliate_applications')
    .select('application_id,user_id,full_name,phone_number,organization_name,status,created_at')
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  return {
    title: 'Affiliate Requests',
    subtitle: 'Creator affiliate applications.',
    cards: [{ label: 'Applications', value: (data || []).length }],
    body: renderTable(data || [], {
      title: 'Applications',
      columns: ['application_id', 'user_id', 'full_name', 'organization_name', 'status', 'created_at'],
      labels: { application_id: 'Application', user_id: 'User', full_name: 'Name', organization_name: 'Organization', status: 'Status', created_at: 'Created' },
      emptyText: 'No affiliate applications.',
    }),
  }
}

async function loadAffiliatePayouts() {
  const [profilesRes, payoutsRes] = await Promise.all([
    supabase.from('kls_affiliate_profiles').select('user_id,affiliate_code,is_active').eq('is_active', true).limit(100),
    supabase.from('kls_affiliate_payouts').select('payout_id,affiliate_user_id,amount,paid_at,notes').order('paid_at', { ascending: false }).limit(50),
  ])
  const firstErr = profilesRes.error ?? payoutsRes.error
  if (firstErr) throw firstErr
  return {
    title: 'Affiliate Payouts',
    subtitle: 'Active affiliate profiles and payouts.',
    cards: [{ label: 'Active Affiliates', value: (profilesRes.data || []).length }, { label: 'Payouts', value: (payoutsRes.data || []).length }],
    body: [
      renderTable(profilesRes.data || [], {
        title: 'Active profiles',
        columns: ['user_id', 'affiliate_code', 'is_active'],
        labels: { user_id: 'User', affiliate_code: 'Code', is_active: 'Active' },
        emptyText: 'No active affiliates.',
      }),
      renderTable(payoutsRes.data || [], {
        title: 'Payouts',
        columns: ['payout_id', 'affiliate_user_id', 'amount', 'paid_at', 'notes'],
        labels: { payout_id: 'Payout', affiliate_user_id: 'Affiliate User', amount: 'Amount', paid_at: 'Paid At', notes: 'Notes' },
        emptyText: 'No payouts found.',
      }),
    ].join(''),
  }
}

async function loadAffiliateCommissionRules() {
  const [profilesRes, rulesRes, plansRes, seriesRes] = await Promise.all([
    supabase.from('kls_affiliate_profiles').select('affiliate_profile_id,user_id,affiliate_code,commission_percent,is_active').limit(100),
    supabase.from('kls_affiliate_commission_rules').select('rule_id,affiliate_profile_id,product_type,test_series_id,subscription_plan_id,fixed_commission_amount,is_active,updated_at').order('updated_at', { ascending: false }).limit(50),
    supabase.from('kls_subscription_plans').select('subscription_plan_id,plan_name,plan_code').limit(100),
    supabase.from('kls_test_series').select('test_series_id,series_name').limit(100),
  ])
  const firstErr = profilesRes.error ?? rulesRes.error ?? plansRes.error ?? seriesRes.error
  if (firstErr) throw firstErr
  const planMap = new Map((plansRes.data || []).map((row) => [row.subscription_plan_id, row.plan_name]))
  const seriesMap = new Map((seriesRes.data || []).map((row) => [row.test_series_id, row.series_name]))
  const rows = (rulesRes.data || []).map((row) => ({
    rule_id: row.rule_id,
    profile: row.affiliate_profile_id,
    product_type: row.product_type,
    target: row.product_type === 'subscription' ? (row.subscription_plan_id ? planMap.get(row.subscription_plan_id) || row.subscription_plan_id : 'All Plans') : (row.test_series_id ? seriesMap.get(row.test_series_id) || row.test_series_id : 'All Series'),
    amount: row.fixed_commission_amount,
    is_active: row.is_active,
  }))
  return {
    title: 'Affiliate Commission Rules',
    subtitle: 'Profiles, plans, test series and rules.',
    cards: [{ label: 'Profiles', value: (profilesRes.data || []).length }, { label: 'Rules', value: rows.length }],
    body: renderTable(rows, {
      title: 'Commission rules',
      columns: ['rule_id', 'profile', 'product_type', 'target', 'amount', 'is_active'],
      labels: { rule_id: 'Rule', profile: 'Profile', product_type: 'Type', target: 'Target', amount: 'Amount', is_active: 'Active' },
      emptyText: 'No commission rules.',
    }),
  }
}

async function loadSubscriptionPlans() {
  const { data, error } = await supabase
    .from('kls_subscription_plans')
    .select('subscription_plan_id,plan_name,plan_code,price,period_days,is_active')
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  return {
    title: 'Subscription Plans',
    subtitle: 'Manage plan list.',
    cards: [{ label: 'Plans', value: (data || []).length }],
    body: renderTable(data || [], {
      title: 'Plans',
      columns: ['subscription_plan_id', 'plan_name', 'plan_code', 'price', 'period_days', 'is_active'],
      labels: { subscription_plan_id: 'Plan ID', plan_name: 'Plan Name', plan_code: 'Code', price: 'Price', period_days: 'Days', is_active: 'Active' },
      emptyText: 'No subscription plans.',
    }),
  }
}

async function loadTestSeries() {
  const [seriesRes, mocksRes, mapsRes] = await Promise.all([
    supabase.from('kls_test_series').select('test_series_id,exam_code,series_name,is_active,created_at').order('created_at', { ascending: false }).limit(50),
    supabase.from('kls_mock_tests').select('mock_test_id,exam_code,mock_name,is_active,is_live,is_paused').order('created_at', { ascending: false }).limit(50),
    supabase.from('kls_test_series_mocks').select('test_series_id,mock_test_id,display_order').order('display_order', { ascending: true }).limit(100),
  ])
  const firstErr = seriesRes.error ?? mocksRes.error ?? mapsRes.error
  if (firstErr) throw firstErr
  return {
    title: 'Test Series',
    subtitle: 'Series, mocks, and mapping rows.',
    cards: [{ label: 'Series', value: (seriesRes.data || []).length }, { label: 'Mocks', value: (mocksRes.data || []).length }],
    body: [
      renderTable(seriesRes.data || [], {
        title: 'Series',
        columns: ['test_series_id', 'exam_code', 'series_name', 'is_active', 'created_at'],
        labels: { test_series_id: 'Series ID', exam_code: 'Exam', series_name: 'Series Name', is_active: 'Active', created_at: 'Created' },
        emptyText: 'No test series.',
      }),
      renderTable(mocksRes.data || [], {
        title: 'Mocks',
        columns: ['mock_test_id', 'exam_code', 'mock_name', 'is_active', 'is_live', 'is_paused'],
        labels: { mock_test_id: 'Mock ID', exam_code: 'Exam', mock_name: 'Mock Name', is_active: 'Active', is_live: 'Live', is_paused: 'Paused' },
        emptyText: 'No mocks.',
      }),
      renderTable(mapsRes.data || [], {
        title: 'Mappings',
        columns: ['test_series_id', 'mock_test_id', 'display_order'],
        labels: { test_series_id: 'Series', mock_test_id: 'Mock', display_order: 'Order' },
        emptyText: 'No mappings.',
      }),
    ].join(''),
  }
}

async function loadMockBroadcast() {
  const { data, error } = await supabase
    .from('kls_mock_tests')
    .select('mock_test_id,exam_code,mock_name,is_active,is_live,is_paused,created_at')
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  return {
    title: 'Mock Broadcast',
    subtitle: 'Choose a mock and broadcast it from your backend workflows.',
    cards: [{ label: 'Mocks', value: (data || []).length }],
    body: renderTable(data || [], {
      title: 'Mocks',
      columns: ['mock_test_id', 'exam_code', 'mock_name', 'is_active', 'is_live', 'is_paused'],
      labels: { mock_test_id: 'Mock ID', exam_code: 'Exam', mock_name: 'Mock Name', is_active: 'Active', is_live: 'Live', is_paused: 'Paused' },
      emptyText: 'No mocks found.',
    }),
  }
}

async function loadNotificationBroadcast() {
  return {
    title: 'Notification Broadcast',
    subtitle: 'Send a broadcast to users from the configured RPC.',
    cards: [{ label: 'Target Groups', value: 4 }],
    body: `
      <div class="panel">
        <div class="form-grid">
          <select id="targetGroup" class="kap-input">
            <option value="all_users">All Users</option>
            <option value="subscription_users">Subscription Users</option>
            <option value="test_series_buyers">Test Series Buyers</option>
            <option value="affiliates_only">Affiliates Only</option>
          </select>
          <input id="broadcastTitle" class="kap-input" placeholder="Notification Title" />
          <textarea id="broadcastBody" class="kap-input" rows="5" placeholder="Notification Message"></textarea>
          <button id="sendBroadcastBtn" class="kap-btn kap-btn-primary" type="button">Send Notification</button>
        </div>
      </div>
    `,
  }
}

async function loadDailyLearning() {
  const [subjectRes, chapterRes, quizRes, questionRes] = await Promise.all([
    supabase.from('kls_subjects').select('id,name,subject_code').limit(50),
    supabase.from('kls_chapters').select('id,name,chapter_code,subject_id').limit(50),
    supabase.from('kls_quizzes').select('quiz_id,quiz_name,chapter_code,difficulty_level,subject_id,total_questions,time_limit,is_active').limit(50),
    supabase.from('kls_questions').select('id,quiz_id,question,subject_id,chapter_code,difficulty_level,suggestion').limit(50),
  ])
  const firstErr = subjectRes.error ?? chapterRes.error ?? quizRes.error ?? questionRes.error
  if (firstErr) throw firstErr
  return {
    title: 'Daily Learning Manager',
    subtitle: 'Subjects, chapters, quizzes and questions.',
    cards: [{ label: 'Subjects', value: (subjectRes.data || []).length }, { label: 'Quizzes', value: (quizRes.data || []).length }],
    body: [
      renderTable(subjectRes.data || [], { title: 'Subjects', columns: ['id', 'name', 'subject_code'], labels: { id: 'ID', name: 'Name', subject_code: 'Code' }, emptyText: 'No subjects.' }),
      renderTable(chapterRes.data || [], { title: 'Chapters', columns: ['id', 'name', 'chapter_code', 'subject_id'], labels: { id: 'ID', name: 'Name', chapter_code: 'Chapter', subject_id: 'Subject' }, emptyText: 'No chapters.' }),
      renderTable(quizRes.data || [], { title: 'Quizzes', columns: ['quiz_id', 'quiz_name', 'chapter_code', 'difficulty_level', 'subject_id', 'total_questions', 'time_limit', 'is_active'], labels: { quiz_id: 'Quiz ID', quiz_name: 'Quiz Name', chapter_code: 'Chapter', difficulty_level: 'Level', subject_id: 'Subject', total_questions: 'Questions', time_limit: 'Time', is_active: 'Active' }, emptyText: 'No quizzes.' }),
      renderTable(questionRes.data || [], { title: 'Questions', columns: ['id', 'quiz_id', 'chapter_code', 'difficulty_level', 'suggestion'], labels: { id: 'Question ID', quiz_id: 'Quiz', chapter_code: 'Chapter', difficulty_level: 'Level', suggestion: 'Suggestion' }, emptyText: 'No questions.' }),
    ].join(''),
  }
}

async function loadAdminUsers() {
  const { data, error } = await supabase
    .from('ngm_admin_roles')
    .select('user_id,role,is_active')
    .order('role', { ascending: true })
    .limit(100)
  if (error) throw error
  return {
    title: 'Admin Users',
    subtitle: 'Admin role rows from ngm_admin_roles.',
    cards: [{ label: 'Admin rows', value: (data || []).length }],
    body: renderTable(data || [], {
      title: 'Roles',
      columns: ['user_id', 'role', 'is_active'],
      labels: { user_id: 'User ID', role: 'Role', is_active: 'Active' },
      emptyText: 'No admin roles.',
    }),
  }
}

async function loadAuditLogs() {
  const [logsRes, usersRes] = await Promise.all([
    supabase.from('ngm_admin_actions_log').select('action_id,admin_user_id,action_type,target_table,target_id,created_at').order('created_at', { ascending: false }).limit(100),
    supabase.from('ngm_users').select('user_id,username,full_name,email').limit(500),
  ])
  const firstErr = logsRes.error ?? usersRes.error
  if (firstErr) throw firstErr
  const userMap = new Map((usersRes.data || []).map((user) => [user.user_id, user]))
  const rows = (logsRes.data || []).map((row) => ({
    action_id: row.action_id,
    admin: userMap.get(row.admin_user_id)?.full_name || userMap.get(row.admin_user_id)?.username || row.admin_user_id,
    action_type: row.action_type,
    target_table: row.target_table,
    target_id: row.target_id,
    created_at: row.created_at,
  }))
  return {
    title: 'Audit Logs',
    subtitle: 'Recent admin actions.',
    cards: [{ label: 'Logs', value: rows.length }],
    body: renderTable(rows, {
      title: 'Recent actions',
      columns: ['action_id', 'admin', 'action_type', 'target_table', 'target_id', 'created_at'],
      labels: { action_id: 'Action ID', admin: 'Admin', action_type: 'Action', target_table: 'Table', target_id: 'Target', created_at: 'Created' },
      emptyText: 'No audit logs.',
    }),
  }
}

async function loadAnalytics() {
  const { data: kpiData, error: kpiError } = await supabase.rpc('ngm_admin_get_kpi', { p_from: new Date(Date.now() - 6 * 86400000).toISOString(), p_to: new Date().toISOString() })
  const { data: seriesData, error: seriesError } = await supabase.rpc('ngm_admin_get_daily_series', { p_from: new Date(Date.now() - 6 * 86400000).toISOString().slice(0, 10), p_to: new Date().toISOString().slice(0, 10) })
  if (kpiError) throw kpiError
  if (seriesError) throw seriesError
  const kpi = kpiData || {}
  const rows = seriesData || []
  return {
    title: 'App Analytics',
    subtitle: 'Owner-only analytics overview.',
    cards: [
      { label: 'Total Users', value: kpi.total_users ?? 0 },
      { label: 'New Users', value: kpi.new_users_in_range ?? 0 },
      { label: 'DAU', value: kpi.dau_today ?? 0 },
      { label: 'MAU', value: kpi.mau_30d ?? 0 },
      { label: 'Peak Concurrent', value: kpi.peak_concurrent_5m ?? 0 },
    ],
    body: renderTable(rows, {
      title: 'Daily series',
      columns: ['day', 'dau', 'new_users', 'sessions', 'screen_views', 'app_opens'],
      labels: { day: 'Day', dau: 'DAU', new_users: 'New Users', sessions: 'Sessions', screen_views: 'Views', app_opens: 'Opens' },
      emptyText: 'No analytics data.',
    }),
  }
}

async function loadAnalyticsRevenue() {
  const [txRes, seriesRes, earnRes, payoutRes, profileRes] = await Promise.all([
    supabase.from('kls_payment_transactions').select('payment_txn_id,user_id,product_type,paid_at,created_at,test_series_id,final_amount,amount,status').eq('status', 'paid').order('paid_at', { ascending: false }).limit(200),
    supabase.from('kls_test_series').select('test_series_id,series_name').limit(200),
    supabase.from('kls_affiliate_earnings').select('affiliate_user_id,affiliate_code,commission_amount,status,created_at').in('status', ['approved', 'paid']).limit(200),
    supabase.from('kls_affiliate_payouts').select('affiliate_user_id,amount,paid_at').limit(200),
    supabase.from('kls_affiliate_profiles').select('user_id,affiliate_code').eq('is_active', true).limit(200),
  ])
  const firstErr = txRes.error ?? seriesRes.error ?? earnRes.error ?? payoutRes.error ?? profileRes.error
  if (firstErr) throw firstErr
  const txRows = txRes.data || []
  const seriesMap = new Map((seriesRes.data || []).map((s) => [s.test_series_id, s.series_name]))
  const subUsers = new Set()
  const seriesUsers = new Set()
  let subRevenue = 0
  let tsRevenue = 0
  const seriesAgg = new Map()
  for (const tx of txRows) {
    const amt = Number(tx.final_amount ?? tx.amount ?? 0)
    const ptype = String(tx.product_type || '').toLowerCase()
    if (ptype.includes('subscription')) {
      subUsers.add(tx.user_id)
      subRevenue += amt
    } else {
      seriesUsers.add(tx.user_id)
      tsRevenue += amt
      if (tx.test_series_id) {
        const name = seriesMap.get(tx.test_series_id) || tx.test_series_id
        const cur = seriesAgg.get(name) || { students: new Set(), revenue: 0 }
        cur.students.add(tx.user_id)
        cur.revenue += amt
        seriesAgg.set(name, cur)
      }
    }
  }
  const earnRows = earnRes.data || []
  const payoutRows = payoutRes.data || []
  const profileRows = profileRes.data || []
  const codeByUser = new Map(profileRows.map((p) => [p.user_id, p.affiliate_code]))
  const totalEarn = earnRows.reduce((s, r) => s + Number(r.commission_amount || 0), 0)
  const totalPaid = payoutRows.reduce((s, r) => s + Number(r.amount || 0), 0)
  const totalPayable = Math.max(0, totalEarn - totalPaid)
  const perAff = new Map()
  for (const e of earnRows) {
    const uid = e.affiliate_user_id
    const code = e.affiliate_code ?? codeByUser.get(uid) ?? uid
    const cur = perAff.get(uid) || { code, total: 0, paid: 0 }
    cur.total += Number(e.commission_amount || 0)
    perAff.set(uid, cur)
  }
  for (const p of payoutRows) {
    const uid = p.affiliate_user_id
    const code = codeByUser.get(uid) ?? uid
    const cur = perAff.get(uid) || { code, total: 0, paid: 0 }
    cur.paid += Number(p.amount || 0)
    perAff.set(uid, cur)
  }
  const affiliateRows = Array.from(perAff.values()).map((x) => ({ affiliate_code: x.code, total: x.total, paid: x.paid, payable: Math.max(0, x.total - x.paid) }))
  return {
    title: 'Revenue Analytics',
    subtitle: 'Owner-only revenue and affiliate insight.',
    cards: [
      { label: 'Subscription Students', value: subUsers.size },
      { label: 'Test-Series Students', value: seriesUsers.size },
      { label: 'Subscription Revenue', value: `Rs.${subRevenue.toFixed(2)}` },
      { label: 'Test-Series Revenue', value: `Rs.${tsRevenue.toFixed(2)}` },
      { label: 'Affiliate Payable', value: `Rs.${totalPayable.toFixed(2)}` },
    ],
    body: [
      renderTable(Array.from(seriesAgg.entries()).map(([series_name, v]) => ({ series_name, students: v.students.size, revenue: v.revenue })), {
        title: 'Series Wise Buyers',
        columns: ['series_name', 'students', 'revenue'],
        labels: { series_name: 'Series', students: 'Students', revenue: 'Revenue' },
        emptyText: 'No series revenue.',
      }),
      renderTable(affiliateRows, {
        title: 'Affiliate Payments',
        columns: ['affiliate_code', 'total', 'paid', 'payable'],
        labels: { affiliate_code: 'Affiliate Code', total: 'Total', paid: 'Paid', payable: 'Payable' },
        emptyText: 'No affiliate revenue.',
      }),
    ].join(''),
  }
}

async function loadPageData() {
  const loaders = {
    'verification-requests': loadVerificationRequests,
    'verified-users': loadVerifiedUsers,
    'moderation-reports': loadModerationReports,
    'non-educational-reports': loadNonEducationalReports,
    suggestions: loadSuggestions,
    'feedback-replies': loadFeedbackReplies,
    'affiliate-requests': loadAffiliateRequests,
    'affiliate-payouts': loadAffiliatePayouts,
    'affiliate-commission-rules': loadAffiliateCommissionRules,
    'subscription-plans': loadSubscriptionPlans,
    'test-series': loadTestSeries,
    'mock-broadcast': loadMockBroadcast,
    'notification-broadcast': loadNotificationBroadcast,
    'daily-learning': loadDailyLearning,
    'admin-users': loadAdminUsers,
    'audit-logs': loadAuditLogs,
    analytics: loadAnalytics,
    'analytics-revenue': loadAnalyticsRevenue,
  }

  const load = loaders[moduleKey]
  if (!load) {
    return {
      title: 'Module',
      subtitle: 'No module configuration found.',
      cards: [],
      body: `<div class="panel"><p>Unknown module: ${escapeHtml(moduleKey)}</p></div>`,
    }
  }

  return load()
}

async function refreshPage() {
  const access = await getAdminAccess()
  currentRole = access.role

  if (access.user) {
    if (userEmail) userEmail.textContent = access.user.email || 'Authenticated user'
  }

  if (access.error) {
    setMessage(access.error.message || 'Access check failed.')
  }

  const accessGroups = {
    'verification-requests': ROLE_GROUPS.moderation,
    'verified-users': ROLE_GROUPS.moderation,
    'moderation-reports': ROLE_GROUPS.moderation,
    'non-educational-reports': ROLE_GROUPS.moderation,
    suggestions: ROLE_GROUPS.moderation,
    'feedback-replies': ROLE_GROUPS.moderation,
    'affiliate-requests': ROLE_GROUPS.sales,
    'affiliate-payouts': ROLE_GROUPS.sales,
    'affiliate-commission-rules': ROLE_GROUPS.sales,
    'subscription-plans': ROLE_GROUPS.sales,
    'test-series': ROLE_GROUPS.sales,
    'mock-broadcast': ROLE_GROUPS.sales,
    'notification-broadcast': ROLE_GROUPS.sales,
    'daily-learning': ROLE_GROUPS.ownerAdmin,
    'admin-users': ROLE_GROUPS.ownerOnly,
    'audit-logs': ROLE_GROUPS.ownerOnly,
    analytics: ROLE_GROUPS.ownerOnly,
    'analytics-revenue': ROLE_GROUPS.ownerOnly,
  }
  const allowed = accessGroups[moduleKey] || ROLE_GROUPS.moderation

  if (!access.user) {
    setVisible(false)
    setMessage('Sign in to continue.')
    return
  }

  if (!hasAccess(access.role, allowed)) {
    setVisible(false)
    setMessage('Access denied.')
    return
  }

  setVisible(true)
  if (roleTitle) roleTitle.textContent = document.body.dataset.title || document.title
  if (moduleShell) moduleShell.classList.remove('hidden')

  const page = await loadPageData()
  if (moduleTitle) moduleTitle.textContent = page.title
  if (moduleSubtitle) moduleSubtitle.textContent = page.subtitle
  if (moduleMeta) moduleMeta.innerHTML = renderCards(page.cards)
  if (moduleContent) moduleContent.innerHTML = page.body

  if (moduleKey === 'notification-broadcast') {
    const sendBtn = document.getElementById('sendBroadcastBtn')
    if (sendBtn) {
      sendBtn.addEventListener('click', async () => {
        const targetGroup = document.getElementById('targetGroup')?.value || 'all_users'
        const title = document.getElementById('broadcastTitle')?.value?.trim() || ''
        const body = document.getElementById('broadcastBody')?.value?.trim() || ''
        if (!title || !body) {
          setMessage('Title and message required.')
          return
        }
        const { error, data } = await supabase.rpc('kls_send_admin_broadcast_notification', {
          p_title: title,
          p_body: body,
          p_target_group: targetGroup,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        setMessage(`Notification sent successfully to ${Number(data ?? 0)} users.`, false)
      })
    }
  }
}

async function login() {
  setMessage('')
  const email = emailInput.value.trim()
  const password = passwordInput.value
  if (!email || !password) {
    setMessage('Email and password required.')
    return
  }
  loginBtn.disabled = true
  loginBtn.textContent = 'Logging in...'
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  loginBtn.disabled = false
  loginBtn.textContent = 'Login'
  if (error) {
    setMessage(error.message)
    return
  }
  await refreshPage()
}

async function logout() {
  await supabase.auth.signOut()
  setVisible(false)
  setMessage('Logged out.')
}

async function init() {
  if (!supabaseUrl || !supabaseAnonKey) {
    setConnectionStatus(false, 'Add Supabase URL and anon key in config.js.')
    return
  }
  if (!isValidHttpUrl(supabaseUrl)) {
    setConnectionStatus(false, 'Supabase URL must start with http:// or https://.')
    return
  }
  if (!window.supabase?.createClient) {
    setConnectionStatus(false, 'Supabase library failed to load.')
    return
  }

  supabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey)
  setConnectionStatus(true, 'Supabase connected.')

  const { data } = await supabase.auth.getSession()
  if (data.session?.user) {
    await refreshPage()
  } else {
    setVisible(false)
  }

  supabase.auth.onAuthStateChange(() => {
    void refreshPage()
  })
}

loginBtn?.addEventListener('click', () => {
  void login()
})

signOutBtn?.addEventListener('click', () => {
  void logout()
})

emailInput?.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') void login()
})

passwordInput?.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') void login()
})

void init()
