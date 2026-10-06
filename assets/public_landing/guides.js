let publicGuides=[];
// Stable UTC daily selection: no extra backend calls or changes to CMS content.
const GUIDE_DAY_MS=24*60*60*1000;
function dailyFeaturedGuides(rows,now=Date.now()){
 const count=Math.min(4,rows.length);
 if(!count)return [];
 const start=((Math.floor(now/GUIDE_DAY_MS)%rows.length)+rows.length)%rows.length;
 return Array.from({length:count},(_,i)=>rows[(start+i)%rows.length]);
}
let renderedGuideDay=Math.floor(Date.now()/GUIDE_DAY_MS);
function refreshGuideDay(){const day=Math.floor(Date.now()/GUIDE_DAY_MS);if(day!==renderedGuideDay){renderedGuideDay=day;renderPublicGuides()}}
setInterval(refreshGuideDay,60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)refreshGuideDay()});
function renderPublicGuides(){const es=document.documentElement.lang.startsWith('es'), l=es?'es':'pt';
 document.getElementById('guides-eyebrow').textContent=es?'GUÍAS CLÍNICAS':'GUIAS CLÍNICOS';document.getElementById('guides-heading').textContent=es?'Estudiá, revisá y consultá.':'Estude, revise e consulte.';document.getElementById('guides-copy').textContent=es?'Conocé guías publicadas en el catálogo MedCases.':'Conheça guias publicados no catálogo MedCases.';document.getElementById('guides-all').textContent=es?'Ver todas las guías ↗':'Ver todos os guias ↗';document.getElementById('guides-all').hash=l;
 const host=document.getElementById('featured-guides');host.replaceChildren();host.scrollLeft=0;host.setAttribute('aria-label',es?'Guías destacadas, desplazamiento horizontal':'Guias em destaque, rolagem horizontal');host.tabIndex=0;for(const g of dailyFeaturedGuides(publicGuides)){const card=document.createElement('article');card.className='guide-card';const img=document.createElement('img');img.src=g.cover;img.alt='';img.loading='lazy';const specialty=document.createElement('p');specialty.textContent=g.specialty[l];const title=document.createElement('h3');title.textContent=g.title[l];const desc=document.createElement('p');desc.textContent=es?'Contenido publicado para estudio y consulta.':'Conteúdo publicado para estudo e consulta.';const a=document.createElement('a');a.className='text-link';a.textContent=es?'Ver guía ↗':'Ver guia ↗';a.href='https://medcasespro.com/?guide='+encodeURIComponent(g.slug)+'#'+l;a.target='_top';a.onclick=e=>{if(window.parent!==window){e.preventDefault();window.parent.postMessage(JSON.stringify({type:'medcases:guide:v1',language:es?'es':'pt-BR',slug:g.slug}),window.location.origin)}};const updated=document.createElement('p');updated.textContent=(es?'Actualización del catálogo: ':'Atualização do catálogo: ')+g.updatedAt.slice(0,10);card.append(img,specialty,title,desc,updated,a);host.append(card)}}
fetch('featured_guides.json').then(r=>{if(!r.ok)throw Error('CATALOG_UNAVAILABLE');return r.json()}).then(rows=>{publicGuides=rows;renderPublicGuides()}).catch(()=>{document.getElementById('guias').hidden=true});new MutationObserver(renderPublicGuides).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
