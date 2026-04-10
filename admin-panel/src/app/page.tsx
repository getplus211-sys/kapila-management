'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'
import { hasModerationAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'

type BadgeCounts = {
  verificationPending: number
  reportsPending: number
  suggestionsPending: number
  nonEducationalReportsPending: number
}

function badgeClassByCount(count: number) {
  if (count <= 5) return 'kap-badge kap-badge-green'
  if (count <= 10) return 'kap-badge kap-badge-yellow'
  if (count <= 20) return 'kap-badge kap-badge-orange'
  if (count <= 49) return 'kap-badge kap-badge-dark-orange'
  return 'kap-badge kap-badge-red'
}

export default function HomePage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<AdminRole>(null)
  const [msg, setMsg] = useState('')
  const [counts, setCounts] = useState<BadgeCounts>({
    verificationPending: 0,
    reportsPending: 0,
    suggestionsPending: 0,
    nonEducationalReportsPending: 0,
  })

  async function checkAccess() {
    setLoading(true)
    setMsg('')
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user

    if (!user) {
      setRole(null)
      setLoading(false)
      return
    }

    const { data, error } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (error) {
      setMsg(error.message)
      setRole(null)
    } else if (!data || data.is_active !== true) {
      setRole(null)
      setMsg('No admin access for this account.')
    } else {
      setRole((data.role as AdminRole) ?? null)
    }

    setLoading(false)
  }

  async function loadBadges() {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) {
      setCounts({
        verificationPending: 0,
        reportsPending: 0,
        suggestionsPending: 0,
        nonEducationalReportsPending: 0,
      })
      return
    }

    const [vReq, postRep, quizRep, pollRep, userRep, sugg, seenLogs, nonEduCountRes] = await Promise.all([
      supabase
        .from('ngm_verification_requests')
        .select('request_id')
        .eq('status', 'pending'),
      supabase
        .from('ngm_post_reports')
        .select('report_id')
        .eq('status', 'pending'),
      supabase
        .from('ngm_quiz_reports')
        .select('report_id')
        .eq('status', 'pending'),
      supabase
        .from('ngm_poll_reports')
        .select('report_id')
        .eq('status', 'pending'),
      supabase
        .from('ngm_user_reports')
        .select('report_id')
        .eq('status', 'pending'),
      supabase
        .from('kls_questions')
        .select('id')
        .not('suggestion', 'is', null)
        .neq('suggestion', ''),
      supabase
        .from('ngm_admin_actions_log')
        .select('action_type,target_table,target_id')
        .eq('admin_user_id', user.id)
        .in('action_type', ['verification_seen', 'report_seen', 'suggestion_seen'])
        .limit(3000),
      supabase.rpc('ngm_admin_count_pending_non_educational_reports'),
    ])

    const seen = (seenLogs.data ?? []) as Array<{
      action_type: string
      target_table: string
      target_id: string
    }>
    const seenVerification = new Set(
      seen.filter((x) => x.action_type === 'verification_seen' && x.target_table === 'ngm_verification_requests').map((x) => x.target_id),
    )
    const seenReports = new Set(
      seen.filter((x) => x.action_type === 'report_seen' && x.target_table === 'ngm_reports').map((x) => x.target_id),
    )
    const seenSuggestions = new Set(
      seen.filter((x) => x.action_type === 'suggestion_seen' && x.target_table === 'kls_questions').map((x) => x.target_id),
    )

    const pendingVerificationIds = (vReq.data ?? []).map((x: { request_id: string }) => x.request_id)
    const pendingReportIds = [
      ...(postRep.data ?? []).map((x: { report_id: string }) => `ngm_post_reports:${x.report_id}`),
      ...(quizRep.data ?? []).map((x: { report_id: string }) => `ngm_quiz_reports:${x.report_id}`),
      ...(pollRep.data ?? []).map((x: { report_id: string }) => `ngm_poll_reports:${x.report_id}`),
      ...(userRep.data ?? []).map((x: { report_id: string }) => `ngm_user_reports:${x.report_id}`),
    ]
    const pendingSuggestionIds = (sugg.data ?? []).map((x: { id: string }) => x.id)

    setCounts({
      verificationPending: pendingVerificationIds.filter((id) => !seenVerification.has(id)).length,
      reportsPending: pendingReportIds.filter((id) => !seenReports.has(id)).length,
      suggestionsPending: pendingSuggestionIds.filter((id) => !seenSuggestions.has(id)).length,
      nonEducationalReportsPending: Number(nonEduCountRes.data ?? 0),
    })
  }

  async function login() {
    setMsg('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) setMsg(error.message)
    await checkAccess()
  }

  async function logout() {
    await supabase.auth.signOut()
    setRole(null)
    setMsg('Logged out.')
  }

  useEffect(() => {
    checkAccess()
    loadBadges()
    logAdminPageView('dashboard')
  }, [])

  if (loading) {
    return <main className='kap-wrap'>Loading...</main>
  }

  return (
    <main className='kap-wrap' style={{ maxWidth: 860 }}>
      <div className='kap-head'>
        <h1 className='kap-title'>Admin Panel</h1>
      </div>

      {role ? (
        <div className='kap-card'>
          <p><b>Access Granted:</b> <span className='kap-chip'>{role}</span></p>
          <p style={{ marginTop: 8, marginBottom: 12, color: 'var(--kap-muted)' }}>Choose a module:</p>
          <div className='kap-grid kap-module-grid'>
            {role === 'owner' ? (
              <Link href='/analytics' className='kap-module-card kap-mod-analytics'>
                <span className='kap-module-title'>App Analytics (Owner)</span>
              </Link>
            ) : null}
            {role === 'owner' ? (
              <Link href='/analytics/revenue' className='kap-module-card kap-mod-analytics'>
                <span className='kap-module-title'>Revenue Analytics (Owner)</span>
              </Link>
            ) : null}
            {hasModerationAccess(role) ? (
              <>
                <Link href='/verification-requests' className='kap-module-card kap-mod-verify-req'>
                  <span className='kap-module-title'>Verification Requests</span>
                  {counts.verificationPending > 0 ? (
                    <span className={badgeClassByCount(counts.verificationPending)}>{counts.verificationPending}</span>
                  ) : null}
                </Link>
                <Link href='/verified-users' className='kap-module-card kap-mod-verified'>
                  <span className='kap-module-title'>Verified Users</span>
                </Link>
                <Link href='/moderation-reports' className='kap-module-card kap-mod-reports'>
                  <span className='kap-module-title'>Reports</span>
                  {counts.reportsPending > 0 ? (
                    <span className={badgeClassByCount(counts.reportsPending)}>{counts.reportsPending}</span>
                  ) : null}
                </Link>
                <Link href='/moderation-reports?tab=non_edu' className='kap-module-card kap-mod-non-edu'>
                  <span className='kap-module-title'>Non-Educational Reports</span>
                  {counts.nonEducationalReportsPending > 0 ? (
                    <span className={badgeClassByCount(counts.nonEducationalReportsPending)}>
                      {counts.nonEducationalReportsPending}
                    </span>
                  ) : null}
                </Link>
                <Link href='/suggestions' className='kap-module-card kap-mod-suggestions'>
                  <span className='kap-module-title'>Suggestions</span>
                  {counts.suggestionsPending > 0 ? (
                    <span className={badgeClassByCount(counts.suggestionsPending)}>{counts.suggestionsPending}</span>
                  ) : null}
                </Link>
                <Link href='/feedback-replies' className='kap-module-card kap-mod-feedback'>
                  <span className='kap-module-title'>Ask/Feedback Replies</span>
                </Link>
              </>
            ) : null}
            {hasSalesAccess(role) ? (
              <>
                <Link href='/affiliate-requests' className='kap-module-card kap-mod-affiliate'>
                  <span className='kap-module-title'>Affiliate Requests</span>
                </Link>
                <Link href='/affiliate-payouts' className='kap-module-card kap-mod-payouts'>
                  <span className='kap-module-title'>Affiliate Payouts</span>
                </Link>
                <Link href='/affiliate-commission-rules' className='kap-module-card kap-mod-affiliate-rules'>
                  <span className='kap-module-title'>Affiliate Commission Rules</span>
                </Link>
                <Link href='/subscription-plans' className='kap-module-card kap-mod-subscription'>
                  <span className='kap-module-title'>Subscription Plans</span>
                </Link>
                <Link href='/test-series' className='kap-module-card kap-mod-series'>
                  <span className='kap-module-title'>Test Series Manager</span>
                </Link>
                <Link href='/mock-broadcast' className='kap-module-card kap-mod-mock'>
                  <span className='kap-module-title'>Mock Broadcast</span>
                </Link>
                <Link href='/notification-broadcast' className='kap-module-card kap-mod-notification'>
                  <span className='kap-module-title'>Notification Broadcast</span>
                </Link>
              </>
            ) : null}
            {role === 'owner' ? (
              <Link href='/admin-users' className='kap-module-card kap-mod-admin'>
                <span className='kap-module-title'>Admin Users</span>
              </Link>
            ) : null}
            {role === 'owner' ? (
              <Link href='/audit-logs' className='kap-module-card kap-mod-audit'>
                <span className='kap-module-title'>Audit Logs</span>
              </Link>
            ) : null}
          </div>
          <button onClick={logout} className='kap-btn kap-btn-outline' style={{ marginTop: 12 }}>Logout</button>
        </div>
      ) : (
        <div className='kap-card'>
          <p style={{ marginBottom: 12 }}><b>Login (Admin/Owner account)</b></p>
          <input
            placeholder='Email'
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className='kap-input'
          />
          <input
            placeholder='Password'
            type='password'
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className='kap-input'
            style={{ marginTop: 8 }}
          />
          <button onClick={login} className='kap-btn kap-btn-primary' style={{ marginTop: 10 }}>Login</button>
        </div>
      )}

      {msg ? <p className='kap-msg'>{msg}</p> : null}
    </main>
  )
}
