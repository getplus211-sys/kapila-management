'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Kpi = {
  total_users: number
  new_users_in_range: number
  dau_today: number
  mau_30d: number
  peak_concurrent_5m: number
}

type DayRow = {
  day: string
  dau: number
  new_users: number
  sessions: number
  screen_views: number
  app_opens: number
}

const RANGE_OPTIONS = [
  { label: 'Last 7 days', days: 7 },
  { label: 'Last 30 days', days: 30 },
  { label: 'Last 90 days', days: 90 },
]

function formatDay(d: string) {
  const dt = new Date(`${d}T00:00:00`)
  return dt.toLocaleDateString(undefined, { day: '2-digit', month: 'short' })
}

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [isOwner, setIsOwner] = useState(false)
  const [rangeDays, setRangeDays] = useState(7)
  const [kpi, setKpi] = useState<Kpi | null>(null)
  const [series, setSeries] = useState<DayRow[]>([])

  const maxDau = useMemo(() => {
    if (!series.length) return 1
    return Math.max(...series.map((x) => Number(x.dau || 0)), 1)
  }, [series])

  async function loadAnalytics(days: number) {
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

    const to = new Date()
    const from = new Date()
    from.setDate(to.getDate() - days + 1)

    const fromIso = from.toISOString()
    const toIso = to.toISOString()
    const fromDate = from.toISOString().slice(0, 10)
    const toDate = to.toISOString().slice(0, 10)

    const [kpiRes, seriesRes] = await Promise.all([
      supabase.rpc('ngm_admin_get_kpi', { p_from: fromIso, p_to: toIso }),
      supabase.rpc('ngm_admin_get_daily_series', { p_from: fromDate, p_to: toDate }),
    ])

    const firstErr = kpiRes.error ?? seriesRes.error
    if (firstErr) {
      setMsg(firstErr.message)
      setKpi(null)
      setSeries([])
      setLoading(false)
      return
    }

    setKpi((kpiRes.data ?? null) as Kpi | null)
    setSeries(((seriesRes.data ?? []) as DayRow[]).reverse())
    setLoading(false)
  }

  useEffect(() => {
    loadAnalytics(rangeDays)
    logAdminPageView('owner_analytics')
  }, [rangeDays])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>App Analytics</h1>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Link href='/analytics/revenue' className='kap-btn kap-btn-primary'>Revenue Analytics</Link>
          <Link href='/' className='kap-subtle-link'>Back</Link>
        </div>
      </div>

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <label style={{ fontWeight: 700, marginRight: 8 }}>Range:</label>
        <select
          className='kap-input'
          style={{ maxWidth: 220, display: 'inline-block' }}
          value={rangeDays}
          onChange={(e) => setRangeDays(Number(e.target.value))}
        >
          {RANGE_OPTIONS.map((o) => (
            <option key={o.days} value={o.days}>{o.label}</option>
          ))}
        </select>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading analytics...</p> : null}

      {!loading && isOwner && kpi ? (
        <>
          <div className='kap-analytics-grid' style={{ marginBottom: 12 }}>
            <div className='kap-card'><b>Total Users</b><div className='kap-kpi'>{kpi.total_users}</div></div>
            <div className='kap-card'><b>New Users (Range)</b><div className='kap-kpi'>{kpi.new_users_in_range}</div></div>
            <div className='kap-card'><b>DAU (Today)</b><div className='kap-kpi'>{kpi.dau_today}</div></div>
            <div className='kap-card'><b>MAU (30d)</b><div className='kap-kpi'>{kpi.mau_30d}</div></div>
            <div className='kap-card'><b>Peak Concurrent (5m)</b><div className='kap-kpi'>{kpi.peak_concurrent_5m}</div></div>
          </div>

          <div className='kap-card'>
            <h3 style={{ fontWeight: 800, marginBottom: 10 }}>Daily Activity</h3>
            {!series.length ? (
              <p>No daily analytics rows yet.</p>
            ) : (
              <div className='kap-grid'>
                {series.map((row) => {
                  const barPct = Math.max(4, Math.round((Number(row.dau || 0) / maxDau) * 100))
                  return (
                    <div key={row.day} className='kap-day-row'>
                      <div className='kap-day-label'>{formatDay(row.day)}</div>
                      <div className='kap-day-bar-wrap'>
                        <div className='kap-day-bar' style={{ width: `${barPct}%` }} />
                      </div>
                      <div className='kap-day-num'>DAU {row.dau}</div>
                      <div className='kap-day-mini'>New {row.new_users}</div>
                      <div className='kap-day-mini'>Sessions {row.sessions}</div>
                      <div className='kap-day-mini'>Views {row.screen_views}</div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </>
      ) : null}
    </main>
  )
}
