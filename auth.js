window.KapilaAuth = (() => {
  let supabaseClient = null

  function createClient() {
    const config = window.ADMIN_PANEL_CONFIG || {}
    const supabaseUrl = config.supabaseUrl || ''
    const supabaseAnonKey = config.supabaseAnonKey || ''
    if (!supabaseUrl || !supabaseAnonKey || !window.supabase?.createClient) return null
    if (!supabaseClient) {
      supabaseClient = window.supabase.createClient(supabaseUrl, supabaseAnonKey)
    }
    return supabaseClient
  }

  async function getSessionUser() {
    const client = createClient()
    if (!client) return null
    const { data } = await client.auth.getSession()
    if (data.session?.user) return data.session.user
    const { data: authData } = await client.auth.getUser()
    return authData.user ?? null
  }

  async function getAdminAccess() {
    const client = createClient()
    if (!client) return { client: null, user: null, role: null }
    const user = await getSessionUser()
    if (!user) return { client, user: null, role: null }
    const { data, error } = await client
      .from('ngm_admin_roles')
      .select('role,is_active')
      .eq('user_id', user.id)
      .maybeSingle()
    if (error || !data || data.is_active !== true) {
      return { client, user, role: null }
    }
    return { client, user, role: data.role || null }
  }

  return {
    createClient,
    getSessionUser,
    getAdminAccess,
  }
})()
