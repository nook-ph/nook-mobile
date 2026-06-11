-- RPC: get_crawl_detail
-- Returns full crawl detail including stops, tiers, and user progress.
-- Security: SECURITY INVOKER — respects RLS policies.

create or replace function get_crawl_detail(
  p_slug text,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_crawl_id uuid;
  v_crawl jsonb;
  v_stops jsonb;
  v_tiers jsonb;
  v_registration jsonb;
  v_progress jsonb;
begin
  -- Resolve crawl
  select id into strict v_crawl_id
  from public.crawls
  where slug = p_slug;

  -- Crawl metadata
  select to_jsonb(c) into v_crawl
  from public.crawls c
  where c.id = v_crawl_id;

  -- Stops with cafe info and claim status
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cs.id,
      'crawl_id', cs.crawl_id,
      'cafe_id', cs.cafe_id,
      'cafe_name', cf.name,
      'cafe_address', cf.address,
      'cafe_lat', cf.lat,
      'cafe_lng', cf.lng,
      'stop_order', cs.stop_order,
      'tier', cs.tier,
      'is_active', cs.is_active,
      'label', cs.label,
      'is_claimed', case when p_user_id is not null
        then exists(
          select 1 from public.crawl_stamps cst
          where cst.stop_id = cs.id and cst.user_id = p_user_id
        )
        else false end,
      'claimed_at', case when p_user_id is not null
        then (select cst.claimed_at from public.crawl_stamps cst
              where cst.stop_id = cs.id and cst.user_id = p_user_id
              limit 1)
        else null end
    )
    order by cs.stop_order
  ), '[]'::jsonb) into v_stops
  from public.crawl_stops cs
  join public.cafes cf on cf.id = cs.cafe_id
  where cs.crawl_id = v_crawl_id;

  -- Tiers with completion progress
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', ct.id,
      'crawl_id', ct.crawl_id,
      'slug', ct.slug,
      'name', ct.name,
      'description', ct.description,
      'completion_copy', ct.completion_copy,
      'tier_order', ct.tier_order,
      'required_tier_tags', ct.required_tier_tags,
      'badge_image_url', ct.badge_image_url,
      'total_required', (
        select count(*)::int
        from public.crawl_stops cst
        where cst.crawl_id = v_crawl_id
          and cst.is_active = true
          and cst.tier = any(ct.required_tier_tags)
      ),
      'total_claimed', case when p_user_id is not null
        then (
          select count(*)::int
          from public.crawl_stops cst
          join public.crawl_stamps csm on csm.stop_id = cst.id
          where cst.crawl_id = v_crawl_id
            and cst.is_active = true
            and cst.tier = any(ct.required_tier_tags)
            and csm.user_id = p_user_id
        )
        else 0 end,
      'is_complete', case when p_user_id is not null
        then (
          select count(*)::int = (
            select count(*)::int
            from public.crawl_stops cst
            where cst.crawl_id = v_crawl_id
              and cst.is_active = true
              and cst.tier = any(ct.required_tier_tags)
          )
          from public.crawl_stops cst
          join public.crawl_stamps csm on csm.stop_id = cst.id
          where cst.crawl_id = v_crawl_id
            and cst.is_active = true
            and cst.tier = any(ct.required_tier_tags)
            and csm.user_id = p_user_id
        )
        else false end
    )
    order by ct.tier_order
  ), '[]'::jsonb) into v_tiers
  from public.crawl_tiers ct
  where ct.crawl_id = v_crawl_id;

  -- Registration and user progress
  if p_user_id is not null then
    select to_jsonb(r) into v_registration
    from public.crawl_registrations r
    where r.crawl_id = v_crawl_id and r.user_id = p_user_id;

    if v_registration is not null then
      v_progress := jsonb_build_object(
        'total_stamps', v_registration->'total_stamps',
        'highest_tier', (
          select to_jsonb(ct)
          from public.crawl_tiers ct
          where ct.id = (v_registration->>'highest_tier_id')::uuid
        ),
        'stamps', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', cst.id,
              'stop_id', cst.stop_id,
              'cafe_id', cst.cafe_id,
              'cafe_name', cf.name,
              'stop_order', cs.stop_order,
              'tier', cs.tier,
              'claimed_at', cst.claimed_at,
              'claim_method', cst.claim_method,
              'is_verified', cst.is_verified
            )
            order by cst.claimed_at desc
          )
          from public.crawl_stamps cst
          join public.crawl_stops cs on cs.id = cst.stop_id
          join public.cafes cf on cf.id = cst.cafe_id
          where cst.crawl_id = v_crawl_id and cst.user_id = p_user_id
        ), '[]'::jsonb)
      );
    end if;
  end if;

  return jsonb_build_object(
    'crawl', v_crawl,
    'is_registered', v_registration is not null,
    'progress', v_progress,
    'stops', v_stops,
    'tiers', v_tiers
  );
end;
$$;
