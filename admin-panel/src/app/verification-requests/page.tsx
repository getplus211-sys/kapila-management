'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | null

type ReqRow = {
  request_id: string
  user_id: string
  username: string | null
  full_name: string | null
  status: 'pending' | 'approved' | 'rejected' | 'needs_more_info'
  doc_type: string
  doc_front_url: string | null
  doc_back_url: string | null
  doc_extra_url: string | null
  submitted_note: string | null
  review_note: string | null
  created_at: string
  updated_at: string
}

type UserMeta = {
  user_id: string
  email: string | null
  mobile: string | null
  district: string | null
}

type Overview = {
  posts_count?: number
  total_views?: number
  likes_count?: number
  comments_count?: number
  profile_visits?: number
}

export default function VerificationRequestsPage() {
  const [rows, setRows] = useState<ReqRow[]>([])
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<Role>(null)
  const [status, setStatus] = useState<string>('pending')
  const [msg, setMsg] = useState('')
  const [counts, setCounts] = useState<Record<string, number>>({})
  const [userMeta, setUserMeta] = useState<Record<string, UserMeta>>({})
  const [overviewOpenId, setOverviewOpenId] = useState('')
  const [overviewLoadingId, setOverviewLoadingId] = useState('')
  const [overviewByUserId, setOverviewByUserId] = useState<Record<string, Overview>>({})

  async function markSeen(requestIds: string[], adminUserId: string) {
    if (!requestIds.length || !adminUserId) return
    const rowsToInsert = requestIds.map((id) => ({
      admin_user_id: adminUserId,
      action_type: 'verification_seen',
      target_table: 'ngm_verification_requests',
      target_id: id,
      new_data: { seen: true },
    }))
    await supabase.from('ngm_admin_actions_log').insert(rowsToInsert)
  }

  async function loadRows() {
    setLoading(true)
    setMsg('')
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) {
      setRole(null)
      setRows([])
      setLoading(false)
      return
    }

    const { data: roleData, error: roleErr } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (roleErr || !roleData || roleData.is_active !== true || !['owner', 'admin'].includes(roleData.role)) {
      setRole(null)
      setRows([])
      setMsg(roleErr?.message ?? 'Access denied. Owner/Admin only.')
      setLoading(false)
      return
    }
    setRole(roleData.role as Role)

    const [pendingRes, approvedRes, rejectedRes, moreInfoRes] = await Promise.all([
      supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'pending'),
      supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'approved'),
      supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'rejected'),
      supabase.from('ngm_verification_requests').select('request_id', { head: true, count: 'exact' }).eq('status', 'needs_more_info'),
    ])
    setCounts({
      pending: Number(pendingRes.count ?? 0),
      approved: Number(approvedRes.count ?? 0),
      rejected: Number(rejectedRes.count ?? 0),
      needs_more_info: Number(moreInfoRes.count ?? 0),
    })

    const { data, error } = await supabase.rpc('ngm_admin_list_verification_requests', {
      p_status: status,
      p_limit: 100,
      p_offset: 0,
    })
    if (error) {
      setMsg(error.message)
      setRows([])
    } else {
      const nextRows = (data ?? []) as ReqRow[]
      setRows(nextRows)

      const ids = [...new Set(nextRows.map((r) => r.user_id).filter(Boolean))]
      if (ids.length > 0) {
        const { data: usersData } = await supabase
          .from('ngm_users')
          .select('user_id,email,mobile,district')
          .in('user_id', ids)
        const map: Record<string, UserMeta> = {}
        for (const u of (usersData ?? []) as UserMeta[]) map[u.user_id] = u
        setUserMeta(map)
      } else {
        setUserMeta({})
      }

      if (status === 'pending') {
        await markSeen(nextRows.map((r) => r.request_id), user.id)
      }
    }
    setLoading(false)
  }

  async function review(requestId: string, newStatus: 'approved' | 'rejected' | 'needs_more_info') {
    const note = prompt('Review note (optional):') ?? null
    const { data, error } = await supabase.rpc('ngm_admin_review_verification', {
      p_request_id: requestId,
      p_status: newStatus,
      p_review_note: note,
    })
    if (error) {
      alert(error.message)
      return
    }
    alert('Updated: ' + (data?.status ?? newStatus))
    await loadRows()
  }

  async function loadOverview(userId: string) {
    if (!userId) return
    if (overviewByUserId[userId]) {
      setOverviewOpenId((p) => (p === userId ? '' : userId))
      return
    }
    setOverviewLoadingId(userId)
    const { data } = await supabase.rpc('ngm_get_creator_overview', {
      p_user_id: userId,
      p_range: 'month',
    })
    setOverviewLoadingId('')

    const root = (Array.isArray(data) ? data[0] : data) as Record<string, unknown> | null
    const overview =
      (root?.overview as Overview | undefined) ??
      (root?.ngm_get_creator_overview as Overview | undefined) ??
      (root as Overview | null) ??
      {}
    setOverviewByUserId((prev) => ({ ...prev, [userId]: overview }))
    setOverviewOpenId((p) => (p === userId ? '' : userId))
  }

  useEffect(() => {
    loadRows()
    logAdminPageView('verification_requests')
  }, [status])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Verification Requests</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>

      <div className='kap-card' style={{ marginBottom: 12 }}>
        <b>Total Approved:</b> {counts.approved ?? 0}
      </div>

      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        {['pending', 'approved', 'rejected', 'needs_more_info'].map((s) => (
          <button
            key={s}
            onClick={() => setStatus(s)}
            className={`kap-btn ${status === s ? 'kap-btn-primary' : 'kap-btn-outline'}`}
          >
            {s} ({counts[s] ?? 0})
          </button>
        ))}
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}
      {!loading && !role ? <p className='kap-msg'>Access denied.</p> : null}

      {!loading && role && rows.length === 0 ? <p>No requests.</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.request_id} className='kap-card'>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
              <div>
                <p>
                  <b>{r.full_name ?? 'User'}</b>{' '}
                  {r.username ? `(@${r.username})` : ''}
                </p>
                <p style={{ fontSize: 13, color: '#6b7280' }}>User: {r.user_id}</p>
                <p style={{ fontSize: 13, color: '#6b7280' }}>Email: {userMeta[r.user_id]?.email ?? '-'}</p>
                <p style={{ fontSize: 13, color: '#6b7280' }}>Mobile: {userMeta[r.user_id]?.mobile ?? '-'}</p>
                <p style={{ fontSize: 13, color: '#6b7280' }}>District: {userMeta[r.user_id]?.district ?? '-'}</p>
                <p style={{ fontSize: 13, color: '#6b7280' }}>
                  Type: {r.doc_type} | Status: <span className='kap-chip'>{r.status}</span>
                </p>
              </div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <Link href={`/user-profile/${r.user_id}`} className='kap-btn kap-btn-outline'>
                  View Profile
                </Link>
                <button
                  onClick={() => loadOverview(r.user_id)}
                  className='kap-btn kap-btn-outline'
                >
                  {overviewLoadingId === r.user_id ? 'Loading...' : 'Profile Overview'}
                </button>
                <button onClick={() => review(r.request_id, 'approved')} className='kap-btn kap-btn-primary'>Approve</button>
                <button onClick={() => review(r.request_id, 'rejected')} className='kap-btn kap-btn-danger'>Reject</button>
                <button onClick={() => review(r.request_id, 'needs_more_info')} className='kap-btn kap-btn-outline'>Need Info</button>
              </div>
            </div>

            {r.submitted_note ? <p style={{ marginTop: 8 }}><b>User note:</b> {r.submitted_note}</p> : null}

            <div style={{ marginTop: 8, display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              {r.doc_front_url ? <a href={r.doc_front_url} target='_blank' className='kap-subtle-link'>Front Doc</a> : null}
              {r.doc_back_url ? <a href={r.doc_back_url} target='_blank' className='kap-subtle-link'>Back Doc</a> : null}
              {r.doc_extra_url ? <a href={r.doc_extra_url} target='_blank' className='kap-subtle-link'>Extra Doc</a> : null}
            </div>

            {overviewOpenId === r.user_id ? (
              <div className='kap-card' style={{ marginTop: 10, background: '#f8fafc' }}>
                <p><b>Overview (Last Month)</b></p>
                <p style={{ fontSize: 13, color: '#475569' }}>
                  Posts: {overviewByUserId[r.user_id]?.posts_count ?? 0} | Views: {overviewByUserId[r.user_id]?.total_views ?? 0}
                </p>
                <p style={{ fontSize: 13, color: '#475569' }}>
                  Likes: {overviewByUserId[r.user_id]?.likes_count ?? 0} | Comments: {overviewByUserId[r.user_id]?.comments_count ?? 0}
                </p>
                <p style={{ fontSize: 13, color: '#475569' }}>
                  Profile Visits: {overviewByUserId[r.user_id]?.profile_visits ?? 0}
                </p>
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </main>
  )
}
