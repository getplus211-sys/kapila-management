'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { logAdminPageView } from '@/lib/admin-analytics'

type Role = 'owner' | 'admin' | 'moderator' | null

type ThreadRow = {
  thread_id: string
  user_id: string
  subject: string | null
  status: string
  created_at: string
}

type MessageRow = {
  message_id: string
  thread_id: string
  sender_user_id: string
  sender_type: string
  message_text: string
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

export default function FeedbackRepliesPage() {
  const [loading, setLoading] = useState(true)
  const [role, setRole] = useState<Role>(null)
  const [msg, setMsg] = useState('')
  const [threads, setThreads] = useState<ThreadRow[]>([])
  const [activeThread, setActiveThread] = useState<string>('')
  const [messages, setMessages] = useState<MessageRow[]>([])
  const [replyText, setReplyText] = useState('')
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [lastSyncedAt, setLastSyncedAt] = useState('')
  const [userMetaById, setUserMetaById] = useState<Record<string, UserMeta>>({})

  async function loadUserMeta(userIds: string[]) {
    const ids = [...new Set(userIds.filter(Boolean))]
    if (ids.length === 0) {
      setUserMetaById({})
      return
    }
    const { data } = await supabase
      .from('ngm_users')
      .select('user_id,username,full_name,email,mobile,district')
      .in('user_id', ids)
    const map: Record<string, UserMeta> = {}
    for (const u of (data ?? []) as UserMeta[]) {
      map[u.user_id] = u
    }
    setUserMetaById(map)
  }

  async function checkAdmin() {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) return { ok: false, userId: '' }

    const { data: roleData, error } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()

    if (error || !roleData || roleData.is_active !== true) {
      return { ok: false, userId: user.id }
    }
    setRole((roleData.role as Role) ?? null)
    return { ok: true, userId: user.id }
  }

  async function loadThreads() {
    setLoading(true)
    setMsg('')
    const admin = await checkAdmin()
    if (!admin.ok) {
      setMsg('No admin access for this account.')
      setLoading(false)
      return
    }

    const { data, error } = await supabase
      .from('ngm_feedback_threads')
      .select('thread_id,user_id,subject,status,created_at')
      .order('created_at', { ascending: false })
      .limit(200)

    if (error) {
      setMsg(error.message)
      setThreads([])
    } else {
      const rows = (data ?? []) as ThreadRow[]
      setThreads(rows)
      await loadUserMeta(rows.map((r) => r.user_id))
      if (!activeThread && rows.length > 0) {
        setActiveThread(rows[0].thread_id)
      }
      setLastSyncedAt(new Date().toLocaleTimeString())
    }
    setLoading(false)
  }

  async function loadMessages(threadId: string) {
    if (!threadId) return
    const { data, error } = await supabase
      .from('ngm_feedback_messages')
      .select('message_id,thread_id,sender_user_id,sender_type,message_text,created_at')
      .eq('thread_id', threadId)
      .order('created_at', { ascending: true })
      .limit(500)
    if (error) {
      setMsg(error.message)
      setMessages([])
      return
    }
    const rows = (data ?? []) as MessageRow[]
    setMessages(rows)
    await loadUserMeta([
      ...threads.map((t) => t.user_id),
      ...rows.map((m) => m.sender_user_id),
    ])
  }

  async function sendReply() {
    if (!activeThread || !replyText.trim()) return
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) return

    const { error } = await supabase.from('ngm_feedback_messages').insert({
      thread_id: activeThread,
      sender_user_id: user.id,
      sender_type: 'admin',
      message_text: replyText.trim(),
    })
    if (error) {
      alert(error.message)
      return
    }
    setReplyText('')
    await loadMessages(activeThread)
  }

  useEffect(() => {
    loadThreads()
    logAdminPageView('feedback_replies')
  }, [])

  useEffect(() => {
    const id = setInterval(() => {
      void loadThreads()
      if (activeThread) {
        void loadMessages(activeThread)
      }
    }, 15000)
    return () => clearInterval(id)
  }, [activeThread])

  async function manualRefresh() {
    setIsRefreshing(true)
    await loadThreads()
    if (activeThread) {
      await loadMessages(activeThread)
    }
    setIsRefreshing(false)
  }

  useEffect(() => {
    if (activeThread) loadMessages(activeThread)
  }, [activeThread])

  return (
    <main className='kap-wrap'>
      <div className='kap-head'>
        <h1 className='kap-title'>Ask/Feedback Replies</h1>
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
      {loading ? <p>Loading...</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}

      <div className='kap-two-col'>
        <div className='kap-card' style={{ maxHeight: 520, overflow: 'auto' }}>
          <p style={{ fontWeight: 700, marginBottom: 8 }}>Threads</p>
          {threads.map((t) => (
            <button
              key={t.thread_id}
              onClick={() => setActiveThread(t.thread_id)}
              style={{
                width: '100%',
                textAlign: 'left',
                marginBottom: 8,
                padding: 10,
                borderRadius: 8,
                border: '1px solid #e8e5ff',
                background: activeThread === t.thread_id ? '#f2efff' : '#fff',
              }}
            >
              <p><b>{t.subject ?? 'No Subject'}</b></p>
              <p style={{ fontSize: 12, color: '#6b7280' }}>
                {userMetaById[t.user_id]?.full_name ?? t.user_id}
                {userMetaById[t.user_id]?.username ? ` (@${userMetaById[t.user_id]?.username})` : ''}
              </p>
              <p style={{ fontSize: 12, color: '#94a3b8' }}>
                {userMetaById[t.user_id]?.email ?? '-'} | {userMetaById[t.user_id]?.mobile ?? '-'} | {userMetaById[t.user_id]?.district ?? '-'}
              </p>
              <p style={{ marginTop: 6 }}>
                <Link href={`/user-profile/${t.user_id}`} className='kap-btn kap-btn-outline'>
                  View Profile
                </Link>
              </p>
            </button>
          ))}
        </div>

        <div className='kap-card'>
          <p style={{ fontWeight: 700, marginBottom: 8 }}>Messages</p>
          <div style={{ maxHeight: 420, overflow: 'auto', border: '1px solid #eee', borderRadius: 8, padding: 8 }}>
            {messages.map((m) => (
              <div
                key={m.message_id}
                style={{
                  marginBottom: 8,
                  padding: 8,
                  border: '1px solid #eee',
                  borderRadius: 8,
                  background: m.sender_type === 'admin' ? '#f4f2ff' : '#fff',
                }}
              >
                <p style={{ fontSize: 12, color: '#6b7280' }}>
                  {m.sender_type} | {new Date(m.created_at).toLocaleString()}
                </p>
                <p style={{ fontSize: 12, color: '#94a3b8' }}>
                  {userMetaById[m.sender_user_id]?.full_name ?? m.sender_user_id}
                  {userMetaById[m.sender_user_id]?.username ? ` (@${userMetaById[m.sender_user_id]?.username})` : ''}
                </p>
                <p>{m.message_text}</p>
                <p style={{ marginTop: 6 }}>
                  <Link href={`/user-profile/${m.sender_user_id}`} className='kap-btn kap-btn-outline'>
                    View Profile
                  </Link>
                </p>
              </div>
            ))}
            {messages.length === 0 ? <p style={{ color: '#6b7280' }}>No messages.</p> : null}
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
            <input
              value={replyText}
              onChange={(e) => setReplyText(e.target.value)}
              placeholder='Type admin reply...'
              className='kap-input'
            />
            <button onClick={sendReply} className='kap-btn kap-btn-primary'>Send</button>
          </div>
        </div>
      </div>
    </main>
  )
}
