(()=>{
const section=document.getElementById('mobile'),stage=section.querySelector('.phone-stage'),phones=[...section.querySelectorAll('.showcase-phone')],buttons=[...section.querySelectorAll('[data-mobile-slide]')],full=section.querySelector('.mobile-full'),motion=matchMedia('(prefers-reduced-motion: reduce)'),count=phones.length;
let index=0,paused=motion.matches,visible=false,timer=null,start=null;
function label(){phones.forEach((phone,i)=>phone.querySelector('img').alt='MedCases Pro — '+buttons[i].textContent);}
function show(next){index=(next+count)%count;phones.forEach((phone,i)=>{phone.classList.toggle('is-current',i===index);phone.classList.toggle('is-previous',i===(index+count-1)%count);phone.classList.toggle('is-next',i===(index+1)%count);phone.setAttribute('aria-hidden',String(i!==index));});buttons.forEach((b,i)=>b.setAttribute('aria-pressed',String(i===index)));full.href=phones[index].querySelector('img').getAttribute('src');section.querySelector('.mobile-counter').textContent=String(index+1).padStart(2,'0')+' / '+String(count).padStart(2,'0');const strip=section.querySelector('.mobile-select');if(strip.scrollWidth>strip.clientWidth){const target=buttons[index];strip.scrollTo({left:target.offsetLeft-strip.offsetLeft-(strip.clientWidth-target.offsetWidth)/2,behavior:motion.matches?'instant':'smooth'});}}
function schedule(){clearInterval(timer);timer=null;if(visible&&!paused&&!document.hidden)timer=setInterval(()=>show(index+1),4000);}
buttons.forEach((b,i)=>b.addEventListener('click',()=>{show(i);schedule();}));
document.querySelectorAll('[data-open-screen]').forEach(link=>link.addEventListener('click',()=>{show(Number(link.dataset.openScreen));schedule();}));
section.addEventListener('keydown',e=>{if(e.target.matches('[data-mobile-slide]')&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();buttons[(index+(e.key==='ArrowRight'?1:count-1))%count].click();buttons[index].focus();}});
stage.addEventListener('pointerdown',e=>{start={x:e.clientX,y:e.clientY};stage.setPointerCapture(e.pointerId);});
stage.addEventListener('pointerup',e=>{if(!start)return;const dx=e.clientX-start.x,dy=e.clientY-start.y;start=null;if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy)){show(index+(dx<0?1:-1));schedule();}});
stage.addEventListener('pointercancel',()=>start=null);
new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;schedule();},{threshold:.2}).observe(stage);
new MutationObserver(label).observe(document.documentElement,{attributes:true,attributeFilter:['lang']});
document.addEventListener('visibilitychange',schedule);motion.addEventListener('change',()=>{paused=motion.matches;label();schedule();});show(0);label();
})();
