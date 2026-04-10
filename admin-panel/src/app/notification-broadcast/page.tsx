'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { getAdminAccess, hasSalesAccess, type AdminRole } from '@/lib/admin-access'
import { logAdminPageView } from '@/lib/admin-analytics'

type TargetGroup = 'all_users' | 'subscription_users' | 'test_series_buyers' | 'affiliates_only'

export default function NotificationBroadcastPage() {
  const [role, setRole] = useState<AdminRole>(null)
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [msg, setMsg] = useState('')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [targetGroup, setTargetGroup] = useState<TargetGroup>('all_users')

  async function checkAccess() {
    setLoading(true)
    setMsg('')
    const access = await getAdminAccess()
    setRole(access.role)
    if (!hasSalesAccess(access.role)) {
      setMsg('Access denied.')
    }
    setLoading(false)
  }

  async function sendNotification() {
    if (!hasSalesAccess(role)) {
      setMsg('Access denied.')
      return
    }
    if (!title.trim() || !body.trim()) {
      setMsg('Title and message required.')
      return
    }

    setSending(true)
    setMsg('')
    const { data, error } = await supabase.rpc('kls_send_admin_broadcast_notification', {
      p_title: title.trim(),
      p_body: body.trim(),
      p_target_group: targetGroup,
    })
    setSending(false)

    if (error) {
      setMsg(error.message)
      return
    }

    const sent = Number(data ?? 0)
    setMsg(`Notification sent successfully to ${sent} users.`)
    setTitle('')
    setBody('')
  }

  useEffect(() => {
    void checkAccess()
    logAdminPageView('notification_broadcast')
  }, [])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Notification Broadcast</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>
      {role ? <p style={{ marginBottom: 8 }}>Role: <span className='kap-chip'>{role}</span></p> : null}

      {loading ? <p>Loading...</p> : null}

      {!loading && (
        <div className='kap-card'>
          <p style={{ fontWeight: 800, marginBottom: 10 }}>
            Manual Notification
          </p>
          <p style={{ fontSize: 13, color: '#6b7280', marginBottom: 10 }}>
            Dropdown thi audience select karo: All Users, Subscription Users, Test Series Buyers, Affiliaters Only.
          </p>
          <div style={{ display: 'grid', gap: 8 }}>
            <select
              className='kap-input'
              value={targetGroup}
              onChange={(e) => setTargetGroup(e.target.value as TargetGroup)}
            >
              <option value='all_users'>All Users</option>
              <option value='subscription_users'>Subscription Users</option>
              <option value='test_series_buyers'>Test Series Buyers</option>
              <option value='affiliates_only'>Affiliaters Only</option>
            </select>
            <input
              className='kap-input'
              placeholder='Notification Title'
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
            <textarea
              className='kap-input'
              placeholder='Notification Message'
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
            />
            <button
              className='kap-btn kap-btn-primary'
              onClick={sendNotification}
              disabled={sending}
            >
              {sending ? 'Sending...' : 'Send Notification'}
            </button>
          </div>
        </div>
      )}

      {msg ? <p className='kap-msg'>{msg}</p> : null}
    </main>
  )
}
