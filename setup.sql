-- =====================================================
--  ACHADINHOS POR POST — configuração do banco (Supabase)
--  Cole tudo no SQL Editor do Supabase e clique em RUN.
--  Pode rodar de novo sem problema, se precisar.
-- =====================================================

-- 1) PERFIL (nome, bio, foto, cores, links)
create table if not exists public.settings (
  id int primary key default 1 check (id = 1),
  name text,
  handle text,
  bio text,
  avatar_url text,
  whatsapp_url text,
  instagram_url text,
  color text,
  footer text,
  updated_at timestamptz default now()
);

insert into public.settings (id, name, bio, color, footer)
values (1, 'Leva, miga!', 'Achadinhos que resolvem a vida da mulher 💖', '#B5124F',
        'Achado bom a gente divide com as migas 💖 Preço e estoque podem mudar, então confere na loja antes de finalizar.')
on conflict (id) do nothing;

-- 2) POSTS (cada publicação do Instagram)
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  number int not null,
  title text,
  category text,
  cover_url text,
  instagram_url text,
  active boolean not null default true,
  created_at timestamptz default now()
);

-- 3) PRODUTOS (os links de cada post)
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  name text not null,
  url text not null default '',
  platform text default 'shopee',
  price text,
  coupon text,
  image_url text,
  position int default 0,
  clicks int not null default 0,
  created_at timestamptz default now()
);
create index if not exists products_post_idx on public.products(post_id);

-- 4) SEGURANÇA: todo mundo pode VER, só você (logada) pode EDITAR
alter table public.settings enable row level security;
alter table public.posts    enable row level security;
alter table public.products enable row level security;

drop policy if exists "leitura publica settings" on public.settings;
drop policy if exists "admin settings"           on public.settings;
drop policy if exists "leitura publica posts"    on public.posts;
drop policy if exists "admin posts"              on public.posts;
drop policy if exists "leitura publica produtos" on public.products;
drop policy if exists "admin produtos"           on public.products;

create policy "leitura publica settings" on public.settings for select using (true);
create policy "admin settings" on public.settings for all to authenticated using (true) with check (true);

create policy "leitura publica posts" on public.posts for select using (active);
create policy "admin posts" on public.posts for all to authenticated using (true) with check (true);

create policy "leitura publica produtos" on public.products for select
  using (exists (select 1 from public.posts p where p.id = post_id and p.active));
create policy "admin produtos" on public.products for all to authenticated using (true) with check (true);

grant select on public.settings, public.posts, public.products to anon;
grant all    on public.settings, public.posts, public.products to authenticated;

-- 5) CONTADOR DE CLIQUES em cada link
create or replace function public.increment_click(pid uuid)
returns void language sql security definer set search_path = public as $$
  update public.products set clicks = clicks + 1 where id = pid;
$$;
grant execute on function public.increment_click(uuid) to anon, authenticated;

-- 6) PASTA DE IMAGENS (capas e fotos de produto)
insert into storage.buckets (id, name, public)
values ('imagens', 'imagens', true)
on conflict (id) do nothing;

drop policy if exists "imagens leitura" on storage.objects;
drop policy if exists "imagens upload"  on storage.objects;
drop policy if exists "imagens update"  on storage.objects;
drop policy if exists "imagens delete"  on storage.objects;

create policy "imagens leitura" on storage.objects for select using (bucket_id = 'imagens');
create policy "imagens upload"  on storage.objects for insert to authenticated with check (bucket_id = 'imagens');
create policy "imagens update"  on storage.objects for update to authenticated using (bucket_id = 'imagens');
create policy "imagens delete"  on storage.objects for delete to authenticated using (bucket_id = 'imagens');
