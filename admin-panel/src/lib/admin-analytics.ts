import { supabase } from '@/lib/supabase'

export async function logAdminPageView(pageName: string): Promise<void> {
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData.user
    if (!user) return

    await supabase.from('ngm_admin_actions_log').insert({
      admin_user_id: user.id,
      action_type: 'page_view',
      target_table: 'admin_panel',
      target_id: pageName,
      new_data: { page: pageName },
    })
  } catch (_) {
    // Keep UI unaffected if analytics table/policies are not ready.
  }
}

