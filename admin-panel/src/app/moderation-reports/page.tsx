'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | null

type TabMode = 'all' | 'non_edu' | 'archive'

type ReportRow = {
  report_id: string
  content_id: string
  reported_by: string
  report_details?: string | null
  target_user_id?: string
  report_reason: string
  status: string
  created_at: string
  source_table: string
  is_non_educational?: boolean
}

type NonEducationalGroupedRow = {
  report_type: 'post' | 'poll' | 'quiz' | 'user'
  content_id: string
  reports_count: number
  first_report_at: string
  latest_report_at: string
}

type BreakdownRow = {
  report_type: 'post' | 'poll' | 'quiz' | 'user'
  pending_count: number
}

type PostReportDbRow = {
  report_id: string
  post_id: string
  reported_by: string
  report_reason: string
  report_details: string | null
  status: string | null
  created_at: string
  is_non_educational: boolean | null
}

type QuizReportDbRow = {
  report_id: string
  quiz_id: string
  reported_by: string
  report_reason: string
  status: string | null
  created_at: string
  is_non_educational: boolean | null
}

type PollReportDbRow = {
  report_id: string
  poll_id: string
  reported_by: string
  report_reason: string
  status: string | null
  created_at: string
  is_non_educational: boolean | null
}

type UserReportDbRow = {
  report_id: string
  reported_user_id: string
  reporter_user_id: string
  report_reason: string
  report_details: string | null
  status: string | null
  created_at: string
  is_non_educational: boolean | null
}

type PendingNonEduRow = {
  report_type: 'post' | 'poll' | 'quiz' | 'user'
  report_id: string
  content_id: string
  reporter_user_id: string
  report_reason: string
  report_details: string | null
  status: string
  is_non_educational: boolean
  created_at: string
}

type ArchiveReportRow = {
  archive_id: string
  source_table: string
  report_id: string
  status: string | null
  resolved_by: string | null
  resolution_notes: string | null
  resolved_at: string | null
  archived_at: string
  payload: Record<string, unknown>
}

type ReportReplyRow = {
  reply_id: string
  report_table: string
  report_id: string
  user_id: string
  admin_user_id: string
  reply_text: string
  created_at: string
}

type UserMeta = {
  user_id: string
  username: string | null
  full_name: string | null
  email: string | null
  mobile: string | null
  district: string | null
}

function mapReportTypeToSourceTable(reportType: string) {
  if (reportType === 'post') return 'ngm_post_reports'
  if (reportType === 'poll') return 'ngm_poll_reports'
  if (reportType === 'quiz') return 'ngm_quiz_reports'
  return 'ngm_user_reports'
}

export default function ModerationReportsPage() {
  const searchParams = useSearchParams()
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<Role>(null)
  const [msg, setMsg] = useState('')
  const [tab, setTab] = useState<TabMode>(
    searchParams.get('tab') === 'non_edu' ? 'non_edu' : 'all',
  )
  const [rows, setRows] = useState<ReportRow[]>([])
  const [nonEduRows, setNonEduRows] = useState<ReportRow[]>([])
  const [archiveRows, setArchiveRows] = useState<ArchiveReportRow[]>([])
  const [groupedRows, setGroupedRows] = useState<NonEducationalGroupedRow[]>([])
  const [nonEduCount, setNonEduCount] = useState(0)
  const [breakdown, setBreakdown] = useState<Record<string, number>>({})
  const [replyingId, setReplyingId] = useState<string>('')
  const [replyBoxId, setReplyBoxId] = useState<string>('')
  const [replyText, setReplyText] = useState<string>('')
  const [resolvingId, setResolvingId] = useState<string>('')
  const [repliesByReport, setRepliesByReport] = useState<Record<string, ReportReplyRow[]>>({})
  const [userMetaById, setUserMetaById] = useState<Record<string, UserMeta>>({})
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [lastSyncedAt, setLastSyncedAt] = useState<string>('')

  async function loadReports() {
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

    const [postRes, quizRes, pollRes, userRes, nonEduCountRes, nonEduBreakdownRes, nonEduListRes, nonEduGroupedRes, repliesRes, archiveRes] = await Promise.all([
      supabase
        .from('ngm_post_reports')
        .select('report_id,post_id,reported_by,report_reason,report_details,status,created_at,is_non_educational')
        .order('created_at', { ascending: false })
        .limit(200),
      supabase
        .from('ngm_quiz_reports')
        .select('report_id,quiz_id,reported_by,report_reason,status,created_at,is_non_educational')
        .order('created_at', { ascending: false })
        .limit(200),
      supabase
        .from('ngm_poll_reports')
        .select('report_id,poll_id,reported_by,report_reason,status,created_at,is_non_educational')
        .order('created_at', { ascending: false })
        .limit(200),
      supabase
        .from('ngm_user_reports')
        .select('report_id,reported_user_id,reporter_user_id,report_reason,report_details,status,created_at,is_non_educational')
        .order('created_at', { ascending: false })
        .limit(200),
      supabase.rpc('ngm_admin_count_pending_non_educational_reports'),
      supabase.rpc('ngm_admin_pending_non_educational_breakdown'),
      supabase.rpc('ngm_admin_list_pending_non_educational_reports_by_type', {
        p_report_type: null,
        p_limit: 200,
        p_offset: 0,
      }),
      supabase.rpc('ngm_admin_list_pending_non_educational_grouped', {
        p_report_type: null,
        p_limit: 200,
        p_offset: 0,
      }),
      supabase
        .from('ngm_report_replies')
        .select('reply_id,report_table,report_id,user_id,admin_user_id,reply_text,created_at')
        .order('created_at', { ascending: false })
        .limit(1000),
      supabase.rpc('ngm_admin_list_resolved_reports_archive', {
        p_limit: 300,
        p_offset: 0,
        p_source_table: null,
      }),
    ])

    const firstErr = postRes.error ?? quizRes.error ?? pollRes.error ?? userRes.error ?? repliesRes.error ?? archiveRes.error
    if (firstErr) {
      setMsg(firstErr.message)
      setRows([])
      setLoading(false)
      return
    }

    const mapped: ReportRow[] = [
      ...((postRes.data ?? []) as PostReportDbRow[]).map((r) => ({
        report_id: r.report_id,
        content_id: r.post_id,
        reported_by: r.reported_by,
        report_reason: r.report_reason,
        report_details: r.report_details,
        status: r.status ?? 'pending',
        created_at: r.created_at,
        source_table: 'ngm_post_reports',
        is_non_educational: Boolean(r.is_non_educational),
      })),
      ...((quizRes.data ?? []) as QuizReportDbRow[]).map((r) => ({
        report_id: r.report_id,
        content_id: r.quiz_id,
        reported_by: r.reported_by,
        report_reason: r.report_reason,
        status: r.status ?? 'pending',
        created_at: r.created_at,
        source_table: 'ngm_quiz_reports',
        is_non_educational: Boolean(r.is_non_educational),
      })),
      ...((pollRes.data ?? []) as PollReportDbRow[]).map((r) => ({
        report_id: r.report_id,
        content_id: r.poll_id,
        reported_by: r.reported_by,
        report_reason: r.report_reason,
        status: r.status ?? 'pending',
        created_at: r.created_at,
        source_table: 'ngm_poll_reports',
        is_non_educational: Boolean(r.is_non_educational),
      })),
      ...((userRes.data ?? []) as UserReportDbRow[]).map((r) => ({
        report_id: r.report_id,
        content_id: r.reported_user_id,
        target_user_id: r.reported_user_id,
        reported_by: r.reporter_user_id,
        report_reason: r.report_reason,
        report_details: r.report_details,
        status: r.status ?? 'pending',
        created_at: r.created_at,
        source_table: 'ngm_user_reports',
        is_non_educational: Boolean(r.is_non_educational),
      })),
    ].sort((a, b) => (a.created_at < b.created_at ? 1 : -1))

    const mappedNonEdu: ReportRow[] = ((nonEduListRes.data ?? []) as PendingNonEduRow[]).map((r) => ({
      report_id: r.report_id,
      content_id: r.content_id,
      reported_by: r.reporter_user_id,
      report_reason: r.report_reason ?? '',
      report_details: r.report_details ?? null,
      status: r.status ?? 'pending',
      created_at: r.created_at,
      source_table: mapReportTypeToSourceTable(r.report_type),
      is_non_educational: true,
    }))

    const mappedBreakdown = ((nonEduBreakdownRes.data ?? []) as BreakdownRow[]).reduce<Record<string, number>>(
      (acc, row) => {
        acc[row.report_type] = Number(row.pending_count ?? 0)
        return acc
      },
      {},
    )

    const archiveData = (archiveRes.data ?? []) as ArchiveReportRow[]
    setRows(mapped)
    setNonEduRows(mappedNonEdu)
    setArchiveRows(archiveData)
    setGroupedRows((nonEduGroupedRes.data ?? []) as NonEducationalGroupedRow[])
    setNonEduCount(Number(nonEduCountRes.data ?? 0))
    setBreakdown(mappedBreakdown)
    const replyMap: Record<string, ReportReplyRow[]> = {}
    for (const row of (repliesRes.data ?? []) as ReportReplyRow[]) {
      const key = `${row.report_table}:${row.report_id}`
      if (!replyMap[key]) {
        replyMap[key] = []
      }
      replyMap[key].push(row)
    }
    setRepliesByReport(replyMap)

    const userIds = new Set<string>()
    for (const r of mapped) {
      if (r.reported_by) userIds.add(r.reported_by)
      if (r.target_user_id) userIds.add(r.target_user_id)
    }
    for (const r of mappedNonEdu) {
      if (r.reported_by) userIds.add(r.reported_by)
      if (r.target_user_id) userIds.add(r.target_user_id)
    }
    for (const rp of (repliesRes.data ?? []) as ReportReplyRow[]) {
      if (rp.user_id) userIds.add(rp.user_id)
      if (rp.admin_user_id) userIds.add(rp.admin_user_id)
    }
    for (const a of archiveData) {
      if (a.resolved_by) userIds.add(a.resolved_by)
    }
    if (userIds.size > 0) {
      const { data: usersData } = await supabase
        .from('ngm_users')
        .select('user_id,username,full_name,email,mobile,district')
        .in('user_id', Array.from(userIds))
      const map: Record<string, UserMeta> = {}
      for (const u of (usersData ?? []) as UserMeta[]) {
        map[u.user_id] = u
      }
      setUserMetaById(map)
    } else {
      setUserMetaById({})
    }

    const seenRows = mapped.map((r) => ({
      admin_user_id: user.id,
      action_type: 'report_seen',
      target_table: 'ngm_reports',
      target_id: `${r.source_table}:${r.report_id}`,
      new_data: { seen: true },
    }))
    if (seenRows.length > 0) {
      await supabase.from('ngm_admin_actions_log').insert(seenRows)
    }
    setLastSyncedAt(new Date().toLocaleTimeString())
    setLoading(false)
  }

  useEffect(() => {
    loadReports()
    logAdminPageView('moderation_reports')
  }, [])

  useEffect(() => {
    const id = setInterval(() => {
      void loadReports()
    }, 15000)
    return () => clearInterval(id)
  }, [])

  async function manualRefresh() {
    setIsRefreshing(true)
    await loadReports()
    setIsRefreshing(false)
  }

  async function replyToUser(row: ReportRow, text: string) {
    const trimmed = text.trim()
    if (!trimmed) return
    const { data: authData } = await supabase.auth.getUser()
    const me = authData.user
    if (!me) return

    setReplyingId(row.report_id)
    const { error } = await supabase.from('ngm_report_replies').insert({
      report_table: row.source_table,
      report_id: row.report_id,
      user_id: row.reported_by,
      admin_user_id: me.id,
      reply_text: trimmed,
    })
    setReplyingId('')
    if (error) {
      alert(error.message)
      return
    }
    setReplyText('')
    setReplyBoxId('')
    alert('Reply sent to user.')
    await loadReports()
  }

  function openReplyBox(reportId: string) {
    if (replyBoxId === reportId) {
      setReplyBoxId('')
      setReplyText('')
      return
    }
    setReplyBoxId(reportId)
    setReplyText('')
  }

  function cancelReplyBox() {
    setReplyBoxId('')
    setReplyText('')
  }

  async function sendReply(row: ReportRow) {
    const text = replyText
    if (!text) return
    await replyToUser(row, text)
  }

  async function resolveReport(row: ReportRow, action: 'keep' | 'delete') {
    const note = prompt(
      action === 'delete'
        ? 'Reason for deleting content (optional):'
        : 'Reason for keeping content (optional):',
    ) ?? null

    setResolvingId(row.report_id)
    const { data, error } = await supabase.rpc('ngm_admin_resolve_report', {
      p_report_table: row.source_table,
      p_report_id: row.report_id,
      p_action: action,
      p_note: note,
    })
    setResolvingId('')

    if (error) {
      alert(error.message)
      return
    }

    alert(`Updated: ${data?.status ?? 'done'}`)
    await loadReports()
  }

  const visibleRows = tab === 'all' ? rows : nonEduRows

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Reports</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {lastSyncedAt ? (
            <span style={{ fontSize: 12, color: '#6b7280' }}>Synced: {lastSyncedAt}</span>
          ) : null}
          <button
            className='kap-btn kap-btn-outline'
            onClick={() => void manualRefresh()}
            disabled={isRefreshing || loading}
          >
            {isRefreshing ? 'Refreshing...' : 'Refresh'}
          </button>
          <Link href='/' className='kap-subtle-link'>Back</Link>
        </div>
      </div>
      {!loading && role ? (
        <div className='kap-card' style={{ marginBottom: 12 }}>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
            <button
              className='kap-btn'
              style={{
                background: tab === 'all' ? '#4f46e5' : '#fff',
                color: tab === 'all' ? '#fff' : '#312e81',
                border: '1px solid #c7d2fe',
              }}
              onClick={() => setTab('all')}
            >
              All Reports ({rows.length})
            </button>
            <button
              className='kap-btn'
              style={{
                background: tab === 'non_edu' ? '#ea580c' : '#fff',
                color: tab === 'non_edu' ? '#fff' : '#9a3412',
                border: '1px solid #fdba74',
              }}
              onClick={() => setTab('non_edu')}
            >
              Non-Educational Pending ({nonEduCount})
            </button>
            <button
              className='kap-btn'
              style={{
                background: tab === 'archive' ? '#0f766e' : '#fff',
                color: tab === 'archive' ? '#fff' : '#134e4a',
                border: '1px solid #99f6e4',
              }}
              onClick={() => setTab('archive')}
            >
              Resolved (Archive) ({archiveRows.length})
            </button>
            {tab === 'non_edu' ? (
              <span className='kap-chip' style={{ borderColor: '#fdba74', color: '#9a3412', background: '#fff7ed' }}>
                post:{breakdown.post ?? 0} | poll:{breakdown.poll ?? 0} | quiz:{breakdown.quiz ?? 0} | user:{breakdown.user ?? 0}
              </span>
            ) : null}
          </div>
        </div>
      ) : null}
      {loading ? <p>Loading...</p> : null}
      {!loading && !role ? <p style={{ color: '#b91c1c' }}>Access denied.</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {!loading && role && tab !== 'archive' && visibleRows.length === 0 ? <p>No reports found.</p> : null}
      {!loading && role && tab === 'archive' && archiveRows.length === 0 ? <p>No archived reports found.</p> : null}

      {!loading && role && tab === 'non_edu' && groupedRows.length > 0 ? (
        <div className='kap-card' style={{ marginBottom: 12 }}>
          <p style={{ fontWeight: 800, marginBottom: 8 }}>Grouped By Same Content</p>
          <div style={{ display: 'grid', gap: 8 }}>
            {groupedRows.map((g) => (
              <div
                key={`${g.report_type}:${g.content_id}`}
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  gap: 8,
                  border: '1px solid #fed7aa',
                  borderRadius: 10,
                  background: '#fff7ed',
                  padding: 10,
                }}
              >
                <div>
                  <b>{g.report_type.toUpperCase()}</b> | Content: {g.content_id}
                </div>
                <div style={{ fontWeight: 800 }}>Reports: {g.reports_count}</div>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {tab === 'archive' ? (
        <div className='kap-grid'>
          {archiveRows.map((a) => (
            <div key={a.archive_id} className='kap-card'>
              <p>
                <b>{a.source_table}</b> | <b>Status:</b> <span className='kap-chip'>{a.status ?? 'resolved'}</span>
              </p>
              <p style={{ fontSize: 13 }}><b>Report ID:</b> {a.report_id}</p>
              <p style={{ fontSize: 13 }}>
                <b>Resolved By:</b>{' '}
                {a.resolved_by ? (
                  <>
                    {userMetaById[a.resolved_by]?.full_name ?? a.resolved_by}
                    {userMetaById[a.resolved_by]?.username ? ` (@${userMetaById[a.resolved_by]?.username})` : ''}
                  </>
                ) : '-'}
              </p>
              {a.resolved_by ? (
                <p style={{ marginTop: 6 }}>
                  <Link href={`/user-profile/${a.resolved_by}`} className='kap-btn kap-btn-outline'>
                    View Resolver Profile
                  </Link>
                </p>
              ) : null}
              {a.resolution_notes ? (
                <p style={{ marginTop: 4 }}><b>Resolution Note:</b> {a.resolution_notes}</p>
              ) : null}
              <p style={{ color: '#6b7280', fontSize: 12, marginTop: 4 }}>
                Resolved: {a.resolved_at ? new Date(a.resolved_at).toLocaleString() : '-'} | Archived: {new Date(a.archived_at).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      ) : (
      <div className='kap-grid'>
        {visibleRows.map((r) => (
          <div key={`${r.source_table}_${r.report_id}`} className='kap-card'>
            <p>
              <b>{r.source_table}</b> | <b>Status:</b> <span className='kap-chip'>{r.status}</span>
              {r.is_non_educational ? (
                <span className='kap-chip' style={{ marginLeft: 8, borderColor: '#fdba74', color: '#9a3412', background: '#fff7ed' }}>
                  Non-Educational
                </span>
              ) : null}
            </p>
            <p style={{ fontSize: 13 }}>
              <b>{r.source_table === 'ngm_user_reports' ? 'Target User' : 'Content'}:</b> {r.content_id}
            </p>
            {r.source_table === 'ngm_user_reports' && r.target_user_id ? (
              <p style={{ fontSize: 13 }}>
                <b>Target User:</b>{' '}
                {userMetaById[r.target_user_id]?.full_name ?? r.target_user_id}
                {userMetaById[r.target_user_id]?.username ? ` (@${userMetaById[r.target_user_id]?.username})` : ''}
              </p>
            ) : null}
            <p style={{ fontSize: 13 }}>
              <b>Reported by:</b>{' '}
              {userMetaById[r.reported_by]?.full_name ?? r.reported_by}
              {userMetaById[r.reported_by]?.username ? ` (@${userMetaById[r.reported_by]?.username})` : ''}
            </p>
            <p style={{ fontSize: 13, color: '#6b7280' }}>
              Email: {userMetaById[r.reported_by]?.email ?? '-'} | Mobile: {userMetaById[r.reported_by]?.mobile ?? '-'} | District: {userMetaById[r.reported_by]?.district ?? '-'}
            </p>
            <p style={{ marginTop: 4 }}><b>Reason:</b> {r.report_reason}</p>
            {r.report_details ? (
              <p style={{ marginTop: 4, fontSize: 12, color: '#6b7280' }}><b>Details:</b> {r.report_details}</p>
            ) : null}
            {(repliesByReport[`${r.source_table}:${r.report_id}`] ?? []).length > 0 ? (
              <div style={{ marginTop: 8, border: '1px solid #e5e7eb', borderRadius: 10, padding: 8, background: '#f8fafc' }}>
                <p style={{ fontSize: 12, fontWeight: 800, marginBottom: 6 }}>Previous Replies</p>
                <div style={{ display: 'grid', gap: 6 }}>
                  {(repliesByReport[`${r.source_table}:${r.report_id}`] ?? []).map((rp) => (
                    <div
                      key={rp.reply_id}
                      style={{
                        border: '1px solid #e2e8f0',
                        borderRadius: 8,
                        padding: 8,
                        background: '#ffffff',
                        fontSize: 12,
                      }}
                    >
                      <div>
                        <b>Admin:</b> {userMetaById[rp.admin_user_id]?.full_name ?? rp.admin_user_id}
                        {userMetaById[rp.admin_user_id]?.username ? ` (@${userMetaById[rp.admin_user_id]?.username})` : ''}
                      </div>
                      <div style={{ marginTop: 2 }}>{rp.reply_text}</div>
                      <div style={{ marginTop: 3, color: '#64748b' }}>{new Date(rp.created_at).toLocaleString()}</div>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
              <button
                className='kap-btn kap-btn-outline'
                disabled={resolvingId === r.report_id}
                onClick={() => resolveReport(r, 'keep')}
              >
                {resolvingId === r.report_id ? 'Working...' : 'Resolve Keep'}
              </button>
              <button
                className='kap-btn kap-btn-danger'
                disabled={resolvingId === r.report_id}
                onClick={() => resolveReport(r, 'delete')}
              >
                {resolvingId === r.report_id ? 'Working...' : (r.source_table === 'ngm_user_reports' ? 'Take Action' : 'Delete Content')}
              </button>
              <button
                className='kap-btn kap-btn-outline'
                disabled={replyingId === r.report_id}
                onClick={() => openReplyBox(r.report_id)}
              >
                {replyBoxId === r.report_id ? 'Close Reply' : 'Reply to User'}
              </button>
              <Link href={`/user-profile/${r.reported_by}`} className='kap-btn kap-btn-outline'>
                View Reporter Profile
              </Link>
              {r.source_table === 'ngm_user_reports' && r.target_user_id ? (
                <Link href={`/user-profile/${r.target_user_id}`} className='kap-btn kap-btn-outline'>
                  View Target Profile
                </Link>
              ) : null}
            </div>
            {replyBoxId === r.report_id ? (
              <div style={{ marginTop: 10, display: 'grid', gap: 8 }}>
                <textarea
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  rows={3}
                  placeholder='Write reply for this user...'
                  style={{
                    width: '100%',
                    border: '1px solid #d1d5db',
                    borderRadius: 10,
                    padding: 10,
                    fontSize: 14,
                    outline: 'none',
                  }}
                />
                <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                  <button
                    className='kap-btn kap-btn-outline'
                    onClick={cancelReplyBox}
                    disabled={replyingId === r.report_id}
                  >
                    Cancel
                  </button>
                  <button
                    className='kap-btn'
                    onClick={() => sendReply(r)}
                    disabled={replyingId === r.report_id || !replyText.trim()}
                  >
                    {replyingId === r.report_id ? 'Sending...' : 'Send Reply'}
                  </button>
                </div>
              </div>
            ) : null}
            <p style={{ color: '#6b7280', fontSize: 12, marginTop: 4 }}>{new Date(r.created_at).toLocaleString()}</p>
          </div>
        ))}
      </div>
      )}
    </main>
  )
}
