'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type PlanRow = {
  subscription_plan_id: string
  plan_code: string
  plan_name: string
  plan_description: string | null
  duration_months: number
  price: number
  currency_code: string
  is_active: boolean
}

export default function SubscriptionPlansPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<PlanRow[]>([])
  const [code, setCode] = useState('KLS_FULL_12M')
  const [name, setName] = useState('Full Subscription 12M')
  const [description, setDescription] = useState('All content access for 12 months')
  const [months, setMonths] = useState('12')
  const [price, setPrice] = useState('999')

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
      .from('kls_subscription_plans')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) {
      setMsg(error.message)
      setRows([])
    } else {
      setRows((data ?? []) as PlanRow[])
    }
    setLoading(false)
  }

  async function savePlan() {
    const m = Number(months)
    const p = Number(price)
    if (!code.trim() || !name.trim() || !Number.isFinite(m) || !Number.isFinite(p)) {
      setMsg('Invalid input.')
      return
    }
    const { error } = await supabase
      .from('kls_subscription_plans')
      .upsert(
        {
          plan_code: code.trim().toUpperCase(),
          plan_name: name.trim(),
          plan_description: description.trim(),
          duration_months: m,
          price: p,
          currency_code: 'INR',
          is_active: true,
        },
        { onConflict: 'plan_code' },
      )
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  async function toggleActive(row: PlanRow) {
    const { error } = await supabase
      .from('kls_subscription_plans')
      .update({ is_active: !row.is_active })
      .eq('subscription_plan_id', row.subscription_plan_id)
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  async function editPlan(row: PlanRow) {
    const nextCode = prompt('Plan code (DB: plan_code)', row.plan_code)
    if (nextCode == null) return
    const nextName = prompt('Plan name (DB: plan_name)', row.plan_name)
    if (nextName == null) return
    const nextDesc = prompt('Description (DB: plan_description)', row.plan_description ?? '')
    if (nextDesc == null) return
    const nextMonthsRaw = prompt('Duration months (DB: duration_months)', String(row.duration_months))
    if (nextMonthsRaw == null) return
    const nextPriceRaw = prompt('Price INR (DB: price)', String(row.price))
    if (nextPriceRaw == null) return
    const nextMonths = Number(nextMonthsRaw)
    const nextPrice = Number(nextPriceRaw)
    if (!Number.isFinite(nextMonths) || !Number.isFinite(nextPrice)) {
      setMsg('Months અને price number જ હોવા જોઈએ.')
      return
    }

    const { error } = await supabase
      .from('kls_subscription_plans')
      .update({
        plan_code: nextCode.trim().toUpperCase(),
        plan_name: nextName.trim(),
        plan_description: nextDesc.trim() || null,
        duration_months: nextMonths,
        price: nextPrice,
      })
      .eq('subscription_plan_id', row.subscription_plan_id)
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  useEffect(() => {
    void loadRows()
    logAdminPageView('subscription_plans')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Subscription Plans</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <p style={{ fontWeight: 700, marginBottom: 8 }}>Create / Update Plan</p>
        <div style={{ display: 'grid', gap: 8 }}>
          <label style={{ fontSize: 13, color: '#6b7280' }}>
            Plan Code (DB field: <code>plan_code</code>) - unique code, duplicate નથી રાખવો.
          </label>
          <input className='kap-input' placeholder='જેમ કે: KLS_FULL_12M' value={code} onChange={(e) => setCode(e.target.value)} />
          <label style={{ fontSize: 13, color: '#6b7280' }}>
            Plan Name (DB field: <code>plan_name</code>) - app માં user ને દેખાતું નામ.
          </label>
          <input className='kap-input' placeholder='જેમ કે: Full Subscription 12M' value={name} onChange={(e) => setName(e.target.value)} />
          <label style={{ fontSize: 13, color: '#6b7280' }}>
            Description (DB field: <code>plan_description</code>)
          </label>
          <input className='kap-input' placeholder='Planમાં શું મળે તે લખો' value={description} onChange={(e) => setDescription(e.target.value)} />
          <label style={{ fontSize: 13, color: '#6b7280' }}>
            Duration (DB field: <code>duration_months</code>) - મહિના.
          </label>
          <input className='kap-input' placeholder='12' value={months} onChange={(e) => setMonths(e.target.value)} />
          <label style={{ fontSize: 13, color: '#6b7280' }}>
            Price (DB field: <code>price</code>) - INR amount.
          </label>
          <input className='kap-input' placeholder='999' value={price} onChange={(e) => setPrice(e.target.value)} />
          <button className='kap-btn kap-btn-primary' onClick={savePlan}>Save Plan</button>
        </div>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.subscription_plan_id} className='kap-card'>
            <p><b>{r.plan_name}</b> ({r.plan_code})</p>
            <p>Duration: {r.duration_months} months</p>
            <p>Price: Rs.{Number(r.price).toFixed(2)}</p>
            <p style={{ fontSize: 12, color: '#6b7280' }}>
              DB: <code>plan_code</code>, <code>plan_name</code>, <code>duration_months</code>, <code>price</code>, <code>is_active</code>
            </p>
            <p>Status: <span className='kap-chip'>{r.is_active ? 'active' : 'inactive'}</span></p>
            <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
              <button className='kap-btn kap-btn-outline' onClick={() => editPlan(r)}>
                Edit
              </button>
              <button className='kap-btn kap-btn-outline' onClick={() => toggleActive(r)}>
                {r.is_active ? 'Deactivate' : 'Activate'}
              </button>
            </div>
          </div>
        ))}
        {!loading && rows.length === 0 ? <p>No plans found.</p> : null}
      </div>
    </main>
  )
}
