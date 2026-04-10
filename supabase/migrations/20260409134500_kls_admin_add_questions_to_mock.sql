create or replace function public.kls_is_sales_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.ngm_admin_roles r
    where r.user_id::text = auth.uid()::text
      and r.is_active = true
      and r.role in ('owner', 'admin', 'moderator', 'sales_manager', 'sales_agent')
  );
$$;

grant execute on function public.kls_is_sales_or_admin() to authenticated, service_role;

create or replace function public.kls_admin_add_questions_to_mock(
  p_mock_test_id uuid,
  p_question_ids uuid[],
  p_default_subject_id text default 'GEN',
  p_default_subject_name text default 'General',
  p_default_chapter_code text default 'GENERAL',
  p_default_chapter_name text default 'General',
  p_reset_existing boolean default false
)
returns table (
  inserted_count integer,
  skipped_count integer,
  starting_order integer,
  ending_order integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base_order integer := 0;
  v_inserted integer := 0;
  v_skipped integer := 0;
  v_start integer := 0;
  v_end integer := 0;
  v_q jsonb;
  v_subject_id text;
  v_subject_name text;
  v_chapter_code text;
  v_chapter_name text;
  v_question_text text;
  v_option_a text;
  v_option_b text;
  v_option_c text;
  v_option_d text;
  v_option_e text;
  v_correct_answer text;
  v_explanation text;
  r record;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not public.kls_is_sales_or_admin() then
    raise exception 'ADMIN_OR_SALES_ONLY';
  end if;

  if p_mock_test_id is null then
    raise exception 'MOCK_TEST_ID_REQUIRED';
  end if;

  if p_question_ids is null or coalesce(array_length(p_question_ids, 1), 0) = 0 then
    raise exception 'QUESTION_IDS_REQUIRED';
  end if;

  if p_reset_existing then
    delete from public.kls_mock_questions where mock_test_id = p_mock_test_id;
  end if;

  select coalesce(max(q.question_order), 0)
  into v_base_order
  from public.kls_mock_questions q
  where q.mock_test_id = p_mock_test_id;

  v_start := v_base_order + 1;

  for r in
    select qid, ord
    from unnest(p_question_ids) with ordinality as t(qid, ord)
    order by ord
  loop
    select to_jsonb(q)
    into v_q
    from public.kls_questions q
    where q.id = r.qid;

    if v_q is null then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_question_text := coalesce(nullif(v_q->>'question', ''), nullif(v_q->>'question_text', ''));
    v_option_a := nullif(v_q->>'option_a', '');
    v_option_b := nullif(v_q->>'option_b', '');
    v_option_c := nullif(v_q->>'option_c', '');
    v_option_d := nullif(v_q->>'option_d', '');
    v_option_e := nullif(v_q->>'option_e', '');
    v_correct_answer := upper(coalesce(nullif(v_q->>'correct_answer', ''), ''));
    v_explanation := coalesce(nullif(v_q->>'solution', ''), nullif(v_q->>'explanation', ''));

    v_subject_id := coalesce(
      nullif(v_q->>'subject_id', ''),
      nullif(v_q->>'subject_code', ''),
      p_default_subject_id
    );
    v_subject_name := coalesce(nullif(v_q->>'subject_name', ''), p_default_subject_name);

    v_chapter_code := coalesce(
      nullif(v_q->>'chapter_code', ''),
      nullif(v_q->>'chapter_name', ''),
      p_default_chapter_code
    );
    v_chapter_name := coalesce(nullif(v_q->>'chapter_name', ''), p_default_chapter_name);

    if v_question_text is null
       or v_option_a is null
       or v_option_b is null
       or v_option_c is null
       or v_option_d is null
       or v_correct_answer not in ('A', 'B', 'C', 'D', 'E')
    then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if exists (
      select 1
      from public.kls_mock_questions x
      where x.mock_test_id = p_mock_test_id
        and x.question_text = v_question_text
        and x.option_a = v_option_a
        and x.option_b = v_option_b
        and x.option_c = v_option_c
        and x.option_d = v_option_d
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    insert into public.kls_mock_questions (
      mock_test_id,
      question_order,
      subject_id,
      subject_name,
      chapter_code,
      chapter_name,
      question_text,
      option_a,
      option_b,
      option_c,
      option_d,
      option_e,
      correct_answer,
      explanation
    )
    values (
      p_mock_test_id,
      v_base_order + r.ord,
      v_subject_id,
      v_subject_name,
      v_chapter_code,
      v_chapter_name,
      v_question_text,
      v_option_a,
      v_option_b,
      v_option_c,
      v_option_d,
      v_option_e,
      v_correct_answer,
      v_explanation
    )
    on conflict do nothing;

    if found then
      v_inserted := v_inserted + 1;
      v_end := v_base_order + r.ord;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  inserted_count := v_inserted;
  skipped_count := v_skipped;
  starting_order := case when v_inserted > 0 then v_start else 0 end;
  ending_order := case when v_inserted > 0 then v_end else 0 end;
  return next;
end;
$$;

grant execute on function public.kls_admin_add_questions_to_mock(uuid, uuid[], text, text, text, text, boolean)
  to authenticated, service_role;
