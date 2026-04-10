'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | null

type SuggestionRow = {
  id: string
  question: string | null
  option_a: string | null
  option_b: string | null
  option_c: string | null
  option_d: string | null
  option_e: string | null
  correct_answer: string | null
  solution: string | null
  difficulty_level: string | null
  suggestion: string | null
  created_at: string
}

type Draft = {
  question: string
  option_a: string
  option_b: string
  option_c: string
  option_d: string
  option_e: string
  correct_answer: string
  solution: string
  difficulty_level: string
}

export default function SuggestionsPage() {
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<Role>(null)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<SuggestionRow[]>([])
  const [drafts, setDrafts] = useState<Record<string, Draft>>({})
  const [savingId, setSavingId] = useState<string>('')
  const [expandedId, setExpandedId] = useState<string>('')

  function toDraft(r: SuggestionRow): Draft {
    return {
      question: r.question ?? '',
      option_a: r.option_a ?? '',
      option_b: r.option_b ?? '',
      option_c: r.option_c ?? '',
      option_d: r.option_d ?? '',
      option_e: r.option_e ?? '',
      correct_answer: r.correct_answer ?? '',
      solution: r.solution ?? '',
      difficulty_level: r.difficulty_level ?? '',
    }
  }

  async function loadSuggestions() {
    setLoading(true)
    setMsg('')
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) {
      setRole(null)
      setLoading(false)
      return
    }

    const { data: roleData, error: roleErr } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (roleErr || !roleData || roleData.is_active !== true) {
      setRole(null)
      setMsg(roleErr?.message ?? 'No admin access for this account.')
      setLoading(false)
      return
    }
    setRole((roleData.role as Role) ?? null)

    const { data, error } = await supabase
      .from('kls_questions')
      .select('id,question,option_a,option_b,option_c,option_d,option_e,correct_answer,solution,difficulty_level,suggestion,created_at')
      .not('suggestion', 'is', null)
      .neq('suggestion', '')
      .order('created_at', { ascending: false })
      .limit(300)

    if (error) {
      setMsg(error.message)
      setRows([])
    } else {
      const nextRows = (data ?? []) as SuggestionRow[]
      setRows(nextRows)
      const seenRows = nextRows.map((r) => ({
        admin_user_id: user.id,
        action_type: 'suggestion_seen',
        target_table: 'kls_questions',
        target_id: r.id,
        new_data: { seen: true },
      }))
      if (seenRows.length > 0) {
        await supabase.from('ngm_admin_actions_log').insert(seenRows)
      }
      const nextDrafts: Record<string, Draft> = {}
      for (const r of nextRows) nextDrafts[r.id] = toDraft(r)
      setDrafts(nextDrafts)
      if (nextRows.length > 0 && !expandedId) setExpandedId(nextRows[0].id)
    }
    setLoading(false)
  }

  useEffect(() => {
    loadSuggestions()
    logAdminPageView('suggestions')
  }, [])

  function setDraftField(id: string, key: keyof Draft, value: string) {
    setDrafts((prev) => ({
      ...prev,
      [id]: {
        ...(prev[id] ?? {
          question: '',
          option_a: '',
          option_b: '',
          option_c: '',
          option_d: '',
          option_e: '',
          correct_answer: '',
          solution: '',
          difficulty_level: '',
        }),
        [key]: value,
      },
    }))
  }

  async function saveQuestion(row: SuggestionRow) {
    const key = String(row.id)
    const d = drafts[key] ?? toDraft(row)
    if (!d.question.trim()) {
      alert('Question text required.')
      return
    }
    if (!d.option_a.trim() || !d.option_b.trim() || !d.option_c.trim() || !d.option_d.trim()) {
      alert('Option A/B/C/D required.')
      return
    }
    if (!d.correct_answer.trim()) {
      alert('Correct answer required.')
      return
    }

    setSavingId(key)
    const { data, error } = await supabase.rpc('ngm_admin_update_kls_question', {
      p_id: row.id,
      p_question: d.question,
      p_option_a: d.option_a,
      p_option_b: d.option_b,
      p_option_c: d.option_c,
      p_option_d: d.option_d,
      p_option_e: d.option_e,
      p_correct_answer: d.correct_answer,
      p_solution: d.solution,
      p_difficulty_level: d.difficulty_level,
      p_admin_note: 'Updated from admin suggestions panel',
    })
    if (!error) {
      await supabase
        .from('kls_questions')
        .update({ suggestion: null })
        .eq('id', row.id)
    }
    setSavingId('')

    if (error) {
      alert(error.message)
      return
    }

    alert(`Saved question: ${data?.id ?? row.id}`)
    await loadSuggestions()
  }

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Suggestions</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {loading ? <p>Loading...</p> : null}
      {!loading && !role ? <p style={{ color: '#b91c1c' }}>Access denied.</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {!loading && role && rows.length === 0 ? <p>No suggestions found in kls_questions.</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.id} className='kap-card'>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
              <p><b>Question ID:</b> {r.id}</p>
              <button
                onClick={() => setExpandedId((p) => (p === r.id ? '' : r.id))}
                className='kap-btn kap-btn-outline'
              >
                {expandedId === r.id ? 'Hide Editor' : 'Open Editor'}
              </button>
            </div>
            <p style={{ marginTop: 4 }}><b>Current:</b> {r.question ?? '-'}</p>
            <p style={{ marginTop: 4 }}><b>Suggestion:</b> {r.suggestion ?? '-'}</p>

            {expandedId === r.id ? (
              <div style={{ marginTop: 10, display: 'grid', gap: 8 }}>
                <textarea
                  value={r.suggestion ?? ''}
                  readOnly
                  placeholder='Suggested question text'
                  className='kap-input'
                  style={{ minHeight: 80, background: '#f8fafc' }}
                />
                <textarea
                  value={drafts[r.id]?.question ?? ''}
                  onChange={(e) => setDraftField(r.id, 'question', e.target.value)}
                  placeholder='Question'
                  className='kap-input'
                  style={{ minHeight: 80 }}
                />
                <input
                  value={drafts[r.id]?.option_a ?? ''}
                  onChange={(e) => setDraftField(r.id, 'option_a', e.target.value)}
                  placeholder='Option A'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.option_b ?? ''}
                  onChange={(e) => setDraftField(r.id, 'option_b', e.target.value)}
                  placeholder='Option B'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.option_c ?? ''}
                  onChange={(e) => setDraftField(r.id, 'option_c', e.target.value)}
                  placeholder='Option C'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.option_d ?? ''}
                  onChange={(e) => setDraftField(r.id, 'option_d', e.target.value)}
                  placeholder='Option D'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.option_e ?? ''}
                  onChange={(e) => setDraftField(r.id, 'option_e', e.target.value)}
                  placeholder='Option E (optional)'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.correct_answer ?? ''}
                  onChange={(e) => setDraftField(r.id, 'correct_answer', e.target.value)}
                  placeholder='Correct Answer (A/B/C/D/E or exact)'
                  className='kap-input'
                />
                <input
                  value={drafts[r.id]?.difficulty_level ?? ''}
                  onChange={(e) => setDraftField(r.id, 'difficulty_level', e.target.value)}
                  placeholder='Difficulty Level'
                  className='kap-input'
                />
                <textarea
                  value={drafts[r.id]?.solution ?? ''}
                  onChange={(e) => setDraftField(r.id, 'solution', e.target.value)}
                  placeholder='Solution'
                  className='kap-input'
                  style={{ minHeight: 80 }}
                />

                <button
                  onClick={() => saveQuestion(r)}
                  disabled={savingId === r.id}
                  className='kap-btn kap-btn-primary'
                  style={{ marginTop: 4 }}
                >
                  {savingId === r.id ? 'Saving...' : 'Save Full Question'}
                </button>
              </div>
            ) : null}

            <p style={{ color: '#6b7280', fontSize: 12, marginTop: 4 }}>{new Date(r.created_at).toLocaleString()}</p>
          </div>
        ))}
      </div>
    </main>
  )
}
