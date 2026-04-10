'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'

type RangeKey = 'day' | 'week' | 'd15' | 'month' | 'm2' | 'm3' | 'm6' | 'year'

type PaidTxn = {
  payment_txn_id: string
  user_id: string
  product_type: string | null
  paid_at: string | null
  created_at: string
  test_series_id: string | null
  final_amount: number | null
  amount: number | null
}

type SeriesRow = {
  test_series_id: string
  series_name: string
}

type AffiliateEarningRow = {
  affiliate_user_id: string
  affiliate_code: string | null
  commission_amount: number
  status: string
  created_at: string
}

type AffiliatePayoutRow = {
  affiliate_user_id: string
  amount: number
  paid_at: string
}

type AffiliateProfileRow = {
  user_id: string
  affiliate_code: string
}

const RANGE_CONFIG: Record<RangeKey, { label: string; days: number; bucket: 'hour' | 'day' | 'week' | 'month' }> = {
  day: { label: 'Per Day', days: 1, bucket: 'hour' },
  week: { label: 'Weekly', days: 7, bucket: 'day' },
  d15: { label: '15 Days', days: 15, bucket: 'day' },
  month: { label: 'Monthly', days: 30, bucket: 'day' },
  m2: { label: '2 Months', days: 60, bucket: 'week' },
  m3: { label: '3 Months', days: 90, bucket: 'week' },
  m6: { label: '6 Months', days: 180, bucket: 'month' },
  year: { label: 'Yearly', days: 365, bucket: 'month' },
}

type RevenuePoint = { label: string; amount: number }

export default function RevenueAnalyticsPage() {
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [isOwner, setIsOwner] = useState(false)
  const [rangeKey, setRangeKey] = useState<RangeKey>('month')

  const [subscriptionStudents, setSubscriptionStudents] = useState(0)
  const [testSeriesStudents, setTestSeriesStudents] = useState(0)
  const [subscriptionRevenue, setSubscriptionRevenue] = useState(0)
  const [testSeriesRevenue, setTestSeriesRevenue] = useState(0)
  const [seriesWise, setSeriesWise] = useState<Array<{ series_name: string; students: number; revenue: number }>>([])
  const [revenueSeries, setRevenueSeries] = useState<RevenuePoint[]>([])

  const [affiliateTotals, setAffiliateTotals] = useState({ total: 0, paid: 0, payable: 0 })
  const [affiliateRows, setAffiliateRows] = useState<Array<{ affiliate_code: string; total: number; paid: number; payable: number }>>([])

  const maxRevenue = useMemo(() => Math.max(...revenueSeries.map((x) => x.amount), 1), [revenueSeries])

  function dateBucket(dt: Date, bucket: 'hour' | 'day' | 'week' | 'month') {
    if (bucket === 'hour') return `${dt.getHours().toString().padStart(2, '0')}:00`
    if (bucket === 'day') return dt.toISOString().slice(0, 10)
    if (bucket === 'week') {
      const weekStart = new Date(dt)
      const day = weekStart.getUTCDay() || 7
      weekStart.setUTCDate(weekStart.getUTCDate() - day + 1)
      return `W:${weekStart.toISOString().slice(0, 10)}`
    }
    return dt.toISOString().slice(0, 7)
  }

  function fmtAmt(v: number) {
    return `Rs.${Number(v || 0).toFixed(2)}`
  }

  async function loadRevenue() {
    setLoading(true)
    setMsg('')

    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) {
      setIsOwner(false)
      setMsg('Access denied. Owner only.')
      setLoading(false)
      return
    }

    const { data: roleData } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (!roleData || roleData.is_active !== true || roleData.role !== 'owner') {
      setIsOwner(false)
      setMsg('Access denied. Owner only.')
      setLoading(false)
      return
    }

    setIsOwner(true)

    const cfg = RANGE_CONFIG[rangeKey]
    const to = new Date()
    const from = new Date()
    from.setUTCDate(to.getUTCDate() - cfg.days + 1)
    const fromIso = from.toISOString()

    const [txRes, seriesRes, earnRes, payoutRes, profileRes] = await Promise.all([
      supabase
        .from('kls_payment_transactions')
        .select('payment_txn_id,user_id,product_type,paid_at,created_at,test_series_id,final_amount,amount')
        .eq('status', 'paid')
        .gte('paid_at', fromIso)
        .order('paid_at', { ascending: true }),
      supabase.from('kls_test_series').select('test_series_id,series_name'),
      supabase
        .from('kls_affiliate_earnings')
        .select('affiliate_user_id,affiliate_code,commission_amount,status,created_at')
        .in('status', ['approved', 'paid'])
        .gte('created_at', fromIso),
      supabase
        .from('kls_affiliate_payouts')
        .select('affiliate_user_id,amount,paid_at')
        .gte('paid_at', fromIso),
      supabase.from('kls_affiliate_profiles').select('user_id,affiliate_code').eq('is_active', true),
    ])

    const firstErr = txRes.error ?? seriesRes.error ?? earnRes.error ?? payoutRes.error ?? profileRes.error
    if (firstErr) {
      setMsg(firstErr.message)
      setLoading(false)
      return
    }

    const txRows = (txRes.data ?? []) as PaidTxn[]
    const seriesMap = new Map((seriesRes.data ?? []).map((s: SeriesRow) => [s.test_series_id, s.series_name]))

    const subUsers = new Set<string>()
    const seriesUsers = new Set<string>()
    let subRevenue = 0
    let tsRevenue = 0

    const bucketMap = new Map<string, number>()
    const seriesAgg = new Map<string, { students: Set<string>; revenue: number }>()

    for (const tx of txRows) {
      const ptype = (tx.product_type ?? '').toLowerCase()
      const amt = Number(tx.final_amount ?? tx.amount ?? 0)
      const paidAtStr = tx.paid_at ?? tx.created_at
      const d = new Date(paidAtStr)

      const b = dateBucket(d, cfg.bucket)
      bucketMap.set(b, (bucketMap.get(b) ?? 0) + amt)

      if (ptype.includes('subscription')) {
        subUsers.add(tx.user_id)
        subRevenue += amt
      } else {
        seriesUsers.add(tx.user_id)
        tsRevenue += amt
        if (tx.test_series_id) {
          const name = seriesMap.get(tx.test_series_id) ?? tx.test_series_id
          const cur = seriesAgg.get(name) ?? { students: new Set<string>(), revenue: 0 }
          cur.students.add(tx.user_id)
          cur.revenue += amt
          seriesAgg.set(name, cur)
        }
      }
    }

    setSubscriptionStudents(subUsers.size)
    setTestSeriesStudents(seriesUsers.size)
    setSubscriptionRevenue(subRevenue)
    setTestSeriesRevenue(tsRevenue)

    setSeriesWise(
      Array.from(seriesAgg.entries())
        .map(([series_name, v]) => ({ series_name, students: v.students.size, revenue: v.revenue }))
        .sort((a, b) => b.students - a.students)
    )

    setRevenueSeries(
      Array.from(bucketMap.entries())
        .map(([label, amount]) => ({ label, amount }))
        .sort((a, b) => a.label.localeCompare(b.label))
    )

    const earnRows = (earnRes.data ?? []) as AffiliateEarningRow[]
    const payoutRows = (payoutRes.data ?? []) as AffiliatePayoutRow[]
    const profileRows = (profileRes.data ?? []) as AffiliateProfileRow[]

    const codeByUser = new Map(profileRows.map((p) => [p.user_id, p.affiliate_code]))

    const totalEarn = earnRows.reduce((s, r) => s + Number(r.commission_amount || 0), 0)
    const totalPaid = payoutRows.reduce((s, r) => s + Number(r.amount || 0), 0)
    const totalPayable = Math.max(0, totalEarn - totalPaid)

    setAffiliateTotals({ total: totalEarn, paid: totalPaid, payable: totalPayable })

    const perAff = new Map<string, { code: string; total: number; paid: number }>()
    for (const e of earnRows) {
      const uid = e.affiliate_user_id
      const code = e.affiliate_code ?? codeByUser.get(uid) ?? uid
      const cur = perAff.get(uid) ?? { code, total: 0, paid: 0 }
      cur.total += Number(e.commission_amount || 0)
      perAff.set(uid, cur)
    }
    for (const p of payoutRows) {
      const uid = p.affiliate_user_id
      const code = codeByUser.get(uid) ?? uid
      const cur = perAff.get(uid) ?? { code, total: 0, paid: 0 }
      cur.paid += Number(p.amount || 0)
      perAff.set(uid, cur)
    }

    setAffiliateRows(
      Array.from(perAff.values())
        .map((x) => ({ affiliate_code: x.code, total: x.total, paid: x.paid, payable: Math.max(0, x.total - x.paid) }))
        .sort((a, b) => b.payable - a.payable)
    )

    setLoading(false)
  }

  useEffect(() => {
    void loadRevenue()
  }, [rangeKey])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Revenue Analytics (Owner)</h1>
        <Link href='/analytics' className='kap-subtle-link'>Back</Link>
      </div>

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <label style={{ fontWeight: 700, marginRight: 8 }}>Range:</label>
        <select
          className='kap-input'
          style={{ maxWidth: 260, display: 'inline-block' }}
          value={rangeKey}
          onChange={(e) => setRangeKey(e.target.value as RangeKey)}
        >
          {(Object.keys(RANGE_CONFIG) as RangeKey[]).map((k) => (
            <option key={k} value={k}>{RANGE_CONFIG[k].label}</option>
          ))}
        </select>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading revenue analytics...</p> : null}

      {!loading && isOwner ? (
        <>
          <div className='kap-analytics-grid' style={{ marginBottom: 12 }}>
            <div className='kap-card'><b>Subscription Students</b><div className='kap-kpi'>{subscriptionStudents}</div></div>
            <div className='kap-card'><b>Only Test-Series Students</b><div className='kap-kpi'>{testSeriesStudents}</div></div>
            <div className='kap-card'><b>Subscription Revenue</b><div className='kap-kpi'>{fmtAmt(subscriptionRevenue)}</div></div>
            <div className='kap-card'><b>Test-Series Revenue</b><div className='kap-kpi'>{fmtAmt(testSeriesRevenue)}</div></div>
          </div>

          <div className='kap-card' style={{ marginBottom: 12 }}>
            <h3 style={{ fontWeight: 800, marginBottom: 10 }}>Revenue Graph</h3>
            {!revenueSeries.length ? (
              <p>No revenue rows for selected range.</p>
            ) : (
              <div className='kap-grid'>
                {revenueSeries.map((row) => {
                  const barPct = Math.max(4, Math.round((Number(row.amount || 0) / maxRevenue) * 100))
                  return (
                    <div key={row.label} className='kap-day-row'>
                      <div className='kap-day-label'>{row.label}</div>
                      <div className='kap-day-bar-wrap'>
                        <div className='kap-day-bar' style={{ width: `${barPct}%` }} />
                      </div>
                      <div className='kap-day-num'>{fmtAmt(row.amount)}</div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>

          <div className='kap-card' style={{ marginBottom: 12 }}>
            <h3 style={{ fontWeight: 800, marginBottom: 10 }}>Series Wise Buyers</h3>
            {!seriesWise.length ? (
              <p>No test-series purchase in selected range.</p>
            ) : (
              <div className='kap-grid'>
                {seriesWise.map((s) => (
                  <div key={s.series_name} className='kap-card' style={{ padding: 10 }}>
                    <p style={{ margin: 0, fontWeight: 700 }}>{s.series_name}</p>
                    <p style={{ margin: '6px 0 0 0' }}>Students: <b>{s.students}</b></p>
                    <p style={{ margin: '4px 0 0 0' }}>Revenue: <b>{fmtAmt(s.revenue)}</b></p>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className='kap-card'>
            <h3 style={{ fontWeight: 800, marginBottom: 10 }}>Affiliate Payments</h3>
            <div className='kap-analytics-grid' style={{ marginBottom: 10 }}>
              <div className='kap-card'><b>Total Commission</b><div className='kap-kpi'>{fmtAmt(affiliateTotals.total)}</div></div>
              <div className='kap-card'><b>Total Paid</b><div className='kap-kpi'>{fmtAmt(affiliateTotals.paid)}</div></div>
              <div className='kap-card'><b>Total Payable</b><div className='kap-kpi'>{fmtAmt(affiliateTotals.payable)}</div></div>
            </div>

            {!affiliateRows.length ? (
              <p>No affiliate data in selected range.</p>
            ) : (
              <div className='kap-grid'>
                {affiliateRows.map((a) => (
                  <div key={a.affiliate_code} className='kap-card' style={{ padding: 10 }}>
                    <p style={{ margin: 0, fontWeight: 700 }}>{a.affiliate_code}</p>
                    <p style={{ margin: '6px 0 0 0' }}>Total: <b>{fmtAmt(a.total)}</b></p>
                    <p style={{ margin: '4px 0 0 0' }}>Paid: <b>{fmtAmt(a.paid)}</b></p>
                    <p style={{ margin: '4px 0 0 0' }}>Payable: <b>{fmtAmt(a.payable)}</b></p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      ) : null}
    </main>
  )
}
