'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'

type ExamRow = {
  exam_code: string
  exam_name: string
}

type SeriesRow = {
  test_series_id: string
  exam_code: string
  series_name: string
}

type MockRow = {
  mock_test_id: string
  exam_code: string
  mock_name: string
}

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
  is_active: boolean
}

type BankQuestion = Record<string, unknown>

export default function CreateNewMockPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(true)

  const [exams, setExams] = useState<ExamRow[]>([])
  const [seriesRows, setSeriesRows] = useState<SeriesRow[]>([])
  const [mockRows, setMockRows] = useState<MockRow[]>([])

  const [examCode, setExamCode] = useState('GPSC')
  const [mockName, setMockName] = useState('')
  const [mockDetails, setMockDetails] = useState('')
  const [engineType, setEngineType] = useState<'MOCK_025' | 'MOCK_033'>('MOCK_025')
  const [durationMinutes, setDurationMinutes] = useState('30')
  const [isPaid, setIsPaid] = useState(true)
  const [makeLiveNow, setMakeLiveNow] = useState(false)
  const [isPaused, setIsPaused] = useState(false)
  const [isActive, setIsActive] = useState(true)
  const [mapSeriesId, setMapSeriesId] = useState('')
  const [displayOrder, setDisplayOrder] = useState('1')

  const [importMockId, setImportMockId] = useState('')
  const [subjectRows, setSubjectRows] = useState<SubjectRow[]>([])
  const [chapterRows, setChapterRows] = useState<ChapterRow[]>([])
  const [quizRows, setQuizRows] = useState<QuizRow[]>([])
  const [selectedSubjectId, setSelectedSubjectId] = useState('')
  const [selectedChapterCode, setSelectedChapterCode] = useState('')
  const [selectedQuizId, setSelectedQuizId] = useState('')
  const [questionSearch, setQuestionSearch] = useState('')
  const [questionBankRows, setQuestionBankRows] = useState<BankQuestion[]>([])
  const [questionBankLoading, setQuestionBankLoading] = useState(false)
  const [selectedQuestionIds, setSelectedQuestionIds] = useState<string[]>([])
  const [expandedOptionQuestionIds, setExpandedOptionQuestionIds] = useState<string[]>([])

  const negativeMark = useMemo(() => (engineType === 'MOCK_025' ? 0.25 : 0.33), [engineType])

  async function loadData() {
    setLoading(true)
    setMsg('')

    const access = await getAdminAccess()
    setRole(access.role)
    if (!hasSalesAccess(access.role)) {
      setMsg('Access denied.')
      setLoading(false)
      return
    }

    const [eRes, sRes, mRes] = await Promise.all([
      supabase.from('kls_exams').select('exam_code,exam_name').order('sort_order'),
      supabase.from('kls_test_series').select('test_series_id,exam_code,series_name').order('created_at', { ascending: false }),
      supabase.from('kls_mock_tests').select('mock_test_id,exam_code,mock_name').order('created_at', { ascending: false }),
    ])

    if (eRes.error || sRes.error || mRes.error) {
      setMsg(eRes.error?.message ?? sRes.error?.message ?? mRes.error?.message ?? 'Load error')
      setLoading(false)
      return
    }

    const eRows = (eRes.data ?? []) as ExamRow[]
    setExams(eRows)
    setSeriesRows((sRes.data ?? []) as SeriesRow[])
    setMockRows((mRes.data ?? []) as MockRow[])

    if (eRows.length > 0 && !examCode) setExamCode(eRows[0].exam_code)
    setLoading(false)
  }

  async function loadSubjects() {
    const { data, error } = await supabase.from('kls_subjects').select('id,name,subject_code').order('created_at')
    if (error) {
      setMsg(error.message)
      setSubjectRows([])
      return
    }
    const rows = (data ?? []) as SubjectRow[]
    setSubjectRows(rows)
    if (rows.length > 0 && !selectedSubjectId) setSelectedSubjectId(rows[0].id)
  }

  async function loadChaptersForSubject(subjectId: string) {
    if (!subjectId) {
      setChapterRows([])
      setSelectedChapterCode('')
      return
    }
    const { data, error } = await supabase
      .from('kls_chapters')
      .select('id,name,chapter_code,subject_id')
      .eq('subject_id', subjectId)
      .order('chapter_code')
    if (error) {
      setMsg(error.message)
      setChapterRows([])
      setSelectedChapterCode('')
      return
    }
    const rows = (data ?? []) as ChapterRow[]
    setChapterRows(rows)
    setSelectedChapterCode(rows[0]?.chapter_code ?? '')
  }

  async function loadQuizzesForChapter(chapterCode: string) {
    if (!chapterCode) {
      setQuizRows([])
      setSelectedQuizId('')
      return
    }

    const { data, error } = await supabase
      .from('kls_quizzes')
      .select('quiz_id,quiz_name,chapter_code,is_active')
      .eq('chapter_code', chapterCode)
      .order('created_at')

    if (error) {
      setMsg(error.message)
      setQuizRows([])
      setSelectedQuizId('')
      return
    }

    const rows = (data ?? []) as QuizRow[]
    setQuizRows(rows)
    setSelectedQuizId(rows[0]?.quiz_id ?? '')
  }

  async function loadQuestionBank() {
    setQuestionBankLoading(true)

    if (!selectedQuizId) {
      setQuestionBankRows([])
      setQuestionBankLoading(false)
      return
    }

    let query = supabase
      .from('kls_questions')
      .select('*')
      .eq('quiz_id', selectedQuizId)
      .order('created_at', { ascending: false })
      .limit(300)

    if (questionSearch.trim()) {
      query = query.ilike('question', `%${questionSearch.trim()}%`)
    }

    const { data, error } = await query
    if (error) {
      setMsg(error.message)
      setQuestionBankRows([])
      setQuestionBankLoading(false)
      return
    }

    setQuestionBankRows((data ?? []) as BankQuestion[])
    setQuestionBankLoading(false)
  }

  function toggleQuestionSelection(questionId: string, checked: boolean) {
    setSelectedQuestionIds((prev) => {
      if (checked) {
        if (prev.includes(questionId)) return prev
        return [...prev, questionId]
      }
      return prev.filter((x) => x !== questionId)
    })
  }

  function toggleQuestionOptions(questionId: string) {
    setExpandedOptionQuestionIds((prev) =>
      prev.includes(questionId) ? prev.filter((x) => x !== questionId) : [...prev, questionId]
    )
  }

  function hasHtml(input: string): boolean {
    return /<[^>]+>/.test(input)
  }

  function renderHtmlOrText(input: string) {
    if (!input.trim()) return <span>-</span>
    if (hasHtml(input)) {
      return <span dangerouslySetInnerHTML={{ __html: input }} />
    }
    return <span>{input}</span>
  }

  async function addSelectedQuestionsToMock(resetExisting: boolean) {
    if (!importMockId) {
      setMsg('Import mate target mock select karo.')
      return
    }
    if (selectedQuestionIds.length === 0) {
      setMsg('Pehla questions select karo.')
      return
    }

    const selectedSubject = subjectRows.find((s) => s.id === selectedSubjectId)
    const selectedChapter = chapterRows.find((c) => c.chapter_code === selectedChapterCode)

    const { data, error } = await supabase.rpc('kls_admin_add_questions_to_mock', {
      p_mock_test_id: importMockId,
      p_question_ids: selectedQuestionIds,
      p_default_subject_id: selectedSubject?.subject_code ?? 'GEN',
      p_default_subject_name: selectedSubject?.name ?? 'General',
      p_default_chapter_code: selectedChapter?.chapter_code ?? 'GENERAL',
      p_default_chapter_name: selectedChapter?.name ?? 'General',
      p_reset_existing: resetExisting,
    })

    if (error) {
      setMsg(error.message)
      return
    }

    const row = Array.isArray(data) ? data[0] : null
    setMsg(
      `Done. Inserted: ${row?.inserted_count ?? 0}, Skipped: ${row?.skipped_count ?? 0}, Order: ${row?.starting_order ?? 0}-${row?.ending_order ?? 0}`
    )
    setSelectedQuestionIds([])
    await loadData()
  }

  async function createMock() {
    setMsg('')
    const duration = Number(durationMinutes)
    const order = Number(displayOrder)

    if (!examCode || !mockName.trim() || !Number.isFinite(duration) || duration <= 0) {
      setMsg('Exam, mock name, duration required.')
      return
    }

    const { data, error } = await supabase
      .from('kls_mock_tests')
      .insert({
        exam_code: examCode,
        mock_name: mockName.trim(),
        mock_details: mockDetails.trim() || null,
        engine_type: engineType,
        negative_mark: negativeMark,
        positive_mark: 1,
        duration_minutes: duration,
        is_paid: isPaid,
        is_live: makeLiveNow,
        is_paused: isPaused,
        is_active: isActive,
        result_mode: 'final_only',
      })
      .select('mock_test_id')
      .single()

    if (error || !data?.mock_test_id) {
      setMsg(error?.message ?? 'Create mock failed')
      return
    }

    if (mapSeriesId) {
      const { error: mapErr } = await supabase
        .from('kls_test_series_mocks')
        .upsert({
          test_series_id: mapSeriesId,
          mock_test_id: data.mock_test_id,
          display_order: Number.isFinite(order) && order > 0 ? order : 1,
        })

      if (mapErr) {
        setMsg(`Mock created, but mapping failed: ${mapErr.message}`)
        return
      }
    }

    setMockName('')
    setMockDetails('')
    setDurationMinutes('30')
    setDisplayOrder('1')
    setMapSeriesId('')
    setImportMockId(data.mock_test_id)
    setMsg('New mock test created successfully. Now you can import questions below.')
    await loadData()
  }

  useEffect(() => {
    void loadData()
    void loadSubjects()
  }, [])

  useEffect(() => {
    void loadChaptersForSubject(selectedSubjectId)
  }, [selectedSubjectId])

  useEffect(() => {
    void loadQuizzesForChapter(selectedChapterCode)
  }, [selectedChapterCode])

  useEffect(() => {
    void loadQuestionBank()
  }, [selectedQuizId])

  const seriesByExam = useMemo(() => seriesRows.filter((s) => s.exam_code === examCode), [seriesRows, examCode])
  const mocksByExam = useMemo(() => mockRows.filter((m) => m.exam_code === examCode), [mockRows, examCode])

  useEffect(() => {
    if (!mocksByExam.length) {
      setImportMockId('')
      return
    }
    if (!mocksByExam.some((m) => m.mock_test_id === importMockId)) {
      setImportMockId(mocksByExam[0].mock_test_id)
    }
  }, [mocksByExam, importMockId])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Create New Mock Test</h1>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Link href='/test-series' className='kap-subtle-link'>Back to Test Series</Link>
          <Link href='/' className='kap-subtle-link'>Home</Link>
        </div>
      </div>

      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}
      {loading ? <p>Loading...</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}

      <div className='kap-card' style={{ maxWidth: 980, display: 'grid', gap: 10, marginBottom: 12 }}>
        <label style={{ fontSize: 12, color: '#6b7280' }}>Exam (kls_mock_tests.exam_code)</label>
        <select className='kap-input' value={examCode} onChange={(e) => setExamCode(e.target.value)}>
          {exams.map((e) => (
            <option key={e.exam_code} value={e.exam_code}>
              {e.exam_name} ({e.exam_code})
            </option>
          ))}
        </select>

        <label style={{ fontSize: 12, color: '#6b7280' }}>Mock Name (kls_mock_tests.mock_name)</label>
        <input className='kap-input' value={mockName} onChange={(e) => setMockName(e.target.value)} />

        <label style={{ fontSize: 12, color: '#6b7280' }}>Mock Details (kls_mock_tests.mock_details)</label>
        <input className='kap-input' value={mockDetails} onChange={(e) => setMockDetails(e.target.value)} />

        <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 1fr 1fr' }}>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Engine Type</label>
            <select className='kap-input' value={engineType} onChange={(e) => setEngineType(e.target.value as 'MOCK_025' | 'MOCK_033')}>
              <option value='MOCK_025'>MOCK_025 (-0.25)</option>
              <option value='MOCK_033'>MOCK_033 (-0.33)</option>
            </select>
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Duration Minutes</label>
            <input className='kap-input' value={durationMinutes} onChange={(e) => setDurationMinutes(e.target.value)} />
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Negative Mark (auto)</label>
            <input className='kap-input' value={String(negativeMark)} readOnly />
          </div>
        </div>

        <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
          <label><input type='checkbox' checked={isPaid} onChange={(e) => setIsPaid(e.target.checked)} /> Paid</label>
          <label><input type='checkbox' checked={makeLiveNow} onChange={(e) => setMakeLiveNow(e.target.checked)} /> Live Now</label>
          <label><input type='checkbox' checked={isPaused} onChange={(e) => setIsPaused(e.target.checked)} /> Paused</label>
          <label><input type='checkbox' checked={isActive} onChange={(e) => setIsActive(e.target.checked)} /> Active</label>
        </div>

        <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10, display: 'grid', gap: 8 }}>
          <p style={{ margin: 0, fontWeight: 700 }}>Optional: Map This Mock to Series</p>
          <label style={{ fontSize: 12, color: '#6b7280' }}>Series (kls_test_series_mocks.test_series_id)</label>
          <select className='kap-input' value={mapSeriesId} onChange={(e) => setMapSeriesId(e.target.value)}>
            <option value=''>No mapping now</option>
            {seriesByExam.map((s) => (
              <option key={s.test_series_id} value={s.test_series_id}>
                {s.series_name}
              </option>
            ))}
          </select>

          <label style={{ fontSize: 12, color: '#6b7280' }}>Display Order</label>
          <input className='kap-input' value={displayOrder} onChange={(e) => setDisplayOrder(e.target.value)} />
        </div>

        <button className='kap-btn kap-btn-primary' onClick={() => void createMock()}>
          Create New Mock Test
        </button>
      </div>

      <div className='kap-card' style={{ maxWidth: 980, display: 'grid', gap: 10 }}>
        <p style={{ fontWeight: 700, marginBottom: 0 }}>Question Bank to Mock Import</p>
        <p style={{ fontSize: 12, color: '#6b7280', margin: 0 }}>
          Flow: Subject to Chapter to Quiz to Questions list. Questions only after quiz selection.
        </p>

        <label style={{ fontSize: 12, color: '#6b7280' }}>Target Mock</label>
        <select className='kap-input' value={importMockId} onChange={(e) => setImportMockId(e.target.value)}>
          <option value=''>Select Mock</option>
          {mocksByExam.map((m) => (
            <option key={m.mock_test_id} value={m.mock_test_id}>
              {m.mock_name}
            </option>
          ))}
        </select>

        <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 1fr 1fr' }}>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Subject (kls_subjects)</label>
            <select
              className='kap-input'
              value={selectedSubjectId}
              onChange={(e) => {
                setSelectedSubjectId(e.target.value)
                setSelectedQuestionIds([])
              }}
            >
              <option value=''>Select Subject</option>
              {subjectRows.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.subject_code ?? '-'})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Chapter (kls_chapters)</label>
            <select
              className='kap-input'
              value={selectedChapterCode}
              onChange={(e) => {
                setSelectedChapterCode(e.target.value)
                setSelectedQuestionIds([])
              }}
            >
              <option value=''>Select Chapter</option>
              {chapterRows.map((c) => (
                <option key={c.id} value={c.chapter_code}>
                  {c.name} ({c.chapter_code})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Quiz (kls_quizzes)</label>
            <select
              className='kap-input'
              value={selectedQuizId}
              onChange={(e) => {
                setSelectedQuizId(e.target.value)
                setSelectedQuestionIds([])
              }}
            >
              <option value=''>Select Quiz</option>
              {quizRows.map((q) => (
                <option key={q.quiz_id} value={q.quiz_id}>
                  {q.quiz_name}{q.is_active ? '' : ' [Inactive]'}
                </option>
              ))}
            </select>
          </div>
        </div>

        <label style={{ fontSize: 12, color: '#6b7280' }}>Search Question Text</label>
        <div style={{ display: 'flex', gap: 8 }}>
          <input
            className='kap-input'
            value={questionSearch}
            onChange={(e) => setQuestionSearch(e.target.value)}
            placeholder='Search in question text...'
          />
          <button className='kap-btn kap-btn-outline' onClick={() => void loadQuestionBank()}>
            Search
          </button>
        </div>

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button className='kap-btn kap-btn-primary' onClick={() => void addSelectedQuestionsToMock(false)}>
            Add Selected (Append)
          </button>
          <button className='kap-btn kap-btn-outline' onClick={() => void addSelectedQuestionsToMock(true)}>
            Replace All and Add Selected
          </button>
          <button className='kap-btn kap-btn-outline' onClick={() => setSelectedQuestionIds([])}>
            Clear Selected
          </button>
        </div>

        <p style={{ fontSize: 12, color: '#475569', margin: 0 }}>
          Selected: <b>{selectedQuestionIds.length}</b>
        </p>

        {selectedQuestionIds.length > 0 ? (
          <div style={{ border: '1px solid #cbd5e1', borderRadius: 8, padding: 8, background: '#f8fafc' }}>
            <p style={{ margin: 0, fontWeight: 700, fontSize: 13 }}>
              Selected Questions Preview ({selectedQuestionIds.length})
            </p>
            <div style={{ marginTop: 6, display: 'grid', gap: 4 }}>
              {selectedQuestionIds.map((qid, idx) => {
                const q = questionBankRows.find((x) => String(x['id'] ?? '') === qid)
                return (
                  <div key={qid} style={{ fontSize: 13, color: '#334155' }}>
                    <b>#{idx + 1}</b> {String(q?.['question'] ?? qid)}
                  </div>
                )
              })}
            </div>
          </div>
        ) : null}

        <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10, display: 'grid', gap: 8 }}>
          {questionBankLoading ? <p>Question bank loading...</p> : null}
          {!questionBankLoading && !selectedQuizId ? <p>Pehla quiz select karo.</p> : null}
          {!questionBankLoading && selectedQuizId && questionBankRows.length === 0 ? <p>No questions found in selected quiz.</p> : null}

          {!questionBankLoading && questionBankRows.map((q) => {
            const id = String(q['id'] ?? '')
            const checked = selectedQuestionIds.includes(id)
            const seq = checked ? selectedQuestionIds.indexOf(id) + 1 : 0
            const optionsExpanded = expandedOptionQuestionIds.includes(id)
            return (
              <label
                key={id}
                style={{
                  display: 'grid',
                  gap: 6,
                  border: '1px solid #e2e8f0',
                  borderRadius: 8,
                  padding: 8,
                  background: checked ? '#f0f9ff' : '#fff',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type='checkbox'
                    checked={checked}
                    onChange={(e) => toggleQuestionSelection(id, e.target.checked)}
                  />
                  <span style={{ fontWeight: 700, fontSize: 13 }}>
                    {checked ? `#${seq}` : 'Select'}
                  </span>
                  <button
                    type='button'
                    className='kap-btn kap-btn-outline'
                    style={{ marginLeft: 'auto', padding: '4px 10px', fontSize: 12 }}
                    onClick={(e) => {
                      e.preventDefault()
                      toggleQuestionOptions(id)
                    }}
                  >
                    {optionsExpanded ? 'Hide Options' : 'Show Options'}
                  </button>
                </div>
                <div style={{ fontSize: 17, lineHeight: 1.5, fontWeight: 600 }}>
                  {renderHtmlOrText(String(q['question'] ?? ''))}
                </div>
                <div style={{ fontSize: 13, color: '#0f766e', fontWeight: 700 }}>
                  Right Answer: {String(q['correct_answer'] ?? '-')}
                </div>
                {optionsExpanded ? (
                  <div style={{ fontSize: 14, color: '#334155', display: 'grid', gap: 4 }}>
                    <div>A. {renderHtmlOrText(String(q['option_a'] ?? ''))}</div>
                    <div>B. {renderHtmlOrText(String(q['option_b'] ?? ''))}</div>
                    <div>C. {renderHtmlOrText(String(q['option_c'] ?? ''))}</div>
                    <div>D. {renderHtmlOrText(String(q['option_d'] ?? ''))}</div>
                    {String(q['option_e'] ?? '').trim()
                      ? <div>E. {renderHtmlOrText(String(q['option_e'] ?? ''))}</div>
                      : null}
                  </div>
                ) : null}
              </label>
            )
          })}
        </div>
      </div>
    </main>
  )
}
