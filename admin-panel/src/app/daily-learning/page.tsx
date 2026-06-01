'use client'

import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type SubjectRow = {
  id: string
  name: string
  subject_code: string | null
}

type ChapterRow = {
  id: string
  name: string
  chapter_code: string
  subject_id: string
}

type QuizRow = {
  quiz_id: string
  quiz_name: string
  chapter_code: string
  difficulty_level: string | null
  subject_id: string | null
  total_questions: number | null
  time_limit: number | null
  is_active: boolean
}

type QuestionRow = {
  id: string
  quiz_id: string
  question: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  option_e: string | null
  correct_answer: string
  solution: string | null
  suggestion: string | null
  difficulty_level: string | null
  chapter_code: string | null
  subject_id: string | null
}

function dailyQuizIdForDate(date: Date) {
  const local = new Date(date)
  const y = local.getFullYear().toString().padStart(4, '0')
  const m = (local.getMonth() + 1).toString().padStart(2, '0')
  const d = local.getDate().toString().padStart(2, '0')
  return `DAILY_${y}${m}${d}`
}

export default function DailyLearningPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [publishing, setPublishing] = useState(false)
  const [msg, setMsg] = useState('')

  const [subjects, setSubjects] = useState<SubjectRow[]>([])
  const [chapters, setChapters] = useState<ChapterRow[]>([])
  const [quizzes, setQuizzes] = useState<QuizRow[]>([])
  const [questions, setQuestions] = useState<QuestionRow[]>([])

  const [selectedSubjectId, setSelectedSubjectId] = useState('')
  const [selectedChapterCode, setSelectedChapterCode] = useState('')
  const [selectedQuizId, setSelectedQuizId] = useState('')
  const [selectedQuestionIds, setSelectedQuestionIds] = useState<string[]>([])
  const [search, setSearch] = useState('')
  const [quizName, setQuizName] = useState('Daily Learning')
  const [timeLimit, setTimeLimit] = useState('15')

  const todayQuizId = useMemo(() => dailyQuizIdForDate(new Date()), [])

  async function loadBase() {
    setLoading(true)
    setMsg('')

    const access = await getAdminAccess()
    setRole(access.role)
    if (!['owner', 'admin'].includes(access.role ?? '')) {
      setMsg('Access denied.')
      setLoading(false)
      return
    }

    const [subjectRes] = await Promise.all([
      supabase.from('kls_subjects').select('id,name,subject_code').order('created_at'),
    ])

    if (subjectRes.error) {
      setMsg(subjectRes.error.message)
      setLoading(false)
      return
    }

    const subjectRows = (subjectRes.data ?? []) as SubjectRow[]
    setSubjects(subjectRows)

    const firstSubjectId = selectedSubjectId || subjectRows[0]?.id || ''
    setSelectedSubjectId(firstSubjectId)

    if (firstSubjectId) {
      await loadChapters(firstSubjectId, false)
    } else {
      setLoading(false)
    }
  }

  async function loadChapters(subjectId: string, resetLoading = true) {
    if (resetLoading) setLoading(true)
    const { data, error } = await supabase
      .from('kls_chapters')
      .select('id,name,chapter_code,subject_id')
      .eq('subject_id', subjectId)
      .order('chapter_code')

    if (error) {
      setMsg(error.message)
      setChapters([])
      setQuizzes([])
      setQuestions([])
      setLoading(false)
      return
    }

    const rows = (data ?? []) as ChapterRow[]
    setChapters(rows)
    const firstChapter = rows[0]?.chapter_code || ''
    setSelectedChapterCode(firstChapter)

    if (firstChapter) {
      await loadQuizzes(firstChapter, false)
    } else {
      setQuizzes([])
      setQuestions([])
      setLoading(false)
    }
  }

  async function loadQuizzes(chapterCode: string, resetLoading = true) {
    if (resetLoading) setLoading(true)
    const { data, error } = await supabase
      .from('kls_quizzes')
      .select('quiz_id,quiz_name,chapter_code,difficulty_level,subject_id,total_questions,time_limit,is_active')
      .eq('chapter_code', chapterCode)
      .eq('is_active', true)
      .order('created_at', { ascending: false })

    if (error) {
      setMsg(error.message)
      setQuizzes([])
      setQuestions([])
      setLoading(false)
      return
    }

    const rows = (data ?? []) as QuizRow[]
    setQuizzes(rows)
    const firstQuiz = rows[0]?.quiz_id || ''
    setSelectedQuizId(firstQuiz)

    if (firstQuiz) {
      await loadQuestions(firstQuiz, false)
    } else {
      setQuestions([])
      setLoading(false)
    }
  }

  async function loadQuestions(quizId: string, resetLoading = true) {
    if (resetLoading) setLoading(true)
    let query = supabase
      .from('kls_questions')
      .select('id,quiz_id,question,option_a,option_b,option_c,option_d,option_e,correct_answer,solution,suggestion,difficulty_level,chapter_code,subject_id')
      .eq('quiz_id', quizId)
      .order('created_at', { ascending: false })
      .limit(500)

    if (search.trim()) {
      query = query.ilike('question', `%${search.trim()}%`)
    }

    const { data, error } = await query
    if (error) {
      setMsg(error.message)
      setQuestions([])
      setSelectedQuestionIds([])
      setLoading(false)
      return
    }

    const rows = (data ?? []) as QuestionRow[]
    setQuestions(rows)
    setSelectedQuestionIds(rows.slice(0, 10).map((q) => q.id))
    setLoading(false)
  }

  async function refreshCurrent() {
    if (!selectedQuizId) return
    await loadQuestions(selectedQuizId)
  }

  async function onSubjectChange(subjectId: string) {
    setSelectedSubjectId(subjectId)
    setSelectedChapterCode('')
    setSelectedQuizId('')
    setQuestions([])
    setQuizzes([])
    setSelectedQuestionIds([])
    if (subjectId) {
      await loadChapters(subjectId)
    }
  }

  async function onChapterChange(chapterCode: string) {
    setSelectedChapterCode(chapterCode)
    setSelectedQuizId('')
    setQuestions([])
    setSelectedQuestionIds([])
    if (chapterCode) {
      await loadQuizzes(chapterCode)
    }
  }

  async function onQuizChange(quizId: string) {
    setSelectedQuizId(quizId)
    setSelectedQuestionIds([])
    if (quizId) {
      await loadQuestions(quizId)
    } else {
      setQuestions([])
    }
  }

  function toggleQuestion(id: string, checked: boolean) {
    setSelectedQuestionIds((prev) => {
      if (checked) {
        if (prev.includes(id)) return prev
        return [...prev, id]
      }
      return prev.filter((x) => x !== id)
    })
  }

  async function publishDaily() {
    if (!selectedQuizId) {
      setMsg('Select a source quiz.')
      return
    }
    if (!selectedQuestionIds.length) {
      setMsg('Select at least one question.')
      return
    }

    setPublishing(true)
    setMsg('')

    const selectedQuiz = quizzes.find((q) => q.quiz_id === selectedQuizId)
    const selectedSubject = subjects.find((s) => s.id === selectedSubjectId)

    const payload = {
      quiz_id: todayQuizId,
      quiz_name: quizName.trim() || 'Daily Learning',
      subject_id: selectedQuiz?.subject_id || selectedSubject?.id || null,
      chapter_code: selectedQuiz?.chapter_code || selectedChapterCode || null,
      difficulty_level: selectedQuiz?.difficulty_level || null,
      total_questions: selectedQuestionIds.length,
      time_limit: Number(timeLimit) || 15,
      is_active: true,
    }

    const { error: quizDeleteError } = await supabase.from('kls_questions').delete().eq('quiz_id', todayQuizId)
    if (quizDeleteError) {
      setMsg(quizDeleteError.message)
      setPublishing(false)
      return
    }

    const { error: quizRowDeleteError } = await supabase.from('kls_quizzes').delete().eq('quiz_id', todayQuizId)
    if (quizRowDeleteError) {
      setMsg(quizRowDeleteError.message)
      setPublishing(false)
      return
    }

    const { error: insertQuizError } = await supabase.from('kls_quizzes').insert(payload)
    if (insertQuizError) {
      setMsg(insertQuizError.message)
      setPublishing(false)
      return
    }

    const rowsToCopy = questions
      .filter((q) => selectedQuestionIds.includes(q.id))
      .map((q) => ({
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
    if (insertQuestionsError) {
      setMsg(insertQuestionsError.message)
      setPublishing(false)
      return
    }

    setMsg(`Published ${selectedQuestionIds.length} questions for ${todayQuizId}.`)
    setPublishing(false)
  }

  useEffect(() => {
    void loadBase()
    logAdminPageView('daily-learning')
  }, [])

  if (loading) {
    return <main style={{ padding: 24 }}>Loading...</main>
  }

  if (!role) {
    return (
      <main style={{ padding: 24 }}>
        <h1>Daily Learning Manager</h1>
        <p>{msg || 'Access denied.'}</p>
      </main>
    )
  }

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, alignItems: 'center', marginBottom: 20 }}>
        <div>
          <h1 style={{ fontSize: 30, fontWeight: 800, marginBottom: 6 }}>Daily Learning Manager</h1>
          <p style={{ color: '#666' }}>Select questions from kls_questions and publish today's daily quiz.</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Today quiz ID</div>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{todayQuizId}</div>
        </div>
      </div>

      {msg ? (
        <div style={{ padding: 12, marginBottom: 16, borderRadius: 10, background: '#fff4e5', color: '#7a4a00' }}>
          {msg}
        </div>
      ) : null}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12, marginBottom: 16 }}>
        <select value={selectedSubjectId} onChange={(e) => void onSubjectChange(e.target.value)} style={{ padding: 10 }}>
          <option value=''>Select subject</option>
          {subjects.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>

        <select value={selectedChapterCode} onChange={(e) => void onChapterChange(e.target.value)} style={{ padding: 10 }}>
          <option value=''>Select chapter</option>
          {chapters.map((c) => (
            <option key={c.chapter_code} value={c.chapter_code}>
              {c.chapter_code} - {c.name}
            </option>
          ))}
        </select>

        <select value={selectedQuizId} onChange={(e) => void onQuizChange(e.target.value)} style={{ padding: 10 }}>
          <option value=''>Select source quiz</option>
          {quizzes.map((q) => (
            <option key={q.quiz_id} value={q.quiz_id}>
              {q.quiz_name} ({q.total_questions ?? 0})
            </option>
          ))}
        </select>

        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder='Search question text'
          style={{ padding: 10 }}
        />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12, marginBottom: 20 }}>
        <input value={quizName} onChange={(e) => setQuizName(e.target.value)} placeholder='Daily title' style={{ padding: 10 }} />
        <input value={timeLimit} onChange={(e) => setTimeLimit(e.target.value)} placeholder='Time limit' style={{ padding: 10 }} />
        <button onClick={() => void refreshCurrent()} style={{ padding: 10, cursor: 'pointer' }}>Refresh questions</button>
        <button
          onClick={() => void publishDaily()}
          disabled={publishing}
          style={{ padding: 10, cursor: 'pointer', background: '#16a34a', color: 'white', border: 'none' }}
        >
          {publishing ? 'Publishing...' : 'Publish Today'}
        </button>
      </div>

      <div style={{ marginBottom: 12, color: '#444' }}>
        Selected {selectedQuestionIds.length} questions
      </div>

      <div style={{ display: 'grid', gap: 12 }}>
        {questions.map((q, index) => {
          const checked = selectedQuestionIds.includes(q.id)
          return (
            <label
              key={q.id}
              style={{
                display: 'block',
                border: '1px solid #ddd',
                borderRadius: 12,
                padding: 14,
                background: checked ? '#eefbf3' : 'white',
              }}
            >
              <div style={{ display: 'flex', gap: 12, alignItems: 'start' }}>
                <input type='checkbox' checked={checked} onChange={(e) => toggleQuestion(q.id, e.target.checked)} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, marginBottom: 8 }}>
                    {index + 1}. {q.question}
                  </div>
                  <div style={{ color: '#555', fontSize: 14, lineHeight: 1.6 }}>
                    <div>A. {q.option_a}</div>
                    <div>B. {q.option_b}</div>
                    <div>C. {q.option_c}</div>
                    <div>D. {q.option_d}</div>
                    {q.option_e ? <div>E. {q.option_e}</div> : null}
                  </div>
                  <div style={{ marginTop: 8, fontSize: 13, color: '#666' }}>
                    Answer: {q.correct_answer} {q.chapter_code ? `| Chapter: ${q.chapter_code}` : ''}
                  </div>
                </div>
              </div>
            </label>
          )
        })}
      </div>
    </main>
  )
}
