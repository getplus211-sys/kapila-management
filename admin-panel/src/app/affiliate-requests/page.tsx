'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type ApplicationRow = {
  application_id: string
  user_id: string
  full_name: string
  phone: string | null
  email: string | null
  district: string | null
  website_url: string | null
  social_link: string | null
  telegram_url: string | null
  instagram_url: string | null
  youtube_url: string | null
  facebook_url: string | null
  is_private_account: boolean
  status: 'pending' | 'approved' | 'rejected'
  rejection_reason: string | null
  created_at: string
}

export default function AffiliateRequestsPage() {
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<AdminRole>(null)
  const [rows, setRows] = useState<ApplicationRow[]>([])
  const [status, setStatus] = useState<'pending' | 'approved' | 'rejected'>('pending')
  const [msg, setMsg] = useState('')
  const [approveCode, setApproveCode] = useState<Record<string, string>>({})
  const [approvePct, setApprovePct] = useState<Record<string, string>>({})

  async function loadRows() {
    setLoading(true)
    setMsg('')
    const access = await getAdminAccess()
    setRole(access.role)
    if (!hasSalesAccess(access.role)) {
      setRows([])
      setMsg('Access denied.')
      setLoading(false)
      return
    }

    const { data, error } = await supabase
      .from('kls_affiliate_applications')
      .select(
        'application_id,user_id,full_name,phone,email,district,website_url,social_link,telegram_url,instagram_url,youtube_url,facebook_url,is_private_account,status,rejection_reason,created_at',
      )
      .eq('status', status)
      .order('created_at', { ascending: false })

    if (error) {
      setRows([])
      setMsg(error.message)
    } else {
      setRows((data ?? []) as ApplicationRow[])
    }
    setLoading(false)
  }

  async function approve(row: ApplicationRow) {
    const code = (approveCode[row.application_id] ?? '').trim().toUpperCase()
    const pctRaw = (approvePct[row.application_id] ?? '10').trim()
    const pct = Number(pctRaw)
    if (!code) {
      setMsg('Affiliate code required.')
      return
    }
    if (!Number.isFinite(pct) || pct < 0 || pct > 100) {
      setMsg('Commission % invalid.')
      return
    }
    setMsg('')

    const { error } = await supabase.rpc('kls_approve_affiliate_application', {
      p_application_id: row.application_id,
      p_affiliate_code: code,
      p_commission_percent: pct,
    })
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  async function reject(row: ApplicationRow) {
    const reason = prompt('Reject reason') ?? ''
    if (!reason.trim()) return
    const { error } = await supabase.rpc('kls_reject_affiliate_application', {
      p_application_id: row.application_id,
      p_rejection_reason: reason.trim(),
    })
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  useEffect(() => {
    void loadRows()
    logAdminPageView('affiliate_requests')
  }, [status])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Affiliate Requests</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        {(['pending', 'approved', 'rejected'] as const).map((s) => (
          <button
            key={s}
            onClick={() => setStatus(s)}
            className={`kap-btn ${status === s ? 'kap-btn-primary' : 'kap-btn-outline'}`}
          >
            {s}
          </button>
        ))}
      </div>
      <p style={{ marginBottom: 10, fontSize: 13, color: '#6b7280' }}>
        Note: Approval ma aapelu <b>Commission %</b> fallback default chhe. Fixed Rs amount set karva
        mate "Affiliate Commission Rules" module vapro.
      </p>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}
      {!loading && !rows.length ? <p>No affiliate requests.</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.application_id} className='kap-card'>
            <p><b>{r.full_name}</b> ({r.user_id})</p>
            <p style={{ fontSize: 13, color: '#6b7280' }}>
              Mobile: {r.phone ?? '-'} | Email: {r.email ?? '-'} | District: {r.district ?? '-'}
            </p>
            <p style={{ fontSize: 13, color: '#6b7280' }}>
              Private: {r.is_private_account ? 'Yes' : 'No'}
            </p>
            <p style={{ fontSize: 13, color: '#6b7280' }}>
              Telegram: {r.telegram_url ?? '-'} | Instagram: {r.instagram_url ?? '-'}
            </p>
            <p style={{ fontSize: 13, color: '#6b7280' }}>
              YouTube: {r.youtube_url ?? '-'} | Facebook: {r.facebook_url ?? '-'}
            </p>
            {r.rejection_reason ? (
              <p style={{ marginTop: 8 }}>
                <b>Reason:</b> {r.rejection_reason}
              </p>
            ) : null}

            {status === 'pending' ? (
              <div style={{ marginTop: 10, display: 'grid', gap: 8 }}>
                <input
                  className='kap-input'
                  placeholder='Affiliate Code (e.g. GPSC100)'
                  value={approveCode[r.application_id] ?? ''}
                  onChange={(e) =>
                    setApproveCode((prev) => ({ ...prev, [r.application_id]: e.target.value }))
                  }
                />
                <input
                  className='kap-input'
                  placeholder='Default Commission % (fallback)'
                  value={approvePct[r.application_id] ?? '10'}
                  onChange={(e) =>
                    setApprovePct((prev) => ({ ...prev, [r.application_id]: e.target.value }))
                  }
                />
                <div style={{ display: 'flex', gap: 8 }}>
                  <button className='kap-btn kap-btn-primary' onClick={() => approve(r)}>Approve</button>
                  <button className='kap-btn kap-btn-danger' onClick={() => reject(r)}>Reject</button>
                </div>
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </main>
  )
}
