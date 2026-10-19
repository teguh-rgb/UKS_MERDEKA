'use strict';
const U='https://xeluoexmhsyuthgnqzuw.supabase.co',K='sb_publishable_KQ-ML0r0AHmBA__1qTIHyQ_lj_sb0T5';
const ST={istirahat:'Istirahat di UKS',menunggu_verifikasi_fisik:'Menunggu verifikasi jemput',sudah_dijemput:'Sudah dijemput',kembali_ke_kelas:'Kembali ke kelas',menunggu_konfirmasi_wali:'Menunggu konfirmasi wali'};
const RL={admin:'Penanggung Jawab UKS',petugas_uks:'Administrasi UKS',wali_kelas:'Wali Kelas'};
const TABS={admin:['kunjungan','obat','alat','akun'],petugas_uks:['kunjungan','obat','alat'],wali_kelas:['kunjungan']};
const LB={kunjungan:'Kunjungan',obat:'Obat',alat:'Alat',akun:'Akun'};
const EQ=[['baik','Baik'],['perlu_kalibrasi','Perlu kalibrasi'],['rusak','Rusak']];
let S=null,ME=null,tab='kunjungan',idle=0;
const $=s=>document.querySelector(s);
const h=(t,a={},...c)=>{const e=document.createElement(t);for(const k in a){if(k==='class')e.className=a[k];else if(k.startsWith('on'))e.addEventListener(k.slice(2),a[k]);else e.setAttribute(k,a[k])}e.append(...c.flat().filter(x=>x!=null&&x!==false));return e};
const safe=f=>async(...a)=>{try{await f(...a)}catch(e){alert(e.message)}};
const btn=(t,f,g)=>h('button',{class:g?'ghost sm':'sm',onclick:safe(f)},t);
const brand=()=>h('div',{class:'brand'},h('span',{class:'mark'},'+'),h('div',{},h('strong',{},'UKS Digital'),h('small',{},'Unit Kesehatan Sekolah')));
const badge=s=>h('span',{class:'b '+s},ST[s]||s);
const dt=s=>s?new Date(s).toLocaleString('id-ID',{dateStyle:'short',timeStyle:'short'}):'-';
async function api(p,o={}){
  const hd={apikey:K,'Content-Type':'application/json'},au=o.auth!==false&&S;
  if(au)hd.Authorization='Bearer '+S.access_token;
  const r=await fetch(U+p,{method:o.m||'GET',headers:hd,body:o.b?JSON.stringify(o.b):undefined});
  if(r.status===401&&au&&!o.retry&&await refresh())return api(p,{...o,retry:1});
  const t=await r.text();let j=null;try{j=t?JSON.parse(t):null}catch(e){}
  if(!r.ok)throw new Error((j&&(j.message||j.msg||j.error_description))||'Terjadi kesalahan ('+r.status+')');
  return j}
const rpc=(n,b)=>api('/rest/v1/rpc/'+n,{m:'POST',b}),get=q=>api('/rest/v1/'+q),post=(t,b)=>api('/rest/v1/'+t,{m:'POST',b});
function setSession(j){S=j;sessionStorage.setItem('rt',j.refresh_token)}
async function refresh(){
  const rt=sessionStorage.getItem('rt');if(!rt)return false;
  try{setSession(await api('/auth/v1/token?grant_type=refresh_token',{m:'POST',b:{refresh_token:rt},auth:false}));return true}
  catch(e){S=null;ME=null;sessionStorage.removeItem('rt');render();return false}}
async function boot(){const r=await get('profiles?select=full_name,role,kelas,aktif&id=eq.'+S.user.id);ME=r[0]||null;render()}
async function logout(){try{await api('/auth/v1/logout?scope=local',{m:'POST'})}catch(e){}S=null;ME=null;sessionStorage.clear();render()}
const bump=()=>{clearTimeout(idle);if(S)idle=setTimeout(logout,15*60e3)};
['click','keydown','touchstart'].forEach(e=>addEventListener(e,bump,{passive:true}));

function ask(title,fs){return new Promise(res=>{
  const d=h('dialog'),f=h('form',{method:'dialog'});let vals=null;
  f.append(h('h3',{},title));
  for(const x of fs){
    const id='f'+x.n;let i;
    if(x.t==='select')i=h('select',{id,name:x.n},x.o.map(o=>h('option',{value:o[0]},o[1])));
    else if(x.t==='area')i=h('textarea',{id,name:x.n,rows:3,maxlength:1000});
    else i=h('input',{id,name:x.n,type:x.t||'text',...(x.t==='number'?{step:'any',min:0}:x.t==='date'?{}:{maxlength:200})});
    if(x.r)i.required=true;if(x.v!=null)i.value=x.v;
    f.append(h('label',{for:id},x.l),i)}
  f.append(h('menu',{},h('button',{type:'button',class:'ghost',onclick:()=>d.close('x')},'Batal'),h('button',{value:'ok'},'Simpan')));
  f.addEventListener('submit',()=>{vals={};for(const x of fs){const v=f.elements[x.n].value.trim();vals[x.n]=x.t==='number'?(v===''?null:Number(v)):(v||null)}});
  d.addEventListener('close',()=>{d.remove();res(d.returnValue==='ok'?vals:null)});
  d.append(f);document.body.append(d);d.showModal()})}

const tbl=(hd,rows)=>h('div',{class:'tw'},h('table',{},h('thead',{},h('tr',{},hd.map(x=>h('th',{},x)))),h('tbody',{},rows.length?rows.map(r=>h('tr',{},r.map(c=>h('td',{},c)))):h('tr',{},h('td',{colspan:hd.length,class:'mut'},'Belum ada data.')))));
const V={};
const vital=v=>{const a=[['Suhu',v.suhu_c!=null&&v.suhu_c+' °C'],['Tensi',v.tensi],['BB',v.bb_kg!=null&&v.bb_kg+' kg'],['TB',v.tb_cm!=null&&v.tb_cm+' cm']].filter(x=>x[1]);return a.length?h('dl',{class:'vit'},a.flatMap(x=>[h('dt',{},x[0]),h('dd',{},x[1])])):'-'};

V.kunjungan=async()=>{
  const r=await get('uks_visits?select=id,keluhan,bb_kg,tb_cm,suhu_c,tensi,status,masuk_at,students(nama,kelas)&order=masuk_at.desc&limit=100');
  return h('div',{},ME.role==='wali_kelas'?null:h('p',{},btn('+ Pemeriksaan baru',baru)),
    tbl(['Waktu','Siswa','Kelas','Keluhan','Vital','Status','Aksi'],r.map(v=>[dt(v.masuk_at),v.students?.nama||'-',v.students?.kelas||'-',v.keluhan||'-',vital(v),badge(v.status),aksi(v)])))};
function aksi(v){
  const b=[],w=ME.role==='wali_kelas';
  if(v.status==='istirahat'){
    if(w)b.push(btn('Konfirmasi jemput',async()=>{await rpc('confirm_pickup_wali',{p_visit_id:v.id});show()}));
    else{b.push(btn('Beri obat',()=>beriObat(v)));b.push(btn('Kembali ke kelas',async()=>{await rpc('resolve_to_class',{p_visit_id:v.id});show()},1))}}
  if(v.status==='menunggu_verifikasi_fisik'&&!w)b.push(btn('Verifikasi jemput',async()=>{
    const x=await ask('Dijemput oleh',[{n:'c',l:'Kategori penjemput',t:'select',o:[['orang_tua','Orang tua'],['wali_keluarga','Wali/keluarga'],['driver','Driver']]}]);
    if(x){await rpc('verify_pickup_petugas',{p_visit_id:v.id,p_category:x.c});show()}}));
  return h('div',{class:'ac'},b)}
async function baru(){
  const x=await ask('Pemeriksaan baru',[{n:'a',l:'Nama siswa',r:1},{n:'b',l:'Kelas',r:1},{n:'c',l:'Keluhan',t:'area'},{n:'d',l:'Suhu (°C)',t:'number'},{n:'e',l:'Tensi (mis. 110/70)'},{n:'f',l:'Berat (kg)',t:'number'},{n:'g',l:'Tinggi (cm)',t:'number'}]);
  if(x){await rpc('create_uks_visit',{p_nama:x.a,p_kelas:x.b,p_keluhan:x.c,p_bb:x.f,p_tb:x.g,p_suhu:x.d,p_tensi:x.e,p_offline_synced:true});show()}}
async function beriObat(v){
  const m=await get('medicines?select=id,nama,satuan,stok&stok=gt.0&order=nama');
  if(!m.length)return alert('Stok obat kosong.');
  const x=await ask('Beri obat: '+(v.students?.nama||''),[{n:'m',l:'Obat',t:'select',o:m.map(o=>[o.id,o.nama+' (stok '+o.stok+' '+o.satuan+')'])},{n:'j',l:'Jumlah (per tablet/butir)',t:'number',r:1,v:1},{n:'d',l:'Dosis / aturan pakai',r:1},{n:'t',l:'Tindakan',t:'area'}]);
  if(x){await rpc('give_medicine',{p_visit_id:v.id,p_medicine_id:x.m,p_dosis:x.d,p_jumlah:x.j,p_tindakan:x.t});show()}}

const catatan=(o,now)=>{const x=[];if(o.stok<=o.threshold_min)x.push(h('span',{class:'b warn'},'Stok menipis'));if(o.tanggal_kadaluarsa)x.push(o.tanggal_kadaluarsa<now?h('span',{class:'b bad'},'Sudah kedaluwarsa'):h('span',{class:'t'},'Kedaluwarsa '+o.tanggal_kadaluarsa));return x.length?h('div',{class:'ac'},x):'-'};
V.obat=async()=>{
  const r=await get('medicines?select=id,nama,kategori,satuan,stok,threshold_min,tanggal_kadaluarsa&order=nama'),a=ME.role==='admin',now=new Date().toISOString().slice(0,10);
  return h('div',{},a?h('p',{},btn('+ Obat baru',obatBaru)):null,
    tbl(['Obat','Kategori','Stok','Catatan',...(a?['Aksi']:[])],r.map(o=>[o.nama,o.kategori||'-',o.stok+' '+o.satuan,
      catatan(o,now),
      ...(a?[btn('Tambah stok',async()=>{
        const x=await ask('Tambah stok: '+o.nama,[{n:'j',l:'Jumlah ('+o.satuan+')',t:'number',r:1},{n:'c',l:'Catatan'}]);
        if(x){await rpc('restock_medicine',{p_medicine_id:o.id,p_jumlah:x.j,p_catatan:x.c});show()}},1)]:[])])))};
async function obatBaru(){
  const x=await ask('Obat baru',[{n:'n',l:'Nama obat',r:1},{n:'k',l:'Kategori'},{n:'s',l:'Satuan',v:'tablet'},{n:'m',l:'Batas stok minimum',t:'number',v:10},{n:'e',l:'Tanggal kedaluwarsa',t:'date'}]);
  if(x){await post('medicines',{nama:x.n,kategori:x.k,satuan:x.s||'tablet',stok:0,threshold_min:x.m||0,tanggal_kadaluarsa:x.e});show()}}

V.alat=async()=>{
  const r=await get('equipment?select=id,nama,kategori,status&order=nama'),a=ME.role==='admin';
  return h('div',{},a?h('p',{},btn('+ Alat baru',async()=>{
      const x=await ask('Alat baru',[{n:'n',l:'Nama alat',r:1},{n:'k',l:'Kategori'}]);
      if(x){await post('equipment',{nama:x.n,kategori:x.k});show()}})):null,
    tbl(['Alat','Kategori','Status','Aksi'],r.map(q=>[q.nama,q.kategori||'-',h('span',{class:'b '+({baik:'good',perlu_kalibrasi:'warn',rusak:'bad'}[q.status]||'')},(EQ.find(e=>e[0]===q.status)||[0,q.status])[1]),btn('Ubah status',async()=>{
      const x=await ask('Status: '+q.nama,[{n:'s',l:'Status',t:'select',o:EQ,v:q.status}]);
      if(x){await rpc('set_equipment_status',{p_equipment_id:q.id,p_status:x.s});show()}},1)])))};

V.akun=async()=>{
  const [p,u]=await Promise.all([get('profiles?select=id,full_name,role,kelas,aktif&order=full_name'),rpc('pending_users',{})]);
  return h('div',{},h('h3',{},'Menunggu persetujuan'),
    tbl(['Email','Mendaftar','Aksi'],u.map(x=>[x.email,dt(x.created_at),btn('Setujui',()=>atur(x.id,'','petugas_uks',null,true))])),
    h('h3',{class:'gap'},'Akun terdaftar'),
    tbl(['Nama','Peran','Kelas','Status','Aksi'],p.map(x=>[x.full_name,RL[x.role],x.kelas||'-',x.aktif?'Aktif':'Nonaktif',btn('Ubah',()=>atur(x.id,x.full_name,x.role,x.kelas,x.aktif),1)])))};
async function atur(id,nama,role,kelas,aktif){
  const x=await ask('Atur akun',[{n:'n',l:'Nama lengkap',r:1,v:nama},{n:'r',l:'Peran',t:'select',o:Object.entries(RL),v:role},{n:'k',l:'Kelas (khusus Wali Kelas)',v:kelas},{n:'a',l:'Status',t:'select',o:[['true','Aktif'],['false','Nonaktif']],v:String(aktif)}]);
  if(x){await rpc('approve_user',{p_user:id,p_full_name:x.n,p_role:x.r,p_kelas:x.k,p_aktif:x.a==='true'});show()}}

async function show(){
  const v=$('#v');if(!v)return;
  v.replaceChildren(h('p',{class:'mut'},'Memuat…'));
  try{v.replaceChildren(await V[tab]())}catch(e){v.replaceChildren(h('p',{class:'err'},e.message))}}
function authView(reg){
  const msg=h('p',{role:'alert'}),em=h('input',{type:'email',required:'',autocomplete:'username',maxlength:200}),
    pw=h('input',{type:'password',required:'',minlength:reg?12:1,autocomplete:reg?'new-password':'current-password',maxlength:200});
  const f=h('form',{onsubmit:safe(async e=>{
    e.preventDefault();msg.textContent='';msg.className='';
    try{
      const b={email:em.value.trim(),password:pw.value};
      if(reg){await api('/auth/v1/signup',{m:'POST',b,auth:false});msg.className='ok';msg.textContent='Pendaftaran terkirim. Tunggu persetujuan Penanggung Jawab UKS, lalu masuk.'}
      else{setSession(await api('/auth/v1/token?grant_type=password',{m:'POST',b,auth:false}));await boot()}
    }catch(x){msg.className='err';msg.textContent=/invalid login/i.test(x.message)?'Email atau password salah.':/not confirmed/i.test(x.message)?'Akun belum disetujui Penanggung Jawab UKS.':x.message}})},
    h('label',{},'Email',em),h('label',{},'Password'+(reg?' (minimal 12 karakter)':''),pw),h('p',{},h('button',{},reg?'Daftar':'Masuk')),msg);
  return h('section',{class:'card auth'},brand(),h('h2',{},reg?'Daftar akun staf':'Masuk'),h('p',{class:'mut'},reg?'Akun baru perlu disetujui Penanggung Jawab UKS.':'Gunakan akun yang sudah disetujui.'),f,
    h('button',{class:'link',onclick:()=>$('main').replaceChildren(authView(!reg))},reg?'Sudah punya akun? Masuk':'Belum punya akun? Daftar'))}
function render(){
  const m=$('main');m.replaceChildren();bump();
  if(!S)return m.append(authView(false));
  if(!ME||!ME.aktif)return m.append(h('section',{class:'card auth'},h('h2',{},ME?'Akun dinonaktifkan':'Menunggu persetujuan'),
    h('p',{},ME?'Hubungi Penanggung Jawab UKS.':'Akun Anda terdaftar tetapi belum diberi peran oleh Penanggung Jawab UKS.'),h('button',{onclick:logout},'Keluar')));
  const t=TABS[ME.role];if(!t.includes(tab))tab=t[0];
  m.append(h('div',{class:'app'},
    h('aside',{},brand(),h('nav',{},t.map(k=>h('button',{class:k===tab?'on':'',onclick:()=>{tab=k;render()}},LB[k]))),
      h('div',{class:'me'},h('strong',{},ME.full_name),h('small',{},RL[ME.role]),h('button',{class:'ghost sm',onclick:logout},'Keluar'))),
    h('section',{class:'pane'},h('h1',{},LB[tab]),h('div',{id:'v'}))));
  show()}
(async()=>{try{if(await refresh())await boot();else render()}catch(e){render()}})();
