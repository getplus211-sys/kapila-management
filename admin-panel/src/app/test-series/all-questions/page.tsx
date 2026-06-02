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

type MockMini = {
  mock_test_id: string
  exam_code: string
  mock_name: string
  is_active: boolean
  is_live: boolean
  is_paused: boolean
} | null

type SeriesMockMapRow = {
  test_series_id: string
  mock_test_id: string
  display_order: number
  kls_mock_tests: MockMini
}

type SeriesMockMapApiRow = {
  test_series_id: string
  mock_test_id: string
  display_order: number
  kls_mock_tests: MockMini | MockMini[] | null
}

type MockQuestionRow = {
  mock_question_id: string
  mock_test_id: string
  question_order: number
  subject_id: string
  subject_name: string | null
  chapter_code: string
  chapter_name: string | null
  question_text: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  option_e: string | null
  correct_answer: string
  explanation: string | null
}

export default function AllQuestionsPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')

  const [exams, setExams] = useState<ExamRow[]>([])
  const [seriesRows, setSeriesRows] = useState<SeriesRow[]>([])
  const [mocks, setMocks] = useState<MockMini[]>([])
  const [seriesMockLinks, setSeriesMockLinks] = useState<SeriesMockMapRow[]>([])

  const [selectedExamCode, setSelectedExamCode] = useState('GPSC')
  const [selectedSeriesId, setSelectedSeriesId] = useState('')
  const [selectedMockId, setSelectedMockId] = useState('')

  const [mockQuestions, setMockQuestions] = useState<MockQuestionRow[]>([])
  const [questionLoading, setQuestionLoading] = useState(false)

  const [addMockId, setAddMockId] = useState('')
  const [addDisplayOrder, setAddDisplayOrder] = useState('1')

  function hasHtml(input: string): boolean {
    return /<[^>]+>/.test(input)
  }

  function renderHtmlOrText(input: string) {
    const text = input ?? ''
    if (!text.trim()) return <span>-</span>
    if (hasHtml(text)) return <span dangerouslySetInnerHTML={{ __html: text }} />
    return <span>{text}</span>
  }

  async function loadBase() {
    setLoading(true)
    setMsg('')

    const access = await getAdminAccess()
    setRole(access.role)
    if (!hasSalesAccess(access.role)) {
      setMsg('Access denied.')
      setLoading(false)
      return
    }

    const [eRes, sRes, mRes, mapRes] = await Promise.all([
      supabase.from('kls_exams').select('exam_code,exam_name').order('sort_order'),
      supabase.from('kls_test_series').select('test_series_id,exam_code,series_name').order('created_at', { ascending: false }),
      supabase
        .from('kls_mock_tests')
        .select('mock_test_id,exam_code,mock_name,is_active,is_live,is_paused')
        .order('created_at', { ascending: false }),
      supabase
        .from('kls_test_series_mocks')
        .select('test_series_id,mock_test_id,display_order,kls_mock_tests(mock_test_id,exam_code,mock_name,is_active,is_live,is_paused)'),
    ])

    if (eRes.error || sRes.error || mRes.error || mapRes.error) {
      setMsg(eRes.error?.message ?? sRes.error?.message ?? mRes.error?.message ?? mapRes.error?.message ?? 'Load error')
      setLoading(false)
      return
    }

    const eRows = (eRes.data ?? []) as ExamRow[]
    const sRows = (sRes.data ?? []) as SeriesRow[]
    const mRows = (mRes.data ?? []) as MockMini[]
    const mapApiRows = (mapRes.data ?? []) as SeriesMockMapApiRow[]
    const mapRows: SeriesMockMapRow[] = mapApiRows.map((row) => ({
      test_series_id: row.test_series_id,
      mock_test_id: row.mock_test_id,
      display_order: row.display_order,
      kls_mock_tests: Array.isArray(row.kls_mock_tests)
        ? (row.kls_mock_tests[0] ?? null)
        : row.kls_mock_tests,
    }))

    setExams(eRows)
    setSeriesRows(sRows)
    setMocks(mRows)
    setSeriesMockLinks(mapRows)

    if (!selectedExamCode && eRows.length > 0) setSelectedExamCode(eRows[0].exam_code)

    setLoading(false)
  }

  async function loadMockQuestions(mockId: string) {
    if (!mockId) {
      setMockQuestions([])
      return
    }

    setQuestionLoading(true)
    const { data, error } = await supabase
      .from('kls_mock_questions')
      .select('*')
      .eq('mock_test_id', mockId)
      .order('question_order')

    if (error) {
      setMsg(error.message)
      setMockQuestions([])
      setQuestionLoading(false)
      return
    }

    setMockQuestions((data ?? []) as MockQuestionRow[])
    setQuestionLoading(false)
  }

  async function saveQuestion(row: MockQuestionRow) {
    const { error } = await supabase
      .from('kls_mock_questions')
      .update({
        question_text: row.question_text,
        option_a: row.option_a,
        option_b: row.option_b,
        option_c: row.option_c,
        option_d: row.option_d,
        option_e: row.option_e,
        correct_answer: row.correct_answer.toUpperCase(),
        explanation: row.explanation,
      })
      .eq('mock_question_id', row.mock_question_id)

    if (error) {
      setMsg(error.message)
      return
    }

    setMsg(`Saved Q${row.question_order}`)
  }

  async function addMockToSeries() {
    if (!selectedSeriesId || !addMockId) {
      setMsg('Series and mock select karo.')
      return
    }

    const order = Number(addDisplayOrder)
    if (!Number.isFinite(order) || order <= 0) {
      setMsg('Display order valid number hovu joie.')
      return
    }

    const { error } = await supabase
      .from('kls_test_series_mocks')
      .upsert({
        test_series_id: selectedSeriesId,
        mock_test_id: addMockId,
        display_order: order,
      })

    if (error) {
      setMsg(error.message)
      return
    }

    setMsg('Mock added to selected series.')
    await loadBase()
  }

  useEffect(() => {
    void loadBase()
  }, [])

  const seriesByExam = useMemo(
    () => seriesRows.filter((s) => s.exam_code === selectedExamCode),
    [seriesRows, selectedExamCode]
  )

  useEffect(() => {
    if (!seriesByExam.length) {
      setSelectedSeriesId('')
      return
    }
    if (!seriesByExam.some((s) => s.test_series_id === selectedSeriesId)) {
      setSelectedSeriesId(seriesByExam[0].test_series_id)
    }
  }, [seriesByExam, selectedSeriesId])

  const mappedMocks = useMemo(
    () => seriesMockLinks
      .filter((x) => x.test_series_id === selectedSeriesId)
      .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0)),
    [seriesMockLinks, selectedSeriesId]
  )

  useEffect(() => {
    if (!mappedMocks.length) {
      setSelectedMockId('')
      return
    }
    if (!mappedMocks.some((x) => x.mock_test_id === selectedMockId)) {
      setSelectedMockId(mappedMocks[0].mock_test_id)
    }
  }, [mappedMocks, selectedMockId])

  useEffect(() => {
    void loadMockQuestions(selectedMockId)
  }, [selectedMockId])

  const availableMocksForExam = useMemo(
    () => mocks.filter((m) => m && m.exam_code === selectedExamCode) as Exclude<MockMini, null>[],
    [mocks, selectedExamCode]
  )

  useEffect(() => {
    if (!availableMocksForExam.length) {
      setAddMockId('')
      return
    }
    if (!availableMocksForExam.some((m) => m.mock_test_id === addMockId)) {
      setAddMockId(availableMocksForExam[0].mock_test_id)
    }
  }, [availableMocksForExam, addMockId])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>All Questions (Mock Wise)</h1>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Link href='/test-series/new-mock' className='kap-btn kap-btn-primary'>Create New Mock Test</Link>
          <Link href='/test-series' className='kap-subtle-link'>Back to Test Series</Link>
        </div>
      </div>

      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}
      {loading ? <p>Loading...</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}

      <div className='kap-card' style={{ display: 'grid', gap: 10, marginBottom: 12 }}>
        <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 1fr' }}>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Exam</label>
            <select className='kap-input' value={selectedExamCode} onChange={(e) => setSelectedExamCode(e.target.value)}>
              {exams.map((e) => (
                <option key={e.exam_code} value={e.exam_code}>
                  {e.exam_name} ({e.exam_code})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#6b7280' }}>Series</label>
            <select className='kap-input' value={selectedSeriesId} onChange={(e) => setSelectedSeriesId(e.target.value)}>
              {seriesByExam.map((s) => (
                <option key={s.test_series_id} value={s.test_series_id}>{s.series_name}</option>
              ))}
            </select>
          </div>
        </div>

        <p style={{ margin: 0, fontSize: 13 }}>
          Selected series ma total mocks: <b>{mappedMocks.length}</b>
        </p>

        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 8, background: '#f8fafc' }}>
          <p style={{ margin: 0, fontWeight: 700, fontSize: 13 }}>Mapped Mocks</p>
          <div style={{ marginTop: 6, display: 'grid', gap: 4 }}>
            {mappedMocks.map((x) => (
              <div key={`${x.test_series_id}:${x.mock_test_id}`} style={{ fontSize: 12, color: '#334155' }}>
                #{x.display_order} {x.kls_mock_tests?.mock_name ?? x.mock_test_id}
              </div>
            ))}
            {mappedMocks.length === 0 ? <div style={{ fontSize: 12, color: '#64748b' }}>No mapped mock.</div> : null}
          </div>
        </div>

        <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10, display: 'grid', gap: 8 }}>
          <p style={{ margin: 0, fontWeight: 700, fontSize: 13 }}>Add Mock to Selected Series</p>
          <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 120px auto' }}>
            <select className='kap-input' value={addMockId} onChange={(e) => setAddMockId(e.target.value)}>
              {availableMocksForExam.map((m) => (
                <option key={m.mock_test_id} value={m.mock_test_id}>{m.mock_name}</option>
              ))}
            </select>
            <input className='kap-input' value={addDisplayOrder} onChange={(e) => setAddDisplayOrder(e.target.value)} />
            <button className='kap-btn kap-btn-primary' onClick={() => void addMockToSeries()}>
              Add Mock
            </button>
          </div>
        </div>

        <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10 }}>
          <label style={{ fontSize: 12, color: '#6b7280' }}>Mock for Question Editing</label>
          <select className='kap-input' value={selectedMockId} onChange={(e) => setSelectedMockId(e.target.value)}>
            {mappedMocks.map((x) => (
              <option key={x.mock_test_id} value={x.mock_test_id}>
                #{x.display_order} {x.kls_mock_tests?.mock_name ?? x.mock_test_id}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className='kap-card'>
        <p style={{ fontWeight: 700, marginBottom: 8 }}>
          Questions in Selected Mock ({mockQuestions.length})
        </p>
        {questionLoading ? <p>Loading questions...</p> : null}
        {!questionLoading && mockQuestions.length === 0 ? <p>No questions in selected mock.</p> : null}

        <div style={{ display: 'grid', gap: 10 }}>
          {mockQuestions.map((q, idx) => (
            <div key={q.mock_question_id} className='kap-card' style={{ border: '1px solid #e2e8f0' }}>
              <p style={{ margin: 0, fontWeight: 700 }}>Q#{q.question_order} (Row {idx + 1})</p>
              <p style={{ margin: '4px 0', fontSize: 12, color: '#64748b' }}>
                Subject: {q.subject_name ?? q.subject_id} | Chapter: {q.chapter_name ?? q.chapter_code}
              </p>

              <div style={{ border: '1px solid #dbeafe', borderRadius: 8, background: '#f8fbff', padding: 8, marginBottom: 8 }}>
                <p style={{ margin: '0 0 6px 0', fontWeight: 700, fontSize: 12, color: '#1d4ed8' }}>Preview (HTML Render)</p>
                <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 6 }}>{renderHtmlOrText(q.question_text)}</div>
                <div style={{ fontSize: 13, display: 'grid', gap: 4, color: '#334155' }}>
                  <div>A. {renderHtmlOrText(q.option_a)}</div>
                  <div>B. {renderHtmlOrText(q.option_b)}</div>
                  <div>C. {renderHtmlOrText(q.option_c)}</div>
                  <div>D. {renderHtmlOrText(q.option_d)}</div>
                  {q.option_e?.trim() ? <div>E. {renderHtmlOrText(q.option_e)}</div> : null}
                </div>
                <div style={{ marginTop: 6, fontSize: 12, color: '#0f766e', fontWeight: 700 }}>
                  Right Answer: {q.correct_answer}
                </div>
                {q.explanation?.trim() ? (
                  <div style={{ marginTop: 6, fontSize: 13 }}>
                    <b>Solution:</b> {renderHtmlOrText(q.explanation)}
                  </div>
                ) : null}
              </div>

              <div style={{ display: 'grid', gap: 8 }}>
                <textarea
                  className='kap-input'
                  style={{ minHeight: 70 }}
                  value={q.question_text}
                  onChange={(e) => {
                    const v = e.target.value
                    setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, question_text: v } : x))
                  }}
                />
                <input className='kap-input' value={q.option_a} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, option_a: e.target.value } : x))} />
                <input className='kap-input' value={q.option_b} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, option_b: e.target.value } : x))} />
                <input className='kap-input' value={q.option_c} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, option_c: e.target.value } : x))} />
                <input className='kap-input' value={q.option_d} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, option_d: e.target.value } : x))} />
                <input className='kap-input' value={q.option_e ?? ''} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, option_e: e.target.value || null } : x))} placeholder='Option E (optional)' />
                <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '120px 1fr' }}>
                  <select className='kap-input' value={q.correct_answer} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, correct_answer: e.target.value } : x))}>
                    <option value='A'>A</option>
                    <option value='B'>B</option>
                    <option value='C'>C</option>
                    <option value='D'>D</option>
                    <option value='E'>E</option>
                  </select>
                  <input className='kap-input' value={q.explanation ?? ''} onChange={(e) => setMockQuestions((prev) => prev.map((x) => x.mock_question_id === q.mock_question_id ? { ...x, explanation: e.target.value || null } : x))} placeholder='Solution / Explanation' />
                </div>
                <button className='kap-btn kap-btn-primary' onClick={() => void saveQuestion(q)}>
                  Save This Question
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </main>
  )
}
