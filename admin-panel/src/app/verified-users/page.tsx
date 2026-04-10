'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | null

type VerifiedRow = {
  user_id: string
  username: string | null
  full_name: string | null
  is_verified: boolean
  manual_verified: boolean
  auto_verified: boolean
}

export default function VerifiedUsersPage() {
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<Role>(null)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<VerifiedRow[]>([])

  async function checkAccessAndLoad() {
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

    const { data, error } = await supabase.rpc('ngm_admin_list_verified_users', {
      p_limit: 500,
      p_offset: 0,
    })
    if (error) {
      setRows([])
      setMsg(error.message)
    } else {
      setRows((data ?? []) as VerifiedRow[])
    }

    setLoading(false)
  }

  useEffect(() => {
    checkAccessAndLoad()
    logAdminPageView('verified_users')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Verified Users</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {loading ? <p>Loading...</p> : null}
      {!loading && !role ? <p style={{ color: '#b91c1c' }}>Access denied.</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {!loading && role && rows.length === 0 ? <p>No verified users found.</p> : null}

      <div className='kap-grid'>
        {rows.map((r) => (
          <div key={r.user_id} className='kap-card'>
            <p><b>{r.full_name ?? 'User'}</b> {r.username ? `(@${r.username})` : ''}</p>
            <p style={{ color: '#6b7280', fontSize: 13 }}>{r.user_id}</p>
            <p style={{ marginTop: 4, fontSize: 13 }}>
              manual_verified: <span className='kap-chip'>{String(r.manual_verified)}</span>{' '}
              auto_verified: <span className='kap-chip'>{String(r.auto_verified)}</span>
            </p>
            <div style={{ marginTop: 8 }}>
              <Link href={`/user-profile/${r.user_id}`} className='kap-btn kap-btn-outline'>
                View Profile
              </Link>
            </div>
          </div>
        ))}
      </div>
    </main>
  )
}
