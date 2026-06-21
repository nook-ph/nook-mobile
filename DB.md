-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  category text NOT NULL,
  icon_name text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  CONSTRAINT tags_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cafes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  name text NOT NULL,
  description text,
  address text NOT NULL,
  neighborhood text,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  location USER-DEFINED,
  featured_image_url text,
  rating numeric DEFAULT 0.0,
  review_count integer DEFAULT 0,
  is_new boolean DEFAULT false,
  operating_hours jsonb,
  social_links jsonb,
  status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'active'::text, 'inactive'::text])),
  is_featured boolean NOT NULL DEFAULT false,
  city text NOT NULL DEFAULT 'Cebu City'::text,
  photo_urls jsonb,
  is_claimed boolean NOT NULL DEFAULT false,
  claimed_at timestamp with time zone,
  logo_url text,
  CONSTRAINT cafes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cafe_tags (
  cafe_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  is_featured boolean DEFAULT false,
  CONSTRAINT cafe_tags_pkey PRIMARY KEY (cafe_id, tag_id),
  CONSTRAINT cafe_tags_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT cafe_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id)
);
CREATE TABLE public.menu_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  name text NOT NULL,
  price numeric NOT NULL,
  image_url text,
  is_highlight boolean DEFAULT false,
  category_id uuid,
  description text,
  CONSTRAINT menu_items_pkey PRIMARY KEY (id),
  CONSTRAINT menu_items_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT menu_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.menu_categories(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text UNIQUE,
  full_name text,
  avatar_url text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  is_suspended boolean NOT NULL DEFAULT false,
  email text,
  account_status text NOT NULL DEFAULT 'active'::text CHECK (account_status = ANY (ARRAY['pending_invite'::text, 'invited'::text, 'password_set'::text, 'mfa_enrolled'::text, 'active'::text, 'suspended'::text])),
  bio text CHECK (char_length(bio) <= 500),
  last_username_change timestamp with time zone,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.reviews (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  user_id uuid NOT NULL,
  rating smallint NOT NULL CHECK (rating >= 1 AND rating <= 5),
  content text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  photo_urls jsonb,
  image_urls ARRAY DEFAULT '{}'::text[],
  helpful_count integer NOT NULL DEFAULT 0,
  moderation_status text DEFAULT 'visible'::text CHECK (moderation_status = ANY (ARRAY['visible'::text, 'hidden'::text, 'removed'::text])),
  moderated_at timestamp with time zone,
  moderated_by uuid,
  CONSTRAINT reviews_pkey PRIMARY KEY (id),
  CONSTRAINT reviews_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT reviews_moderated_by_fkey FOREIGN KEY (moderated_by) REFERENCES auth.users(id)
);
CREATE TABLE public.cafe_images (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  image_url text NOT NULL,
  alt_text text,
  display_order smallint DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT cafe_images_pkey PRIMARY KEY (id),
  CONSTRAINT cafe_images_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id)
);
CREATE TABLE public.menu_categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  is_global boolean DEFAULT true,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT menu_categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cafe_owner_cafe (
  owner_id uuid NOT NULL,
  cafe_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'owner'::text CHECK (role = ANY (ARRAY['owner'::text, 'manager'::text])),
  linked_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT cafe_owner_cafe_pkey PRIMARY KEY (owner_id, cafe_id),
  CONSTRAINT cafe_owner_cafe_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id),
  CONSTRAINT cafe_owner_cafe_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id)
);
CREATE TABLE public.review_helpful_votes (
  review_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT review_helpful_votes_pkey PRIMARY KEY (review_id, user_id),
  CONSTRAINT review_helpful_votes_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id),
  CONSTRAINT review_helpful_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.owner_invites (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  invited_profile_id uuid NOT NULL,
  invited_email text NOT NULL,
  token_hash text UNIQUE,
  status text NOT NULL DEFAULT 'sent'::text CHECK (status = ANY (ARRAY['sent'::text, 'opened'::text, 'accepted'::text, 'expired'::text, 'revoked'::text, 'failed'::text])),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + '48:00:00'::interval),
  sent_at timestamp with time zone NOT NULL DEFAULT now(),
  opened_at timestamp with time zone,
  used_at timestamp with time zone,
  revoked_at timestamp with time zone,
  created_by uuid NOT NULL,
  resent_by uuid,
  resent_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  role text NOT NULL DEFAULT 'owner'::text CHECK (role = ANY (ARRAY['owner'::text, 'manager'::text])),
  CONSTRAINT owner_invites_pkey PRIMARY KEY (id),
  CONSTRAINT owner_invites_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT owner_invites_invited_profile_id_fkey FOREIGN KEY (invited_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT owner_invites_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id),
  CONSTRAINT owner_invites_resent_by_fkey FOREIGN KEY (resent_by) REFERENCES auth.users(id)
);
CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_type text NOT NULL CHECK (actor_type = ANY (ARRAY['superadmin'::text, 'owner'::text, 'system'::text])),
  actor_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cafe_analytics_summaries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  summary_date date NOT NULL,
  views_count integer DEFAULT 0,
  hours_checked_count integer DEFAULT 0,
  directions_tapped_count integer DEFAULT 0,
  favorites_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT cafe_analytics_summaries_pkey PRIMARY KEY (id),
  CONSTRAINT cafe_analytics_summaries_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id)
);
CREATE TABLE public.lists (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  cover_image_url text,
  is_public boolean NOT NULL DEFAULT false,
  cafe_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT lists_pkey PRIMARY KEY (id)
);
CREATE TABLE public.list_members (
  list_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'viewer'::text CHECK (role = ANY (ARRAY['owner'::text, 'editor'::text, 'viewer'::text])),
  is_default boolean NOT NULL DEFAULT false,
  joined_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT list_members_pkey PRIMARY KEY (list_id, user_id),
  CONSTRAINT list_members_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.lists(id),
  CONSTRAINT list_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.list_cafes (
  list_id uuid NOT NULL,
  cafe_id uuid NOT NULL,
  added_by uuid,
  added_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  note text,
  CONSTRAINT list_cafes_pkey PRIMARY KEY (list_id, cafe_id),
  CONSTRAINT list_cafes_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.lists(id),
  CONSTRAINT list_cafes_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT list_cafes_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.menu_item_variants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_item_id uuid NOT NULL,
  label text NOT NULL,
  price_override numeric,
  price_modifier numeric NOT NULL DEFAULT 0,
  is_default boolean DEFAULT false,
  sort_order smallint DEFAULT 0,
  CONSTRAINT menu_item_variants_pkey PRIMARY KEY (id),
  CONSTRAINT menu_item_variants_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id)
);
CREATE TABLE public.cafe_claims (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cafe_id uuid NOT NULL,
  claimant_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'under_review'::text, 'approved'::text, 'rejected'::text, 'withdrawn'::text])),
  role text NOT NULL DEFAULT 'owner'::text CHECK (role = ANY (ARRAY['owner'::text, 'manager'::text])),
  business_email text,
  proof_urls jsonb,
  note text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  rejection_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  verification_code character varying,
  expires_at timestamp with time zone,
  verification_method text DEFAULT 'instagram_dm'::text CHECK (verification_method = ANY (ARRAY['instagram_dm'::text, 'document'::text])),
  instagram_handle text,
  CONSTRAINT cafe_claims_pkey PRIMARY KEY (id),
  CONSTRAINT cafe_claims_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT cafe_claims_claimant_id_fkey FOREIGN KEY (claimant_id) REFERENCES public.profiles(id),
  CONSTRAINT cafe_claims_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id)
);
CREATE TABLE public.review_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL,
  reporter_id uuid,
  reporter_type text NOT NULL CHECK (reporter_type = ANY (ARRAY['owner'::text, 'user'::text, 'system'::text])),
  reason_code text NOT NULL CHECK (reason_code = ANY (ARRAY['spam'::text, 'fake_review'::text, 'harassment'::text, 'hate_speech'::text, 'off_topic'::text, 'conflict_of_interest'::text, 'impersonation'::text, 'privacy_violation'::text, 'inappropriate_content'::text, 'other'::text])),
  description text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'under_review'::text, 'resolved'::text, 'rejected'::text])),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  resolution_note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  cafe_id uuid NOT NULL,
  evidence_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  resolution_type text CHECK (resolution_type = ANY (ARRAY['valid_report'::text, 'invalid_report'::text, 'insufficient_evidence'::text, 'owner_abuse'::text])),
  CONSTRAINT review_reports_pkey PRIMARY KEY (id),
  CONSTRAINT review_reports_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id),
  CONSTRAINT review_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id),
  CONSTRAINT review_reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id),
  CONSTRAINT review_reports_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id)
);
CREATE TABLE public.review_moderation_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL,
  action text NOT NULL CHECK (action = ANY (ARRAY['hide'::text, 'restore'::text, 'remove'::text, 'warn_user'::text, 'suspend_user'::text, 'under_review'::text])),
  moderator_id uuid,
  reason text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT review_moderation_actions_pkey PRIMARY KEY (id),
  CONSTRAINT review_moderation_actions_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id),
  CONSTRAINT review_moderation_actions_moderator_id_fkey FOREIGN KEY (moderator_id) REFERENCES auth.users(id)
);
CREATE TABLE public.crawls (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  slug text NOT NULL UNIQUE,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'active'::text, 'completed'::text, 'cancelled'::text])),
  cover_image_url text,
  is_featured boolean NOT NULL DEFAULT false,
  city text NOT NULL DEFAULT 'Cebu City'::text,
  total_stops integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid,
  stamp_template_url text,
  CONSTRAINT crawls_pkey PRIMARY KEY (id),
  CONSTRAINT crawls_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);
CREATE TABLE public.crawl_tiers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crawl_id uuid NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  description text,
  completion_copy text,
  tier_order smallint NOT NULL CHECK (tier_order > 0),
  required_tier_tags ARRAY NOT NULL,
  badge_image_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crawl_tiers_pkey PRIMARY KEY (id),
  CONSTRAINT crawl_tiers_crawl_id_fkey FOREIGN KEY (crawl_id) REFERENCES public.crawls(id)
);
CREATE TABLE public.crawl_stops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crawl_id uuid NOT NULL,
  cafe_id uuid NOT NULL,
  stop_order smallint NOT NULL CHECK (stop_order > 0),
  tier text NOT NULL DEFAULT 'city'::text,
  is_active boolean NOT NULL DEFAULT true,
  label text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crawl_stops_pkey PRIMARY KEY (id),
  CONSTRAINT crawl_stops_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT crawl_stops_crawl_id_fkey FOREIGN KEY (crawl_id) REFERENCES public.crawls(id)
);
CREATE TABLE public.crawl_registrations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crawl_id uuid NOT NULL,
  user_id uuid NOT NULL,
  registered_at timestamp with time zone NOT NULL DEFAULT now(),
  highest_tier_id uuid,
  completed_at timestamp with time zone,
  last_stamp_at timestamp with time zone,
  total_stamps integer NOT NULL DEFAULT 0 CHECK (total_stamps >= 0),
  share_card_generated_at timestamp with time zone,
  CONSTRAINT crawl_registrations_pkey PRIMARY KEY (id),
  CONSTRAINT crawl_registrations_crawl_id_fkey FOREIGN KEY (crawl_id) REFERENCES public.crawls(id),
  CONSTRAINT crawl_registrations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT crawl_registrations_highest_tier_id_fkey FOREIGN KEY (highest_tier_id) REFERENCES public.crawl_tiers(id)
);
CREATE TABLE public.crawl_stamps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crawl_id uuid NOT NULL,
  stop_id uuid NOT NULL,
  cafe_id uuid NOT NULL,
  user_id uuid NOT NULL,
  claimed_at timestamp with time zone NOT NULL DEFAULT now(),
  claim_method text NOT NULL DEFAULT 'qr'::text CHECK (claim_method = ANY (ARRAY['qr'::text, 'redemption'::text, 'manual'::text])),
  claim_lat double precision CHECK (claim_lat IS NULL OR claim_lat >= '-90'::integer::double precision AND claim_lat <= 90::double precision),
  claim_lng double precision CHECK (claim_lng IS NULL OR claim_lng >= '-180'::integer::double precision AND claim_lng <= 180::double precision),
  distance_meters integer CHECK (distance_meters IS NULL OR distance_meters >= 0),
  is_verified boolean NOT NULL DEFAULT false,
  verification_note text,
  CONSTRAINT crawl_stamps_pkey PRIMARY KEY (id),
  CONSTRAINT crawl_stamps_crawl_id_fkey FOREIGN KEY (crawl_id) REFERENCES public.crawls(id),
  CONSTRAINT crawl_stamps_stop_id_fkey FOREIGN KEY (stop_id) REFERENCES public.crawl_stops(id),
  CONSTRAINT crawl_stamps_cafe_id_fkey FOREIGN KEY (cafe_id) REFERENCES public.cafes(id),
  CONSTRAINT crawl_stamps_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.achievement_definitions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  category text NOT NULL CHECK (category = ANY (ARRAY['crawl'::text, 'drops'::text, 'social'::text, 'milestones'::text, 'hidden'::text])),
  source_type text NOT NULL CHECK (source_type = ANY (ARRAY['crawl_tier'::text, 'drop_redemption'::text, 'manual'::text, 'streak'::text, 'milestone'::text])),
  source_id uuid,
  badge_image_url text,
  is_limited_edition boolean NOT NULL DEFAULT false,
  is_hidden boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT achievement_definitions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_achievements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  achievement_id uuid NOT NULL,
  earned_at timestamp with time zone NOT NULL DEFAULT now(),
  source_type text NOT NULL,
  source_ref_id uuid,
  metadata jsonb,
  is_visible boolean NOT NULL DEFAULT true,
  CONSTRAINT user_achievements_pkey PRIMARY KEY (id),
  CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievement_definitions(id)
);