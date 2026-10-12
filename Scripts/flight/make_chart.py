#!/usr/bin/env python3
"""Render the in-flight Starlink CSV into a self-contained HTML chart (inline SVG, no deps)."""
import csv
import json
import re
import sys

POP_RE = re.compile(r"^customer\.([a-z0-9]+)\.isp\.starlink\.com$")

src, dst = sys.argv[1], sys.argv[2]
rows = []
for r in csv.DictReader(open(src)):
    num = lambda k: float(r[k]) if r.get(k) else None
    # Older CSVs have no pop_code / space_* columns: derive the code from the hostname.
    m = POP_RE.match(r["hostname"])
    code = r.get("pop_code") or (m.group(1) if m else "")
    rows.append({"t": r["utc"], "min": num("rtt_min"), "avg": num("rtt_avg"),
                 "max": num("rtt_max"), "loss": float(r["loss_pct"]),
                 "code": code, "city": r["pop_city"],
                 "space": num("space_rtt_avg"), "sloss": num("space_loss_pct")})

html = r"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Latence Starlink en vol</title>
<style>
:root{color-scheme:light;--surface:#fcfcfb;--text:#0b0b0b;--text2:#52514e;--muted:#8a8984;--grid:#e6e5e0;--axis:#c9c8c2;--s1:#2a78d6;--s2:#eb6834;--band:rgba(42,120,214,.16);--gap:#f1f0ec}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){color-scheme:dark;--surface:#1a1a19;--text:#f0efec;--text2:#c3c2b7;--muted:#8d8c85;--grid:#2c2c2a;--axis:#45453f;--s1:#3987e5;--s2:#d95926;--band:rgba(57,135,229,.22);--gap:#232322}}
:root[data-theme="dark"]{color-scheme:dark;--surface:#1a1a19;--text:#f0efec;--text2:#c3c2b7;--muted:#8d8c85;--grid:#2c2c2a;--axis:#45453f;--s1:#3987e5;--s2:#d95926;--band:rgba(57,135,229,.22);--gap:#232322}
body{margin:0;background:var(--surface);color:var(--text);font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1000px;margin:0 auto;padding:24px 16px 40px}
h1{font-size:20px;margin:0 0 4px}.sub{color:var(--text2);margin:0 0 20px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:24px}
.tile{border:1px solid var(--grid);border-radius:8px;padding:10px 12px}.tile b{display:block;font-size:22px;font-variant-numeric:tabular-nums}.tile span{color:var(--text2);font-size:12px}
h2{font-size:15px;margin:20px 0 2px}.note{color:var(--text2);font-size:12px;margin:0 0 6px}
.chart{position:relative}svg{display:block;width:100%;height:auto;overflow:visible}
svg text{fill:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
.tip{position:absolute;pointer-events:none;background:var(--surface);border:1px solid var(--axis);border-radius:6px;padding:6px 8px;font-size:12px;color:var(--text);box-shadow:0 2px 8px rgba(0,0,0,.15);display:none;white-space:nowrap;font-variant-numeric:tabular-nums}
.tip .k{color:var(--text2)}
.legend{display:flex;gap:16px;font-size:12px;color:var(--text2);margin:0 0 4px}.legend i{display:inline-block;width:14px;height:3px;border-radius:2px;margin-right:6px;vertical-align:middle}
details{margin-top:24px}summary{cursor:pointer;color:var(--text2)}
table{border-collapse:collapse;font-size:12px;margin-top:8px;font-variant-numeric:tabular-nums}td,th{padding:3px 10px;border-bottom:1px solid var(--grid);text-align:right}th{color:var(--text2);font-weight:600}
</style></head><body><main>
<h1>Latence Starlink en vol</h1>
<p class="sub" id="sub"></p>
<div class="tiles" id="tiles"></div>
<h2>Latence (ms)</h2>
<p class="note" id="note1"></p>
<div class="legend" id="legend"></div>
<div class="chart" id="c1"></div>
<h2>Perte de paquets vers 1.1.1.1 (%)</h2>
<div class="chart" id="c2"></div>
<details><summary>Tableau des relevés</summary><table id="tbl"></table></details>
</main>
<script>
const D=__DATA__;
const T=D.map(d=>Date.parse(d.t));
const esc=v=>String(v).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const hhmm=ms=>new Date(ms).toISOString().slice(11,16);
const hhmmss=ms=>new Date(ms).toISOString().slice(11,19);
const f0=v=>v==null?'–':v.toFixed(0);
const avgs=D.filter(d=>d.avg!=null).map(d=>d.avg).sort((a,b)=>a-b);
const med=avgs[Math.floor(avgs.length/2)];
const lossN=D.filter(d=>d.loss>0).length;
const hasSpace=D.some(d=>d.space!=null);
const gaps=[];for(let i=1;i<T.length;i++)if(T[i]-T[i-1]>90e3)gaps.push([T[i-1],T[i]]);
const gapMin=Math.round(gaps.reduce((s,g)=>s+(g[1]-g[0]),0)/60e3);
// PoP segments: a new one starts whenever a known code differs from the previous known code
const cityOf={};D.forEach(d=>{if(d.code&&d.city)cityOf[d.code]=d.city});
const popLabel=c=>cityOf[c]?`${cityOf[c]} (${c})`:c;
const pops=[];D.forEach((d,i)=>{if(d.code&&(!pops.length||pops[pops.length-1].code!==d.code))pops.push({i,code:d.code})});
const changes=pops.slice(1);
document.getElementById('sub').textContent=`${D.length} relevés · ${hhmm(T[0])} → ${hhmm(T[T.length-1])} UTC · PoP de sortie : ${pops.map(p=>popLabel(p.code)).join(' → ')||'inconnu'}`;
const sp=D.filter(d=>d.space!=null).map(d=>d.space).sort((a,b)=>a-b);
document.getElementById('tiles').innerHTML=[
 [f0(med)+' ms','latence médiane (Internet)'],
 ...(hasSpace?[[f0(sp[Math.floor(sp.length/2)])+' ms','latence médiane (segment spatial)']]:[[f0(avgs[0])+' ms','meilleure moyenne']]),
 [f0(avgs[avgs.length-1])+' ms','pire moyenne'],[lossN+' / '+D.length,'relevés avec perte'],
 [String(changes.length),'changements de PoP'],
 [gaps.length?`${gaps.length} (${gapMin} min)`:'0','trous de mesure']].map(([v,l])=>`<div class="tile"><b>${esc(v)}</b><span>${l}</span></div>`).join('');
document.getElementById('note1').textContent='Moyenne par relevé · zone : min–max vers 1.1.1.1 · bandes grises : pas de relevé (> 90 s) · tirets : changement de PoP'+(hasSpace?' · écart entre les deux lignes : Internet au-delà du sol':'');
document.getElementById('legend').innerHTML=hasSpace?'<span><i style="background:var(--s1)"></i>Bout en bout (1.1.1.1)</span><span><i style="background:var(--s2)"></i>Segment spatial (100.64.0.1)</span>':'';

function chart(el,h,yMax,yTicks,draw,tipFn,popLabels){
 const W=960,m={l:40,r:12,t:popLabels?20:8,b:24},iw=W-m.l-m.r,ih=h-m.t-m.b;
 const x=t=>m.l+(t-T[0])/(T[T.length-1]-T[0])*iw, y=v=>m.t+ih-v/yMax*ih;
 let s=`<svg viewBox="0 0 ${W} ${h}" role="img">`;
 gaps.forEach(([a,b])=>s+=`<rect x="${x(a)}" y="${m.t}" width="${x(b)-x(a)}" height="${ih}" fill="var(--gap)"/>`);
 yTicks.forEach(v=>s+=`<line x1="${m.l}" x2="${W-m.r}" y1="${y(v)}" y2="${y(v)}" stroke="var(--grid)"/><text x="${m.l-6}" y="${y(v)+4}" text-anchor="end">${v}</text>`);
 const step=10*60e3,t0=Math.ceil(T[0]/step)*step;
 for(let t=t0;t<=T[T.length-1];t+=step)s+=`<text x="${x(t)}" y="${h-6}" text-anchor="middle">${hhmm(t)}</text>`;
 s+=`<line x1="${m.l}" x2="${W-m.r}" y1="${y(0)}" y2="${y(0)}" stroke="var(--axis)"/>`;
 changes.forEach(c=>{const px=x(T[c.i]);s+=`<line x1="${px}" x2="${px}" y1="${m.t}" y2="${m.t+ih}" stroke="var(--text2)" stroke-dasharray="4 3"/>`;
  if(popLabels)s+=`<text x="${px}" y="12" text-anchor="${px>W-120?'end':'middle'}" style="fill:var(--text2)">→ ${esc(popLabel(c.code))}</text>`});
 s+=draw(x,y)+`<line class="xh" y1="${m.t}" y2="${m.t+ih}" stroke="var(--axis)" style="display:none"/><circle class="dot" r="4" fill="var(--s1)" stroke="var(--surface)" stroke-width="2" style="display:none"/><circle class="dot2" r="4" fill="var(--s2)" stroke="var(--surface)" stroke-width="2" style="display:none"/>`;
 s+=`<rect x="${m.l}" y="0" width="${iw}" height="${h}" fill="transparent" class="hit"/></svg><div class="tip"></div>`;
 el.innerHTML=s;
 const svg=el.querySelector('svg'),tip=el.querySelector('.tip'),xh=el.querySelector('.xh'),dots=[el.querySelector('.dot'),el.querySelector('.dot2')];
 const hide=()=>{tip.style.display='none';xh.style.display='none';dots.forEach(d=>d.style.display='none')};
 el.querySelector('.hit').addEventListener('pointermove',e=>{
  const p=svg.createSVGPoint();p.x=e.clientX;p.y=e.clientY;const q=p.matrixTransform(svg.getScreenCTM().inverse());
  let i=0,best=1e18;T.forEach((t,j)=>{const dd=Math.abs(x(t)-q.x);if(dd<best){best=dd;i=j}});
  const {vals,html}=tipFn(D[i]);const px=x(T[i]);
  xh.setAttribute('x1',px);xh.setAttribute('x2',px);xh.style.display='';
  dots.forEach((d,k)=>{const v=vals[k];if(v!=null){d.setAttribute('cx',px);d.setAttribute('cy',y(v));d.style.display=''}else d.style.display='none'});
  tip.innerHTML=`<div class="k">${hhmmss(T[i])} UTC${D[i].code?' · PoP '+esc(popLabel(D[i].code)):''}</div>`+html;tip.style.display='block';
  const r=el.getBoundingClientRect(),lx=(px/W)*r.width;
  tip.style.left=Math.min(Math.max(lx+12,0),r.width-tip.offsetWidth)+'px';tip.style.top='8px';
 });
 el.querySelector('.hit').addEventListener('pointerleave',hide);
}
// break series at gaps and missing values
function segs(key){const out=[];let cur=[];D.forEach((d,i)=>{const brk=i>0&&T[i]-T[i-1]>90e3;if(d[key]==null||brk){if(cur.length)out.push(cur);cur=[]}if(d[key]!=null)cur.push(i)});if(cur.length)out.push(cur);return out}
const line=(x,y,sg,key,color)=>`<polyline points="${sg.map(i=>`${x(T[i])},${y(D[i][key])}`).join(' ')}" fill="none" stroke="var(${color})" stroke-width="2" stroke-linejoin="round"/>`;
const yMax1=Math.ceil(Math.max(50,...D.map(d=>d.max||0),...D.map(d=>d.space||0))/50)*50;
const tk=Math.max(50,Math.ceil(yMax1/6/50)*50);
chart(document.getElementById('c1'),320,yMax1,Array.from({length:Math.floor(yMax1/tk)+1},(_,k)=>k*tk),(x,y)=>{
 let s='';segs('avg').forEach(sg=>{
  const up=sg.map(i=>`${x(T[i])},${y(D[i].max)}`),dn=sg.slice().reverse().map(i=>`${x(T[i])},${y(D[i].min)}`);
  s+=`<polygon points="${up.concat(dn).join(' ')}" fill="var(--band)"/>`+line(x,y,sg,'avg','--s1');
 });
 segs('space').forEach(sg=>s+=line(x,y,sg,'space','--s2'));
 return s},
 d=>({vals:[d.avg,d.space],html:(d.avg==null?'bout en bout : aucune réponse':`bout en bout <b>${f0(d.avg)} ms</b> <span class="k">(min ${f0(d.min)} · max ${f0(d.max)})</span>`)+
   (hasSpace?`<br>segment spatial <b>${d.space==null?'aucune réponse':f0(d.space)+' ms'}</b>`+(d.avg!=null&&d.space!=null?`<br><span class="k">au-delà du sol : ${f0(d.avg-d.space)} ms</span>`:''):'')}),true);
chart(document.getElementById('c2'),140,100,[0,50,100],(x,y)=>{
 const bw=Math.max(2,(960-52)/D.length-2);let s='';
 D.forEach((d,i)=>{if(d.loss>0){const h=Math.max(2,y(0)-y(d.loss));s+=`<rect x="${x(T[i])-bw/2}" y="${y(0)-h}" width="${bw}" height="${h}" rx="2" fill="var(--s1)"/>`}});return s},
 d=>({vals:[],html:`perte bout en bout <b>${d.loss} %</b>`+(d.sloss!=null?`<br>perte segment spatial <b>${d.sloss} %</b>`:'')}),false);
document.getElementById('tbl').innerHTML='<tr><th>UTC</th><th>min</th><th>moy.</th><th>max</th><th>perte %</th>'+(hasSpace?'<th>spatial</th><th>perte spatial %</th>':'')+'<th>PoP</th></tr>'+
 D.map((d,i)=>`<tr><td>${hhmmss(T[i])}</td><td>${f0(d.min)}</td><td>${f0(d.avg)}</td><td>${f0(d.max)}</td><td>${d.loss}</td>`+(hasSpace?`<td>${f0(d.space)}</td><td>${d.sloss??'–'}</td>`:'')+`<td>${esc(d.code||'–')}</td></tr>`).join('');
</script></body></html>"""
open(dst, "w").write(html.replace("__DATA__", json.dumps(rows)))
print(dst, len(rows))
