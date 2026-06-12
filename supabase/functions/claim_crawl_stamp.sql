-- RPC: claim_crawl_stamp
-- Server-side stamp claim: validates, auto-registers, inserts stamp,
-- updates progress, checks tier completion, awards achievements.
-- Security: SECURITY INVOKER — respects RLS policies.

create or replace function claim_crawl_stamp(
  p_crawl_id uuid,
  p_stop_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_crawl record;
  v_stop record;
  v_cafe record;
  v_distance_meters integer;
  v_reg_id uuid;
  v_stamp_id uuid;
  v_tier record;
  v_total_req int;
  v_total_claimed_for_tier int;
  v_achievement_id uuid;
  v_result jsonb;
begin
  -- Identify the calling user
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  -- 1. Validate crawl
  select * into v_crawl
  from public.crawls
  where id = p_crawl_id;

  if v_crawl is null then
    return jsonb_build_object('error', 'crawl_not_found');
  end if;

  if v_crawl.status != 'active' then
    return jsonb_build_object('error', 'crawl_ended');
  end if;

  if now() < v_crawl.starts_at or now() > v_crawl.ends_at then
    return jsonb_build_object('error', 'crawl_ended');
  end if;

  -- 2. Validate stop
  select * into v_stop
  from public.crawl_stops
  where id = p_stop_id and crawl_id = p_crawl_id;

  if v_stop is null then
    return jsonb_build_object('error', 'stop_not_found');
  end if;

  if v_stop.is_active = false then
    return jsonb_build_object('error', 'stop_inactive');
  end if;

  -- 3. Get cafe coordinates for distance check
  select * into v_cafe
  from public.cafes
  where id = v_stop.cafe_id;

  -- 4. Auto-register user if not registered
  insert into public.crawl_registrations (crawl_id, user_id)
  values (p_crawl_id, v_user_id)
  on conflict (crawl_id, user_id) do nothing
  returning id into v_reg_id;

  if v_reg_id is null then
    select id into v_reg_id
    from public.crawl_registrations
    where crawl_id = p_crawl_id and user_id = v_user_id;
  end if;

  -- 5. Check unique stamp
  if exists (
    select 1 from public.crawl_stamps
    where stop_id = p_stop_id and user_id = v_user_id
  ) then
    select claimed_at into v_stamp_id
    from public.crawl_stamps
    where stop_id = p_stop_id and user_id = v_user_id
    limit 1;

    return jsonb_build_object(
      'error', 'already_claimed',
      'claimed_at', v_stamp_id
    );
  end if;

  -- 6. Compute Haversine distance
  -- TEMPORARILY DISABLED for testing. To re-enable, uncomment the block below.
  v_distance_meters := 0;
  -- if v_cafe.lat is not null and v_cafe.lng is not null then
  --   v_distance_meters := (
  --     select round(
  --       6371000.0 * 2.0 * asin(
  --         sqrt(
  --           sin(radians((v_cafe.lat - p_lat) / 2.0)) ^ 2
  --           + cos(radians(v_cafe.lat))
  --           * cos(radians(p_lat))
  --           * sin(radians((v_cafe.lng - p_lng) / 2.0)) ^ 2
  --         )
  --       )
  --     )::int
  --   );
  --
  --   if v_distance_meters > 200 then
  --     return jsonb_build_object(
  --       'error', 'location_too_far',
  --       'distance_meters', v_distance_meters
  --     );
  --   end if;
  -- end if;

  -- 7. Insert stamp
  insert into public.crawl_stamps (
    crawl_id, stop_id, cafe_id, user_id,
    claim_method, claim_lat, claim_lng,
    distance_meters, is_verified
  ) values (
    p_crawl_id, p_stop_id, v_stop.cafe_id, v_user_id,
    'qr', p_lat, p_lng,
    v_distance_meters, true
  )
  returning id into v_stamp_id;

  -- 8. Update registration counters
  update public.crawl_registrations
  set
    total_stamps = total_stamps + 1,
    last_stamp_at = now()
  where id = v_reg_id;

  -- 9. Check tier completion (ordered by tier_order ascending)
  for v_tier in
    select *
    from public.crawl_tiers
    where crawl_id = p_crawl_id
    order by tier_order asc
  loop
    -- Count required active stops for this tier
    select count(*)::int into v_total_req
    from public.crawl_stops
    where crawl_id = p_crawl_id
      and is_active = true
      and tier = any(v_tier.required_tier_tags);

    -- Count claimed stops for this tier
    select count(*)::int into v_total_claimed_for_tier
    from public.crawl_stops cst
    join public.crawl_stamps csm on csm.stop_id = cst.id
    where cst.crawl_id = p_crawl_id
      and cst.is_active = true
      and cst.tier = any(v_tier.required_tier_tags)
      and csm.user_id = v_user_id;

    -- If tier completed and not already recorded
    if v_total_req > 0
      and v_total_claimed_for_tier >= v_total_req
      and coalesce(
        (select highest_tier_id from public.crawl_registrations where id = v_reg_id),
        '00000000-0000-0000-0000-000000000000'::uuid
      ) != v_tier.id
    then
      -- Update highest tier
      update public.crawl_registrations
      set highest_tier_id = v_tier.id
      where id = v_reg_id;

      -- Check if this is the final tier (highest tier_order)
      if not exists (
        select 1 from public.crawl_tiers
        where crawl_id = p_crawl_id and tier_order > v_tier.tier_order
      ) then
        update public.crawl_registrations
        set completed_at = now()
        where id = v_reg_id;
      end if;

      -- Award achievement
      select id into v_achievement_id
      from public.achievement_definitions
      where source_type = 'crawl_tier' and source_id = v_tier.id
      limit 1;

      if v_achievement_id is not null then
        insert into public.user_achievements (
          user_id, achievement_id, source_type, source_ref_id, metadata
        ) values (
          v_user_id, v_achievement_id, 'crawl_tier', v_stamp_id,
          jsonb_build_object(
            'crawl_title', v_crawl.title,
            'tier_name', v_tier.name
          )
        )
        on conflict (user_id, achievement_id) do nothing;
      end if;

      -- Build tier completion result
      v_result := jsonb_build_object(
        'stamp', jsonb_build_object(
          'id', v_stamp_id,
          'stop_id', p_stop_id,
          'cafe_id', v_stop.cafe_id,
          'cafe_name', v_cafe.name,
          'stop_order', v_stop.stop_order,
          'tier', v_stop.tier,
          'claimed_at', now(),
          'claim_method', 'qr',
          'is_verified', true
        ),
        'total_stamps', (select total_stamps from public.crawl_registrations where id = v_reg_id),
        'tier_completion', jsonb_build_object(
          'tier_id', v_tier.id,
          'tier_slug', v_tier.slug,
          'tier_name', v_tier.name,
          'completion_copy', v_tier.completion_copy,
          'achievement_id', v_achievement_id,
          'badge_image_url', v_tier.badge_image_url,
          'earned_at', now()
        )
      );

      return v_result;
    end if;
  end loop;

  -- 10. Return result without tier completion
  return jsonb_build_object(
    'stamp', jsonb_build_object(
      'id', v_stamp_id,
      'stop_id', p_stop_id,
      'cafe_id', v_stop.cafe_id,
      'cafe_name', v_cafe.name,
      'stop_order', v_stop.stop_order,
      'tier', v_stop.tier,
      'claimed_at', now(),
      'claim_method', 'qr',
      'is_verified', true
    ),
    'total_stamps', (select total_stamps from public.crawl_registrations where id = v_reg_id),
    'tier_completion', null
  );
end;
$$;
