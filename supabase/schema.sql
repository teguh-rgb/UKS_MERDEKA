-- UKS Digital: skema database (snapshot dari proyek Supabase yang berjalan)
--
-- Cara pakai: buka SQL Editor di project Supabase BARU yang masih kosong,
-- tempel seluruh isi file ini, lalu Run.
--
-- Catatan penting:
--  * Pendaftaran akun TIDAK membuat profil otomatis. Akun baru tidak punya akses
--    apa pun sampai Admin memanggil approve_user() (lewat menu Akun di web).
--  * Semua perubahan data dilakukan lewat fungsi (RPC) yang mengecek peran.
--    Tabel hanya boleh dibaca, kecuali tabel kelolaan Admin (lihat policy).
--  * Setiap perubahan skema berikutnya: buat file baru di supabase/migrations/
--    dan perbarui file ini.

set search_path = public;
set check_function_bodies = off;

-- ============ Tipe data ============
create type public.activity_tone as enum ('neutral', 'success', 'danger');
create type public.correction_decision as enum ('pending', 'approved', 'rejected');
create type public.equipment_status as enum ('baik', 'perlu_kalibrasi', 'rusak');
create type public.log_status as enum ('sah', 'menunggu_persetujuan', 'dikoreksi_disetujui', 'ditolak');
create type public.pickup_category as enum ('orang_tua', 'wali_keluarga', 'driver');
create type public.user_role as enum ('admin', 'petugas_uks', 'wali_kelas');
create type public.visit_status as enum ('istirahat', 'menunggu_konfirmasi_wali', 'menunggu_verifikasi_fisik', 'sudah_dijemput', 'kembali_ke_kelas');

-- ============ Tabel ============
create table public.activity_log (
  id uuid not null default gen_random_uuid(),
  message text not null,
  tone activity_tone not null default 'neutral'::activity_tone,
  audience user_role[] not null,
  kelas text,
  created_by uuid,
  created_at timestamp with time zone not null default now()
);
create table public.classes (
  id uuid not null default gen_random_uuid(),
  nama text not null,
  wali_kelas_id uuid,
  created_at timestamp with time zone not null default now()
);
create table public.equipment (
  id uuid not null default gen_random_uuid(),
  nama text not null,
  kategori text,
  status equipment_status not null default 'baik'::equipment_status,
  last_updated_by uuid,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);
create table public.equipment_status_log (
  id uuid not null default gen_random_uuid(),
  equipment_id uuid not null,
  status equipment_status not null,
  changed_by uuid,
  changed_at timestamp with time zone not null default now()
);
create table public.medicine_log_corrections (
  id uuid not null default gen_random_uuid(),
  medicine_log_id uuid not null,
  original_dosis text not null,
  proposed_dosis text not null,
  reason text not null,
  requested_by uuid,
  requested_at timestamp with time zone not null default now(),
  decision correction_decision not null default 'pending'::correction_decision,
  decided_by uuid,
  decided_at timestamp with time zone
);
create table public.medicine_logs (
  id uuid not null default gen_random_uuid(),
  visit_id uuid not null,
  medicine_id uuid not null,
  dosis text not null,
  officer_id uuid,
  given_at timestamp with time zone not null default now(),
  status log_status not null default 'sah'::log_status,
  created_at timestamp with time zone not null default now(),
  jumlah integer,
  tindakan text
);
create table public.medicines (
  id uuid not null default gen_random_uuid(),
  nama text not null,
  kategori text,
  satuan text not null default 'unit'::text,
  stok integer not null default 0,
  threshold_min integer not null default 0,
  tanggal_kadaluarsa date,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);
create table public.profiles (
  id uuid not null,
  full_name text not null,
  role user_role not null,
  kelas text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  aktif boolean not null default true
);
create table public.students (
  id uuid not null default gen_random_uuid(),
  nama text not null,
  kelas text not null,
  nis text,
  created_at timestamp with time zone not null default now(),
  nisn text,
  jurusan text,
  tanggal_lahir date,
  jenis_kelamin text,
  golongan_darah text,
  riwayat_alergi text
);
create table public.uks_visits (
  id uuid not null default gen_random_uuid(),
  student_id uuid not null,
  petugas_id uuid,
  keluhan text,
  bb_kg numeric(5,2),
  tb_cm numeric(5,1),
  suhu_c numeric(4,1),
  tensi text,
  status visit_status not null default 'istirahat'::visit_status,
  masuk_at timestamp with time zone not null default now(),
  offline_synced boolean not null default true,
  wali_confirmed_by uuid,
  wali_confirmed_at timestamp with time zone,
  verified_by uuid,
  verified_category pickup_category,
  verified_at timestamp with time zone,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

-- ============ Kunci dan batasan ============
alter table public.activity_log add constraint activity_log_pkey PRIMARY KEY (id);
alter table public.classes add constraint classes_pkey PRIMARY KEY (id);
alter table public.equipment_status_log add constraint equipment_status_log_pkey PRIMARY KEY (id);
alter table public.equipment add constraint equipment_pkey PRIMARY KEY (id);
alter table public.medicine_log_corrections add constraint medicine_log_corrections_pkey PRIMARY KEY (id);
alter table public.medicine_logs add constraint medicine_logs_pkey PRIMARY KEY (id);
alter table public.medicines add constraint medicines_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.students add constraint students_pkey PRIMARY KEY (id);
alter table public.uks_visits add constraint uks_visits_pkey PRIMARY KEY (id);
alter table public.classes add constraint classes_nama_key UNIQUE (nama);
alter table public.medicine_logs add constraint medicine_logs_jumlah_check CHECK (((jumlah IS NULL) OR (jumlah > 0)));
alter table public.medicines add constraint medicines_stok_check CHECK ((stok >= 0));
alter table public.medicines add constraint medicines_threshold_min_check CHECK ((threshold_min >= 0));
alter table public.students add constraint students_golongan_darah_check CHECK (((golongan_darah = ANY (ARRAY['A'::text, 'B'::text, 'AB'::text, 'O'::text])) OR (golongan_darah IS NULL)));
alter table public.students add constraint students_jenis_kelamin_check CHECK (((jenis_kelamin = ANY (ARRAY['L'::text, 'P'::text])) OR (jenis_kelamin IS NULL)));
alter table public.activity_log add constraint activity_log_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.classes add constraint classes_wali_kelas_id_fkey FOREIGN KEY (wali_kelas_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.equipment_status_log add constraint equipment_status_log_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.equipment_status_log add constraint equipment_status_log_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE CASCADE;
alter table public.equipment add constraint equipment_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.medicine_log_corrections add constraint medicine_log_corrections_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.medicine_log_corrections add constraint medicine_log_corrections_medicine_log_id_fkey FOREIGN KEY (medicine_log_id) REFERENCES medicine_logs(id) ON DELETE RESTRICT;
alter table public.medicine_log_corrections add constraint medicine_log_corrections_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.medicine_logs add constraint medicine_logs_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE RESTRICT;
alter table public.medicine_logs add constraint medicine_logs_officer_id_fkey FOREIGN KEY (officer_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.medicine_logs add constraint medicine_logs_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES uks_visits(id) ON DELETE RESTRICT;
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.uks_visits add constraint uks_visits_petugas_id_fkey FOREIGN KEY (petugas_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.uks_visits add constraint uks_visits_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE RESTRICT;
alter table public.uks_visits add constraint uks_visits_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.uks_visits add constraint uks_visits_wali_confirmed_by_fkey FOREIGN KEY (wali_confirmed_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- ============ Indeks ============
CREATE INDEX idx_activity_audience ON public.activity_log USING gin (audience);
CREATE INDEX idx_activity_created_at ON public.activity_log USING btree (created_at DESC);
CREATE INDEX idx_activity_log_created_by ON public.activity_log USING btree (created_by);
CREATE INDEX idx_classes_wali_kelas_id ON public.classes USING btree (wali_kelas_id);
CREATE INDEX idx_corrections_decided_by ON public.medicine_log_corrections USING btree (decided_by);
CREATE INDEX idx_corrections_decision ON public.medicine_log_corrections USING btree (decision);
CREATE INDEX idx_corrections_log ON public.medicine_log_corrections USING btree (medicine_log_id);
CREATE INDEX idx_corrections_requested_by ON public.medicine_log_corrections USING btree (requested_by);
CREATE INDEX idx_equipment_last_updated_by ON public.equipment USING btree (last_updated_by);
CREATE INDEX idx_equipment_status ON public.equipment USING btree (status);
CREATE INDEX idx_equipment_status_log_changed_by ON public.equipment_status_log USING btree (changed_by);
CREATE INDEX idx_equipment_status_log_equipment ON public.equipment_status_log USING btree (equipment_id);
CREATE INDEX idx_medicine_logs_medicine_id ON public.medicine_logs USING btree (medicine_id);
CREATE INDEX idx_medicine_logs_officer_id ON public.medicine_logs USING btree (officer_id);
CREATE INDEX idx_medicine_logs_status ON public.medicine_logs USING btree (status);
CREATE INDEX idx_medicine_logs_visit ON public.medicine_logs USING btree (visit_id);
CREATE INDEX idx_medicines_expiry ON public.medicines USING btree (tanggal_kadaluarsa);
CREATE INDEX idx_students_kelas ON public.students USING btree (kelas);
CREATE UNIQUE INDEX idx_students_nisn_unique ON public.students USING btree (nisn) WHERE (nisn IS NOT NULL);
CREATE INDEX idx_uks_visits_masuk_at ON public.uks_visits USING btree (masuk_at DESC);
CREATE INDEX idx_uks_visits_petugas_id ON public.uks_visits USING btree (petugas_id);
CREATE INDEX idx_uks_visits_status ON public.uks_visits USING btree (status);
CREATE INDEX idx_uks_visits_student ON public.uks_visits USING btree (student_id);
CREATE INDEX idx_uks_visits_verified_by ON public.uks_visits USING btree (verified_by);
CREATE INDEX idx_uks_visits_wali_confirmed_by ON public.uks_visits USING btree (wali_confirmed_by);

-- ============ Row Level Security: aktif di semua tabel ============
alter table public.activity_log enable row level security;
alter table public.classes enable row level security;
alter table public.equipment enable row level security;
alter table public.equipment_status_log enable row level security;
alter table public.medicine_log_corrections enable row level security;
alter table public.medicine_logs enable row level security;
alter table public.medicines enable row level security;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.uks_visits enable row level security;

-- ============ Fungsi peran (dipakai oleh policy) ============
CREATE OR REPLACE FUNCTION public."current_role"()
 RETURNS user_role
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select role from public.profiles where id = auth.uid() and aktif $function$;

CREATE OR REPLACE FUNCTION public.current_kelas()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select kelas from public.profiles where id = auth.uid() and aktif $function$;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.current_role() = 'admin', false);
$function$;

CREATE OR REPLACE FUNCTION public.is_petugas()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.current_role() = 'petugas_uks', false);
$function$;

CREATE OR REPLACE FUNCTION public.is_petugas_or_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_petugas() or public.is_admin();
$function$;

CREATE OR REPLACE FUNCTION public.is_wali()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.current_role() = 'wali_kelas', false);
$function$;

-- ============ Fungsi trigger ============
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.forbid_medicine_log_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  raise exception 'Log pemberian obat tidak boleh dihapus (audit trail permanen, lihat REQ-04-EDIT).';
end;
$function$;

-- ============ Fungsi internal (tidak boleh dipanggil dari web) ============
CREATE OR REPLACE FUNCTION public.log_activity(p_message text, p_audience user_role[], p_tone activity_tone DEFAULT 'neutral'::activity_tone, p_kelas text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.activity_log (message, tone, audience, kelas, created_by)
  values (p_message, p_tone, p_audience, p_kelas, auth.uid());
end;
$function$;

-- ============ Fungsi yang dipanggil web (RPC) ============
-- Akun: persetujuan oleh Admin
CREATE OR REPLACE FUNCTION public.pending_users()
 RETURNS TABLE(id uuid, email text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_admin() then raise exception 'Hanya Admin yang dapat melihat akun menunggu.'; end if;
  return query select u.id, u.email::text, u.created_at from auth.users u
    where not exists (select 1 from public.profiles p where p.id = u.id) order by u.created_at;
end $function$;

CREATE OR REPLACE FUNCTION public.approve_user(p_user uuid, p_full_name text, p_role user_role, p_kelas text DEFAULT NULL::text, p_aktif boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_admin() then raise exception 'Hanya Admin yang dapat mengatur akun.'; end if;
  if char_length(trim(coalesce(p_full_name, ''))) < 2 then raise exception 'Nama wajib diisi.'; end if;
  if p_role = 'wali_kelas' and nullif(trim(p_kelas), '') is null then raise exception 'Wali Kelas wajib punya kelas.'; end if;
  if p_user = auth.uid() and (p_role <> 'admin' or not p_aktif) then raise exception 'Tidak bisa menurunkan atau menonaktifkan akun sendiri.'; end if;
  if not exists (select 1 from auth.users where id = p_user) then raise exception 'Akun tidak ditemukan.'; end if;
  insert into public.profiles(id, full_name, role, kelas, aktif)
  values (p_user, trim(p_full_name), p_role, case when p_role = 'wali_kelas' then trim(p_kelas) end, p_aktif)
  on conflict (id) do update set full_name = excluded.full_name, role = excluded.role, kelas = excluded.kelas, aktif = excluded.aktif;
  update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()) where id = p_user;
end $function$;

-- Kunjungan dan penjemputan
CREATE OR REPLACE FUNCTION public.create_uks_visit(p_nama text, p_kelas text, p_keluhan text DEFAULT NULL::text, p_bb numeric DEFAULT NULL::numeric, p_tb numeric DEFAULT NULL::numeric, p_suhu numeric DEFAULT NULL::numeric, p_tensi text DEFAULT NULL::text, p_offline_synced boolean DEFAULT true)
 RETURNS uks_visits
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_student_id uuid;
  v_visit public.uks_visits;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Petugas UKS/Admin yang dapat menginput pemeriksaan fisik.';
  end if;

  select id into v_student_id from public.students
    where nama = p_nama and kelas = p_kelas
    limit 1;

  if v_student_id is null then
    insert into public.students (nama, kelas) values (p_nama, p_kelas)
      returning id into v_student_id;
  end if;

  insert into public.uks_visits
    (student_id, petugas_id, keluhan, bb_kg, tb_cm, suhu_c, tensi, offline_synced)
  values
    (v_student_id, auth.uid(), p_keluhan, p_bb, p_tb, p_suhu, p_tensi, p_offline_synced)
  returning * into v_visit;

  perform public.log_activity(
    format('Pemeriksaan fisik baru: %s (%s) — %s.', p_nama, p_kelas, coalesce(p_keluhan, 'tanpa keluhan spesifik')),
    array['admin','petugas_uks']::public.user_role[],
    'neutral',
    p_kelas
  );

  return v_visit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_pickup_wali(p_visit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_kelas text; v_status public.visit_status; v_nama text;
begin
  if not public.is_wali() then
    raise exception 'Hanya Wali Kelas yang dapat memberi konfirmasi penjemputan.';
  end if;

  select s.nama, s.kelas, v.status into v_nama, v_kelas, v_status
    from public.uks_visits v join public.students s on s.id = v.student_id
    where v.id = p_visit_id;

  if v_kelas is null then
    raise exception 'Kunjungan UKS tidak ditemukan.';
  end if;
  if v_kelas is distinct from public.current_kelas() then
    raise exception 'Anda hanya dapat mengonfirmasi siswa di kelas Anda sendiri.';
  end if;
  if v_status is distinct from 'istirahat' then
    raise exception 'Siswa ini tidak dalam status yang dapat dikonfirmasi untuk dijemput.';
  end if;

  update public.uks_visits
    set status = 'menunggu_verifikasi_fisik',
        wali_confirmed_by = auth.uid(),
        wali_confirmed_at = now()
    where id = p_visit_id;

  perform public.log_activity(
    format('%s (%s) dikonfirmasi oleh Wali Kelas untuk dijemput. Menunggu verifikasi fisik Petugas UKS.', v_nama, v_kelas),
    array['admin','petugas_uks']::public.user_role[],
    'neutral',
    v_kelas
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.verify_pickup_petugas(p_visit_id uuid, p_category pickup_category)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_kelas text; v_status public.visit_status; v_nama text;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Petugas UKS/Admin yang dapat melakukan verifikasi fisik penjemputan.';
  end if;

  select s.nama, s.kelas, v.status into v_nama, v_kelas, v_status
    from public.uks_visits v join public.students s on s.id = v.student_id
    where v.id = p_visit_id;

  if v_status is null then
    raise exception 'Kunjungan UKS tidak ditemukan.';
  end if;
  if v_status is distinct from 'menunggu_verifikasi_fisik' then
    raise exception 'Siswa ini belum dikonfirmasi oleh Wali Kelas.';
  end if;

  update public.uks_visits
    set status = 'sudah_dijemput',
        verified_by = auth.uid(),
        verified_category = p_category,
        verified_at = now(),
        resolved_at = now()
    where id = p_visit_id;

  perform public.log_activity(
    format('%s (%s) telah diverifikasi & dipulangkan oleh Petugas UKS — dijemput oleh %s.', v_nama, v_kelas, p_category::text),
    array['admin','wali_kelas']::public.user_role[],
    'success',
    v_kelas
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_to_class(p_visit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nama text; v_kelas text;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Petugas UKS/Admin yang dapat mengubah status ini.';
  end if;

  select s.nama, s.kelas into v_nama, v_kelas
    from public.uks_visits v join public.students s on s.id = v.student_id
    where v.id = p_visit_id;

  update public.uks_visits
    set status = 'kembali_ke_kelas', resolved_at = now()
    where id = p_visit_id;

  perform public.log_activity(
    format('%s (%s) telah kembali ke kelas.', v_nama, v_kelas),
    array['admin','petugas_uks']::public.user_role[],
    'success',
    v_kelas
  );
end;
$function$;

-- Obat
CREATE OR REPLACE FUNCTION public.give_medicine(p_visit_id uuid, p_medicine_id uuid, p_dosis text, p_jumlah integer, p_tindakan text DEFAULT NULL::text)
 RETURNS medicine_logs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_log public.medicine_logs;
  v_nama_obat text;
  v_nama_siswa text;
  v_stok integer;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Administrasi UKS/Penanggung Jawab UKS yang dapat mencatat pemberian obat.';
  end if;
  if p_jumlah is null or p_jumlah < 1 then
    raise exception 'Jumlah obat yang diberikan wajib diisi (minimal 1 unit terkecil).';
  end if;

  select nama, stok into v_nama_obat, v_stok from public.medicines where id = p_medicine_id for update;
  select s.nama into v_nama_siswa from public.uks_visits v
    join public.students s on s.id = v.student_id where v.id = p_visit_id;

  if v_nama_obat is null then
    raise exception 'Obat tidak ditemukan.';
  end if;
  if v_stok < p_jumlah then
    raise exception 'Stok tidak mencukupi: tersisa % , diminta %.', v_stok, p_jumlah;
  end if;

  insert into public.medicine_logs (visit_id, medicine_id, dosis, jumlah, tindakan, officer_id, status)
  values (p_visit_id, p_medicine_id, p_dosis, p_jumlah, p_tindakan, auth.uid(), 'sah')
  returning * into v_log;

  update public.medicines set stok = stok - p_jumlah where id = p_medicine_id;

  perform public.log_activity(
    format('Obat diberikan: %s (%s unit) untuk %s.', v_nama_obat, p_jumlah, coalesce(v_nama_siswa,'-')),
    array['admin']::public.user_role[],
    'neutral'
  );

  return v_log;
end;
$function$;

CREATE OR REPLACE FUNCTION public.restock_medicine(p_medicine_id uuid, p_jumlah integer, p_catatan text DEFAULT NULL::text)
 RETURNS medicines
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_med public.medicines;
begin
  if not public.is_admin() then
    raise exception 'Hanya Penanggung Jawab UKS yang dapat menambah stok obat secara manual.';
  end if;
  if p_jumlah is null or p_jumlah < 1 then
    raise exception 'Jumlah tambahan stok wajib diisi (minimal 1).';
  end if;

  update public.medicines set stok = stok + p_jumlah where id = p_medicine_id
    returning * into v_med;
  if v_med.id is null then
    raise exception 'Obat tidak ditemukan.';
  end if;

  perform public.log_activity(
    format('Stok "%s" ditambah manual sebanyak %s %s.%s', v_med.nama, p_jumlah, v_med.satuan,
      case when p_catatan is not null then ' Catatan: '||p_catatan else '' end),
    array['admin']::public.user_role[],
    'neutral'
  );

  return v_med;
end;
$function$;

-- Koreksi log obat (backend sudah ada, tampilan web belum)
CREATE OR REPLACE FUNCTION public.request_medicine_correction(p_log_id uuid, p_proposed_dosis text, p_reason text)
 RETURNS medicine_log_corrections
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_log public.medicine_logs;
  v_correction public.medicine_log_corrections;
  v_nama_siswa text;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Petugas UKS/Admin yang dapat mengajukan koreksi log obat.';
  end if;
  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'Alasan koreksi wajib diisi.';
  end if;

  select * into v_log from public.medicine_logs where id = p_log_id for update;
  if v_log.id is null then
    raise exception 'Log obat tidak ditemukan.';
  end if;
  if v_log.status is distinct from 'sah' then
    raise exception 'Hanya log berstatus sah yang dapat diajukan koreksi.';
  end if;

  insert into public.medicine_log_corrections
    (medicine_log_id, original_dosis, proposed_dosis, reason, requested_by, decision)
  values
    (p_log_id, v_log.dosis, p_proposed_dosis, p_reason, auth.uid(), 'pending')
  returning * into v_correction;

  update public.medicine_logs set status = 'menunggu_persetujuan' where id = p_log_id;

  select s.nama into v_nama_siswa from public.uks_visits v
    join public.students s on s.id = v.student_id where v.id = v_log.visit_id;

  perform public.log_activity(
    format('Pengajuan koreksi log obat untuk %s.', coalesce(v_nama_siswa,'-')),
    array['admin']::public.user_role[],
    'neutral'
  );

  return v_correction;
end;
$function$;

CREATE OR REPLACE FUNCTION public.approve_medicine_correction(p_correction_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_correction public.medicine_log_corrections;
  v_nama_siswa text;
begin
  if not public.is_admin() then
    raise exception 'Hanya Penanggung Jawab UKS yang dapat menyetujui koreksi.';
  end if;

  select * into v_correction from public.medicine_log_corrections where id = p_correction_id for update;
  if v_correction.id is null then
    raise exception 'Pengajuan koreksi tidak ditemukan.';
  end if;
  if v_correction.decision <> 'pending' then
    raise exception 'Pengajuan koreksi ini sudah diputuskan sebelumnya.';
  end if;

  update public.medicine_logs
    set dosis = v_correction.proposed_dosis, status = 'dikoreksi_disetujui'
    where id = v_correction.medicine_log_id;

  update public.medicine_log_corrections
    set decision = 'approved', decided_by = auth.uid(), decided_at = now()
    where id = p_correction_id;

  select s.nama into v_nama_siswa from public.medicine_logs l
    join public.uks_visits v on v.id = l.visit_id
    join public.students s on s.id = v.student_id
    where l.id = v_correction.medicine_log_id;

  perform public.log_activity(
    format('Koreksi log obat %s disetujui.', coalesce(v_nama_siswa,'-')),
    array['petugas_uks']::public.user_role[],
    'success'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.reject_medicine_correction(p_correction_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_correction public.medicine_log_corrections;
  v_nama_siswa text;
begin
  if not public.is_admin() then
    raise exception 'Hanya Penanggung Jawab UKS yang dapat menolak koreksi.';
  end if;

  select * into v_correction from public.medicine_log_corrections where id = p_correction_id for update;
  if v_correction.id is null then
    raise exception 'Pengajuan koreksi tidak ditemukan.';
  end if;
  if v_correction.decision <> 'pending' then
    raise exception 'Pengajuan koreksi ini sudah diputuskan sebelumnya.';
  end if;

  update public.medicine_logs set status = 'ditolak' where id = v_correction.medicine_log_id;

  update public.medicine_log_corrections
    set decision = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = p_correction_id;

  select s.nama into v_nama_siswa from public.medicine_logs l
    join public.uks_visits v on v.id = l.visit_id
    join public.students s on s.id = v.student_id
    where l.id = v_correction.medicine_log_id;

  perform public.log_activity(
    format('Pengajuan koreksi log obat %s ditolak. Log asli tetap berlaku.', coalesce(v_nama_siswa,'-')),
    array['petugas_uks']::public.user_role[],
    'danger'
  );
end;
$function$;

-- Alat kesehatan
CREATE OR REPLACE FUNCTION public.set_equipment_status(p_equipment_id uuid, p_status equipment_status)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_prev public.equipment_status;
  v_nama text;
begin
  if not public.is_petugas_or_admin() then
    raise exception 'Hanya Petugas UKS/Admin yang dapat mengubah status alat kesehatan.';
  end if;

  select status, nama into v_prev, v_nama from public.equipment where id = p_equipment_id for update;
  if v_nama is null then
    raise exception 'Alat kesehatan tidak ditemukan.';
  end if;

  update public.equipment
    set status = p_status, last_updated_by = auth.uid()
    where id = p_equipment_id;

  insert into public.equipment_status_log (equipment_id, status, changed_by)
    values (p_equipment_id, p_status, auth.uid());

  perform public.log_activity(
    format('Status alat "%s" diubah menjadi %s.', v_nama, p_status::text),
    array['admin','petugas_uks']::public.user_role[],
    'neutral'
  );

  if p_status is distinct from 'baik' and v_prev is not distinct from 'baik' then
    perform public.log_activity(
      format('ALKES RUSAK: %s berstatus %s. Segera karantina dan jangan gunakan untuk pelayanan!', v_nama, p_status::text),
      array['petugas_uks']::public.user_role[],
      'danger'
    );
  end if;
end;
$function$;

-- ============ Trigger ============
CREATE TRIGGER trg_equipment_updated_at BEFORE UPDATE ON public.equipment FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_medicine_logs_no_delete BEFORE DELETE ON public.medicine_logs FOR EACH ROW EXECUTE FUNCTION forbid_medicine_log_delete();
CREATE TRIGGER trg_medicines_updated_at BEFORE UPDATE ON public.medicines FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_uks_visits_updated_at BEFORE UPDATE ON public.uks_visits FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============ Kebijakan akses baris (RLS) ============
create policy activity_insert_admin_only on public.activity_log
  for INSERT to authenticated
  with check (is_admin());
create policy activity_select_scoped on public.activity_log
  for SELECT to authenticated
  using ((is_admin() OR (is_petugas() AND ('petugas_uks'::user_role = ANY (audience))) OR (is_wali() AND ('wali_kelas'::user_role = ANY (audience)) AND ((kelas IS NULL) OR (kelas = current_kelas())))));

create policy classes_delete_admin_only on public.classes
  for DELETE to authenticated
  using (is_admin());
create policy classes_insert_admin_only on public.classes
  for INSERT to authenticated
  with check (is_admin());
create policy classes_select_staff on public.classes
  for SELECT to authenticated
  using ((( SELECT "current_role"() AS "current_role") IS NOT NULL));
create policy classes_update_admin_only on public.classes
  for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy equipment_log_select_petugas_admin on public.equipment_status_log
  for SELECT to authenticated
  using (("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])));

create policy equipment_delete_admin_only on public.equipment
  for DELETE to authenticated
  using (is_admin());
create policy equipment_insert_admin_only on public.equipment
  for INSERT to authenticated
  with check (is_admin());
create policy equipment_select_petugas_admin on public.equipment
  for SELECT to authenticated
  using (("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])));

create policy corrections_select_petugas_admin on public.medicine_log_corrections
  for SELECT to authenticated
  using (("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])));

create policy medicine_logs_select_petugas_admin on public.medicine_logs
  for SELECT to authenticated
  using (("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])));

create policy medicines_delete_admin_only on public.medicines
  for DELETE to authenticated
  using (is_admin());
create policy medicines_insert_admin_only on public.medicines
  for INSERT to authenticated
  with check (is_admin());
create policy medicines_select_petugas_admin on public.medicines
  for SELECT to authenticated
  using (("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])));
create policy medicines_update_admin_only on public.medicines
  for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy profiles_delete_admin_only on public.profiles
  for DELETE to authenticated
  using (is_admin());
create policy profiles_select_scoped on public.profiles
  for SELECT to authenticated
  using (((id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_admin() AS is_admin)));
create policy profiles_update_admin_only on public.profiles
  for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy students_delete_admin_only on public.students
  for DELETE to authenticated
  using (is_admin());
create policy students_insert_admin_only on public.students
  for INSERT to authenticated
  with check (is_admin());
create policy students_select_petugas_admin on public.students
  for SELECT to authenticated
  using ((("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])) OR (is_wali() AND (kelas = current_kelas()))));
create policy students_update_admin_only on public.students
  for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy visits_select_petugas_admin on public.uks_visits
  for SELECT to authenticated
  using ((("current_role"() = ANY (ARRAY['petugas_uks'::user_role, 'admin'::user_role])) OR (is_wali() AND (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = uks_visits.student_id) AND (s.kelas = current_kelas())))))));

-- ============ Hak akses (prinsip: cabut semua, beri seperlunya) ============
-- Pengguna tanpa login (anon) tidak boleh menyentuh tabel maupun fungsi apa pun.
revoke all on all tables in schema public from anon, authenticated;
grant DELETE, INSERT, SELECT, UPDATE on public.activity_log to authenticated;
grant DELETE, INSERT, SELECT, UPDATE on public.classes to authenticated;
grant DELETE, INSERT, SELECT on public.equipment to authenticated;
grant SELECT on public.equipment_status_log to authenticated;
grant SELECT on public.medicine_log_corrections to authenticated;
grant SELECT on public.medicine_logs to authenticated;
grant DELETE, INSERT, SELECT, UPDATE on public.medicines to authenticated;
grant DELETE, INSERT, SELECT, UPDATE on public.profiles to authenticated;
grant SELECT on public.students to authenticated;
grant SELECT on public.uks_visits to authenticated;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.approve_medicine_correction(uuid) to authenticated;
grant execute on function public.approve_user(uuid, text, user_role, text, boolean) to authenticated;
grant execute on function public.confirm_pickup_wali(uuid) to authenticated;
grant execute on function public.create_uks_visit(text, text, text, numeric, numeric, numeric, text, boolean) to authenticated;
grant execute on function public.current_kelas() to authenticated;
grant execute on function public."current_role"() to authenticated;
grant execute on function public.give_medicine(uuid, uuid, text, integer, text) to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_petugas() to authenticated;
grant execute on function public.is_petugas_or_admin() to authenticated;
grant execute on function public.is_wali() to authenticated;
grant execute on function public.pending_users() to authenticated;
grant execute on function public.reject_medicine_correction(uuid) to authenticated;
grant execute on function public.request_medicine_correction(uuid, text, text) to authenticated;
grant execute on function public.resolve_to_class(uuid) to authenticated;
grant execute on function public.restock_medicine(uuid, integer, text) to authenticated;
grant execute on function public.set_equipment_status(uuid, equipment_status) to authenticated;
grant execute on function public.verify_pickup_petugas(uuid, pickup_category) to authenticated;
-- Tidak diberi ke authenticated: forbid_medicine_log_delete, log_activity, set_updated_at
revoke execute on function public.forbid_medicine_log_delete() from authenticated;
revoke execute on function public.log_activity(text, user_role[], activity_tone, text) from authenticated;
revoke execute on function public.set_updated_at() from authenticated;
