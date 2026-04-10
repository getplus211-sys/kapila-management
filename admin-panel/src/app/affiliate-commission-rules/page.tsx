'use client'

import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type ProductType = 'subscription' | 'test_series'

type AffiliateProfileRow = {
  affiliate_profile_id: string
  user_id: string
  affiliate_code: string
  commission_percent: number
  is_active: boolean
}

type RuleRow = {
  rule_id: string
  affiliate_profile_id: string
  product_type: ProductType
  test_series_id: string | null
  subscription_plan_id: string | null
  fixed_commission_amount: number
  is_active: boolean
  updated_at: string
}

type SeriesRow = {
  test_series_id: string
  series_name: string
  exam_code: string
}

type PlanRow = {
  subscription_plan_id: string
  plan_name: string
  plan_code: string
}

export default function AffiliateCommissionRulesPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')

  const [profiles, setProfiles] = useState<AffiliateProfileRow[]>([])
  const [rules, setRules] = useState<RuleRow[]>([])
  const [series, setSeries] = useState<SeriesRow[]>([])
  const [plans, setPlans] = useState<PlanRow[]>([])

  const [selectedProfileId, setSelectedProfileId] = useState('')
  const [productType, setProductType] = useState<ProductType>('subscription')
  const [targetSeriesId, setTargetSeriesId] = useState('')
  const [targetPlanId, setTargetPlanId] = useState('')
  const [fixedAmount, setFixedAmount] = useState('0')

  const profileMap = useMemo(
    () => Object.fromEntries(profiles.map((p) => [p.affiliate_profile_id, p])),
    [profiles],
  )
  const seriesMap = useMemo(
    () => Object.fromEntries(series.map((s) => [s.test_series_id, s])),
    [series],
  )
  const planMap = useMemo(
    () => Object.fromEntries(plans.map((p) => [p.subscription_plan_id, p])),
    [plans],
  )

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

    const [pRes, rRes, sRes, plRes] = await Promise.all([
      supabase
        .from('kls_affiliate_profiles')
        .select('affiliate_profile_id,user_id,affiliate_code,commission_percent,is_active')
        .eq('is_active', true)
        .order('approved_at', { ascending: false }),
      supabase
        .from('kls_affiliate_commission_rules')
        .select('rule_id,affiliate_profile_id,product_type,test_series_id,subscription_plan_id,fixed_commission_amount,is_active,updated_at')
        .order('updated_at', { ascending: false })
        .limit(300),
      supabase
        .from('kls_test_series')
        .select('test_series_id,series_name,exam_code')
        .order('series_name', { ascending: true }),
      supabase
        .from('kls_subscription_plans')
        .select('subscription_plan_id,plan_name,plan_code')
        .order('plan_name', { ascending: true }),
    ])

    if (pRes.error || rRes.error || sRes.error || plRes.error) {
      setMsg(pRes.error?.message ?? rRes.error?.message ?? sRes.error?.message ?? plRes.error?.message ?? 'Load error')
      setLoading(false)
      return
    }

    const pRows = (pRes.data ?? []) as AffiliateProfileRow[]
    setProfiles(pRows)
    setRules((rRes.data ?? []) as RuleRow[])
    setSeries((sRes.data ?? []) as SeriesRow[])
    setPlans((plRes.data ?? []) as PlanRow[])
    if (!selectedProfileId && pRows.length > 0) {
      setSelectedProfileId(pRows[0].affiliate_profile_id)
    }
    setLoading(false)
  }

  async function saveRule() {
    const amount = Number(fixedAmount)
    if (!selectedProfileId) {
      setMsg('Select affiliate code first.')
      return
    }
    if (!Number.isFinite(amount) || amount < 0) {
      setMsg('Fixed amount invalid.')
      return
    }

    const payload = {
      affiliate_profile_id: selectedProfileId,
      product_type: productType,
      test_series_id: productType === 'test_series' ? (targetSeriesId || null) : null,
      subscription_plan_id: productType === 'subscription' ? (targetPlanId || null) : null,
      fixed_commission_amount: amount,
      is_active: true,
    }

    let q = supabase
      .from('kls_affiliate_commission_rules')
      .select('rule_id')
      .eq('affiliate_profile_id', selectedProfileId)
      .eq('product_type', productType)

    if (productType === 'subscription') {
      q = targetPlanId ? q.eq('subscription_plan_id', targetPlanId) : q.is('subscription_plan_id', null)
      q = q.is('test_series_id', null)
    } else {
      q = targetSeriesId ? q.eq('test_series_id', targetSeriesId) : q.is('test_series_id', null)
      q = q.is('subscription_plan_id', null)
    }

    const { data: existing, error: findErr } = await q.maybeSingle()
    if (findErr) {
      setMsg(findErr.message)
      return
    }

    if (existing?.rule_id) {
      const { error } = await supabase
        .from('kls_affiliate_commission_rules')
        .update({
          fixed_commission_amount: amount,
          is_active: true,
          updated_at: new Date().toISOString(),
        })
        .eq('rule_id', existing.rule_id)
      if (error) {
        setMsg(error.message)
        return
      }
      setMsg('Rule updated.')
    } else {
      const { error } = await supabase.from('kls_affiliate_commission_rules').insert(payload)
      if (error) {
        setMsg(error.message)
        return
      }
      setMsg('Rule created.')
    }

    await loadData()
  }

  async function toggleRule(row: RuleRow) {
    const { error } = await supabase
      .from('kls_affiliate_commission_rules')
      .update({ is_active: !row.is_active, updated_at: new Date().toISOString() })
      .eq('rule_id', row.rule_id)
    if (error) {
      setMsg(error.message)
      return
    }
    await loadData()
  }

  useEffect(() => {
    void loadData()
    logAdminPageView('affiliate_commission_rules')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Affiliate Commission Rules</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <p style={{ fontWeight: 800, marginBottom: 8 }}>Set Fixed Amount (per purchase)</p>
        <p style={{ fontSize: 13, color: '#6b7280', marginBottom: 10 }}>
          Note: Profile Commission % is fallback. If fixed rule exists, fixed amount is used.
        </p>
        <div style={{ display: 'grid', gap: 8 }}>
          <select className='kap-input' value={selectedProfileId} onChange={(e) => setSelectedProfileId(e.target.value)}>
            <option value=''>Select Affiliate Code</option>
            {profiles.map((p) => (
              <option key={p.affiliate_profile_id} value={p.affiliate_profile_id}>
                {p.affiliate_code} | default {Number(p.commission_percent).toFixed(2)}%
              </option>
            ))}
          </select>

          <select className='kap-input' value={productType} onChange={(e) => setProductType(e.target.value as ProductType)}>
            <option value='subscription'>Subscription</option>
            <option value='test_series'>Test Series</option>
          </select>

          {productType === 'subscription' ? (
            <select className='kap-input' value={targetPlanId} onChange={(e) => setTargetPlanId(e.target.value)}>
              <option value=''>All Subscription Plans (global)</option>
              {plans.map((pl) => (
                <option key={pl.subscription_plan_id} value={pl.subscription_plan_id}>
                  {pl.plan_name} ({pl.plan_code})
                </option>
              ))}
            </select>
          ) : (
            <select className='kap-input' value={targetSeriesId} onChange={(e) => setTargetSeriesId(e.target.value)}>
              <option value=''>All Test Series (global)</option>
              {series.map((s) => (
                <option key={s.test_series_id} value={s.test_series_id}>
                  {s.series_name} ({s.exam_code})
                </option>
              ))}
            </select>
          )}

          <input
            className='kap-input'
            value={fixedAmount}
            onChange={(e) => setFixedAmount(e.target.value)}
            placeholder='Fixed Commission Amount (Rs)'
          />

          <button className='kap-btn kap-btn-primary' onClick={saveRule}>Save Rule</button>
        </div>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      <div className='kap-grid'>
        {rules.map((r) => {
          const p = profileMap[r.affiliate_profile_id]
          const target = r.product_type === 'subscription'
            ? (r.subscription_plan_id ? planMap[r.subscription_plan_id]?.plan_name ?? r.subscription_plan_id : 'All Plans')
            : (r.test_series_id ? seriesMap[r.test_series_id]?.series_name ?? r.test_series_id : 'All Series')
          return (
            <div key={r.rule_id} className='kap-card'>
              <p><b>{p?.affiliate_code ?? 'Unknown Code'}</b></p>
              <p>Product: <span className='kap-chip'>{r.product_type}</span></p>
              <p>Target: {target}</p>
              <p>Fixed Amount: <b>Rs.{Number(r.fixed_commission_amount).toFixed(2)}</b></p>
              <p>Status: <span className='kap-chip'>{r.is_active ? 'active' : 'inactive'}</span></p>
              <button className='kap-btn kap-btn-outline' style={{ marginTop: 8 }} onClick={() => toggleRule(r)}>
                {r.is_active ? 'Deactivate' : 'Activate'}
              </button>
            </div>
          )
        })}
      </div>
    </main>
  )
}
