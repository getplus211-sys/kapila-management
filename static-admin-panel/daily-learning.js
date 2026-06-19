const config = window.ADMIN_PANEL_CONFIG || {}
const supabaseUrl = config.supabaseUrl || ''
const supabaseAnonKey = config.supabaseAnonKey || ''
const supabase = window.supabase?.createClient ? window.supabase.createClient(supabaseUrl, supabaseAnonKey) : null

const loginCard = document.getElementById('loginCard')
const moduleShell = document.getElementById('moduleShell')
const authNote = document.getElementById('authNote')
const connectionPill = document.getElementById('connectionPill')
const emailInput = document.getElementById('emailInput')
const passwordInput = document.getElementById('passwordInput')
const loginBtn = document.getElementById('loginBtn')
const signOutBtn = document.getElementById('signOutBtn')
const roleTitle = document.getElementById('roleTitle')
const userEmail = document.getElementById('userEmail')
const pageMessage = document.getElementById('pageMessage')
const dailyMeta = document.getElementById('dailyMeta')
const dailyContent = document.getElementById('dailyContent')

const state = {
  role: null,
  loading: true,
  publishing: false,
  enabled: false,
  subjects: [],
  chapters: [],
  quizzes: [],
  questions: [],
  selectedQuestionIds: [],
  selectedSubjectId: '',
  selectedChapterCode: '',
  selectedQuizId: 'all',
  search: '',
  quizName: 'Daily Learning',
  timeLimit: '15',
  msg: '',
}

function dailyQuizIdForDate(date) {
  const local = new Date(date)
  const y = local.getFullYear().toString().padStart(4, '0')
  const m = (local.getMonth() + 1).toString().padStart(2, '0')
  const d = local.getDate().toString().padStart(2, '0')
  return `DAILY_${y}${m}${d}`
}

function setMessage(message) {
  state.msg = message || ''
  if (pageMessage) pageMessage.textContent = state.msg
}

function showVisible(visible) {
  loginCard?.classList.toggle('hidden', visible)
  moduleShell?.classList.toggle('hidden', !visible)
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

async function getAdminAccess() {
  if (!supabase) return { role: null }
  const { data: authData } = await supabase.auth.getUser()
  const user = authData.user
  if (!user) return { role: null }
  const { data, error } = await supabase.from('ngm_admin_roles').select('role,is_active').eq('user_id', user.id).maybeSingle()
  if (error || !data || data.is_active !== true) return { role: null }
  return { role: data.role || null, user }
}

async function loadSubjects() {
  const { data, error } = await supabase.from('kls_subjects').select('id,name,subject_code').order('created_at')
  if (error) throw error
  state.subjects = data || []
  state.selectedSubjectId = state.selectedSubjectId || state.subjects[0]?.id || ''
}

async function loadChapters() {
  if (!state.selectedSubjectId) {
    state.chapters = []
    return
  }
  const { data, error } = await supabase.from('kls_chapters').select('id,name,chapter_code,subject_id').eq('subject_id', state.selectedSubjectId).order('chapter_code')
  if (error) throw error
  state.chapters = data || []
  state.selectedChapterCode = state.selectedChapterCode || state.chapters[0]?.chapter_code || ''
}

async function loadQuizzes() {
  if (!state.selectedChapterCode) {
    state.quizzes = []
    return
  }
  const { data, error } = await supabase
    .from('kls_quizzes')
    .select('quiz_id,quiz_name,chapter_code,difficulty_level,subject_id,total_questions,time_limit,is_active')
    .eq('chapter_code', state.selectedChapterCode)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
  if (error) throw error
  state.quizzes = data || []
  if (state.selectedQuizId !== 'all' && !state.quizzes.some((quiz) => quiz.quiz_id === state.selectedQuizId)) {
    state.selectedQuizId = 'all'
  }
}

async function loadQuestions() {
  let query = supabase
    .from('kls_questions')
    .select('id,quiz_id,question,option_a,option_b,option_c,option_d,option_e,correct_answer,solution,suggestion,difficulty_level,chapter_code,subject_id')
    .order('created_at', { ascending: false })
    .limit(500)

  if (state.selectedSubjectId) query = query.eq('subject_id', state.selectedSubjectId)
  if (state.selectedChapterCode) query = query.eq('chapter_code', state.selectedChapterCode)
  if (state.selectedQuizId && state.selectedQuizId !== 'all') query = query.eq('quiz_id', state.selectedQuizId)
  if (state.search.trim()) query = query.ilike('question', `%${state.search.trim()}%`)

  const { data, error } = await query
  if (error) throw error
  state.questions = data || []
}

async function loadDailyState() {
  const todayQuizId = dailyQuizIdForDate(new Date())
  const { data, error } = await supabase.from('kls_quizzes').select('quiz_id,is_active').eq('quiz_id', todayQuizId).maybeSingle()
  if (error) throw error
  state.enabled = data?.is_active === true
}

async function loadAll() {
  setMessage('')
  state.loading = true
  const access = await getAdminAccess()
  state.role = access.role
  if (!['owner', 'admin'].includes(access.role || '')) {
    setMessage('Access denied.')
    state.loading = false
    render()
    return
  }
  const user = access.user
  if (user) {
    if (roleTitle) roleTitle.textContent = access.role || 'Admin'
    if (userEmail) userEmail.textContent = user.email || user.id
  }
  await loadSubjects()
  await loadChapters()
  await loadQuizzes()
  await loadQuestions()
  await loadDailyState()
  state.loading = false
  render()
}

function render() {
  if (loginCard && moduleShell) showVisible(Boolean(state.role))
  if (!dailyMeta || !dailyContent) return
  const todayQuizId = dailyQuizIdForDate(new Date())
  dailyMeta.innerHTML = `
    <div class="panel">
      <div class="row-between">
        <div>
          <p class="eyebrow">Today Quiz ID</p>
          <h3 style="margin:4px 0 0 0">${escapeHtml(todayQuizId)}</h3>
        </div>
        <div class="action-wrap">
          <button class="kap-btn kap-btn-outline" data-action="refresh">Refresh</button>
          <button class="kap-btn kap-btn-outline" data-action="clear">Clear Selection</button>
          <button class="kap-btn ${state.enabled ? 'kap-btn-primary' : 'kap-btn-outline'}" data-action="toggle-live">${state.enabled ? 'Daily On' : 'Daily Off'}</button>
          <button class="kap-btn kap-btn-primary" data-action="publish">Publish Today</button>
        </div>
      </div>
    </div>
  `

  const selectedSet = new Set(state.selectedQuestionIds)
  const selectedQuestions = state.questions.filter((q) => selectedSet.has(q.id))
  const unselectedQuestions = state.questions.filter((q) => !selectedSet.has(q.id))

  dailyContent.innerHTML = `
    <div class="panel">
      <div class="form-grid" style="grid-template-columns:repeat(4,minmax(0,1fr));align-items:end">
        <select id="subjectSelect" class="kap-input">
          <option value="">Select subject</option>
          ${state.subjects.map((subject) => `<option value="${escapeHtml(subject.id)}" ${subject.id === state.selectedSubjectId ? 'selected' : ''}>${escapeHtml(subject.name)}</option>`).join('')}
        </select>
        <select id="chapterSelect" class="kap-input">
          <option value="">Select chapter</option>
          ${state.chapters.map((chapter) => `<option value="${escapeHtml(chapter.chapter_code)}" ${chapter.chapter_code === state.selectedChapterCode ? 'selected' : ''}>${escapeHtml(chapter.chapter_code)} - ${escapeHtml(chapter.name)}</option>`).join('')}
        </select>
        <select id="quizSelect" class="kap-input">
          <option value="all" ${state.selectedQuizId === 'all' ? 'selected' : ''}>All quizzes</option>
          ${state.quizzes.map((quiz) => `<option value="${escapeHtml(quiz.quiz_id)}" ${quiz.quiz_id === state.selectedQuizId ? 'selected' : ''}>${escapeHtml(quiz.quiz_name)} (${escapeHtml(String(quiz.total_questions ?? 0))})</option>`).join('')}
        </select>
        <input id="searchInput" class="kap-input" placeholder="Search question text" value="${escapeHtml(state.search)}" />
      </div>
    </div>
    <div class="panel">
      <div class="form-grid" style="grid-template-columns:repeat(2,minmax(0,1fr));align-items:end">
        <input id="quizNameInput" class="kap-input" placeholder="Daily title" value="${escapeHtml(state.quizName)}" />
        <input id="timeLimitInput" class="kap-input" placeholder="Time limit" value="${escapeHtml(state.timeLimit)}" />
      </div>
    </div>
    <div class="panel table-card">
      <p style="margin:0 0 12px 0;color:#475569">Selected ${state.selectedQuestionIds.length} questions</p>
      <table>
        <thead>
          <tr><th>Status</th><th>Question</th><th>Quiz</th><th>Chapter</th><th>Difficulty</th><th>Action</th></tr>
        </thead>
        <tbody>
          ${selectedQuestions.map((q) => `
            <tr>
              <td><span class="kap-chip">Selected</span></td>
              <td>${escapeHtml(q.question || '-')}</td>
              <td>${escapeHtml(q.quiz_id || '-')}</td>
              <td>${escapeHtml(q.chapter_code || '-')}</td>
              <td>${escapeHtml(q.difficulty_level || '-')}</td>
              <td><button class="kap-btn kap-btn-outline" data-toggle-id="${escapeHtml(q.id)}">Unselect</button></td>
            </tr>`).join('')}
          ${unselectedQuestions.map((q) => `
            <tr>
              <td><span class="kap-chip">Unselected</span></td>
              <td>${escapeHtml(q.question || '-')}</td>
              <td>${escapeHtml(q.quiz_id || '-')}</td>
              <td>${escapeHtml(q.chapter_code || '-')}</td>
              <td>${escapeHtml(q.difficulty_level || '-')}</td>
              <td><button class="kap-btn kap-btn-primary" data-toggle-id="${escapeHtml(q.id)}">Select</button></td>
            </tr>`).join('')}
          ${!state.questions.length ? '<tr><td colspan="6">No questions found.</td></tr>' : ''}
        </tbody>
      </table>
    </div>
  `

  const subjectSelect = document.getElementById('subjectSelect')
  const chapterSelect = document.getElementById('chapterSelect')
  const quizSelect = document.getElementById('quizSelect')
  const searchInput = document.getElementById('searchInput')
  const quizNameInput = document.getElementById('quizNameInput')
  const timeLimitInput = document.getElementById('timeLimitInput')

  subjectSelect?.addEventListener('change', async (event) => {
    state.selectedSubjectId = event.target.value || ''
    state.selectedChapterCode = ''
    state.selectedQuizId = 'all'
    state.selectedQuestionIds = []
    await loadChapters()
    await loadQuizzes()
    await loadQuestions()
    render()
  })
  chapterSelect?.addEventListener('change', async (event) => {
    state.selectedChapterCode = event.target.value || ''
    state.selectedQuizId = 'all'
    state.selectedQuestionIds = []
    await loadQuizzes()
    await loadQuestions()
    render()
  })
  quizSelect?.addEventListener('change', async (event) => {
    state.selectedQuizId = event.target.value || 'all'
    state.selectedQuestionIds = []
    await loadQuestions()
    render()
  })
  searchInput?.addEventListener('input', (event) => {
    state.search = event.target.value || ''
  })
  quizNameInput?.addEventListener('input', (event) => {
    state.quizName = event.target.value || 'Daily Learning'
  })
  timeLimitInput?.addEventListener('input', (event) => {
    state.timeLimit = event.target.value || '15'
  })

  dailyContent.querySelectorAll('[data-toggle-id]').forEach((button) => {
    button.addEventListener('click', () => {
      const id = button.getAttribute('data-toggle-id') || ''
      if (!id) return
      state.selectedQuestionIds = state.selectedQuestionIds.includes(id)
        ? state.selectedQuestionIds.filter((value) => value !== id)
        : [...state.selectedQuestionIds, id]
      render()
    })
  })

  dailyMeta.querySelectorAll('[data-action]').forEach((button) => {
    button.addEventListener('click', async () => {
      const action = button.getAttribute('data-action')
      if (action === 'refresh') {
        await loadAll()
      }
      if (action === 'clear') {
        state.selectedQuestionIds = []
        render()
      }
      if (action === 'toggle-live') {
        const todayQuizId = dailyQuizIdForDate(new Date())
        const { data, error } = await supabase.from('kls_quizzes').select('quiz_id,is_active,quiz_name,subject_id,chapter_code,difficulty_level,total_questions,time_limit').eq('quiz_id', todayQuizId).maybeSingle()
        if (error) return setMessage(error.message)
        if (!data) return setMessage('Publish today quiz first, then turn it on.')
        const nextEnabled = !state.enabled
        const { error: updateError } = await supabase.from('kls_quizzes').update({ is_active: nextEnabled }).eq('quiz_id', todayQuizId)
        if (updateError) return setMessage(updateError.message)
        await supabase.from('kls_daily_quiz_settings').upsert({
          quiz_id: todayQuizId,
          quiz_name: data.quiz_name || 'Daily Learning',
          source_quiz_id: data.quiz_id,
          subject_id: data.subject_id || null,
          chapter_code: data.chapter_code || null,
          difficulty_level: data.difficulty_level || null,
          total_questions: data.total_questions ?? 0,
          time_limit: data.time_limit ?? 15,
          is_enabled: nextEnabled,
        }, { onConflict: 'quiz_id' })
        state.enabled = nextEnabled
        setMessage(nextEnabled ? 'Daily quiz turned on.' : 'Daily quiz turned off.')
        render()
      }
      if (action === 'publish') {
        const selectedQuestions = state.questions.filter((q) => state.selectedQuestionIds.includes(q.id))
        if (!selectedQuestions.length) return setMessage('Select at least one question.')
        const todayQuizId = dailyQuizIdForDate(new Date())
        const first = selectedQuestions[0]
        const selectedSubject = state.subjects.find((s) => s.id === (first?.subject_id || state.selectedSubjectId))
        const selectedQuiz = state.quizzes.find((q) => q.quiz_id === (first?.quiz_id || state.selectedQuizId))
        const payload = {
          quiz_id: todayQuizId,
          quiz_name: state.quizName.trim() || 'Daily Learning',
          subject_id: first?.subject_id || selectedQuiz?.subject_id || selectedSubject?.id || null,
          chapter_code: first?.chapter_code || selectedQuiz?.chapter_code || state.selectedChapterCode || null,
          difficulty_level: first?.difficulty_level || selectedQuiz?.difficulty_level || null,
          total_questions: state.selectedQuestionIds.length,
          time_limit: Number(state.timeLimit) || 15,
          is_active: state.enabled,
        }
        state.publishing = true
        const { error: qDeleteError } = await supabase.from('kls_questions').delete().eq('quiz_id', todayQuizId)
        if (qDeleteError) { state.publishing = false; return setMessage(qDeleteError.message) }
        const { error: quizDeleteError } = await supabase.from('kls_quizzes').delete().eq('quiz_id', todayQuizId)
        if (quizDeleteError) { state.publishing = false; return setMessage(quizDeleteError.message) }
        const { error: settingsDeleteError } = await supabase.from('kls_daily_quiz_settings').delete().eq('quiz_id', todayQuizId)
        if (settingsDeleteError) { state.publishing = false; return setMessage(settingsDeleteError.message) }
        const { error: insertQuizError } = await supabase.from('kls_quizzes').insert(payload)
        if (insertQuizError) { state.publishing = false; return setMessage(insertQuizError.message) }
        await supabase.from('kls_daily_quiz_settings').insert({
          quiz_id: todayQuizId,
          quiz_name: payload.quiz_name,
          source_quiz_id: first?.quiz_id || null,
          subject_id: payload.subject_id,
          chapter_code: payload.chapter_code,
          difficulty_level: payload.difficulty_level,
          total_questions: payload.total_questions,
          time_limit: payload.time_limit,
          is_enabled: state.enabled,
        })
        const rowsToCopy = selectedQuestions.map((q, index) => ({
          quiz_id: todayQuizId,
          question: q.question,
          option_a: q.option_a,
          option_b: q.option_b,
          option_c: q.option_c,
          option_d: q.option_d,
          option_e: q.option_e,
          correct_answer: q.correct_answer,
          solution: q.solution,
          suggestion: q.suggestion,
          difficulty_level: q.difficulty_level,
          chapter_code: q.chapter_code,
          subject_id: q.subject_id,
        }))
        const { error: insertQuestionsError } = await supabase.from('kls_questions').insert(rowsToCopy)
        if (insertQuestionsError) { state.publishing = false; return setMessage(insertQuestionsError.message) }
        await supabase.from('kls_daily_quiz_questions').delete().eq('quiz_id', todayQuizId)
        await supabase.from('kls_daily_quiz_questions').insert(state.selectedQuestionIds.map((id, index) => ({ quiz_id: todayQuizId, question_id: id, display_order: index + 1 })))
        state.publishing = false
        setMessage(`Published ${selectedQuestions.length} questions for ${todayQuizId}.`)
      }
    })
  })
}

async function init() {
  if (!supabaseUrl || !supabaseAnonKey || !supabase) {
    connectionPill.textContent = 'Config missing'
    setMessage('Add Supabase URL and anon key in config.js.')
    return
  }
  connectionPill.textContent = 'Supabase connected'
  const { data } = await supabase.auth.getSession()
  if (data.session?.user) {
    await loadAll()
  } else {
    showVisible(false)
  }
  supabase.auth.onAuthStateChange(() => {
    void loadAll()
  })
}

loginBtn?.addEventListener('click', async () => {
  const email = emailInput.value.trim()
  const password = passwordInput.value
  if (!email || !password) return setMessage('Email and password required.')
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) return setMessage(error.message)
  await loadAll()
})

signOutBtn?.addEventListener('click', async () => {
  await supabase.auth.signOut()
  showVisible(false)
})

void init()
