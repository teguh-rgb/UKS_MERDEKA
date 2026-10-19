-- Uji keamanan: simulasi penyerang terhadap database.
-- Jalankan di SQL Editor Supabase pada project DEV (bukan data asli). Aman: semuanya di-rollback.
-- Hasil yang diharapkan: SEMUA baris berisi "ditolak" atau "0 baris terlihat".
-- Jika ada "BISA BACA" atau "BERHASIL (bahaya)", ada celah keamanan: jangan rilis.
begin;
create temp table hasil(urut serial, uji text, hasil text) on commit drop;
do $$
declare n bigint; r text; t text;
begin
  -- Penyerang tanpa login (anon)
  foreach t in array array['students','uks_visits','medicines','profiles','medicine_logs'] loop
    perform set_config('request.jwt.claims','',true); set local role anon;
    begin execute format('select count(*) from public.%I',t) into n; r := 'BISA BACA ('||n||' baris)'; exception when others then r := 'ditolak'; end;
    reset role; insert into pg_temp.hasil(uji,hasil) values ('anon baca '||t, r);
  end loop;
  set local role anon;
  begin perform public.create_uks_visit('x','y'); r:='BERHASIL (bahaya)'; exception when others then r:='ditolak'; end;
  reset role; insert into pg_temp.hasil(uji,hasil) values ('anon panggil create_uks_visit', r);
  -- Akun yang baru mendaftar (sudah login, belum disetujui, tanpa profil)
  perform set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}',true);
  foreach t in array array['students','uks_visits','medicines','profiles','classes','equipment','activity_log'] loop
    set local role authenticated;
    begin execute format('select count(*) from public.%I',t) into n; r := n||' baris terlihat'; exception when others then r := 'ditolak'; end;
    reset role; insert into pg_temp.hasil(uji,hasil) values ('akun baru tanpa peran baca '||t, r);
  end loop;
  set local role authenticated;
  begin perform public.create_uks_visit('x','y'); r:='BERHASIL (bahaya)'; exception when others then r:='ditolak'; end;
  reset role; insert into pg_temp.hasil(uji,hasil) values ('akun baru panggil create_uks_visit', r);
  set local role authenticated;
  begin perform public.approve_user('11111111-1111-1111-1111-111111111111','Hacker','admin'); r:='BERHASIL (bahaya)'; exception when others then r:='ditolak'; end;
  reset role; insert into pg_temp.hasil(uji,hasil) values ('akun baru angkat diri jadi admin', r);
  set local role authenticated;
  begin insert into public.profiles(id,full_name,role) values ('11111111-1111-1111-1111-111111111111','Hacker','admin'); r:='BERHASIL (bahaya)'; exception when others then r:='ditolak'; end;
  reset role; insert into pg_temp.hasil(uji,hasil) values ('akun baru tulis langsung ke profiles', r);
end $$;
select urut, uji, hasil from hasil order by urut;
rollback;
