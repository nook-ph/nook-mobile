-- RPC: get_crawl_share_card
-- Returns share card data for a user's crawl progress.
-- Security: SECURITY INVOKER — respects RLS policies.

create or replace function get_crawl_share_card(
  p_crawl_id uuid,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_profile record;
  v_crawl record;
  v_registration record;
  v_highest_tier jsonb;
  v_stops jsonb;
begin
  -- Resolve profile
  if p_user_id is not null then
    select * into v_profile
    from public.profiles
    where id = p_user_id;
  end if;

  -- Crawl metadata
  select * into v_crawl
  from public.crawls
  where id = p_crawl_id;

  if v_crawl is null then
    return null;
  end if;

  -- Registration (if user provided)
  if p_user_id is not null then
    select * into v_registration
    from public.crawl_registrations
    where crawl_id = p_crawl_id and user_id = p_user_id;
  end if;

  -- Highest tier
  if v_registration is not null and v_registration.highest_tier_id is not null then
    select to_jsonb(ct) into v_highest_tier
    from public.crawl_tiers ct
    where ct.id = v_registration.highest_tier_id;
  end if;

  -- All stops with claim status
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'stop_order', cs.stop_order,
      'tier', cs.tier,
      'cafe_name', cf.name,
      'cafe_logo_url', cf.logo_url,
      'cafe_lat', cf.lat,
      'cafe_lng', cf.lng,
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
  where cs.crawl_id = p_crawl_id;

  return jsonb_build_object(
    'user_name', coalesce(v_profile.full_name, v_profile.username, 'Explorer'),
    'crawl_title', v_crawl.title,
    'crawl_period', to_char(v_crawl.starts_at, 'Mon DD') || ' - ' || to_char(v_crawl.ends_at, 'Mon DD, YYYY'),
    'total_stamps', coalesce(v_registration.total_stamps, 0),
    'total_stops', v_crawl.total_stops,
    'highest_tier', v_highest_tier,
    'stops', v_stops
  );
end;
$$;
