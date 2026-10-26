-- Social Media Studio secure connection storage.
-- Tokens and OAuth state are only accessible to the service role through the Edge Function.
create table if not exists public.social_media_oauth_states (
  state_hash text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('facebook','x','whatsapp','linkedin')),
  code_verifier text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists social_media_oauth_states_expiry_idx on public.social_media_oauth_states(expires_at);
alter table public.social_media_oauth_states enable row level security;
revoke all on public.social_media_oauth_states from anon, authenticated;
grant all on public.social_media_oauth_states to service_role;

create table if not exists public.social_media_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('facebook','x','whatsapp','linkedin')),
  account_id text,
  account_name text,
  scopes text[] not null default '{}',
  encrypted_access_token text not null,
  encrypted_refresh_token text,
  token_expires_at timestamptz,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, provider)
);
create index if not exists social_media_connections_user_idx on public.social_media_connections(user_id);
alter table public.social_media_connections enable row level security;
revoke all on public.social_media_connections from anon, authenticated;
grant all on public.social_media_connections to service_role;
