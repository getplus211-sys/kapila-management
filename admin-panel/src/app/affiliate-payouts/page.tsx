'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type AffiliateRow = {
  user_id: string
  affiliate_code: string
}

type PayoutRow = {
  payout_id: string
  affiliate_user_id: string
  amount: number
  paid_at: string
  notes: string | null
}

export default function AffiliatePayoutsPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [affiliates, setAffiliates] = useState<AffiliateRow[]>([])
  const [rows, setRows] = useState<PayoutRow[]>([])
  const [selectedUser, setSelectedUser] = useState('')
  const [amount, setAmount] = useState('')
  const [notes, setNotes] = useState('')

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

    const [aRes, pRes] = await Promise.all([
      supabase.from('kls_affiliate_profiles').select('user_id,affiliate_code').eq('is_active', true),
      supabase
        .from('kls_affiliate_payouts')
        .select('payout_id,affiliate_user_id,amount,paid_at,notes')
        .order('paid_at', { ascending: false })
        .limit(100),
    ])

    if (aRes.error || pRes.error) {
      setMsg(aRes.error?.message ?? pRes.error?.message ?? 'Load error')
    } else {
      setAffiliates((aRes.data ?? []) as AffiliateRow[])
      setRows((pRes.data ?? []) as PayoutRow[])
      if (!selectedUser && (aRes.data ?? []).length) {
        setSelectedUser((aRes.data ?? [])[0].user_id)
      }
    }
    setLoading(false)
  }

  async function addPayout() {
    const value = Number(amount)
    if (!selectedUser || !Number.isFinite(value) || value <= 0) {
      setMsg('Select user and valid amount.')
      return
    }
    const { data: authData } = await supabase.auth.getUser()
    const me = authData.user
    if (!me) return

    const { error } = await supabase.from('kls_affiliate_payouts').insert({
      affiliate_user_id: selectedUser,
      amount: value,
      paid_by: me.id,
      notes: notes.trim() || null,
    })
    if (error) {
      setMsg(error.message)
      return
    }
    setAmount('')
    setNotes('')
    await loadData()
  }

  useEffect(() => {
    void loadData()
    logAdminPageView('affiliate_payouts')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Affiliate Payouts</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <p style={{ fontWeight: 700, marginBottom: 8 }}>Mark Paid Amount</p>
        <div style={{ display: 'grid', gap: 8 }}>
          <select
            className='kap-input'
            value={selectedUser}
            onChange={(e) => setSelectedUser(e.target.value)}
          >
            <option value=''>Select Affiliate</option>
            {affiliates.map((a) => (
              <option key={a.user_id} value={a.user_id}>
                {a.affiliate_code} - {a.user_id}
              </option>
            ))}
          </select>
          <input
            className='kap-input'
            placeholder='Amount'
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
          <input
            className='kap-input'
            placeholder='Notes'
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
          <button className='kap-btn kap-btn-primary' onClick={addPayout}>Add Payout</button>
        </div>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.payout_id} className='kap-card'>
            <p><b>User:</b> {r.affiliate_user_id}</p>
            <p><b>Amount:</b> Rs.{Number(r.amount).toFixed(2)}</p>
            <p><b>Paid At:</b> {new Date(r.paid_at).toLocaleString()}</p>
            <p><b>Notes:</b> {r.notes ?? '-'}</p>
          </div>
        ))}
        {!loading && rows.length === 0 ? <p>No payouts yet.</p> : null}
      </div>
    </main>
  )
}
