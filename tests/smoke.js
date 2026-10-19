const {JSDOM}=require('jsdom');const fs=require('fs');
const dom=new JSDOM(fs.readFileSync(__dirname+'/../public/index.html','utf8'),{runScripts:'outside-only',url:'https://x.test/'});
const w=dom.window;w.sessionStorage.setItem('rt','abc');
const now=new Date().toISOString();
const data={
 profiles:(q)=>q.includes('order=')?[{id:'u1',full_name:'Teguh',role:'admin',kelas:null,aktif:true},{id:'u2',full_name:'Sari',role:'wali_kelas',kelas:'X-1',aktif:true}]:[{full_name:'Teguh',role:'admin',kelas:null,aktif:true}],
 uks_visits:()=>[{id:'1',keluhan:'Pusing <img src=x onerror=alert(1)>',bb_kg:50,tb_cm:160,suhu_c:37.5,tensi:'110/70',status:'istirahat',masuk_at:now,students:{nama:'Budi',kelas:'X-1'}},{id:'2',keluhan:null,bb_kg:null,tb_cm:null,suhu_c:null,tensi:null,status:'menunggu_verifikasi_fisik',masuk_at:now,students:{nama:'Ani',kelas:'X-2'}}],
 medicines:()=>[{id:'m1',nama:'Paracetamol',kategori:'Analgesik',satuan:'tablet',stok:3,threshold_min:10,tanggal_kadaluarsa:'2020-01-01'}],
 equipment:()=>[{id:'e1',nama:'Termometer',kategori:'Diagnostik',status:'rusak'}],
 'rpc/pending_users':()=>[{id:'u9',email:'baru@sekolah.id',created_at:now}]};
w.fetch=async(url,o)=>{let body;const p=url.replace('https://xeluoexmhsyuthgnqzuw.supabase.co','');
 if(p.startsWith('/auth/v1/token'))body={access_token:'t',refresh_token:'r',user:{id:'u1'}};
 else{const k=Object.keys(data).find(k=>p.startsWith('/rest/v1/'+k));body=data[k](p)}
 return {status:200,ok:true,text:async()=>JSON.stringify(body)}};
w.eval(fs.readFileSync(__dirname+'/../public/app.js','utf8'));
const wait=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 await wait(150);const d=w.document;let out=[];
 for(const tab of ['Kunjungan','Obat','Alat','Akun']){
  const b=[...d.querySelectorAll('aside nav button')].find(x=>x.textContent===tab);b.click();await wait(150);
  out.push(tab+': h1='+d.querySelector('h1').textContent+' | baris='+d.querySelectorAll('tbody tr').length+' | badge='+[...d.querySelectorAll('.b')].map(x=>x.textContent).join(',')+' | img/script injeksi='+d.querySelectorAll('#v img,#v script').length);
 }
 console.log(out.join('\n'));console.log('NAV:',[...d.querySelectorAll('aside nav button')].map(x=>x.textContent).join(','));
 console.log('ME:',d.querySelector('.me').textContent);
 d.querySelector('.me button').click();await wait(30);
 let password=d.querySelector('input[type=password]'),toggle=d.querySelector('.password-toggle');
 if(!password||!toggle||toggle.getAttribute('aria-label')!=='Tampilkan password'||!toggle.querySelector('svg path'))throw Error('Ikon mata untuk password login tidak tampil');
 toggle.click();if(password.type!=='text'||toggle.getAttribute('aria-label')!=='Sembunyikan password'||!toggle.querySelector('svg circle'))throw Error('Ikon mata terbuka/password login tidak berfungsi');
 toggle.click();if(password.type!=='password'||toggle.getAttribute('aria-label')!=='Tampilkan password'||!toggle.querySelector('svg path[d="m3 3 18 18"]'))throw Error('Ikon mata tertutup/password login tidak berfungsi');
 d.querySelector('button.link').click();password=d.querySelector('input[type=password]');toggle=d.querySelector('.password-toggle');
 if(!password||password.minLength!==12||!toggle||!toggle.querySelector('svg'))throw Error('Kontrol password daftar tidak tampil atau batas 12 karakter hilang');
 toggle.click();if(password.type!=='text'||!toggle.querySelector('svg circle'))throw Error('Password daftar tidak bisa ditampilkan dengan ikon mata terbuka');
 console.log('Password: lihat/sembunyikan berfungsi saat masuk dan daftar');process.exit(0)})().catch(e=>{console.log('ERROR',e.message);process.exit(1)});
