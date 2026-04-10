'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'
import { supabase } from '@/lib/supabase'

type Role = 'owner' | 'admin' | 'moderator' | null

type UserRow = {
  user_id: string
  username?: string | null
  full_name?: string | null
  email?: string | null
  mobile?: string | null
  district?: string | null
  bio?: string | null
  profile_picture_url?: string | null
  is_verified?: boolean | null
}

type Overview = {
  posts_count?: number
  total_views?: number
  likes_count?: number
  comments_count?: number
  profile_visits?: number
}

export default function UserProfilePage() {
  const params = useParams<{ userId: string }>()
  const userId = params?.userId ?? ''

  const [loading, setLoading] = useState(true)
  const [msg, setMsg] = useState('')
  const [role, setRole] = useState<Role>(null)
  const [userData, setUserData] = useState<UserRow | null>(null)
  const [overview, setOverview] = useState<Overview>({})
  const [followersCount, setFollowersCount] = useState(0)
  const [followingCount, setFollowingCount] = useState(0)
  const [postsCount, setPostsCount] = useState(0)

  async function loadPage() {
    setLoading(true)
    setMsg('')
    const { data: authData } = await supabase.auth.getUser()
    const me = authData.user
    if (!me) {
      setMsg('Not authenticated.')
      setLoading(false)
      return
    }

    const { data: roleData, error: roleErr } = await supabase
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', me.id)
      .maybeSingle()

    if (roleErr || !roleData || roleData.is_active !== true) {
      setMsg(roleErr?.message ?? 'Access denied.')
      setLoading(false)
      return
    }
    setRole((roleData.role as Role) ?? null)

    const [userRes, ovRes, followersRes, followingRes, postsRes] = await Promise.all([
      supabase.from('ngm_users').select('*').eq('user_id', userId).maybeSingle(),
      supabase.rpc('ngm_get_creator_overview', { p_user_id: userId, p_range: 'month' }),
      supabase
        .from('ngm_user_followers')
        .select('follow_id', { head: true, count: 'exact' })
        .eq('following_user_id', userId),
      supabase
        .from('ngm_user_followers')
        .select('follow_id', { head: true, count: 'exact' })
        .eq('follower_user_id', userId),
      supabase
        .from('ngm_user_posts')
        .select('post_id', { head: true, count: 'exact' })
        .eq('user_id', userId),
    ])

    if (userRes.error) {
      setMsg(userRes.error.message)
      setLoading(false)
      return
    }
    setUserData((userRes.data ?? null) as UserRow | null)
    setFollowersCount(Number(followersRes.count ?? 0))
    setFollowingCount(Number(followingRes.count ?? 0))
    setPostsCount(Number(postsRes.count ?? 0))

    const root = (Array.isArray(ovRes.data) ? ovRes.data[0] : ovRes.data) as
      | Record<string, unknown>
      | null
    const ov =
      (root?.overview as Overview | undefined) ??
      (root?.ngm_get_creator_overview as Overview | undefined) ??
      (root as Overview | null) ??
      {}
    setOverview(ov)

    setLoading(false)
  }

  useEffect(() => {
    if (userId) {
      loadPage()
    }
  }, [userId])

  return (
    <main className='kap-wrap' style={{ maxWidth: 900 }}>
      <div className='kap-head'>
        <h1 className='kap-title'>User Profile</h1>
        <Link href='/' className='kap-subtle-link'>Back</Link>
      </div>

      {loading ? <p>Loading...</p> : null}
      {msg ? <p className='kap-msg'>{msg}</p> : null}
      {!loading && role == null ? <p className='kap-msg'>Access denied.</p> : null}

      {!loading && userData ? (
        <div className='kap-grid'>
          <div className='kap-card'>
            <p><b>Full Name:</b> {userData.full_name ?? '-'}</p>
            <p><b>Username:</b> {userData.username ? `@${userData.username}` : '-'}</p>
            <p><b>User ID:</b> {userData.user_id}</p>
            <p><b>Email:</b> {userData.email ?? '-'}</p>
            <p><b>Mobile:</b> {userData.mobile ?? '-'}</p>
            <p><b>District:</b> {userData.district ?? '-'}</p>
            <p><b>Verified:</b> <span className='kap-chip'>{String(userData.is_verified ?? false)}</span></p>
            {userData.bio ? <p style={{ marginTop: 8 }}><b>Bio:</b> {userData.bio}</p> : null}
          </div>

          <div className='kap-card'>
            <p><b>Basic Stats</b></p>
            <p style={{ marginTop: 6 }}>Posts: {postsCount}</p>
            <p>Followers: {followersCount}</p>
            <p>Following: {followingCount}</p>
          </div>

          <div className='kap-card'>
            <p><b>Creator Overview (Month)</b></p>
            <p style={{ marginTop: 6 }}>Posts: {overview.posts_count ?? 0}</p>
            <p>Total Views: {overview.total_views ?? 0}</p>
            <p>Likes: {overview.likes_count ?? 0}</p>
            <p>Comments: {overview.comments_count ?? 0}</p>
            <p>Profile Visits: {overview.profile_visits ?? 0}</p>
          </div>
        </div>
      ) : null}
    </main>
  )
}

