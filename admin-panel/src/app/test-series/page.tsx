'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type ExamRow = {
  exam_code: string
  exam_name: string
}

type SeriesRow = {
  test_series_id: string
  exam_code: string
  series_name: string
  series_description: string | null
  series_price: number
  is_active: boolean
  is_visible: boolean
}

type MockRow = {
  mock_test_id: string
  exam_code: string
  mock_name: string
  mock_details: string | null
  engine_type: string
  negative_mark: number
  duration_minutes: number
  total_questions: number
  is_active: boolean
  is_live: boolean
  is_paused: boolean
}

type SeriesMockMapRow = {
  test_series_id: string
  mock_test_id: string
  display_order: number
  kls_mock_tests: {
    mock_name?: string
    is_active: boolean
    is_live: boolean
    is_paused: boolean
  } | null
}

type SeriesMockMapApiRow = {
  test_series_id: string
  mock_test_id: string
  display_order: number
  kls_mock_tests:
    | {
        mock_name?: string
        is_active: boolean
        is_live: boolean
        is_paused: boolean
      }
    | {
        mock_name?: string
        is_active: boolean
        is_live: boolean
        is_paused: boolean
      }[]
    | null
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

type SeriesFilter = 'all' | 'active' | 'inactive' | 'live_active'
type EditableField = 'exam_code' | 'series_name' | 'series_description' | 'series_price'
type BankQuestion = Record<string, unknown>

const FILTER_LABELS: Record<SeriesFilter, string> = {
  all: 'All Series',
  active: 'Active Series',
  inactive: 'Inactive Series',
  live_active: 'Live (Active Mock)',
}

export default function TestSeriesPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [exams, setExams] = useState<ExamRow[]>([])
  const [seriesRows, setSeriesRows] = useState<SeriesRow[]>([])
  const [mocks, setMocks] = useState<MockRow[]>([])
  const [questionBankRows, setQuestionBankRows] = useState<BankQuestion[]>([])
  const [questionBankLoading, setQuestionBankLoading] = useState(false)
  const [subjectRows, setSubjectRows] = useState<SubjectRow[]>([])
  const [chapterRows, setChapterRows] = useState<ChapterRow[]>([])
  const [quizRows, setQuizRows] = useState<QuizRow[]>([])

  const [examCode, setExamCode] = useState('GPSC')
  const [seriesName, setSeriesName] = useState('')
  const [seriesDescription, setSeriesDescription] = useState('')
  const [seriesPrice, setSeriesPrice] = useState('')

  const [mapSeriesId, setMapSeriesId] = useState('')
  const [mapMockId, setMapMockId] = useState('')
  const [mapDisplayOrder, setMapDisplayOrder] = useState('1')
  const [importMockId, setImportMockId] = useState('')
  const [questionSearch, setQuestionSearch] = useState('')
  const [selectedSubjectId, setSelectedSubjectId] = useState('')
  const [selectedChapterCode, setSelectedChapterCode] = useState('')
  const [selectedQuizId, setSelectedQuizId] = useState('')
  const [selectedQuestionIds, setSelectedQuestionIds] = useState<string[]>([])
  const [defaultSubjectId, setDefaultSubjectId] = useState('GEN')
  const [defaultSubjectName, setDefaultSubjectName] = useState('General')
  const [defaultChapterCode, setDefaultChapterCode] = useState('GENERAL')
  const [defaultChapterName, setDefaultChapterName] = useState('General')

  const [seriesFilter, setSeriesFilter] = useState<SeriesFilter>('all')
  const [seriesHasLiveMap, setSeriesHasLiveMap] = useState<Record<string, boolean>>({})
  const [seriesMockCounts, setSeriesMockCounts] = useState<Record<string, number>>({})
  const [seriesMockLinks, setSeriesMockLinks] = useState<SeriesMockMapRow[]>([])

  const [editingSeriesId, setEditingSeriesId] = useState<string | null>(null)
  const [editingField, setEditingField] = useState<EditableField | null>(null)
  const [deleteArmedSeriesId, setDeleteArmedSeriesId] = useState<string | null>(null)
  const [deleteConfirmText, setDeleteConfirmText] = useState('')
  const [editDraft, setEditDraft] = useState({
    exam_code: '',
    series_name: '',
    series_description: '',
    series_price: '',
  })

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

    const [eRes, sRes, mRes, mapRes] = await Promise.all([
      supabase.from('kls_exams').select('exam_code,exam_name').order('sort_order'),
      supabase.from('kls_test_series').select('*').order('created_at', { ascending: false }),
      supabase
        .from('kls_mock_tests')
        .select(
          'mock_test_id,exam_code,mock_name,mock_details,engine_type,negative_mark,duration_minutes,total_questions,is_active,is_live,is_paused'
        )
        .order('created_at', { ascending: false }),
      supabase
        .from('kls_test_series_mocks')
        .select('test_series_id,mock_test_id,display_order,kls_mock_tests(mock_name,is_active,is_live,is_paused)'),
    ])

    if (eRes.error || sRes.error || mRes.error || mapRes.error) {
      setMsg(
        eRes.error?.message ??
          sRes.error?.message ??
          mRes.error?.message ??
          mapRes.error?.message ??
          'Load error'
      )
      setLoading(false)
      return
    }

    const eRows = (eRes.data ?? []) as ExamRow[]
    const sRows = (sRes.data ?? []) as SeriesRow[]
    const mRows = (mRes.data ?? []) as MockRow[]
    const mappingApiRows = (mapRes.data ?? []) as SeriesMockMapApiRow[]
    const mappingRows = mappingApiRows.map((row) => ({
      test_series_id: row.test_series_id,
      mock_test_id: row.mock_test_id,
      display_order: row.display_order,
      kls_mock_tests: Array.isArray(row.kls_mock_tests)
        ? (row.kls_mock_tests[0] ?? null)
        : row.kls_mock_tests,
    })) as SeriesMockMapRow[]

    const liveMap: Record<string, boolean> = {}
    for (const row of mappingRows) {
      const sid = row.test_series_id
      const mk = row.kls_mock_tests
      if (!sid || !mk) continue
      if (mk.is_active === true && mk.is_live === true && mk.is_paused === false) {
        liveMap[sid] = true
      }
    }
    const countMap: Record<string, number> = {}
    for (const row of mappingRows) {
      if (!row.test_series_id) continue
      countMap[row.test_series_id] = (countMap[row.test_series_id] ?? 0) + 1
    }

    setExams(eRows)
    setSeriesRows(sRows)
    setMocks(mRows)
    setSeriesHasLiveMap(liveMap)
    setSeriesMockCounts(countMap)
    setSeriesMockLinks(mappingRows)

    if (!examCode && eRows.length > 0) {
      setExamCode(eRows[0].exam_code)
    }

    setLoading(false)
  }

  async function createSeries() {
    const price = Number(seriesPrice)
    if (!examCode || !seriesName.trim() || !Number.isFinite(price)) {
      setMsg('Exam, Series Name, Price required.')
      return
    }

    const { error } = await supabase.from('kls_test_series').insert({
      exam_code: examCode,
      series_name: seriesName.trim(),
      series_description: seriesDescription.trim() || null,
      series_price: price,
      currency_code: 'INR',
      is_active: true,
      is_visible: true,
    })

    if (error) {
      setMsg(error.message)
      return
    }

    setSeriesName('')
    setSeriesDescription('')
    setSeriesPrice('')
    setMsg('Series created.')
    await loadData()
  }

  async function mapMock() {
    if (!mapSeriesId || !mapMockId) {
      setMsg('Select series and mock.')
      return
    }

    const displayOrder = Number(mapDisplayOrder)
    if (!Number.isFinite(displayOrder) || displayOrder <= 0) {
      setMsg('Display order must be 1,2,3...')
      return
    }

    const { error } = await supabase
      .from('kls_test_series_mocks')
      .upsert({ test_series_id: mapSeriesId, mock_test_id: mapMockId, display_order: displayOrder })

    if (error) {
      setMsg(error.message)
      return
    }

    setMsg('Mock mapped successfully.')
    await loadData()
  }

  async function loadQuestionBank() {
    setQuestionBankLoading(true)
    setMsg('')

    if (!selectedQuizId) {
      setQuestionBankRows([])
      setQuestionBankLoading(false)
      return
    }

    let query = supabase.from('kls_questions').select('*').order('created_at', { ascending: false }).limit(200)
    query = query.eq('quiz_id', selectedQuizId)
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

  async function loadSubjects() {
    const { data, error } = await supabase
      .from('kls_subjects')
      .select('id,name,subject_code')
      .order('created_at')

    if (error) {
      setMsg(error.message)
      setSubjectRows([])
      return
    }

    const rows = (data ?? []) as SubjectRow[]
    setSubjectRows(rows)
    if (rows.length > 0 && !selectedSubjectId) {
      setSelectedSubjectId(rows[0].id)
    }
  }

  async function loadChaptersForSubject(subjectId: string) {
    if (!subjectId) {
      setChapterRows([])
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
      return
    }

    const rows = (data ?? []) as ChapterRow[]
    setChapterRows(rows)
    setSelectedChapterCode(rows[0]?.chapter_code ?? '')
  }

  async function loadQuizzesForChapter(chapterCode: string) {
    if (!chapterCode) {
      setQuizRows([])
      return
    }

    const { data, error } = await supabase
      .from('kls_quizzes')
      .select('quiz_id,quiz_name,chapter_code,is_active')
      .eq('chapter_code', chapterCode)
      .eq('is_active', true)
      .order('created_at')

    if (error) {
      setMsg(error.message)
      setQuizRows([])
      return
    }

    const rows = (data ?? []) as QuizRow[]
    setQuizRows(rows)
    setSelectedQuizId(rows[0]?.quiz_id ?? '')
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

  async function addSelectedQuestionsToMock(resetExisting: boolean) {
    if (!importMockId) {
      setMsg('Import mate mock select karo.')
      return
    }
    if (selectedQuestionIds.length === 0) {
      setMsg('Pehla questions select karo.')
      return
    }

    const { data, error } = await supabase.rpc('kls_admin_add_questions_to_mock', {
      p_mock_test_id: importMockId,
      p_question_ids: selectedQuestionIds,
      p_default_subject_id: defaultSubjectId.trim() || 'GEN',
      p_default_subject_name: defaultSubjectName.trim() || 'General',
      p_default_chapter_code: defaultChapterCode.trim() || 'GENERAL',
      p_default_chapter_name: defaultChapterName.trim() || 'General',
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

  async function toggleSeries(row: SeriesRow, key: 'is_active' | 'is_visible') {
    const { error } = await supabase
      .from('kls_test_series')
      .update({ [key]: !row[key] })
      .eq('test_series_id', row.test_series_id)

    if (error) {
      setMsg(error.message)
      return
    }

    await loadData()
  }

  async function deleteSeries(row: SeriesRow) {
    if (deleteConfirmText.trim().toUpperCase() !== 'DELETE') {
      setMsg('Delete karva mate confirmation box ma DELETE lakho.')
      return
    }

    // First remove mappings, then series delete
    const mapDelete = await supabase
      .from('kls_test_series_mocks')
      .delete()
      .eq('test_series_id', row.test_series_id)

    if (mapDelete.error) {
      setMsg(mapDelete.error.message)
      return
    }

    const seriesDelete = await supabase
      .from('kls_test_series')
      .delete()
      .eq('test_series_id', row.test_series_id)

    if (seriesDelete.error) {
      setMsg(
        `${seriesDelete.error.message} | Jo purchase/access/history sathe linked hoy to pehla inactive + hidden karo.`
      )
      return
    }

    setDeleteArmedSeriesId(null)
    setDeleteConfirmText('')
    setMsg('Series permanently deleted from DB.')
    await loadData()
  }

  async function toggleMock(row: MockRow, key: 'is_live' | 'is_paused' | 'is_active') {
    const patch = { [key]: !row[key] } as Record<string, boolean>

    if (key === 'is_live' && !row.is_live) patch.is_paused = false
    if (key === 'is_paused' && !row.is_paused) patch.is_live = true

    const { error } = await supabase.from('kls_mock_tests').update(patch).eq('mock_test_id', row.mock_test_id)

    if (error) {
      setMsg(error.message)
      return
    }

    await loadData()
  }

  function startInlineEdit(row: SeriesRow) {
    setEditingSeriesId(row.test_series_id)
    setEditingField(null)
    setEditDraft({
      exam_code: row.exam_code,
      series_name: row.series_name,
      series_description: row.series_description ?? '',
      series_price: String(row.series_price),
    })
  }

  async function saveInlineField(seriesId: string, field: EditableField) {
    const updates: Record<string, string | number | null> = {}

    if (field === 'exam_code') updates.exam_code = editDraft.exam_code.trim().toUpperCase()
    if (field === 'series_name') updates.series_name = editDraft.series_name.trim()
    if (field === 'series_description') updates.series_description = editDraft.series_description.trim() || null
    if (field === 'series_price') {
      const n = Number(editDraft.series_price)
      if (!Number.isFinite(n)) {
        setMsg('Price number j hovu joie.')
        return
      }
      updates.series_price = n
    }

    const { error } = await supabase
      .from('kls_test_series')
      .update(updates)
      .eq('test_series_id', seriesId)

    if (error) {
      setMsg(error.message)
      return
    }

    setMsg('Field updated.')
    setEditingField(null)
    await loadData()
  }

  useEffect(() => {
    void loadData()
    logAdminPageView('test_series')
  }, [])

  useEffect(() => {
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

  const filteredMocks = useMemo(() => mocks.filter((m) => m.exam_code === examCode), [mocks, examCode])

  const filteredSeriesRows = useMemo(() => {
    return seriesRows.filter((r) => {
      if (r.exam_code !== examCode) return false
      if (seriesFilter === 'all') return true
      if (seriesFilter === 'active') return r.is_active
      if (seriesFilter === 'inactive') return !r.is_active
      if (seriesFilter === 'live_active') return r.is_active && seriesHasLiveMap[r.test_series_id] === true
      return true
    })
  }, [seriesRows, seriesFilter, seriesHasLiveMap, examCode])

  const leftPanelSeriesRows = useMemo(
    () => seriesRows.filter((s) => s.exam_code === examCode),
    [seriesRows, examCode]
  )

  useEffect(() => {
    if (!filteredMocks.length) {
      setImportMockId('')
      return
    }
    if (!filteredMocks.some((m) => m.mock_test_id === importMockId)) {
      setImportMockId(filteredMocks[0].mock_test_id)
    }
  }, [filteredMocks, importMockId])

  const filterCounts = useMemo(() => {
    const examSeries = seriesRows.filter((r) => r.exam_code === examCode)
    return {
      all: examSeries.length,
      active: examSeries.filter((r) => r.is_active).length,
      inactive: examSeries.filter((r) => !r.is_active).length,
      live_active: examSeries.filter(
        (r) => r.is_active && seriesHasLiveMap[r.test_series_id] === true
      ).length,
    } satisfies Record<SeriesFilter, number>
  }, [seriesRows, examCode, seriesHasLiveMap])

  const filteredControlMocks = useMemo(() => {
    return filteredMocks.filter((m) => {
      if (seriesFilter === 'all') return true
      if (seriesFilter === 'active') return m.is_active
      if (seriesFilter === 'inactive') return !m.is_active
      if (seriesFilter === 'live_active') return m.is_active && m.is_live && !m.is_paused
      return true
    })
  }, [filteredMocks, seriesFilter])
  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Test Series Manager</h1>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Link href='/test-series/new-mock' className='kap-btn kap-btn-primary'>Create New Mock Test</Link>
          <Link href='/test-series/all-questions' className='kap-btn kap-btn-outline'>All Questions</Link>
          <Link href='/' className='kap-subtle-link'>Back</Link>
        </div>
      </div>

      {role ? (
        <p style={{ marginBottom: 8 }}>
          Role: <span className='kap-chip'>{role}</span>
        </p>
      ) : null}

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      <div style={{ display: 'grid', gridTemplateColumns: '330px 1fr', gap: 12, alignItems: 'start' }}>
        <div className='kap-card' style={{ display: 'grid', gap: 14 }}>
          <div>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Filter Menu</p>
            <p style={{ fontSize: 12, color: '#6b7280', marginBottom: 8 }}>
              Current tab: <b>{FILTER_LABELS[seriesFilter]}</b>
            </p>
            <div style={{ display: 'grid', gap: 8 }}>
              {(['all', 'active', 'inactive', 'live_active'] as SeriesFilter[]).map((f) => (
                <button
                  key={f}
                  className='kap-btn kap-btn-outline'
                  style={
                    seriesFilter === f
                      ? { borderColor: '#3b82f6', background: '#eff6ff', color: '#1d4ed8', fontWeight: 700 }
                      : undefined
                  }
                  onClick={() => setSeriesFilter(f)}
                >
                  <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%' }}>
                    <span>{FILTER_LABELS[f]}</span>
                    <span
                      style={{
                        minWidth: 24,
                        borderRadius: 999,
                        padding: '2px 8px',
                        fontSize: 12,
                        border: '1px solid #d1d5db',
                        background: seriesFilter === f ? '#dbeafe' : '#f8fafc',
                        color: seriesFilter === f ? '#1d4ed8' : '#111827',
                        textAlign: 'center',
                      }}
                    >
                      {filterCounts[f]}
                    </span>
                  </span>
                </button>
              ))}
            </div>
          </div>

          <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10 }}>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Create Series</p>
            <div style={{ display: 'grid', gap: 8 }}>
              <label style={{ fontSize: 12, color: '#6b7280' }}>Exam (exam_code)</label>
              <select className='kap-input' value={examCode} onChange={(e) => setExamCode(e.target.value)}>
                {exams.map((e) => (
                  <option key={e.exam_code} value={e.exam_code}>
                    {e.exam_name} ({e.exam_code})
                  </option>
                ))}
              </select>

              <label style={{ fontSize: 12, color: '#6b7280' }}>Series Name (series_name)</label>
              <input className='kap-input' value={seriesName} onChange={(e) => setSeriesName(e.target.value)} />

              <label style={{ fontSize: 12, color: '#6b7280' }}>Series Description (series_description)</label>
              <input className='kap-input' value={seriesDescription} onChange={(e) => setSeriesDescription(e.target.value)} />

              <label style={{ fontSize: 12, color: '#6b7280' }}>Price INR (series_price)</label>
              <input className='kap-input' value={seriesPrice} onChange={(e) => setSeriesPrice(e.target.value)} />

              <button className='kap-btn kap-btn-primary' onClick={createSeries}>Create</button>
            </div>
          </div>

          <div style={{ borderTop: '1px solid #e5e7eb', paddingTop: 10 }}>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Create Mapping (Series to Mock)</p>
            <div style={{ display: 'grid', gap: 8 }}>
              <label style={{ fontSize: 12, color: '#6b7280' }}>Series (test_series_id)</label>
              <select className='kap-input' value={mapSeriesId} onChange={(e) => setMapSeriesId(e.target.value)}>
                <option value=''>Select Series</option>
                {leftPanelSeriesRows.map((s) => (
                  <option key={s.test_series_id} value={s.test_series_id}>
                    {s.series_name}
                  </option>
                ))}
              </select>
              {mapSeriesId ? (
                <p style={{ margin: 0, fontSize: 12, color: '#475569' }}>
                  Selected series ma total mocks: <b>{seriesMockCounts[mapSeriesId] ?? 0}</b>
                </p>
              ) : null}

              <label style={{ fontSize: 12, color: '#6b7280' }}>Mock (mock_test_id)</label>
              <select className='kap-input' value={mapMockId} onChange={(e) => setMapMockId(e.target.value)}>
                <option value=''>Select Mock</option>
                {filteredMocks.map((m) => (
                  <option key={m.mock_test_id} value={m.mock_test_id}>
                    {m.mock_name}
                  </option>
                ))}
              </select>

              <label style={{ fontSize: 12, color: '#6b7280' }}>Display Order (display_order)</label>
              <input className='kap-input' value={mapDisplayOrder} onChange={(e) => setMapDisplayOrder(e.target.value)} />

              <button className='kap-btn kap-btn-primary' onClick={mapMock}>Add Mock to Series</button>

              {mapSeriesId ? (
                <div style={{ border: '1px solid #e2e8f0', borderRadius: 8, padding: 8, background: '#f8fafc' }}>
                  <p style={{ margin: 0, fontWeight: 700, fontSize: 12 }}>
                    Mapped mocks in selected series
                  </p>
                  <div style={{ marginTop: 6, display: 'grid', gap: 4 }}>
                    {seriesMockLinks
                      .filter((x) => x.test_series_id === mapSeriesId)
                      .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0))
                      .map((x) => (
                        <div key={`${x.test_series_id}:${x.mock_test_id}`} style={{ fontSize: 12, color: '#334155' }}>
                          #{x.display_order ?? 0} {x.kls_mock_tests?.mock_name ?? x.mock_test_id}
                        </div>
                      ))}
                    {(seriesMockCounts[mapSeriesId] ?? 0) === 0 ? (
                      <div style={{ fontSize: 12, color: '#64748b' }}>No mapped mock yet.</div>
                    ) : null}
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        </div>

        <div style={{ display: 'grid', gap: 12 }}>
          <div className='kap-card'>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Test Series List ({filteredSeriesRows.length})</p>
            <p style={{ fontSize: 12, color: '#6b7280', marginBottom: 8 }}>
              Active = app ma series dekhay (jo visible pan true hoy). Inactive = app ma hidden. Field par click karso to niche edit input khulse (popup nathi).
            </p>

            <div className='kap-grid'>
              {filteredSeriesRows.map((r) => {
                const isEditingThis = editingSeriesId === r.test_series_id

                return (
                  <div key={r.test_series_id} className='kap-card'>
                    <p>
                      <b>{r.series_name}</b> ({r.exam_code})
                    </p>
                    <p style={{ fontSize: 13, color: '#6b7280' }}>{r.series_description ?? '-'}</p>
                    <p>Price: Rs.{Number(r.series_price).toFixed(2)}</p>
                    <p>
                      Active: <span className='kap-chip'>{r.is_active ? 'Yes' : 'No'}</span> | Visible:{' '}
                      <span className='kap-chip'>{r.is_visible ? 'Yes' : 'No'}</span> | Live Mock:{' '}
                      <span className='kap-chip'>{seriesHasLiveMap[r.test_series_id] ? 'Yes' : 'No'}</span>
                    </p>

                    <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                      <button className='kap-btn kap-btn-outline' onClick={() => startInlineEdit(r)}>
                        {isEditingThis ? 'Editing Open' : 'Edit'}
                      </button>
                      <button className='kap-btn kap-btn-outline' onClick={() => toggleSeries(r, 'is_active')}>
                        {r.is_active ? 'Make Inactive' : 'Make Active'}
                      </button>
                      <button className='kap-btn kap-btn-outline' onClick={() => toggleSeries(r, 'is_visible')}>
                        {r.is_visible ? 'Hide from App' : 'Show in App'}
                      </button>
                      <button
                        className='kap-btn kap-btn-outline'
                        style={{ borderColor: '#ef4444', color: '#ef4444' }}
                        onClick={() => {
                          setDeleteArmedSeriesId((prev) =>
                            prev === r.test_series_id ? null : r.test_series_id
                          )
                          setDeleteConfirmText('')
                        }}
                      >
                        Delete Series
                      </button>
                    </div>

                    {isEditingThis ? (
                      <div style={{ marginTop: 10, borderTop: '1px solid #e5e7eb', paddingTop: 10, display: 'grid', gap: 8 }}>
                        <button className='kap-btn kap-btn-outline' onClick={() => setEditingField('exam_code')}>
                          exam_code: {editDraft.exam_code || '-'}
                        </button>
                        {editingField === 'exam_code' ? (
                          <div style={{ display: 'flex', gap: 8 }}>
                            <input
                              className='kap-input'
                              value={editDraft.exam_code}
                              onChange={(e) => setEditDraft((d) => ({ ...d, exam_code: e.target.value }))}
                            />
                            <button className='kap-btn kap-btn-primary' onClick={() => saveInlineField(r.test_series_id, 'exam_code')}>
                              Save
                            </button>
                          </div>
                        ) : null}

                        <button className='kap-btn kap-btn-outline' onClick={() => setEditingField('series_name')}>
                          series_name: {editDraft.series_name || '-'}
                        </button>
                        {editingField === 'series_name' ? (
                          <div style={{ display: 'flex', gap: 8 }}>
                            <input
                              className='kap-input'
                              value={editDraft.series_name}
                              onChange={(e) => setEditDraft((d) => ({ ...d, series_name: e.target.value }))}
                            />
                            <button className='kap-btn kap-btn-primary' onClick={() => saveInlineField(r.test_series_id, 'series_name')}>
                              Save
                            </button>
                          </div>
                        ) : null}

                        <button className='kap-btn kap-btn-outline' onClick={() => setEditingField('series_description')}>
                          series_description: {editDraft.series_description || '-'}
                        </button>
                        {editingField === 'series_description' ? (
                          <div style={{ display: 'flex', gap: 8 }}>
                            <input
                              className='kap-input'
                              value={editDraft.series_description}
                              onChange={(e) => setEditDraft((d) => ({ ...d, series_description: e.target.value }))}
                            />
                            <button
                              className='kap-btn kap-btn-primary'
                              onClick={() => saveInlineField(r.test_series_id, 'series_description')}
                            >
                              Save
                            </button>
                          </div>
                        ) : null}

                        <button className='kap-btn kap-btn-outline' onClick={() => setEditingField('series_price')}>
                          series_price: {editDraft.series_price || '-'}
                        </button>
                        {editingField === 'series_price' ? (
                          <div style={{ display: 'flex', gap: 8 }}>
                            <input
                              className='kap-input'
                              value={editDraft.series_price}
                              onChange={(e) => setEditDraft((d) => ({ ...d, series_price: e.target.value }))}
                            />
                            <button className='kap-btn kap-btn-primary' onClick={() => saveInlineField(r.test_series_id, 'series_price')}>
                              Save
                            </button>
                          </div>
                        ) : null}

                        <button
                          className='kap-btn kap-btn-outline'
                          onClick={() => {
                            setEditingSeriesId(null)
                            setEditingField(null)
                          }}
                        >
                          Close Edit
                        </button>
                      </div>
                    ) : null}

                    {deleteArmedSeriesId === r.test_series_id ? (
                      <div
                        style={{
                          marginTop: 10,
                          borderTop: '1px solid #fecaca',
                          paddingTop: 10,
                          display: 'grid',
                          gap: 8,
                        }}
                      >
                        <p style={{ fontSize: 12, color: '#b91c1c', margin: 0 }}>
                          Permanent delete: aa series DB mathi delete thai jashe.
                        </p>
                        <label style={{ fontSize: 12, color: '#6b7280' }}>
                          Confirm mate <b>DELETE</b> lakho:
                        </label>
                        <input
                          className='kap-input'
                          value={deleteConfirmText}
                          onChange={(e) => setDeleteConfirmText(e.target.value)}
                          placeholder='Type DELETE'
                        />
                        <div style={{ display: 'flex', gap: 8 }}>
                          <button
                            className='kap-btn kap-btn-outline'
                            style={{ borderColor: '#ef4444', color: '#ef4444' }}
                            onClick={() => void deleteSeries(r)}
                          >
                            Confirm Delete
                          </button>
                          <button
                            className='kap-btn kap-btn-outline'
                            onClick={() => {
                              setDeleteArmedSeriesId(null)
                              setDeleteConfirmText('')
                            }}
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : null}
                  </div>
                )
              })}
              {!loading && filteredSeriesRows.length === 0 ? <p>No series in selected filter.</p> : null}
            </div>
          </div>
          <div className='kap-card'>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Question Import</p>
            <p style={{ fontSize: 13, color: '#6b7280', margin: 0 }}>
              Question import flow ne "Create New Mock Test" page par move karyu chhe.
            </p>
            <div style={{ marginTop: 8 }}>
              <Link href='/test-series/new-mock' className='kap-btn kap-btn-primary'>Open Create New Mock Test</Link>
            </div>
          </div>

          <div className='kap-card'>
            <p style={{ fontWeight: 700, marginBottom: 8 }}>Mock Live / Pause Controls</p>
            <p style={{ fontSize: 13, color: '#6b7280', marginBottom: 10 }}>
              DB fields: <code>is_live</code>, <code>is_paused</code>, <code>is_active</code>
            </p>

            <div className='kap-grid'>
              {filteredControlMocks.map((m) => (
                <div key={m.mock_test_id} className='kap-card' style={{ padding: 12 }}>
                  <p>
                    <b>{m.mock_name}</b> ({m.exam_code})
                  </p>
                  <p style={{ fontSize: 12, color: '#6b7280' }}>
                    Engine: {m.engine_type} | Neg: {m.negative_mark} | Duration: {m.duration_minutes} min | Q: {m.total_questions}
                  </p>
                  <p style={{ fontSize: 12 }}>
                    Active: <span className='kap-chip'>{m.is_active ? 'Yes' : 'No'}</span> | Live:{' '}
                    <span className='kap-chip'>{m.is_live ? 'Yes' : 'No'}</span> | Paused:{' '}
                    <span className='kap-chip'>{m.is_paused ? 'Yes' : 'No'}</span>
                  </p>
                  <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                    <button className='kap-btn kap-btn-outline' onClick={() => toggleMock(m, 'is_live')}>
                      {m.is_live ? 'Make Not Live' : 'Make Live'}
                    </button>
                    <button className='kap-btn kap-btn-outline' onClick={() => toggleMock(m, 'is_paused')}>
                      {m.is_paused ? 'Resume (Unpause)' : 'Pause'}
                    </button>
                    <button className='kap-btn kap-btn-outline' onClick={() => toggleMock(m, 'is_active')}>
                      {m.is_active ? 'Deactivate' : 'Activate'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}







