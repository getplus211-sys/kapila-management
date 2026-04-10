'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type MockRow = {
  mock_test_id: string
  mock_name: string
  exam_code: string
  is_live: boolean
  created_at: string
}

export default function MockBroadcastPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<MockRow[]>([])
  const [mockId, setMockId] = useState('')
  const [title, setTitle] = useState('New Mock Available')
  const [body, setBody] = useState('New mock test uploaded. Attempt now.')

  async function loadRows() {
    setLoading(true)
    setMsg('')
    const access = await getAdminAccess()
    setRole(access.role)
    if (!hasSalesAccess(access.role)) {
      setMsg('Access denied.')
      setLoading(false)
      return
    }

    const { data, error } = await supabase
      .from('kls_mock_tests')
      .select('mock_test_id,mock_name,exam_code,is_live,created_at')
      .order('created_at', { ascending: false })
      .limit(150)

    if (error) {
      setMsg(error.message)
      setRows([])
    } else {
      const next = (data ?? []) as MockRow[]
      setRows(next)
      if (!mockId && next.length > 0) setMockId(next[0].mock_test_id)
    }
    setLoading(false)
  }

  async function broadcast() {
    if (!mockId || !title.trim() || !body.trim()) {
      setMsg('Select mock and fill title/body.')
      return
    }
    const { data, error } = await supabase.rpc('kls_broadcast_new_mock_notification', {
      p_title: title.trim(),
      p_body: body.trim(),
      p_mock_test_id: mockId,
    })
    if (error) {
      setMsg(error.message)
      return
    }
    setMsg(`Broadcast success. Sent to ${Number(data ?? 0)} users.`)
  }

  useEffect(() => {
    void loadRows()
    logAdminPageView('mock_broadcast')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Mock Broadcast</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <p style={{ fontWeight: 700, marginBottom: 8 }}>Send New Mock Notification</p>
        <div style={{ display: 'grid', gap: 8 }}>
          <select className='kap-input' value={mockId} onChange={(e) => setMockId(e.target.value)}>
            <option value=''>Select Mock</option>
            {rows.map((r) => (
              <option key={r.mock_test_id} value={r.mock_test_id}>
                {r.mock_name} ({r.exam_code}) {r.is_live ? '[Live]' : '[Not Live]'}
              </option>
            ))}
          </select>
          <input className='kap-input' value={title} onChange={(e) => setTitle(e.target.value)} />
          <textarea className='kap-input' value={body} onChange={(e) => setBody(e.target.value)} rows={3} />
          <button className='kap-btn kap-btn-primary' onClick={broadcast}>Broadcast</button>
        </div>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}
    </main>
  )
}


