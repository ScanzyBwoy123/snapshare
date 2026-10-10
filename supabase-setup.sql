-- SnapShare setup. Run in Supabase Dashboard > SQL Editor.
-- Photos are public so people with the shared link can view/download them.
-- Do not use this starter for sensitive/private images.
create extension if not exists pgcrypto;
create table if not exists public.albums (
 id uuid primary key default gen_random_uuid(),
 title text not null check (char_length(title) between 1 and 90),
 slug text not null unique,
 description text not null default '',
 event_date date,
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.photos (
 id uuid primary key default gen_random_uuid(),
 album_id uuid not null references public.albums(id) on delete cascade,
 storage_path text not null unique,
 filename text not null,
 content_type text not null default 'image/jpeg',
 size_bytes bigint not null default 0,
 created_at timestamptz not null default now()
);
alter table public.albums enable row level security;
alter table public.photos enable row level security;
drop policy if exists "Anyone can view albums" on public.albums;
create policy "Anyone can view albums" on public.albums for select using (true);
drop policy if exists "Signed-in users create own albums" on public.albums;
create policy "Signed-in users create own albums" on public.albums for insert to authenticated with check (auth.uid() = created_by);
drop policy if exists "Owners update own albums" on public.albums;
create policy "Owners update own albums" on public.albums for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);
drop policy if exists "Owners delete own albums" on public.albums;
create policy "Owners delete own albums" on public.albums for delete to authenticated using (auth.uid() = created_by);
drop policy if exists "Anyone can view photo records" on public.photos;
create policy "Anyone can view photo records" on public.photos for select using (true);
drop policy if exists "Owners add photo records" on public.photos;
create policy "Owners add photo records" on public.photos for insert to authenticated with check (exists(select 1 from public.albums a where a.id=album_id and a.created_by=auth.uid()));
drop policy if exists "Owners delete photo records" on public.photos;
create policy "Owners delete photo records" on public.photos for delete to authenticated using (exists(select 1 from public.albums a where a.id=album_id and a.created_by=auth.uid()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('album-photos','album-photos',true,26214400,array['image/jpeg','image/png','image/webp','image/gif','image/heic','image/heif','image/avif'])
on conflict(id) do update set public=true,file_size_limit=26214400;
drop policy if exists "Public can view album photos" on storage.objects;
create policy "Public can view album photos" on storage.objects for select using(bucket_id='album-photos');
drop policy if exists "Authenticated users upload album photos" on storage.objects;
create policy "Authenticated users upload album photos" on storage.objects for insert to authenticated with check(bucket_id='album-photos' and exists(select 1 from public.albums a where a.id::text=(storage.foldername(name))[1] and a.created_by=auth.uid()));
drop policy if exists "Owners delete album photos" on storage.objects;
create policy "Owners delete album photos" on storage.objects for delete to authenticated using(bucket_id='album-photos' and exists(select 1 from public.albums a where a.id::text=(storage.foldername(name))[1] and a.created_by=auth.uid()));
grant select on public.albums,public.photos to anon,authenticated;
grant insert,update,delete on public.albums to authenticated;
grant insert,delete on public.photos to authenticated;
