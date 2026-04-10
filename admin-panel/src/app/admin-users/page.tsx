'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | 'sales_manager' | 'sales_agent'

type AdminRow = {
  user_id: string
  role: Role
  is_active: boolean
}

export default function AdminUsersPage() {
  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [rows, setRows] = useState<AdminRow[]>([])
  const [myRole, setMyRole] = useState<Role | null>(null)
  const [inputEmail, setInputEmail] = useState('')
  const [inputRole, setInputRole] = useState<Role>('moderator')

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

  async function loadRows() {
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
      .from('ngm_admin_roles')
      .select('user_id,role,is_active')
      .order('role', { ascending: true })

    if (error) {
      setMsg(error.message)
      setRows([])
      setLoading(false)
      return
    }

    setRows((data ?? []) as AdminRow[])
    setLoading(false)
  }

  async function assignRole() {
    if (myRole !== 'owner') {
      setMsg('Only owner can assign roles.')
      return
    }
    const email = inputEmail.trim().toLowerCase()
    if (!email) return
    setMsg('')
    const { error } = await supabase.rpc('ngm_owner_set_admin_role_by_email', {
      p_email: email,
      p_role: inputRole,
      p_is_active: true,
    })
    if (error) {
      setMsg(error.message)
      return
    }
    setInputEmail('')
    await loadRows()
  }

  async function deactivateRole(userId: string, role: Role) {
    if (myRole !== 'owner') {
      setMsg('Only owner can deactivate roles.')
      return
    }
    setMsg('')
    const { error } = await supabase.rpc('ngm_owner_set_admin_role', {
      p_user_id: userId,
      p_role: role,
      p_is_active: false,
    })
    if (error) {
      setMsg(error.message)
      return
    }
    await loadRows()
  }

  useEffect(() => {
    loadRows()
    logAdminPageView('admin_users')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Admin Users</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>

      {myRole === 'owner' ? (
      <div className='kap-card' style={{ marginBottom: 12 }}>
          <p style={{ fontWeight: 800, marginBottom: 8 }}>Assign Role (Owner only)</p>
          <input
            className='kap-input'
            placeholder='User Email'
            value={inputEmail}
            onChange={(e) => setInputEmail(e.target.value)}
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <select
              className='kap-input'
              style={{ maxWidth: 180 }}
              value={inputRole}
              onChange={(e) => setInputRole(e.target.value as Role)}
            >
              <option value='moderator'>moderator</option>
              <option value='sales_agent'>sales_agent</option>
              <option value='sales_manager'>sales_manager</option>
              <option value='admin'>admin</option>
              <option value='owner'>owner</option>
            </select>
            <button className='kap-btn kap-btn-primary' onClick={assignRole}>Assign</button>
          </div>
        </div>
      ) : null}

      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {loading ? <p>Loading...</p> : null}

      {!loading && (
        <div className='kap-grid'>
          {rows.map((r) => (
            <div className='kap-card' key={`${r.user_id}_${r.role}`}>
              <p><b>User:</b> {r.user_id}</p>
              <p><b>Role:</b> <span className='kap-chip'>{r.role}</span></p>
              <p><b>Active:</b> {r.is_active ? 'Yes' : 'No'}</p>
              {r.role !== 'owner' && r.is_active ? (
                <button
                  className='kap-btn kap-btn-outline'
                  style={{ marginTop: 8 }}
                  onClick={() => deactivateRole(r.user_id, r.role)}
                >
                  Deactivate
                </button>
              ) : null}
            </div>
          ))}
          {!rows.length ? <p>No admin roles found.</p> : null}
        </div>
      )}
    </main>
  )
}
