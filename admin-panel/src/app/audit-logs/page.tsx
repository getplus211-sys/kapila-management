'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator'

type LogRow = {
  id?: string
  action_id?: string
  admin_user_id?: string
  action_type?: string
  target_table?: string
  target_id?: string
  payload?: Record<string, unknown> | null
  created_at?: string
}

type UserMeta = {
  user_id: string
  username: string | null
  full_name: string | null
  email: string | null
  mobile: string | null
  district: string | null
}

export default function AuditLogsPage() {
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<LogRow[]>([])
  const [myRole, setMyRole] = useState<Role | null>(null)
  const [userMetaById, setUserMetaById] = useState<Record<string, UserMeta>>({})

  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

  async function checkAccess() {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) return null

    const { data } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (!data || data.is_active !== true) return null
    return data.role as Role
  }

  async function loadLogs() {
    setLoading(true)
    setMsg('')
    const role = await checkAccess()
    setMyRole(role)
    if (role !== 'owner') {
      setRows([])
      setMsg('Access denied. Owner only.')
      setLoading(false)
      return
    }

    const { data, error } = await supabase
      .from('ngm_admin_actions_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200)

    if (error) {
      setMsg(error.message)
      setRows([])
      setLoading(false)
      return
    }

    const logRows = (data ?? []) as LogRow[]
    setRows(logRows)

    const userIds = new Set<string>()
    for (const r of logRows) {
      if (r.admin_user_id && uuidRegex.test(r.admin_user_id)) {
        userIds.add(r.admin_user_id)
      }
      if (r.target_id && uuidRegex.test(r.target_id)) {
        userIds.add(r.target_id)
      }
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

    setLoading(false)
  }

  useEffect(() => {
    loadLogs()
    logAdminPageView('audit_logs')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Audit Logs</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className='kap-btn kap-btn-outline' onClick={loadLogs}>Refresh</button>
          <Link href='/' className='kap-subtle-link'>Back</Link>
        </div>
      </div>

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      {!loading && myRole === 'owner' ? (
        <div className='kap-grid'>
          {rows.map((r, idx) => (
            <div className='kap-card' key={`${r.action_id ?? r.id ?? 'log'}_${idx}`}>
              <p><b>Action:</b> {r.action_type ?? '-'}</p>
              <p>
                <b>Admin:</b>{' '}
                {r.admin_user_id
                  ? (userMetaById[r.admin_user_id]?.full_name ?? r.admin_user_id)
                  : '-'}
                {r.admin_user_id && userMetaById[r.admin_user_id]?.username
                  ? ` (@${userMetaById[r.admin_user_id]?.username})`
                  : ''}
              </p>
              {r.admin_user_id && userMetaById[r.admin_user_id] ? (
                <p style={{ fontSize: 12, color: 'var(--kap-muted)' }}>
                  {userMetaById[r.admin_user_id]?.email ?? '-'} | {userMetaById[r.admin_user_id]?.mobile ?? '-'} | {userMetaById[r.admin_user_id]?.district ?? '-'}
                </p>
              ) : null}
              <p><b>Table:</b> {r.target_table ?? '-'}</p>
              <p>
                <b>Target:</b>{' '}
                {r.target_id
                  ? (userMetaById[r.target_id]?.full_name ?? r.target_id)
                  : '-'}
                {r.target_id && userMetaById[r.target_id]?.username
                  ? ` (@${userMetaById[r.target_id]?.username})`
                  : ''}
              </p>
              <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                {r.admin_user_id && userMetaById[r.admin_user_id] ? (
                  <Link href={`/user-profile/${r.admin_user_id}`} className='kap-btn kap-btn-outline'>
                    View Admin Profile
                  </Link>
                ) : null}
                {r.target_id && userMetaById[r.target_id] ? (
                  <Link href={`/user-profile/${r.target_id}`} className='kap-btn kap-btn-outline'>
                    View Target Profile
                  </Link>
                ) : null}
              </div>
              <p style={{ color: 'var(--kap-muted)', fontSize: 12 }}>
                {r.created_at ? new Date(r.created_at).toLocaleString() : '-'}
              </p>
            </div>
          ))}
          {!rows.length ? <p>No audit logs found.</p> : null}
        </div>
      ) : null}
    </main>
  )
}
