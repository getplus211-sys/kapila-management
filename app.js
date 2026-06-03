const config = window.ADMIN_PANEL_CONFIG || {}
const supabaseUrl = config.supabaseUrl || ''
const supabaseAnonKey = config.supabaseAnonKey || ''

const authScreen = document.getElementById('authScreen')
const authNote = document.getElementById('authNote')
const loginForm = document.getElementById('loginForm')
const emailInput = document.getElementById('emailInput')
const passwordInput = document.getElementById('passwordInput')
const signOutBtn = document.getElementById('signOutBtn')
const sessionLabel = document.getElementById('sessionLabel')
const sessionSubLabel = document.getElementById('sessionSubLabel')
const userEmail = document.getElementById('userEmail')
const connectionPill = document.getElementById('connectionPill')
const pageTitle = document.getElementById('pageTitle')
const sidebar = document.getElementById('sidebar')
const openSidebar = document.getElementById('openSidebar')
const closeSidebar = document.getElementById('closeSidebar')

const sections = Array.from(document.querySelectorAll('[data-section]'))
const navLinks = Array.from(document.querySelectorAll('[data-section-link]'))

let supabase = null

const state = {
  user: null,
  sessionReady: false,
}

function showSection(name) {
  const sectionName = name || 'dashboard'

  sections.forEach((section) => {
    section.classList.toggle('active', section.dataset.section === sectionName)
  })

  navLinks.forEach((link) => {
    link.classList.toggle('active', link.dataset.sectionLink === sectionName)
  })

  const activeLabel = navLinks.find((link) => link.dataset.sectionLink === sectionName)?.textContent || 'Dashboard'
  pageTitle.textContent = activeLabel
}

function setConnectionStatus(connected, message) {
  connectionPill.textContent = connected ? 'Connected' : 'Disconnected'
  connectionPill.className = `pill ${connected ? 'pill-success' : 'pill-danger'}`
  authNote.textContent = message || (connected ? 'Connected to Supabase.' : 'Add Supabase config in config.js.')
}

function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

function showApp(visible) {
  authScreen.classList.toggle('hidden', visible)
  document.querySelector('.app-shell').classList.toggle('hidden', !visible)
}

async function fetchCount(tableName) {
  const { count, error } = await supabase.from(tableName).select('*', { head: true, count: 'exact' })
  return { count: count ?? 0, error }
}

async function fetchRows(tableName, columns, limit = 5) {
  const { data, error } = await supabase.from(tableName).select(columns).limit(limit)
  return { data: data ?? [], error }
}

function renderList(container, rows, fallbackLabel) {
  container.innerHTML = rows.length
    ? rows
        .map((row) => `<div class="list-item"><strong>${row.title}</strong><span>${row.detail}</span></div>`)
        .join('')
    : `<div class="list-item"><strong>${fallbackLabel}</strong><span>No rows returned.</span></div>`
}

async function loadDashboard() {
  if (!supabase) return

  const counts = await Promise.all([
    fetchCount('kls_exams'),
    fetchCount('kls_test_series'),
    fetchCount('kls_mock_tests'),
    fetchCount('ngm_users'),
    fetchCount('ngm_verification_requests'),
    fetchCount('ngm_report_replies'),
  ])

  const cardValues = document.querySelectorAll('.card strong')
  const metrics = [
    counts[3].count,
    counts[4].count,
    '4 plans',
    counts[1].count,
  ]
  cardValues.forEach((node, index) => {
    if (metrics[index] !== undefined) node.textContent = String(metrics[index])
  })

  const [adminsRes, verifiedRes, seriesRes, mocksRes] = await Promise.all([
    fetchRows('ngm_users', 'user_name, email, account_role, is_verified', 3),
    fetchRows('ngm_users', 'user_name, email, is_verified', 3),
    fetchRows('kls_test_series', 'series_name, exam_code, is_active, created_at', 3),
    fetchRows('kls_mock_tests', 'mock_name, exam_code, is_active, is_live, is_paused, created_at', 3),
  ])

  const adminList = document.querySelector('#admin-users .list-grid') || null
  if (adminList) {
    renderList(
      adminList,
      (adminsRes.data || []).map((row) => ({
        title: row.user_name || row.email || 'Admin',
        detail: `${row.account_role || 'role'} • ${row.is_verified ? 'verified' : 'pending'}`,
      })),
      'No admin rows'
    )
  }

  const verifiedList = document.querySelector('#verified-users .list-grid')
  if (verifiedList) {
    renderList(
      verifiedList,
      (verifiedRes.data || []).map((row) => ({
        title: row.user_name || row.email || 'User',
        detail: row.is_verified ? 'Verified' : 'Not verified',
      })),
      'No verified users'
    )
  }

  const testSeriesPanel = document.querySelector('#test-series .list-grid')
  if (testSeriesPanel) {
    renderList(
      testSeriesPanel,
      (seriesRes.data || []).map((row) => ({
        title: row.series_name || 'Series',
        detail: `${row.exam_code || 'exam'} • ${row.is_active ? 'active' : 'inactive'}`,
      })),
      'No series found'
    )
  }

  const allQuestionsPanel = document.querySelector('#all-questions .panel')
  if (allQuestionsPanel) {
    const mockItems = (mocksRes.data || []).map((row, index) => (
      `<div class="question-preview"><strong>Mock ${index + 1}</strong><p>${row.mock_name || 'Unnamed'} • ${row.exam_code || 'exam'}</p></div>`
    ))
    allQuestionsPanel.innerHTML = mockItems.join('') || '<div class="question-preview"><strong>No mocks</strong><p>No data available.</p></div>'
  }
}

async function refreshSession(user) {
  state.user = user || null

  if (!user) {
    sessionLabel.textContent = 'Guest Mode'
    sessionSubLabel.textContent = 'Not signed in'
    userEmail.textContent = 'No active session.'
    showApp(false)
    return
  }

  sessionLabel.textContent = 'Admin Session'
  sessionSubLabel.textContent = user.email || 'Signed in'
  userEmail.textContent = user.email || 'Authenticated user'
  showApp(true)
  showSection(window.location.hash.replace('#', '') || 'dashboard')
  await loadDashboard()
}

function initNavigation() {
  navLinks.forEach((link) => {
    link.addEventListener('click', () => {
      showSection(link.dataset.sectionLink)
      if (window.innerWidth <= 1200) {
        sidebar.classList.remove('open')
      }
    })
  })

  openSidebar?.addEventListener('click', () => sidebar.classList.add('open'))
  closeSidebar?.addEventListener('click', () => sidebar.classList.remove('open'))

  window.addEventListener('hashchange', () => {
    showSection(window.location.hash.replace('#', ''))
  })
}

async function init() {
  if (!supabaseUrl || !supabaseAnonKey) {
    setConnectionStatus(false, 'Add your Supabase URL and anon key in config.js.')
    showApp(false)
    return
  }

  if (!isValidHttpUrl(supabaseUrl)) {
    setConnectionStatus(false, 'Supabase URL in config.js must start with http:// or https://.')
    showApp(false)
    return
  }

  if (!window.supabase?.createClient) {
    setConnectionStatus(false, 'Supabase library failed to load.')
    showApp(false)
    return
  }

  supabase = window.supabase.createClient(supabaseUrl, supabaseAnonKey)
  setConnectionStatus(true, 'Supabase client created successfully.')
  initNavigation()

  const { data } = await supabase.auth.getSession()
  state.sessionReady = true
  await refreshSession(data.session?.user || null)

  supabase.auth.onAuthStateChange(async (_event, session) => {
    await refreshSession(session?.user || null)
  })
}

loginForm?.addEventListener('submit', async (event) => {
  event.preventDefault()
  if (!supabase) return

  authNote.textContent = 'Signing in...'
  const email = emailInput.value.trim()
  const password = passwordInput.value

  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) {
    authNote.textContent = error.message
    return
  }

  authNote.textContent = 'Signed in.'
})

signOutBtn?.addEventListener('click', async () => {
  if (!supabase) return
  await supabase.auth.signOut()
})

showApp(false)
void init()
