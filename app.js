const config = window.ADMIN_PANEL_CONFIG || {}
const supabaseUrl = config.supabaseUrl || ''
const supabaseAnonKey = config.supabaseAnonKey || ''

const authNote = document.getElementById('authNote')
const loginCard = document.getElementById('loginCard')
const dashboardCard = document.getElementById('dashboardCard')
const statusCard = document.getElementById('statusCard')
const emailInput = document.getElementById('emailInput')
const passwordInput = document.getElementById('passwordInput')
const loginBtn = document.getElementById('loginBtn')
const signOutBtn = document.getElementById('signOutBtn')
const sessionLabel = document.getElementById('sessionLabel')
const sessionSubLabel = document.getElementById('sessionSubLabel')
const sessionDetail = document.getElementById('sessionDetail')
const roleDetail = document.getElementById('roleDetail')
const messageDetail = document.getElementById('messageDetail')
const userEmail = document.getElementById('userEmail')
const roleTitle = document.getElementById('roleTitle')
const connectionPill = document.getElementById('connectionPill')
const verificationBadge = document.getElementById('verificationBadge')
const reportsBadge = document.getElementById('reportsBadge')
const nonEduBadge = document.getElementById('nonEduBadge')
const suggestionsBadge = document.getElementById('suggestionsBadge')
const moduleLinks = Array.from(document.querySelectorAll('.module-link'))

let supabase = null
let currentRole = null

function setMessage(message, isError = true) {
  if (!messageDetail) return
  messageDetail.textContent = message || '-'
  if (authNote) {
    authNote.textContent = message || (isError ? 'Action needed.' : 'Connected.')
  }
}

function setConnectionStatus(connected, message) {
  connectionPill.textContent = connected ? 'Connected' : 'Disconnected'
  connectionPill.className = `pill ${connected ? 'pill-success' : 'pill-danger'}`
  setMessage(message, !connected)
}

function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

function getRoleFromAccessData(data) {
  if (!data || data.is_active !== true) return null
  return data.role || null
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

  if (error) return { user, role: null, error }
  return { user, role: getRoleFromAccessData(data), error: null }
}

function setBadge(node, count) {
  if (!node) return
  const value = Number(count ?? 0)
  if (value <= 0) {
    node.classList.add('hidden')
    node.textContent = ''
    return
  }

  node.classList.remove('hidden')
  node.textContent = String(value)
}

function moduleAllowed(roles, role) {
  const allowed = roles.split(',').map((item) => item.trim())
  return allowed.includes(role || '')
}

function updateModuleVisibility(role) {
  moduleLinks.forEach((link) => {
    const roles = link.dataset.roles || ''
    link.classList.toggle('hidden', !moduleAllowed(roles, role))
  })
}

async function fetchCount(tableName, buildQuery) {
  const baseQuery = supabase.from(tableName).select('*', { head: true, count: 'exact' })
  const query = typeof buildQuery === 'function' ? buildQuery(baseQuery) : baseQuery
  const { count, error } = await query
  if (error) throw error
  return count ?? 0
}

async function loadBadges() {
  try {
    const [verificationPending, reportsPending, suggestionsPending, nonEducationalReportsPending] = await Promise.all([
      fetchCount('ngm_verification_requests', (q) => q.eq('status', 'pending')),
      Promise.all([
        fetchCount('ngm_post_reports', (q) => q.eq('status', 'pending')),
        fetchCount('ngm_quiz_reports', (q) => q.eq('status', 'pending')),
        fetchCount('ngm_poll_reports', (q) => q.eq('status', 'pending')),
        fetchCount('ngm_user_reports', (q) => q.eq('status', 'pending')),
      ]).then((values) => values.reduce((sum, value) => sum + value, 0)),
      fetchCount('kls_questions', (q) => q.not('suggestion', 'is', null).neq('suggestion', '')).catch(() => 0),
      supabase.rpc('ngm_admin_count_pending_non_educational_reports').then(({ data, error }) => {
        if (error) throw error
        return Number(data ?? 0)
      }),
    ])

    setBadge(verificationBadge, verificationPending)
    setBadge(reportsBadge, reportsPending)
    setBadge(suggestionsBadge, suggestionsPending)
    setBadge(nonEduBadge, nonEducationalReportsPending)
  } catch (error) {
    setMessage(error.message || 'Failed to load badge counts.')
  }
}

async function loadDashboardMeta(user, role) {
  sessionLabel.textContent = role ? 'Admin Session' : 'Guest Mode'
  sessionSubLabel.textContent = user?.email || (role ? 'Signed in' : 'Not signed in')
  sessionDetail.textContent = user?.email || 'No active session.'
  roleDetail.textContent = role || '-'
  userEmail.textContent = user?.email || 'Authenticated user'
  roleTitle.textContent = role ? `${role.toUpperCase()} Access Granted` : 'Login to continue'
  updateModuleVisibility(role)
  loginCard.classList.toggle('hidden', Boolean(role))
  dashboardCard.classList.toggle('hidden', !role)
  statusCard.classList.toggle('hidden', !role)
}

async function refreshSession() {
  const access = await getAdminAccess()
  currentRole = access.role

  if (access.error) {
    setMessage(access.error.message || 'Access check failed.')
  }

  await loadDashboardMeta(access.user, access.role)

  if (access.user && access.role) {
    await loadBadges()
    setMessage('Connected to Supabase.', false)
    return
  }

  if (!access.user) {
    setMessage('Sign in to continue.')
  } else if (!access.role) {
    setMessage('No admin access for this account.')
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

  await refreshSession()
}

async function logout() {
  await supabase.auth.signOut()
  currentRole = null
  await refreshSession()
}

function initModuleLinks() {
  moduleLinks.forEach((link) => {
    link.addEventListener('click', (event) => {
      event.preventDefault()
      if (!currentRole) {
        setMessage('Login required.')
        return
      }
      setMessage(`${link.dataset.module} module opens in the Next.js version.`, false)
    })
  })
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
  initModuleLinks()

  const { data: sessionData } = await supabase.auth.getSession()
  await refreshSession(sessionData.session?.user || null)

  supabase.auth.onAuthStateChange(() => {
    void refreshSession()
  })
}

document.getElementById('loginBtn')?.addEventListener('click', () => {
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
