import { supabase } from '@/lib/supabase'

export type AdminRole =
  | 'owner'
  | 'admin'
  | 'moderator'
  | 'sales_manager'
  | 'sales_agent'
  | null

export async function getAdminAccess() {
  const { data: authData } = await supabase.auth.getUser()
  const user = authData.user
  if (!user) return { user: null, role: null as AdminRole }

  const { data } = await supabase
    .from('ngm_admin_roles')
    .select('role,is_active')
    .eq('user_id', user.id)
    .maybeSingle()

  if (!data || data.is_active !== true) {
    return { user, role: null as AdminRole }
  }

  return { user, role: (data.role as AdminRole) ?? null }
}

export function hasOpsAccess(role: AdminRole) {
  return ['owner', 'admin', 'moderator', 'sales_manager', 'sales_agent'].includes(role ?? '')
}

export function hasModerationAccess(role: AdminRole) {
  return ['owner', 'admin', 'moderator'].includes(role ?? '')
}

export function hasSalesAccess(role: AdminRole) {
  return ['owner', 'admin', 'sales_manager', 'sales_agent'].includes(role ?? '')
}
