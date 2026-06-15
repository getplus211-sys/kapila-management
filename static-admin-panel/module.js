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

const uiState = {
  verificationStatus: 'pending',
  moderationTab: 'all',
  daily: {
    subjectId: '',
    chapterCode: '',
    quizId: 'all',
    search: '',
    quizName: 'Daily Learning',
    timeLimit: '15',
    selectedQuestionIds: [],
    subjects: [],
    chapters: [],
    quizzes: [],
    questions: [],
  },
  testSeries: {
    examCode: 'GPSC',
    filter: 'all',
    seriesId: '',
    mockId: '',
    displayOrder: '1',
    importMockId: '',
    selectedQuestionIds: [],
    search: '',
    selectedSubjectId: '',
    selectedChapterCode: '',
    selectedQuizId: '',
    newMockName: '',
    newMockDetails: '',
    newMockDuration: '30',
    newMockEngine: 'MOCK_025',
    newMockIsPaid: true,
    newMockMakeLive: false,
    newMockPaused: false,
    newMockActive: true,
  },
  verification: {
    overviewByUserId: {},
    openUserId: '',
    loadingUserId: '',
  },
  suggestions: {
    savingId: '',
  },
  feedback: {
    activeThread: '',
    replyText: '',
    sending: false,
  },
  moderation: {
    replyBoxId: '',
    replyText: '',
    replyingId: '',
    resolvingId: '',
  },
  affiliateRequests: {
    status: 'pending',
    codes: {},
    percents: {},
  },
  subscriptionPlans: {
    editingPlanId: '',
  },
}

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

function getQueryParam(name) {
  return new URLSearchParams(window.location.search).get(name) || ''
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
  const status = uiState.verificationStatus || 'pending'
  const [reqRes, userRes, pendingRes, approvedRes, rejectedRes, moreInfoRes] = await Promise.all([
    supabase
      .from('ngm_verification_requests')
      .select('request_id,user_id,status,doc_type,doc_front_url,doc_back_url,doc_extra_url,submitted_note,review_note,created_at,updated_at')
      .eq('status', status)
      .order('created_at', { ascending: false })
      .limit(20),
    supabase.from('ngm_users').select('user_id,username,full_name,email,mobile').limit(500),
    supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'pending'),
    supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'approved'),
    supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'rejected'),
    supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'needs_more_info'),
  ])

  if (reqRes.error) throw reqRes.error
  if (userRes.error) throw userRes.error
  const countError = pendingRes.error ?? approvedRes.error ?? rejectedRes.error ?? moreInfoRes.error
  if (countError) throw countError

  const userMap = new Map((userRes.data || []).map((user) => [user.user_id, user]))
  const rows = (reqRes.data || []).map((row) => {
    const user = userMap.get(row.user_id)
    return {
      request_id: row.request_id,
      user: user?.full_name || user?.username || user?.email || row.user_id,
      user_id: row.user_id,
      status: row.status,
      doc_type: row.doc_type,
      submitted_note: row.submitted_note,
      review_note: row.review_note,
      doc_front_url: row.doc_front_url,
      doc_back_url: row.doc_back_url,
      doc_extra_url: row.doc_extra_url,
      created_at: row.created_at,
      updated_at: row.updated_at,
    }
  })

  return {
    title: 'Verification Requests',
    subtitle: 'Pending approvals from ngm_verification_requests.',
    cards: [
      { label: 'Pending', value: pendingRes.count ?? 0 },
      { label: 'Approved', value: approvedRes.count ?? 0 },
      { label: 'Rejected', value: rejectedRes.count ?? 0 },
      { label: 'Need Info', value: moreInfoRes.count ?? 0 },
    ],
    body: `
      <div class="panel">
        <div class="filter-bar">
          ${['pending', 'approved', 'rejected', 'needs_more_info'].map((item) => `
            <button class="kap-btn ${status === item ? 'kap-btn-primary' : 'kap-btn-outline'}" data-action="verification-filter" data-status="${item}">
              ${item.replaceAll('_', ' ')}
            </button>
          `).join('')}
        </div>
      </div>
      <div class="stack">
        ${rows.length ? rows.map((row) => `
          <div class="panel">
            <div class="row-between">
              <div>
                <p><b>${escapeHtml(row.user)}</b></p>
                <p class="muted">User: ${escapeHtml(row.user_id)} | Type: ${escapeHtml(row.doc_type || '-')} | Status: <span class="kap-chip">${escapeHtml(row.status)}</span></p>
                ${row.submitted_note ? `<p><b>User note:</b> ${escapeHtml(row.submitted_note)}</p>` : ''}
                ${row.review_note ? `<p><b>Review note:</b> ${escapeHtml(row.review_note)}</p>` : ''}
                <p class="muted">Created: ${escapeHtml(row.created_at)}</p>
              </div>
              <div class="action-wrap">
                <button class="kap-btn kap-btn-outline" data-action="verification-overview" data-user-id="${escapeHtml(row.user_id)}">
                  ${uiState.verification.openUserId === row.user_id ? 'Close Overview' : (uiState.verification.loadingUserId === row.user_id ? 'Loading...' : 'Profile Overview')}
                </button>
                <a href="user-profile.html?userId=${encodeURIComponent(row.user_id)}" class="secondary-btn">View Profile</a>
                ${status === 'pending' ? `
                  <button class="kap-btn kap-btn-primary" data-action="verification-review" data-request-id="${escapeHtml(row.request_id)}" data-status="approved">Approve</button>
                  <button class="kap-btn kap-btn-danger" data-action="verification-review" data-request-id="${escapeHtml(row.request_id)}" data-status="rejected">Reject</button>
                  <button class="kap-btn kap-btn-outline" data-action="verification-review" data-request-id="${escapeHtml(row.request_id)}" data-status="needs_more_info">Need Info</button>
                ` : ''}
              </div>
            </div>
            ${row.doc_front_url ? `<p><a href="${escapeHtml(row.doc_front_url)}" target="_blank">Front Doc</a></p>` : ''}
            ${row.doc_back_url ? `<p><a href="${escapeHtml(row.doc_back_url)}" target="_blank">Back Doc</a></p>` : ''}
            ${row.doc_extra_url ? `<p><a href="${escapeHtml(row.doc_extra_url)}" target="_blank">Extra Doc</a></p>` : ''}
            ${uiState.verification.openUserId === row.user_id && uiState.verification.overviewByUserId[row.user_id] ? `
              <div class="panel" style="background:#f8fafc;margin-top:10px">
                <p><b>Creator Overview (Month)</b></p>
                <p>Posts: ${uiState.verification.overviewByUserId[row.user_id].posts_count ?? 0} | Views: ${uiState.verification.overviewByUserId[row.user_id].total_views ?? 0}</p>
                <p>Likes: ${uiState.verification.overviewByUserId[row.user_id].likes_count ?? 0} | Comments: ${uiState.verification.overviewByUserId[row.user_id].comments_count ?? 0}</p>
                <p>Profile Visits: ${uiState.verification.overviewByUserId[row.user_id].profile_visits ?? 0}</p>
              </div>
            ` : ''}
          </div>
        `).join('') : '<div class="panel"><p>No requests.</p></div>'}
      </div>
    `,
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
    body: `
      <div class="stack">
        ${(rows.length ? rows : []).map((row) => `
          <div class="panel">
            <p><b>${escapeHtml(row.source)}</b> | Content: ${escapeHtml(row.id)}</p>
            <p class="muted">Reported by: ${escapeHtml(row.reported_by)} | Created: ${escapeHtml(row.created_at)}</p>
            <p><b>Reason:</b> ${escapeHtml(row.reason || '-')}</p>
            <div class="action-wrap">
              <button class="kap-btn kap-btn-outline" data-action="report-reply" data-source="${escapeHtml(row.source)}" data-id="${escapeHtml(row.id)}" data-reported-by="${escapeHtml(row.reported_by)}">Reply to User</button>
              <button class="kap-btn kap-btn-outline" data-action="report-resolve" data-source="${escapeHtml(row.source)}" data-id="${escapeHtml(row.id)}" data-mode="keep">Resolve Keep</button>
              <button class="kap-btn kap-btn-danger" data-action="report-resolve" data-source="${escapeHtml(row.source)}" data-id="${escapeHtml(row.id)}" data-mode="delete">Delete Content</button>
              <a class="secondary-btn" href="user-profile.html?userId=${encodeURIComponent(row.reported_by)}">View Reporter Profile</a>
            </div>
          </div>
        `).join('') || '<div class="panel"><p>No pending reports.</p></div>'}
      </div>
    `,
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
  const access = await getAdminAccess()
  if (!hasAccess(access.role, ROLE_GROUPS.moderation)) {
    return {
      title: 'Suggestions',
      subtitle: 'Question suggestions.',
      cards: [],
      body: `<div class="panel"><p>Access denied.</p></div>`,
    }
  }

  const { data, error } = await supabase
    .from('kls_questions')
    .select('id,quiz_id,chapter_code,question,option_a,option_b,option_c,option_d,option_e,correct_answer,solution,difficulty_level,suggestion,created_at')
    .not('suggestion', 'is', null)
    .neq('suggestion', '')
    .order('created_at', { ascending: false })
    .limit(300)
  if (error) throw error
  const rows = (data || []).map((row) => ({
    id: row.id,
    quiz_id: row.quiz_id || '',
    chapter_code: row.chapter_code || '',
    question: row.question || '',
    option_a: row.option_a || '',
    option_b: row.option_b || '',
    option_c: row.option_c || '',
    option_d: row.option_d || '',
    option_e: row.option_e || '',
    correct_answer: row.correct_answer || '',
    solution: row.solution || '',
    difficulty_level: row.difficulty_level || '',
    suggestion: row.suggestion,
    created_at: row.created_at,
  }))
  return {
    title: 'Suggestions',
    subtitle: 'Review suggested question edits.',
    cards: [{ label: 'Suggestions', value: rows.length }],
    body: `
      <div class="stack">
        <div class="panel">
          <p style="font-weight: 800; margin-bottom: 8px">Suggestions rows</p>
          <p class="muted" style="margin: 0;">Each card shows the question, its quiz/chapter context, and the editable fields used to save the full answer set.</p>
        </div>
        ${rows.length ? rows.map((row) => `
          <div class="panel">
            <div class="row-between">
              <div>
                <p><b>Question ID:</b> ${escapeHtml(row.id)}</p>
                <p class="muted">Quiz ID: ${escapeHtml(row.quiz_id || '-')} | Chapter: ${escapeHtml(row.chapter_code || '-')}</p>
                <p class="muted">Created: ${escapeHtml(row.created_at)}</p>
              </div>
            </div>
            <p style="margin-top:6px"><b>Current:</b> ${escapeHtml(row.question || '-')}</p>
            <p><b>Suggestion:</b> ${escapeHtml(row.suggestion || '-')}</p>
            <div class="stack" style="margin-top:10px">
              <textarea id="suggestionReadOnly-${escapeHtml(row.id)}" class="kap-input" rows="4" placeholder="Suggested question text" readonly style="background:#f8fafc">${escapeHtml(row.suggestion || '')}</textarea>
              <textarea id="suggestionQuestion-${escapeHtml(row.id)}" class="kap-input" rows="4" placeholder="Question">${escapeHtml(row.question)}</textarea>
              <input id="suggestionOptionA-${escapeHtml(row.id)}" class="kap-input" placeholder="Option A" value="${escapeHtml(row.option_a)}" />
              <input id="suggestionOptionB-${escapeHtml(row.id)}" class="kap-input" placeholder="Option B" value="${escapeHtml(row.option_b)}" />
              <input id="suggestionOptionC-${escapeHtml(row.id)}" class="kap-input" placeholder="Option C" value="${escapeHtml(row.option_c)}" />
              <input id="suggestionOptionD-${escapeHtml(row.id)}" class="kap-input" placeholder="Option D" value="${escapeHtml(row.option_d)}" />
              <input id="suggestionOptionE-${escapeHtml(row.id)}" class="kap-input" placeholder="Option E (optional)" value="${escapeHtml(row.option_e)}" />
              <input id="suggestionCorrect-${escapeHtml(row.id)}" class="kap-input" placeholder="Correct Answer" value="${escapeHtml(row.correct_answer)}" />
              <input id="suggestionDifficulty-${escapeHtml(row.id)}" class="kap-input" placeholder="Difficulty Level" value="${escapeHtml(row.difficulty_level)}" />
              <textarea id="suggestionSolution-${escapeHtml(row.id)}" class="kap-input" rows="4" placeholder="Solution">${escapeHtml(row.solution)}</textarea>
              <button class="kap-btn kap-btn-primary" data-action="suggestion-save" data-suggestion-id="${escapeHtml(row.id)}">
                ${uiState.suggestions.savingId === row.id ? 'Saving...' : 'Save Full Question'}
              </button>
            </div>
          </div>
        `).join('') : '<div class="panel"><p>No suggestions found in kls_questions.</p></div>'}
      </div>
    `,
  }
}

async function loadFeedbackReplies() {
  const access = await getAdminAccess()
  if (!hasAccess(access.role, ROLE_GROUPS.moderation)) {
    return {
      title: 'Ask/Feedback Replies',
      subtitle: 'Feedback threads and replies.',
      cards: [],
      body: `<div class="panel"><p>Access denied.</p></div>`,
    }
  }

  const [threadRes] = await Promise.all([
    supabase.from('ngm_feedback_threads').select('thread_id,user_id,subject,status,created_at').order('created_at', { ascending: false }).limit(200),
  ])
  if (threadRes.error) throw threadRes.error
  const threads = (threadRes.data || [])
  const activeThread = uiState.feedback.activeThread || threads[0]?.thread_id || ''
  uiState.feedback.activeThread = activeThread
  const messageRes = activeThread
    ? await supabase
        .from('ngm_feedback_messages')
        .select('message_id,thread_id,sender_user_id,sender_type,message_text,created_at')
        .eq('thread_id', activeThread)
        .order('created_at', { ascending: true })
        .limit(500)
    : { data: [], error: null }
  if (messageRes.error) throw messageRes.error

  const messages = (messageRes.data || [])
  const userIds = [...new Set([
    ...threads.map((t) => t.user_id),
    ...messages.map((m) => m.sender_user_id),
  ].filter(Boolean))]
  const userMetaRes = userIds.length
    ? await supabase.from('ngm_users').select('user_id,username,full_name,email,mobile,district').in('user_id', userIds)
    : { data: [] }
  const userMetaById = {}
  for (const u of (userMetaRes.data || [])) userMetaById[u.user_id] = u
  return {
    title: 'Ask/Feedback Replies',
    subtitle: 'Feedback threads and replies.',
    cards: [{ label: 'Threads', value: threads.length }, { label: 'Messages', value: messages.length }],
    body: `
      <div class="two-col">
        <div class="panel" style="max-height: 560px; overflow: auto;">
          <p style="font-weight: 800; margin-bottom: 10px">Threads</p>
          ${threads.length ? threads.map((thread) => `
            <button class="thread-card ${activeThread === thread.thread_id ? 'thread-active' : ''}" data-action="feedback-thread-select" data-thread-id="${escapeHtml(thread.thread_id)}">
              <p><b>${escapeHtml(thread.subject || 'No Subject')}</b></p>
              <p class="muted">${escapeHtml(userMetaById[thread.user_id]?.full_name || thread.user_id)}${userMetaById[thread.user_id]?.username ? ` (@${escapeHtml(userMetaById[thread.user_id]?.username || '')})` : ''}</p>
              <p class="muted">${escapeHtml(userMetaById[thread.user_id]?.email || '-')} | ${escapeHtml(userMetaById[thread.user_id]?.mobile || '-')} | ${escapeHtml(userMetaById[thread.user_id]?.district || '-')}</p>
              <p style="margin-top: 6px;">
                <a href="user-profile.html?userId=${encodeURIComponent(thread.user_id)}" class="secondary-btn">View Profile</a>
              </p>
            </button>
          `).join('') : '<p>No feedback threads.</p>'}
        </div>

        <div class="panel">
          <p style="font-weight: 800; margin-bottom: 10px">Messages</p>
          <div class="stack" style="max-height: 420px; overflow: auto; border: 1px solid #eee; border-radius: 8px; padding: 8px;">
            ${messages.length ? messages.map((message) => `
              <div class="panel" style="background:${message.sender_type === 'admin' ? '#f4f2ff' : '#fff'}">
                <p class="muted">${escapeHtml(message.sender_type)} | ${escapeHtml(message.created_at)}</p>
                <p class="muted">${escapeHtml(userMetaById[message.sender_user_id]?.full_name || message.sender_user_id)}${userMetaById[message.sender_user_id]?.username ? ` (@${escapeHtml(userMetaById[message.sender_user_id]?.username || '')})` : ''}</p>
                <p>${escapeHtml(message.message_text)}</p>
                <p style="margin-top: 6px;">
                  <a href="user-profile.html?userId=${encodeURIComponent(message.sender_user_id)}" class="secondary-btn">View Profile</a>
                </p>
              </div>
            `).join('') : '<p style="color:#6b7280">No messages.</p>'}
          </div>
          <div class="action-wrap" style="margin-top: 10px;">
            <input id="feedbackReplyText" class="kap-input" value="${escapeHtml(uiState.feedback.replyText)}" placeholder="Type admin reply..." />
            <button class="kap-btn kap-btn-primary" data-action="feedback-send">Send</button>
          </div>
        </div>
      </div>
    `,
  }
}

async function loadAffiliateRequests() {
  const status = uiState.affiliateRequests.status || 'pending'
  const { data, error } = await supabase
    .from('kls_affiliate_applications')
    .select('application_id,user_id,full_name,phone_number,organization_name,status,created_at')
    .eq('status', status)
    .order('created_at', { ascending: false })
    .limit(50)
  if (error) throw error
  return {
    title: 'Affiliate Requests',
    subtitle: 'Creator affiliate applications.',
    cards: [{ label: 'Applications', value: (data || []).length }],
    body: `
      <div class="panel">
        <div class="filter-bar">
          ${['pending', 'approved', 'rejected'].map((item) => `
            <button class="kap-btn ${status === item ? 'kap-btn-primary' : 'kap-btn-outline'}" data-action="affiliate-filter" data-status="${item}">
              ${item}
            </button>
          `).join('')}
        </div>
      </div>
      <div class="stack">
        ${(data || []).length ? (data || []).map((row) => `
          <div class="panel">
            <p><b>${escapeHtml(row.full_name || '-')}</b> (${escapeHtml(row.user_id)})</p>
            <p class="muted">Mobile: ${escapeHtml(row.phone_number || '-')} | Organization: ${escapeHtml(row.organization_name || '-')}</p>
            <p class="muted">Status: <span class="kap-chip">${escapeHtml(row.status)}</span></p>
            ${status === 'pending' ? `
              <div class="form-grid" style="margin-top:10px">
                <input class="kap-input" data-field="affiliate-code" data-application-id="${escapeHtml(row.application_id)}" placeholder="Affiliate Code" />
                <input class="kap-input" data-field="affiliate-percent" data-application-id="${escapeHtml(row.application_id)}" placeholder="Commission %" value="10" />
                <div class="action-wrap">
                  <button class="kap-btn kap-btn-primary" data-action="affiliate-approve" data-application-id="${escapeHtml(row.application_id)}">Approve</button>
                  <button class="kap-btn kap-btn-danger" data-action="affiliate-reject" data-application-id="${escapeHtml(row.application_id)}">Reject</button>
                </div>
              </div>
            ` : ''}
          </div>
        `).join('') : '<div class="panel"><p>No affiliate requests.</p></div>'}
      </div>
    `,
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
    body: `
      <div class="panel">
        <p style="font-weight:800;margin:0 0 10px 0">Mark Paid Amount</p>
        <div class="form-grid">
          <select class="kap-input" id="payoutUser">
            <option value="">Select Affiliate</option>
            ${(profilesRes.data || []).map((row) => `<option value="${escapeHtml(row.user_id)}">${escapeHtml(row.affiliate_code)} - ${escapeHtml(row.user_id)}</option>`).join('')}
          </select>
          <input class="kap-input" id="payoutAmount" placeholder="Amount" />
          <input class="kap-input" id="payoutNotes" placeholder="Notes" />
          <button class="kap-btn kap-btn-primary" data-action="payout-save">Add Payout</button>
        </div>
      </div>
      <div class="stack">
        ${(payoutsRes.data || []).map((row) => `
          <div class="panel">
            <p><b>User:</b> ${escapeHtml(row.affiliate_user_id)}</p>
            <p><b>Amount:</b> Rs.${Number(row.amount).toFixed(2)}</p>
            <p><b>Paid At:</b> ${escapeHtml(row.paid_at)}</p>
            <p><b>Notes:</b> ${escapeHtml(row.notes || '-')}</p>
          </div>
        `).join('') || '<div class="panel"><p>No payouts yet.</p></div>'}
      </div>
    `,
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
    body: `
      <div class="panel">
        <p style="font-weight:800;margin:0 0 10px 0">Create / Update Plan</p>
        <div class="form-grid">
          <input class="kap-input" id="planCode" placeholder="Plan code" value="KLS_FULL_12M" />
          <input class="kap-input" id="planName" placeholder="Plan name" value="Full Subscription 12M" />
          <input class="kap-input" id="planDescription" placeholder="Description" value="All content access for 12 months" />
          <input class="kap-input" id="planMonths" placeholder="Duration months" value="12" />
          <input class="kap-input" id="planPrice" placeholder="Price INR" value="999" />
          <button class="kap-btn kap-btn-primary" data-action="plan-save">Save Plan</button>
        </div>
      </div>
      <div class="stack">
        ${(data || []).map((row) => `
          <div class="panel">
            <p><b>${escapeHtml(row.plan_name)}</b> (${escapeHtml(row.plan_code)})</p>
            <p>Duration: ${escapeHtml(row.period_days)} days</p>
            <p>Price: Rs.${Number(row.price).toFixed(2)}</p>
            <p>Status: <span class="kap-chip">${row.is_active ? 'active' : 'inactive'}</span></p>
            <div class="action-wrap">
              <button class="kap-btn kap-btn-outline" data-action="plan-edit" data-plan-id="${escapeHtml(row.subscription_plan_id)}">Edit</button>
              <button class="kap-btn kap-btn-outline" data-action="plan-toggle" data-plan-id="${escapeHtml(row.subscription_plan_id)}" data-active="${row.is_active ? '1' : '0'}">${row.is_active ? 'Deactivate' : 'Activate'}</button>
            </div>
          </div>
        `).join('') || '<div class="panel"><p>No subscription plans.</p></div>'}
      </div>
    `,
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
  const allSeries = (seriesRes.data || []).map((row) => ({ ...row }))
  const allMocks = (mocksRes.data || []).map((row) => ({ ...row }))
  const allMaps = (mapsRes.data || []).map((row) => ({ ...row }))
  const examCode = uiState.testSeries.examCode || 'GPSC'
  const mockById = new Map(allMocks.map((row) => [row.mock_test_id, row]))
  const liveSeriesIds = new Set()
  for (const row of allMaps) {
    const mock = mockById.get(row.mock_test_id)
    if (mock?.is_active === true && mock?.is_live === true && mock?.is_paused === false) {
      liveSeriesIds.add(row.test_series_id)
    }
  }
  const filteredSeries = allSeries.filter((row) => {
    if (row.exam_code !== examCode) return false
    if (uiState.testSeries.filter === 'active') return row.is_active === true
    if (uiState.testSeries.filter === 'inactive') return row.is_active !== true
    if (uiState.testSeries.filter === 'live_active') return row.is_active === true && liveSeriesIds.has(row.test_series_id)
    return true
  })
  const filteredMocks = allMocks.filter((row) => {
    if (row.exam_code !== examCode) return false
    if (uiState.testSeries.filter === 'active') return row.is_active === true
    if (uiState.testSeries.filter === 'inactive') return row.is_active !== true
    if (uiState.testSeries.filter === 'live_active') return row.is_active === true && row.is_live === true && row.is_paused !== true
    return true
  })
  return {
    title: 'Test Series',
    subtitle: 'Series, mocks, and mapping rows.',
    cards: [{ label: 'Series', value: filteredSeries.length }, { label: 'Mocks', value: filteredMocks.length }],
    body: `
      <div class="panel">
        <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,1fr));align-items:end">
          <select class="kap-input" id="seriesExamCode">
            ${['GPSC', 'GPSC_Gujarati', 'GPSC_English', 'PSI', 'POLICE'].map((code) => `<option value="${code}" ${code === examCode ? 'selected' : ''}>${code}</option>`).join('')}
          </select>
          <input class="kap-input" id="seriesName" placeholder="Series Name" />
          <input class="kap-input" id="seriesDescription" placeholder="Description" />
          <input class="kap-input" id="seriesPrice" placeholder="Price" />
          <button class="kap-btn kap-btn-primary" data-action="series-create">Create Series</button>
        </div>
      </div>
      <div class="panel">
        <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,1fr));align-items:end">
          <select class="kap-input" id="seriesMapSeries">
            ${(filteredSeries.length ? filteredSeries : allSeries).map((row) => `<option value="${escapeHtml(row.test_series_id)}">${escapeHtml(row.series_name)} (${escapeHtml(row.exam_code)})</option>`).join('')}
          </select>
          <select class="kap-input" id="seriesMapMock">
            ${(filteredMocks.length ? filteredMocks : allMocks).map((row) => `<option value="${escapeHtml(row.mock_test_id)}">${escapeHtml(row.mock_name)} (${escapeHtml(row.exam_code)})</option>`).join('')}
          </select>
          <input class="kap-input" id="seriesMapOrder" value="1" />
          <button class="kap-btn kap-btn-primary" data-action="series-map">Map Mock</button>
        </div>
      </div>
      <div class="panel">
        <div class="filter-bar">
          ${(['all', 'active', 'inactive', 'live_active']).map((item) => `
            <button class="kap-btn ${uiState.testSeries.filter === item ? 'kap-btn-primary' : 'kap-btn-outline'}" data-action="series-filter" data-status="${item}">
              ${item.replaceAll('_', ' ')}
            </button>
          `).join('')}
        </div>
      </div>
      <div class="stack">
        ${(filteredSeries.length ? filteredSeries : allSeries).map((row) => `
          <div class="panel">
            <p><b>${escapeHtml(row.series_name)}</b></p>
            <p class="muted">Series ID: ${escapeHtml(row.test_series_id)} | Exam: ${escapeHtml(row.exam_code)} | Active: ${row.is_active ? 'Yes' : 'No'}</p>
            <div class="action-wrap">
              <button class="kap-btn kap-btn-outline" data-action="series-toggle" data-series-id="${escapeHtml(row.test_series_id)}" data-field="is_active">Toggle Active</button>
              <button class="kap-btn kap-btn-outline" data-action="series-edit" data-series-id="${escapeHtml(row.test_series_id)}">Edit</button>
              <button class="kap-btn kap-btn-danger" data-action="series-delete" data-series-id="${escapeHtml(row.test_series_id)}">Delete</button>
            </div>
          </div>
        `).join('') || '<div class="panel"><p>No test series.</p></div>'}
        <div class="panel">
          <p><b>Mocks</b></p>
          <div class="stack">
            ${(filteredMocks.length ? filteredMocks : allMocks).map((row) => `
              <div class="panel" style="background:#f8fafc">
                <p><b>${escapeHtml(row.mock_name)}</b></p>
                <p class="muted">Mock ID: ${escapeHtml(row.mock_test_id)} | Exam: ${escapeHtml(row.exam_code)} | Active: ${row.is_active ? 'Yes' : 'No'} | Live: ${row.is_live ? 'Yes' : 'No'} | Paused: ${row.is_paused ? 'Yes' : 'No'}</p>
                <div class="action-wrap">
                  <button class="kap-btn kap-btn-outline" data-action="mock-toggle" data-mock-id="${escapeHtml(row.mock_test_id)}" data-field="is_active">Toggle Active</button>
                  <button class="kap-btn kap-btn-outline" data-action="mock-toggle" data-mock-id="${escapeHtml(row.mock_test_id)}" data-field="is_live">Toggle Live</button>
                  <button class="kap-btn kap-btn-outline" data-action="mock-toggle" data-mock-id="${escapeHtml(row.mock_test_id)}" data-field="is_paused">Toggle Paused</button>
                </div>
              </div>
            `).join('') || '<p>No mocks.</p>'}
          </div>
        </div>
        <div class="panel">
          <p><b>Mappings</b></p>
          <div class="stack">
            ${(allMaps || []).map((row) => `
              <div class="panel" style="background:#f8fafc">
                <p>Series: ${escapeHtml(row.test_series_id)} | Mock: ${escapeHtml(row.mock_test_id)} | Order: ${escapeHtml(row.display_order)}</p>
              </div>
            `).join('') || '<p>No mappings.</p>'}
          </div>
        </div>
      </div>
    `,
  }
}

async function loadTestSeriesNewMock() {
  const page = await loadTestSeries()
  return {
    ...page,
    title: 'Create New Mock Test',
    subtitle: 'Use the same test-series data to create and map a new mock.',
  }
}

async function loadTestSeriesAllQuestions() {
  const page = await loadTestSeries()
  return {
    ...page,
    title: 'All Questions',
    subtitle: 'Mock-wise question management view.',
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
  const access = await getAdminAccess()
  if (!hasAccess(access.role, ROLE_GROUPS.ownerAdmin)) {
    return {
      title: 'Daily Learning Manager',
      subtitle: 'Question publishing flow.',
      cards: [],
      body: `<div class="panel"><p>Access denied.</p></div>`,
    }
  }

  const subjectRes = await supabase.from('kls_subjects').select('id,name,subject_code').order('created_at')
  if (subjectRes.error) throw subjectRes.error
  const subjects = (subjectRes.data || [])
  uiState.daily.subjects = subjects
  if (!uiState.daily.subjectId && subjects[0]?.id) {
    uiState.daily.subjectId = subjects[0].id
  }

  const chapterRes = uiState.daily.subjectId
    ? await supabase.from('kls_chapters').select('id,name,chapter_code,subject_id').eq('subject_id', uiState.daily.subjectId).order('chapter_code')
    : { data: [], error: null }
  if (chapterRes.error) throw chapterRes.error
  const chapters = (chapterRes.data || [])
  uiState.daily.chapters = chapters
  if (!uiState.daily.chapterCode && chapters[0]?.chapter_code) {
    uiState.daily.chapterCode = chapters[0].chapter_code
  }

  const quizRes = uiState.daily.chapterCode
    ? await supabase
        .from('kls_quizzes')
        .select('quiz_id,quiz_name,chapter_code,difficulty_level,subject_id,total_questions,time_limit,is_active')
        .eq('chapter_code', uiState.daily.chapterCode)
        .eq('is_active', true)
        .order('created_at', { ascending: false })
    : { data: [], error: null }
  if (quizRes.error) throw quizRes.error
  const quizzes = (quizRes.data || [])
  uiState.daily.quizzes = quizzes
  if (uiState.daily.quizId !== 'all' && !quizzes.some((quiz) => quiz.quiz_id === uiState.daily.quizId)) {
    uiState.daily.quizId = 'all'
  }

  let questionQuery = supabase
    .from('kls_questions')
    .select('id,quiz_id,question,option_a,option_b,option_c,option_d,option_e,correct_answer,solution,suggestion,difficulty_level,chapter_code,subject_id')
    .order('created_at', { ascending: false })
    .limit(500)

  if (uiState.daily.subjectId) questionQuery = questionQuery.eq('subject_id', uiState.daily.subjectId)
  if (uiState.daily.chapterCode) questionQuery = questionQuery.eq('chapter_code', uiState.daily.chapterCode)
  if (uiState.daily.quizId && uiState.daily.quizId !== 'all') questionQuery = questionQuery.eq('quiz_id', uiState.daily.quizId)
  if (uiState.daily.search.trim()) questionQuery = questionQuery.ilike('question', `%${uiState.daily.search.trim()}%`)

  const questionRes = await questionQuery
  if (questionRes.error) throw questionRes.error
  const questions = (questionRes.data || [])
  uiState.daily.questions = questions
  return {
    title: 'Daily Learning Manager',
    subtitle: 'Select questions and publish today’s daily quiz.',
    cards: [
      { label: 'Subjects', value: subjects.length },
      { label: 'Chapters', value: chapters.length },
      { label: 'Quizzes', value: quizzes.length },
      { label: 'Questions', value: questions.length },
      { label: 'Selected', value: uiState.daily.selectedQuestionIds.length },
    ],
    body: `
      <div class="panel">
        <div class="row-between">
          <div>
            <p class="eyebrow">Today Quiz ID</p>
            <h3 style="margin:4px 0 0 0">${escapeHtml(dailyQuizIdForDate(new Date()))}</h3>
          </div>
          <div class="action-wrap">
            <button class="kap-btn kap-btn-outline" data-action="daily-refresh">Refresh</button>
            <button class="kap-btn kap-btn-outline" data-action="daily-clear">Clear Selection</button>
            <button class="kap-btn kap-btn-primary" data-action="daily-publish">Publish Today</button>
          </div>
        </div>
      </div>
      <div class="panel">
        <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,1fr));align-items:end">
          <select id="dailySubjectSelect" class="kap-input" data-action="daily-subject">
            <option value="">Select subject</option>
            ${subjects.map((subject) => `<option value="${escapeHtml(subject.id)}" ${subject.id === uiState.daily.subjectId ? 'selected' : ''}>${escapeHtml(subject.name)}</option>`).join('')}
          </select>
          <select id="dailyChapterSelect" class="kap-input" data-action="daily-chapter">
            <option value="">Select chapter</option>
            ${chapters.map((chapter) => `<option value="${escapeHtml(chapter.chapter_code)}" ${chapter.chapter_code === uiState.daily.chapterCode ? 'selected' : ''}>${escapeHtml(chapter.chapter_code)} - ${escapeHtml(chapter.name)}</option>`).join('')}
          </select>
          <select id="dailyQuizSelect" class="kap-input" data-action="daily-quiz">
            <option value="all" ${uiState.daily.quizId === 'all' ? 'selected' : ''}>All quizzes</option>
            ${quizzes.map((quiz) => `<option value="${escapeHtml(quiz.quiz_id)}" ${quiz.quiz_id === uiState.daily.quizId ? 'selected' : ''}>${escapeHtml(quiz.quiz_name)} (${escapeHtml(String(quiz.total_questions ?? 0))})</option>`).join('')}
          </select>
          <input id="dailySearchInput" class="kap-input" placeholder="Search question text" value="${escapeHtml(uiState.daily.search)}" />
          <button class="kap-btn kap-btn-outline" data-action="daily-apply-search">Apply Search</button>
        </div>
      </div>
      <div class="panel">
        <div class="form-grid" style="grid-template-columns:repeat(2,minmax(0,1fr));align-items:end">
          <input id="dailyQuizName" class="kap-input" placeholder="Daily title" value="${escapeHtml(uiState.daily.quizName)}" />
          <input id="dailyTimeLimit" class="kap-input" placeholder="Time limit" value="${escapeHtml(uiState.daily.timeLimit)}" />
        </div>
      </div>
      <p style="margin:0 0 12px 0;color:#475569">Selected ${uiState.daily.selectedQuestionIds.length} questions</p>
      <div class="stack">
        ${questions.length ? questions.map((question, index) => `
          <div class="panel">
            <div class="row-between">
              <div>
                <p><b>#${index + 1}</b> ${escapeHtml(question.question || '-')}</p>
                <p class="muted">Quiz: ${escapeHtml(question.quiz_id)} | Chapter: ${escapeHtml(question.chapter_code || '-')} | Difficulty: ${escapeHtml(question.difficulty_level || '-')}</p>
              </div>
              <button class="kap-btn ${uiState.daily.selectedQuestionIds.includes(question.id) ? 'kap-btn-primary' : 'kap-btn-outline'}" data-action="daily-toggle-question" data-question-id="${escapeHtml(question.id)}">
                ${uiState.daily.selectedQuestionIds.includes(question.id) ? 'Selected' : 'Select'}
              </button>
            </div>
            <div class="stack" style="margin-top:8px">
              <p><b>A.</b> ${escapeHtml(question.option_a || '-')}</p>
              <p><b>B.</b> ${escapeHtml(question.option_b || '-')}</p>
              <p><b>C.</b> ${escapeHtml(question.option_c || '-')}</p>
              <p><b>D.</b> ${escapeHtml(question.option_d || '-')}</p>
              ${question.option_e ? `<p><b>E.</b> ${escapeHtml(question.option_e)}</p>` : ''}
              ${question.suggestion ? `<p><b>Suggestion:</b> ${escapeHtml(question.suggestion)}</p>` : ''}
            </div>
          </div>
        `).join('') : '<div class="panel"><p>No questions found.</p></div>'}
      </div>
    `,
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
    body: `
      <div class="panel">
        <p style="font-weight:800;margin:0 0 10px 0">Assign Role (Owner only)</p>
        <div class="form-grid">
          <input class="kap-input" id="adminAssignEmail" type="email" placeholder="User Email" />
          <select class="kap-input" id="adminAssignRole">
            <option value="moderator">moderator</option>
            <option value="sales_agent">sales_agent</option>
            <option value="sales_manager">sales_manager</option>
            <option value="admin">admin</option>
            <option value="owner">owner</option>
          </select>
          <button class="kap-btn kap-btn-primary" data-action="admin-assign">Assign</button>
        </div>
      </div>
      <div class="stack">
        ${(data || []).map((row) => `
          <div class="panel">
            <p><b>User:</b> ${escapeHtml(row.user_id)}</p>
            <p><b>Role:</b> <span class="kap-chip">${escapeHtml(row.role)}</span></p>
            <p><b>Active:</b> ${row.is_active ? 'Yes' : 'No'}</p>
            ${row.role !== 'owner' && row.is_active ? `<button class="kap-btn kap-btn-outline" data-action="admin-deactivate" data-user-id="${escapeHtml(row.user_id)}" data-role="${escapeHtml(row.role)}">Deactivate</button>` : ''}
          </div>
        `).join('') || '<div class="panel"><p>No admin roles found.</p></div>'}
      </div>
    `,
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

async function loadUserProfile() {
  const userId = getQueryParam('userId')
  if (!userId) {
    return {
      title: 'User Profile',
      subtitle: 'Open a specific user with ?userId=...',
      cards: [],
      body: `<div class="panel"><p>Missing <code>userId</code> in the URL.</p></div>`,
    }
  }

  const [userRes, overviewRes, followersRes, followingRes, postsRes] = await Promise.all([
    supabase.from('ngm_users').select('*').eq('user_id', userId).maybeSingle(),
    supabase.rpc('ngm_get_creator_overview', { p_user_id: userId, p_range: 'month' }),
    supabase.from('ngm_user_followers').select('follow_id', { head: true, count: 'exact' }).eq('following_user_id', userId),
    supabase.from('ngm_user_followers').select('follow_id', { head: true, count: 'exact' }).eq('follower_user_id', userId),
    supabase.from('ngm_user_posts').select('post_id', { head: true, count: 'exact' }).eq('user_id', userId),
  ])

  const error = userRes.error ?? overviewRes.error ?? followersRes.error ?? followingRes.error ?? postsRes.error
  if (error) throw error

  const userData = userRes.data || {}
  const root = (Array.isArray(overviewRes.data) ? overviewRes.data[0] : overviewRes.data) || {}
  const overview = root.overview || root.ngm_get_creator_overview || root

  return {
    title: 'User Profile',
    subtitle: 'Creator overview and profile meta.',
    cards: [
      { label: 'Posts', value: Number(postsRes.count ?? 0) },
      { label: 'Followers', value: Number(followersRes.count ?? 0) },
      { label: 'Following', value: Number(followingRes.count ?? 0) },
      { label: 'Verified', value: String(Boolean(userData.is_verified ?? false)) },
    ],
    body: `
      <div class="panel">
        <div class="row-between">
          <div>
            <p class="eyebrow">Profile</p>
            <h3 style="margin:4px 0 10px 0">${escapeHtml(userData.full_name || userData.username || userId)}</h3>
            <p class="muted">User ID: ${escapeHtml(userId)}</p>
          </div>
          <a href="javascript:history.back()" class="secondary-btn">Back</a>
        </div>
      </div>
      <div class="stack">
        <div class="panel">
          <p><b>Full Name:</b> ${escapeHtml(userData.full_name || '-')}</p>
          <p><b>Username:</b> ${escapeHtml(userData.username ? `@${userData.username}` : '-')}</p>
          <p><b>Email:</b> ${escapeHtml(userData.email || '-')}</p>
          <p><b>Mobile:</b> ${escapeHtml(userData.mobile || '-')}</p>
          <p><b>District:</b> ${escapeHtml(userData.district || '-')}</p>
          <p><b>Verified:</b> <span class="kap-chip">${escapeHtml(String(Boolean(userData.is_verified ?? false)))}</span></p>
          ${userData.bio ? `<p><b>Bio:</b> ${escapeHtml(userData.bio)}</p>` : ''}
        </div>
        <div class="panel">
          <p><b>Creator Overview (Month)</b></p>
          <p>Posts: ${escapeHtml(overview.posts_count ?? 0)}</p>
          <p>Total Views: ${escapeHtml(overview.total_views ?? 0)}</p>
          <p>Likes: ${escapeHtml(overview.likes_count ?? 0)}</p>
          <p>Comments: ${escapeHtml(overview.comments_count ?? 0)}</p>
          <p>Profile Visits: ${escapeHtml(overview.profile_visits ?? 0)}</p>
        </div>
      </div>
    `,
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
    'user-profile': loadUserProfile,
    'test-series-new-mock': loadTestSeriesNewMock,
    'test-series-all-questions': loadTestSeriesAllQuestions,
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
    'user-profile': ROLE_GROUPS.moderation,
    'test-series-new-mock': ROLE_GROUPS.sales,
    'test-series-all-questions': ROLE_GROUPS.sales,
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

  if (moduleContent) {
    moduleContent.onclick = async (event) => {
      const target = event.target?.closest?.('[data-action]')
      if (!target) return
      const action = target.dataset.action

      if (action === 'verification-filter') {
        uiState.verificationStatus = target.dataset.status || 'pending'
        await refreshPage()
        return
      }

      if (action === 'verification-overview') {
        const userId = target.dataset.userId || ''
        if (!userId) return
        if (uiState.verification.openUserId === userId) {
          uiState.verification.openUserId = ''
          await refreshPage()
          return
        }
        if (uiState.verification.overviewByUserId[userId]) {
          uiState.verification.openUserId = userId
          await refreshPage()
          return
        }
        uiState.verification.loadingUserId = userId
        await refreshPage()
        const { data } = await supabase.rpc('ngm_get_creator_overview', { p_user_id: userId, p_range: 'month' })
        const root = Array.isArray(data) ? data[0] : data
        const overview = root?.overview || root?.ngm_get_creator_overview || root || {}
        uiState.verification.loadingUserId = ''
        uiState.verification.overviewByUserId[userId] = overview
        uiState.verification.openUserId = userId
        await refreshPage()
        return
      }

      if (action === 'verification-review') {
        const requestId = target.dataset.requestId || ''
        const nextStatus = target.dataset.status || ''
        if (!requestId || !nextStatus) return
        const reviewNote = window.prompt('Review note (optional):') ?? null
        const { error } = await supabase.rpc('ngm_admin_review_verification', {
          p_request_id: requestId,
          p_status: nextStatus,
          p_review_note: reviewNote,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'report-reply') {
        const reportSource = target.dataset.source || ''
        const reportId = target.dataset.id || ''
        const reportedBy = target.dataset.reportedBy || ''
        if (!reportSource || !reportId || !reportedBy) return
        const replyText = window.prompt('Reply text') ?? ''
        if (!replyText.trim()) return
        const { data: authData } = await supabase.auth.getUser()
        const me = authData.user
        if (!me) return
        const { error } = await supabase.from('ngm_report_replies').insert({
          report_table: `ngm_${reportSource}_reports`,
          report_id: reportId,
          user_id: reportedBy,
          admin_user_id: me.id,
          reply_text: replyText.trim(),
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'report-resolve') {
        const reportSource = target.dataset.source || ''
        const reportId = target.dataset.id || ''
        const mode = target.dataset.mode || 'keep'
        if (!reportSource || !reportId) return
        const note = window.prompt(mode === 'delete' ? 'Reason for deleting content (optional):' : 'Reason for keeping content (optional):') ?? null
        const { data, error } = await supabase.rpc('ngm_admin_resolve_report', {
          p_report_table: `ngm_${reportSource}_reports`,
          p_report_id: reportId,
          p_action: mode,
          p_note: note,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        setMessage(`Updated: ${data?.status ?? 'done'}`)
        await refreshPage()
        return
      }

      if (action === 'feedback-thread-select') {
        uiState.feedback.activeThread = target.dataset.threadId || ''
        await refreshPage()
        return
      }

      if (action === 'feedback-send') {
        const replyInput = document.getElementById('feedbackReplyText')
        const replyText = (replyInput?.value || '').trim()
        if (!uiState.feedback.activeThread || !replyText) return
        const { data: authData } = await supabase.auth.getUser()
        const user = authData.user
        if (!user) return
        uiState.feedback.sending = true
        const { error } = await supabase.from('ngm_feedback_messages').insert({
          thread_id: uiState.feedback.activeThread,
          sender_user_id: user.id,
          sender_type: 'admin',
          message_text: replyText,
        })
        uiState.feedback.sending = false
        if (error) {
          setMessage(error.message)
          return
        }
        uiState.feedback.replyText = ''
        await refreshPage()
        return
      }

      if (action === 'suggestion-save') {
        const suggestionId = target.dataset.suggestionId || ''
        if (!suggestionId) return
        const parsedId = /^\d+$/.test(suggestionId) ? Number(suggestionId) : suggestionId

        const question = (document.getElementById(`suggestionQuestion-${suggestionId}`)?.value || '').trim()
        const optionA = (document.getElementById(`suggestionOptionA-${suggestionId}`)?.value || '').trim()
        const optionB = (document.getElementById(`suggestionOptionB-${suggestionId}`)?.value || '').trim()
        const optionC = (document.getElementById(`suggestionOptionC-${suggestionId}`)?.value || '').trim()
        const optionD = (document.getElementById(`suggestionOptionD-${suggestionId}`)?.value || '').trim()
        const optionE = (document.getElementById(`suggestionOptionE-${suggestionId}`)?.value || '').trim()
        const correctAnswer = (document.getElementById(`suggestionCorrect-${suggestionId}`)?.value || '').trim()
        const difficultyLevel = (document.getElementById(`suggestionDifficulty-${suggestionId}`)?.value || '').trim()
        const solution = (document.getElementById(`suggestionSolution-${suggestionId}`)?.value || '').trim()

        if (!question || !optionA || !optionB || !optionC || !optionD || !correctAnswer) {
          setMessage('Question, A/B/C/D and correct answer required.')
          return
        }

        target.disabled = true
        const originalText = target.textContent
        target.textContent = 'Saving...'
        uiState.suggestions.savingId = suggestionId

        const { data, error } = await supabase.rpc('ngm_admin_update_kls_question', {
          p_id: parsedId,
          p_question: question,
          p_option_a: optionA,
          p_option_b: optionB,
          p_option_c: optionC,
          p_option_d: optionD,
          p_option_e: optionE,
          p_correct_answer: correctAnswer,
          p_solution: solution,
          p_difficulty_level: difficultyLevel,
          p_admin_note: 'Updated from static suggestions panel',
        })
        if (!error) {
          await supabase.from('kls_questions').update({ suggestion: null }).eq('id', parsedId)
        }
        uiState.suggestions.savingId = ''
        if (error) {
          target.disabled = false
          target.textContent = originalText
          setMessage(error.message)
          return
        }
        uiState.suggestions.expandedId = ''
        setMessage(`Saved question: ${data?.id ?? suggestionId}`)
        await refreshPage()
        return
      }

      if (action === 'daily-refresh') {
        await refreshPage()
        return
      }

      if (action === 'daily-clear') {
        uiState.daily.selectedQuestionIds = []
        await refreshPage()
        return
      }

      if (action === 'daily-apply-search') {
        uiState.daily.search = (document.getElementById('dailySearchInput')?.value || '').trim()
        await refreshPage()
        return
      }

      if (action === 'daily-toggle-question') {
        const questionId = target.dataset.questionId || ''
        if (!questionId) return
        const current = uiState.daily.selectedQuestionIds || []
        uiState.daily.selectedQuestionIds = current.includes(questionId)
          ? current.filter((id) => id !== questionId)
          : [...current, questionId]
        await refreshPage()
        return
      }

      if (action === 'daily-publish') {
        const selectedQuestions = (uiState.daily.questions || []).filter((question) => uiState.daily.selectedQuestionIds.includes(question.id))
        if (!selectedQuestions.length) {
          setMessage('Select at least one question.')
          return
        }

        const quizName = (document.getElementById('dailyQuizName')?.value || '').trim() || 'Daily Learning'
        const timeLimit = Number(document.getElementById('dailyTimeLimit')?.value || '15')
        uiState.daily.quizName = quizName
        uiState.daily.timeLimit = String(Number.isFinite(timeLimit) ? timeLimit : 15)
        const firstSelectedQuestion = selectedQuestions[0]
        const selectedSubject = (uiState.daily.subjects || []).find((subject) => subject.id === (firstSelectedQuestion?.subject_id || uiState.daily.subjectId))
        const selectedQuiz = (uiState.daily.quizzes || []).find((quiz) => quiz.quiz_id === (firstSelectedQuestion?.quiz_id || uiState.daily.quizId))
        const todayQuizId = dailyQuizIdForDate(new Date())

        const payload = {
          quiz_id: todayQuizId,
          quiz_name: quizName,
          subject_id: firstSelectedQuestion?.subject_id || selectedQuiz?.subject_id || selectedSubject?.id || null,
          chapter_code: firstSelectedQuestion?.chapter_code || selectedQuiz?.chapter_code || uiState.daily.chapterCode || null,
          difficulty_level: firstSelectedQuestion?.difficulty_level || selectedQuiz?.difficulty_level || null,
          total_questions: uiState.daily.selectedQuestionIds.length,
          time_limit: Number.isFinite(timeLimit) ? timeLimit : 15,
          is_active: true,
        }

        const { error: quizDeleteError } = await supabase.from('kls_questions').delete().eq('quiz_id', todayQuizId)
        if (quizDeleteError) {
          setMessage(quizDeleteError.message)
          return
        }
        const { error: quizRowDeleteError } = await supabase.from('kls_quizzes').delete().eq('quiz_id', todayQuizId)
        if (quizRowDeleteError) {
          setMessage(quizRowDeleteError.message)
          return
        }
        const { error: insertQuizError } = await supabase.from('kls_quizzes').insert(payload)
        if (insertQuizError) {
          setMessage(insertQuizError.message)
          return
        }
        const rowsToCopy = selectedQuestions.map((question) => ({
          quiz_id: todayQuizId,
          question: question.question,
          option_a: question.option_a,
          option_b: question.option_b,
          option_c: question.option_c,
          option_d: question.option_d,
          option_e: question.option_e,
          correct_answer: question.correct_answer,
          solution: question.solution,
          suggestion: question.suggestion,
          difficulty_level: question.difficulty_level,
          chapter_code: question.chapter_code,
          subject_id: question.subject_id,
        }))
        const { error: insertQuestionsError } = await supabase.from('kls_questions').insert(rowsToCopy)
        if (insertQuestionsError) {
          setMessage(insertQuestionsError.message)
          return
        }
        uiState.daily.selectedQuestionIds = []
        setMessage(`Published ${selectedQuestions.length} questions for ${todayQuizId}.`)
        await refreshPage()
        return
      }

      if (action === 'affiliate-filter') {
        uiState.affiliateRequests.status = target.dataset.status || 'pending'
        await refreshPage()
        return
      }

      if (action === 'affiliate-approve') {
        const applicationId = target.dataset.applicationId || ''
        if (!applicationId) return
        const codeInput = moduleContent.querySelector(`[data-field="affiliate-code"][data-application-id="${CSS.escape(applicationId)}"]`)
        const percentInput = moduleContent.querySelector(`[data-field="affiliate-percent"][data-application-id="${CSS.escape(applicationId)}"]`)
        const code = codeInput?.value?.trim().toUpperCase() || ''
        const percent = Number(percentInput?.value ?? '10')
        if (!code) {
          setMessage('Affiliate code required.')
          return
        }
        if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
          setMessage('Commission % invalid.')
          return
        }
        const { error } = await supabase.rpc('kls_approve_affiliate_application', {
          p_application_id: applicationId,
          p_affiliate_code: code,
          p_commission_percent: percent,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'affiliate-reject') {
        const applicationId = target.dataset.applicationId || ''
        if (!applicationId) return
        const reason = window.prompt('Reject reason') ?? ''
        if (!reason.trim()) return
        const { error } = await supabase.rpc('kls_reject_affiliate_application', {
          p_application_id: applicationId,
          p_rejection_reason: reason.trim(),
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'admin-assign') {
        const email = (document.getElementById('adminAssignEmail')?.value || '').trim().toLowerCase()
        const role = document.getElementById('adminAssignRole')?.value || 'moderator'
        if (!email) {
          setMessage('Email required.')
          return
        }
        const { error } = await supabase.rpc('ngm_owner_set_admin_role_by_email', {
          p_email: email,
          p_role: role,
          p_is_active: true,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'admin-deactivate') {
        const userId = target.dataset.userId || ''
        const role = target.dataset.role || ''
        if (!userId || !role) return
        const { error } = await supabase.rpc('ngm_owner_set_admin_role', {
          p_user_id: userId,
          p_role: role,
          p_is_active: false,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'plan-save') {
        const code = (document.getElementById('planCode')?.value || '').trim().toUpperCase()
        const name = (document.getElementById('planName')?.value || '').trim()
        const description = (document.getElementById('planDescription')?.value || '').trim()
        const months = Number(document.getElementById('planMonths')?.value || '0')
        const price = Number(document.getElementById('planPrice')?.value || '0')
        if (!code || !name || !Number.isFinite(months) || !Number.isFinite(price)) {
          setMessage('Invalid input.')
          return
        }
        const { error } = await supabase
          .from('kls_subscription_plans')
          .upsert({
            plan_code: code,
            plan_name: name,
            plan_description: description || null,
            duration_months: months,
            price,
            currency_code: 'INR',
            is_active: true,
          }, { onConflict: 'plan_code' })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'plan-toggle') {
        const planId = target.dataset.planId || ''
        if (!planId) return
        const nextActive = target.dataset.active !== '1'
        const { error } = await supabase.from('kls_subscription_plans').update({ is_active: nextActive }).eq('subscription_plan_id', planId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'plan-edit') {
        const planId = target.dataset.planId || ''
        if (!planId) return
        const currentPlan = await supabase.from('kls_subscription_plans').select('*').eq('subscription_plan_id', planId).maybeSingle()
        if (currentPlan.error) {
          setMessage(currentPlan.error.message)
          return
        }
        const row = currentPlan.data || {}
        const nextCode = window.prompt('Plan code', row.plan_code ?? '') ?? ''
        const nextName = window.prompt('Plan name', row.plan_name ?? '') ?? ''
        const nextDesc = window.prompt('Description', row.plan_description ?? '') ?? ''
        const nextMonths = Number(window.prompt('Duration months', String(row.duration_months ?? 12)) ?? '0')
        const nextPrice = Number(window.prompt('Price INR', String(row.price ?? 0)) ?? '0')
        if (!nextCode.trim() || !nextName.trim() || !Number.isFinite(nextMonths) || !Number.isFinite(nextPrice)) {
          setMessage('Invalid input.')
          return
        }
        const { error } = await supabase
          .from('kls_subscription_plans')
          .update({
            plan_code: nextCode.trim().toUpperCase(),
            plan_name: nextName.trim(),
            plan_description: nextDesc.trim() || null,
            duration_months: nextMonths,
            price: nextPrice,
          })
          .eq('subscription_plan_id', planId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'series-filter') {
        uiState.testSeries.filter = target.dataset.status || 'all'
        await refreshPage()
        return
      }

      if (action === 'series-create') {
        const examCode = document.getElementById('seriesExamCode')?.value || 'GPSC'
        const seriesName = (document.getElementById('seriesName')?.value || '').trim()
        const seriesDescription = (document.getElementById('seriesDescription')?.value || '').trim()
        const seriesPrice = Number(document.getElementById('seriesPrice')?.value || '0')
        if (!examCode || !seriesName || !Number.isFinite(seriesPrice)) {
          setMessage('Exam, series name and price required.')
          return
        }
        const { error } = await supabase.from('kls_test_series').insert({
          exam_code: examCode,
          series_name: seriesName,
          series_description: seriesDescription || null,
          series_price: seriesPrice,
          currency_code: 'INR',
          is_active: true,
          is_visible: true,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'series-map') {
        const testSeriesId = document.getElementById('seriesMapSeries')?.value || ''
        const mockTestId = document.getElementById('seriesMapMock')?.value || ''
        const displayOrder = Number(document.getElementById('seriesMapOrder')?.value || '1')
        if (!testSeriesId || !mockTestId || !Number.isFinite(displayOrder) || displayOrder <= 0) {
          setMessage('Select series, mock and valid order.')
          return
        }
        const { error } = await supabase.from('kls_test_series_mocks').upsert({
          test_series_id: testSeriesId,
          mock_test_id: mockTestId,
          display_order: displayOrder,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'series-toggle') {
        const seriesId = target.dataset.seriesId || ''
        const field = target.dataset.field || 'is_active'
        if (!seriesId) return
        const { data, error: currentError } = await supabase.from('kls_test_series').select('is_active').eq('test_series_id', seriesId).maybeSingle()
        if (currentError) {
          setMessage(currentError.message)
          return
        }
        const patch = { [field]: !(data?.is_active ?? false) }
        const { error } = await supabase.from('kls_test_series').update(patch).eq('test_series_id', seriesId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'series-edit') {
        const seriesId = target.dataset.seriesId || ''
        if (!seriesId) return
        const currentSeries = await supabase.from('kls_test_series').select('*').eq('test_series_id', seriesId).maybeSingle()
        if (currentSeries.error) {
          setMessage(currentSeries.error.message)
          return
        }
        const row = currentSeries.data || {}
        const nextExam = window.prompt('Exam code', row.exam_code ?? '') ?? ''
        const nextName = window.prompt('Series name', row.series_name ?? '') ?? ''
        const nextDesc = window.prompt('Description', row.series_description ?? '') ?? ''
        const nextPrice = Number(window.prompt('Price', String(row.series_price ?? 0)) ?? '0')
        if (!nextExam.trim() || !nextName.trim() || !Number.isFinite(nextPrice)) {
          setMessage('Invalid input.')
          return
        }
        const { error } = await supabase.from('kls_test_series').update({
          exam_code: nextExam.trim().toUpperCase(),
          series_name: nextName.trim(),
          series_description: nextDesc.trim() || null,
          series_price: nextPrice,
        }).eq('test_series_id', seriesId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'series-delete') {
        const seriesId = target.dataset.seriesId || ''
        if (!seriesId) return
        const confirmText = window.prompt('Type DELETE to confirm series delete') ?? ''
        if (confirmText.trim().toUpperCase() !== 'DELETE') return
        await supabase.from('kls_test_series_mocks').delete().eq('test_series_id', seriesId)
        const { error } = await supabase.from('kls_test_series').delete().eq('test_series_id', seriesId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'mock-toggle') {
        const mockId = target.dataset.mockId || ''
        const field = target.dataset.field || 'is_active'
        if (!mockId) return
        const current = await supabase.from('kls_mock_tests').select('is_active,is_live,is_paused').eq('mock_test_id', mockId).maybeSingle()
        if (current.error) {
          setMessage(current.error.message)
          return
        }
        const next = { is_active: current.data?.is_active ?? false, is_live: current.data?.is_live ?? false, is_paused: current.data?.is_paused ?? false }
        next[field] = !next[field]
        if (field === 'is_live' && next.is_live) next.is_paused = false
        if (field === 'is_paused' && next.is_paused) next.is_live = true
        const { error } = await supabase.from('kls_mock_tests').update(next).eq('mock_test_id', mockId)
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

      if (action === 'payout-save') {
        const selectedUser = document.getElementById('payoutUser')?.value || ''
        const amount = Number(document.getElementById('payoutAmount')?.value || '0')
        const notes = (document.getElementById('payoutNotes')?.value || '').trim()
        if (!selectedUser || !Number.isFinite(amount) || amount <= 0) {
          setMessage('Select user and valid amount.')
          return
        }
        const { data: authData } = await supabase.auth.getUser()
        const me = authData.user
        if (!me) return
        const { error } = await supabase.from('kls_affiliate_payouts').insert({
          affiliate_user_id: selectedUser,
          amount,
          paid_by: me.id,
          notes: notes || null,
        })
        if (error) {
          setMessage(error.message)
          return
        }
        await refreshPage()
        return
      }

    }
  }

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

    moduleContent.onchange = async (event) => {
      const target = event.target
      if (!target || !(target instanceof HTMLElement)) return

      if (target.id === 'seriesExamCode') {
        uiState.testSeries.examCode = target.value || 'GPSC'
        await refreshPage()
        return
      }

      if (target.id === 'dailySubjectSelect') {
        uiState.daily.subjectId = target.value || ''
        uiState.daily.chapterCode = ''
        uiState.daily.quizId = 'all'
        uiState.daily.selectedQuestionIds = []
        await refreshPage()
        return
      }

      if (target.id === 'dailyChapterSelect') {
        uiState.daily.chapterCode = target.value || ''
        uiState.daily.quizId = 'all'
        uiState.daily.selectedQuestionIds = []
        await refreshPage()
        return
      }

      if (target.id === 'dailyQuizSelect') {
        uiState.daily.quizId = target.value || 'all'
        uiState.daily.selectedQuestionIds = []
        await refreshPage()
        return
      }

      if (target.id === 'dailyQuizName') {
        uiState.daily.quizName = target.value || 'Daily Learning'
        return
      }

      if (target.id === 'dailyTimeLimit') {
        uiState.daily.timeLimit = target.value || '15'
        return
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
