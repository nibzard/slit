'use strict';
const concepts = [
  {id:'quiet', name:'Quiet', tag:'', title:'The photograph comes first.', description:'A black frame and a familiar centered shutter. The interface recedes; focus lock appears only when you use it.'},
  {id:'daylight', name:'Daylight', tag:'', title:'A lighter instrument.', description:'A warm, light frame with dark controls. The same layout, with a different balance between the photograph and the interface.'},
  {id:'grip', name:'Grip', tag:'CHOSEN', title:'A shorter reach for your thumb.', description:'A larger shutter on the lower right. Review stays on the left. Return from review at the same thumb position. Focus lock stays visible below the photograph.'}
];
const root = document.querySelector('#concepts');
const template = document.querySelector('#camera-template');
const states = [];
let sceneURL = 'assets/street.jpg';
let activeState;
let uploadURL;
let gridEnabled = false;
try { gridEnabled = localStorage.getItem('slit:grid:v1') === 'on'; } catch {}
function updateGrid() {
  states.forEach(state => {
    state.find('.composition-grid').hidden = !gridEnabled;
    state.find('.grid-toggle').checked = gridEnabled;
  });
}
function fitGrid(state) {
  const image=state.find('.scene'), frame=state.find('.viewfinder'), grid=state.find('.composition-grid');
  if(!image.naturalWidth || !frame.clientWidth || !frame.clientHeight) return;
  const scale=Math.min(frame.clientWidth/image.naturalWidth,frame.clientHeight/image.naturalHeight);
  const width=image.naturalWidth*scale, height=image.naturalHeight*scale;
  Object.assign(grid.style,{width:`${width}px`,height:`${height}px`,left:`${(frame.clientWidth-width)/2}px`,top:`${(frame.clientHeight-height)/2}px`});
}
const formatEV = value => Number(value) > 0 ? `+${Number(value).toFixed(1)}` : Number(value).toFixed(1);
const brightness = value => `brightness(${Math.pow(2, Number(value) * .4)})`;
function later(state, fn, delay) {
  const timer = setTimeout(() => {state.timers.delete(timer); fn();}, delay);
  state.timers.add(timer);
  return timer;
}
function setStatus(state, message) { state.find('.capture-status').textContent = message; }
function closeExposure(state) { state.find('.exposure').hidden = true; }
function updateEV(state) {
  state.find('.scene').style.filter = brightness(state.ev);
  state.find('output').textContent = formatEV(state.ev);
  state.find('.ev-slider').value = state.ev;
  const button = state.find('.ev-value');
  button.textContent = `${formatEV(state.ev)} EV`;
  button.hidden = state.ev === 0;
}
function unlock(state) {
  state.locked = false;
  state.find('.focus-lock').hidden = true;
  state.find('.focus-marker').hidden = true;
  setStatus(state, 'Autofocus');
  later(state, () => {if (!state.pending) setStatus(state, '');}, 1000);
}
function focusAt(state, x=.5, y=.5, lock=false) {
  if(state.panel) return;
  if(state.locked && !lock) { state.find('.exposure').hidden = false; return; }
  const marker = state.find('.focus-marker');
  marker.style.left = `${Math.max(.09, Math.min(.91, x))*100}%`;
  marker.style.top = `${Math.max(.07, Math.min(.93, y))*100}%`;
  marker.hidden = false;
  marker.classList.toggle('locked', lock);
  state.locked = lock;
  state.focusVersion++;
  const version = state.focusVersion;
  state.find('.focus-lock').hidden = !lock;
  if(lock) {
    closeExposure(state); setStatus(state, '');
    if(state.id==='grip') later(state, () => {if(version===state.focusVersion) marker.hidden=true;}, 700);
  }
  else {
    state.find('.exposure').hidden = false;
    later(state, () => {if (version === state.focusVersion && !state.locked) marker.hidden = true;}, 1100);
  }
}
function openPanel(state, name) {
  closeExposure(state);
  state.panel = name;
  state.find('.camera-view').inert = true;
  state.find(`.${name}-panel`).hidden = false;
  if(name === 'review') renderReview(state);
  state.find(name==='review' && state.id==='grip' ? '.return-camera' : `.${name}-panel button`).focus();
}
function closePanel(state) {
  const name = state.panel;
  if(!name) return;
  state.find(`.${name}-panel`).hidden = true;
  state.find('.camera-view').inert = false;
  state.panel = null;
  state.find(name === 'review' ? (state.id==='grip' ? '.shutter' : '.thumbnail') : '.more').focus();
}
function renderReview(state) {
  const shot = state.shots[state.reviewIndex];
  if(!shot) return;
  state.find('.review-image').src = shot.src;
  state.find('.review-image').style.filter = brightness(shot.ev);
  state.find('.review-index').textContent = `${state.reviewIndex+1} / ${state.shots.length}`;
  state.find('.review-caption').textContent = `${String(shot.id).padStart(3,'0')} · ${formatEV(shot.ev)} EV`;
  state.find('.previous').disabled = state.reviewIndex === 0;
  state.find('.next').disabled = state.reviewIndex === state.shots.length-1;
}
function capture(state) {
  activeState = state;
  if(state.panel) return;
  if(state.pending >= 2) {setStatus(state, 'Busy'); return;}
  closeExposure(state);
  const shot = {id:++state.sequence, src:sceneURL, ev:state.ev};
  state.pending++;
  const shutter = state.find('.shutter');
  shutter.setAttribute('aria-disabled', String(state.pending >= 2));
  setStatus(state, 'Saving…');
  const phone = state.find('.phone');
  phone.classList.remove('flashing');
  void phone.offsetWidth;
  phone.classList.add('flashing');
  later(state, () => phone.classList.remove('flashing'), 200);
  later(state, () => {
    state.pending--;
    state.shots.push(shot);
    state.shots.sort((a,b) => a.id-b.id);
    // Keep this disposable interaction study bounded. It is not a photo library.
    if(state.shots.length > 30) state.shots.shift();
    const latest = state.shots[state.shots.length-1];
    const thumb = state.find('.thumbnail');
    thumb.disabled = false;
    thumb.querySelector('img').src = latest.src;
    thumb.querySelector('img').style.filter = brightness(latest.ev);
    thumb.querySelector('img').hidden = false;
    thumb.querySelector('.empty-thumb').hidden = true;
    shutter.setAttribute('aria-disabled', String(state.pending >= 2));
    setStatus(state, state.pending ? 'Saving…' : 'Saved');
    later(state, () => {if(!state.pending) setStatus(state, '');}, 1400);
  }, 450);
}
concepts.forEach((concept, index) => {
  const fragment = template.content.cloneNode(true);
  const article = fragment.querySelector('article');
  article.classList.add(concept.id);
  article.dataset.concept = concept.id;
  article.querySelector('.concept-number').textContent = `0${index+1}`;
  article.querySelector('.concept-heading h2').textContent = concept.name;
  article.querySelector('.concept-tag').textContent = concept.tag;
  article.querySelector('.concept-description h3').textContent = concept.title;
  article.querySelector('.concept-description p').textContent = concept.description;
  article.querySelector('.phone').setAttribute('aria-label', `${concept.name} camera prototype`);
  root.append(fragment);
  const state = {id:concept.id, article, find:selector=>article.querySelector(selector), locked:false, focusVersion:0, ev:0, pending:0, sequence:0, shots:[], timers:new Set(), panel:null, reviewIndex:0};
  states.push(state);
  state.find('.grid-toggle').addEventListener('change', event => {
    gridEnabled=event.target.checked;
    try { localStorage.setItem('slit:grid:v1',gridEnabled?'on':'off'); } catch {}
    updateGrid();
  });
  state.find('.scene').addEventListener('load',()=>fitGrid(state));
  new ResizeObserver(()=>fitGrid(state)).observe(state.find('.viewfinder'));
  fitGrid(state);
  article.addEventListener('pointerdown', () => activeState=state);
  article.addEventListener('focusin', () => activeState=state);
  state.find('.shutter').addEventListener('click', () => capture(state));
  state.find('.focus-lock').addEventListener('click', () => {unlock(state); state.find('.viewfinder').focus();});
  state.find('.ev-value').addEventListener('click', () => state.find('.exposure').hidden = !state.find('.exposure').hidden);
  state.find('.ev-slider').addEventListener('input', event => {state.ev=Number(event.target.value); updateEV(state);});
  state.find('.ev-reset').addEventListener('click', () => {state.ev=0; updateEV(state);});
  state.find('.ev-done').addEventListener('click', () => {closeExposure(state); state.find('.viewfinder').focus();});
  state.find('.more').addEventListener('click', () => openPanel(state, 'more'));
  state.find('.close-more').addEventListener('click', () => closePanel(state));
  state.find('.lock-action').addEventListener('click', () => {closePanel(state); focusAt(state,.5,.5,true); state.find('.focus-lock').focus();});
  state.find('.thumbnail').addEventListener('click', () => {state.reviewIndex=state.shots.length-1; openPanel(state, 'review');});
  state.find('.back-camera').addEventListener('click', () => closePanel(state));
  state.find('.return-camera').addEventListener('click', () => closePanel(state));
  const reviewImage = state.find('.review-image-wrap');
  let reviewGesture = null;
  reviewImage.addEventListener('pointerdown', event => {if(event.button===0) reviewGesture={x:event.clientX,y:event.clientY};});
  reviewImage.addEventListener('pointercancel', () => reviewGesture=null);
  reviewImage.addEventListener('pointerup', event => {
    if(!reviewGesture) return;
    const dx=event.clientX-reviewGesture.x, dy=event.clientY-reviewGesture.y;
    reviewGesture=null;
    if(Math.abs(dx)<45 || Math.abs(dx)<Math.abs(dy)*1.5) return;
    state.reviewIndex=Math.max(0,Math.min(state.shots.length-1,state.reviewIndex+(dx<0?1:-1)));
    renderReview(state);
  });
  state.find('.previous').addEventListener('click', () => {state.reviewIndex--; renderReview(state);});
  state.find('.next').addEventListener('click', () => {state.reviewIndex++; renderReview(state);});
  const viewfinder=state.find('.viewfinder');
  let gesture=null;
  function cancelGesture() {if(gesture) clearTimeout(gesture.timer); gesture=null;}
  viewfinder.addEventListener('pointerdown', event => {
    if(event.button !== 0) return;
    const rect=viewfinder.getBoundingClientRect();
    gesture={id:event.pointerId,x:event.clientX,y:event.clientY,fx:(event.clientX-rect.left)/rect.width,fy:(event.clientY-rect.top)/rect.height,held:false};
    gesture.timer=setTimeout(() => {if(gesture) {gesture.held=true; focusAt(state,gesture.fx,gesture.fy,true);}},500);
    viewfinder.setPointerCapture(event.pointerId);
  });
  viewfinder.addEventListener('pointermove', event => {if(gesture && Math.hypot(event.clientX-gesture.x,event.clientY-gesture.y)>12) cancelGesture();});
  viewfinder.addEventListener('pointerup', event => {if(gesture && event.pointerId===gesture.id && !gesture.held) focusAt(state,gesture.fx,gesture.fy); cancelGesture();});
  viewfinder.addEventListener('pointercancel', cancelGesture);
  viewfinder.addEventListener('contextmenu', event => event.preventDefault());
  viewfinder.addEventListener('keydown', event => {
    if(event.key.toLowerCase()==='l') {event.preventDefault(); state.locked?unlock(state):focusAt(state,.5,.5,true);}
    if(event.key==='Enter') {event.preventDefault(); focusAt(state);}
  });
  state.cancelGesture = cancelGesture;
});
updateGrid();
activeState=states[0];
function selectView(id) {
  document.querySelectorAll('[data-view]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.view===id)));
  states.forEach(state => {state.article.hidden=id!=='all' && id!==state.id; if(state.article.hidden) {state.cancelGesture(); closePanel(state);}});
  root.classList.toggle('single',id!=='all');
  activeState=states.find(state=>!state.article.hidden);
}
document.querySelectorAll('[data-view]').forEach(button => button.addEventListener('click', () => selectView(button.dataset.view)));
const initialConcept = new URLSearchParams(location.search).get('concept');
if(concepts.some(concept=>concept.id===initialConcept)) selectView(initialConcept);
else selectView('grip');
function leaveImmersive() {
  document.body.classList.remove('immersive');
  document.querySelector('#leave-immersive').hidden=true;
  document.querySelector('.masthead').inert=false;
  for(const element of document.querySelector('main').children) if(element!==root) element.inert=false;
  document.querySelector('#try-phone').focus();
}
document.querySelector('#try-phone').addEventListener('click', () => {
  selectView(activeState.id);
  document.body.classList.add('immersive');
  document.querySelector('#leave-immersive').hidden=false;
  document.querySelector('.masthead').inert=true;
  for(const element of document.querySelector('main').children) if(element!==root) element.inert=true;
  activeState.find('.phone').focus();
});
document.querySelector('#leave-immersive').addEventListener('click',leaveImmersive);
document.querySelector('#choose-photo').addEventListener('click',()=>document.querySelector('#scene-upload').click());
function reset() {
  states.forEach(state => {
    state.timers.forEach(clearTimeout); state.timers.clear(); state.cancelGesture();
    closePanel(state); closeExposure(state);
    state.locked=false; state.focusVersion++; state.pending=0; state.sequence=0; state.shots=[]; state.ev=0;
    state.find('.scene').src=sceneURL;
    state.find('.scene').alt=uploadURL?'Your selected sample photograph':'A pedestrian crossing a sunlit avenue between tall buildings';
    state.find('.focus-lock').hidden=true;
    state.find('.focus-marker').hidden=true;
    state.find('.thumbnail').disabled=true;
    state.find('.thumbnail img').hidden=true;
    state.find('.empty-thumb').hidden=false;
    state.find('.shutter').setAttribute('aria-disabled','false');
    state.find('.phone').classList.remove('flashing');
    setStatus(state,''); updateEV(state);
  });
  activeState=states.find(state=>!state.article.hidden);
}
document.querySelector('#reset').addEventListener('click',reset);
document.querySelector('#scene-upload').addEventListener('change', event => {
  const file=event.target.files[0]; if(!file) return;
  if(file.size>25*1024*1024) {alert('Choose an image smaller than 25 MB.'); event.target.value=''; return;}
  const url=URL.createObjectURL(file);
  const image=new Image();
  image.onload=() => {if(uploadURL) URL.revokeObjectURL(uploadURL); uploadURL=url; sceneURL=url; reset();};
  image.onerror=() => {URL.revokeObjectURL(url); alert('This image cannot be opened. Choose a JPEG, PNG, or WebP image.');};
  image.src=url; event.target.value='';
});
document.addEventListener('keydown', event => {
  if(event.key==='Escape') {if(document.body.classList.contains('immersive') && !states.some(state=>state.panel || !state.find('.exposure').hidden)) leaveImmersive(); states.forEach(state => {state.cancelGesture(); closePanel(state); closeExposure(state);}); return;}
  if(event.code==='Space' && !event.repeat && activeState && !activeState.panel && (event.target===document.body || event.target.classList.contains('phone') || event.target.classList.contains('viewfinder'))) {
    event.preventDefault(); capture(activeState);
  }
});
document.addEventListener('visibilitychange', () => {if(document.hidden) states.forEach(state=>state.cancelGesture());});

if(new URLSearchParams(location.search).get('view')==='phone') document.querySelector('#try-phone').click();
