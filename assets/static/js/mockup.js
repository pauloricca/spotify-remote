/* Standalone, simulated design preview. Spotify controls live in the Phoenix app. */
(() => {
  const content = document.querySelector('#demo-content');
  const drawer = document.querySelector('#demo-drawer');
  const query = document.querySelector('#q');
  const icon = name => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
  const image = name => `/images/demo/${name}.jpg`;
  const escape = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const songs = [
    {name:'Let It Happen',duration:468}, {name:'Nangs',duration:107},
    {name:'The Moment',duration:255}, {name:'Yes I’m Changing',duration:270},
    {name:'Eventually',duration:318}, {name:'The Less I Know The Better',duration:216},
    {name:'Borderline',duration:237}
  ];
  const state = {playing:true,track:-1,elapsed:0,volume:80,device:'This Echo Show',liked:true,shuffle:false,repeat:false,followed:false,filter:'All'};
  let toastTimer, searchTimer;
  const time = value => `${Math.floor(value/60)}:${String(Math.floor(value%60)).padStart(2,'0')}`;
  const current = () => state.track < 0 ? {name:'Espresso',duration:175} : songs[state.track];
  const cover = () => state.track < 0 ? 'short-sweet' : 'currents';
  const artist = () => state.track < 0 ? 'Sabrina Carpenter' : 'Tame Impala';
  function notify(message) {
    clearTimeout(toastTimer);
    document.querySelector('#demo-toast').textContent = message;
    toastTimer = setTimeout(() => document.querySelector('#demo-toast').textContent = '', 2400);
  }
  function card(name,by,art,href='album',extra='') {
    if (href === "album" && art !== "currents") href = "album/" + art;
    return `<a class="result" href="#${href}"><div class="artwork" ${extra}>${art ? `<img src="${image(art)}" alt="${escape(name)}" loading="lazy">`:'♥'}</div><p class="name">${name}</p><p class="muted">${by}</p></a>`;
  }
  function heading(title,link='') { return `<div class="section-heading"><h2>${title}</h2>${link ? `<a href="#${link}">See all</a>`:''}</div>`; }
  function songRow(song,index,album=false) {
    return `<button class="song-row" data-track="${index}" aria-label="Play ${song.name}">${album ? `<span class="song-index">${index+1}</span>`:`<img src="${image('currents')}" alt="">`}<span>${song.name}${album?'':'<small>Tame Impala</small>'}</span>${album?`<span class="song-duration">${time(song.duration)}</span>`:''}<span class="more" aria-hidden="true">···</span></button>`;
  }
  const mixCards = () => `<div class="mix-grid">${[
    ['Discover<br>Weekly','discover','taylor','discover weekly'],['Daily<br>Mix 1','daily','lonerism','daily mix'],
    ['Chilled<br>Vibes','chill','slow-rush','chill'],['Indie<br>Favourites','indie','stick-season','indie']
  ].map(([title,color,art,q])=>`<a href="#search/${encodeURIComponent(q)}" class="mix-card mix-${color}"><img class="mix-art" src="${image(art)}" alt=""><span>${title}</span></a>`).join('')}</div>`;
  function home() {
    return `<div class="page-heading"><h1>Good morning</h1><span class="muted" style="font-size:12px">Made for you</span></div>${mixCards()}${heading('Recently Played','library')}
      <div class="results">${card('Short n’ Sweet','Sabrina Carpenter','short-sweet','now-playing')}${card('Taylor Swift','Artist','taylor','search/Taylor%20Swift')}${card('Currents','Tame Impala','currents')}${card('Stick Season','Noah Kahan','stick-season','search/Noah%20Kahan')}${card('The Slow Rush','Tame Impala','slow-rush')}</div>
      ${heading('Your afternoon soundtrack','search')}<div class="results">${card('Lonerism','Tame Impala','lonerism')}${card('folklore','Taylor Swift','taylor','search/Taylor%20Swift')}${card('The Slow Rush','Tame Impala','slow-rush')}${card('Stick Season','Noah Kahan','stick-season','search/Noah%20Kahan')}${card('Short n’ Sweet','Sabrina Carpenter','short-sweet','now-playing')}</div>`;
  }
  function browse() {
    return `${heading('Browse all')}<div class="browse-grid">${['New Releases','Pop','Rock','Chill','Focus','Workout','Party','Indie','Country'].map((name,i)=>`<a class="browse-card" href="#search/${encodeURIComponent(name)}"><span>${name}</span><img src="${image(['short-sweet','taylor','currents','lonerism','stick-season','slow-rush'][i%6])}" alt="" style="position:absolute;width:95px;height:95px;right:-13px;bottom:-8px;transform:rotate(22deg);border-radius:5px;opacity:.55;z-index:-1"></a>`).join('')}</div>`;
  }
  function search(term) {
    if (!term) return browse();
    const tame = /tame|currents|nangs|happen|borderline|eventually|moment|changing|better/i.test(term);
    const filters = ['All','Artists','Albums','Songs','Playlists','Profiles'];
    const chips = `<div class="chips" role="group" aria-label="Search type">${filters.map(name=>`<button class="chip ${state.filter===name?'active':''}" data-filter="${name}" aria-pressed="${state.filter===name}">${name}</button>`).join('')}</div>`;
    if (!tame) {
      const matches = [
        {pattern:/sabrina|espresso|short|pop|new|workout|party|daily/i,title:'Short n’ Sweet',by:'Sabrina Carpenter',art:'short-sweet',href:'now-playing'},
        {pattern:/taylor|folklore|chill|focus|discover/i,title:'folklore',by:'Taylor Swift',art:'taylor',href:'now-playing'},
        {pattern:/noah|stick|indie|country|rock/i,title:'Stick Season',by:'Noah Kahan',art:'stick-season',href:'now-playing'}
      ].filter(item=>item.pattern.test(term));
      return `${chips}<div class="page-heading"><h1>Search results</h1></div>${matches.length && ['All','Albums'].includes(state.filter)?`<div class="results">${matches.map(m=>card(m.title,m.by,m.art,m.href)).join('')}</div>`:`<div class="empty-state"><h2>No ${state.filter==='All'?'results':state.filter.toLowerCase()} found for “${escape(term)}”</h2><p>This preview contains a small sample library. Try “Tame Impala”.</p></div>`}`;
    }
    const top = `<div><h3>Top result</h3><a href="#artist" class="top-result"><img src="${image('tame-impala')}" alt="Tame Impala"><h2>Tame Impala</h2><span class="muted">Artist</span><span class="play-round">${icon('play')}</span></a></div>`;
    const songList = `<div><h3>Songs</h3>${[5,6,0,4].map(i=>songRow(songs[i],i)).join('')}</div>`;
    if (state.filter==='Artists') return chips+top;
    if (state.filter==='Albums') return chips+heading('Albums')+`<div class="results">${card('Currents','Tame Impala','currents')}${card('The Slow Rush','Tame Impala','slow-rush')}${card('Lonerism','Tame Impala','lonerism')}</div>`;
    if (state.filter==='Songs') return chips+songList;
    if (state.filter==='Playlists'||state.filter==='Profiles') return chips+`<div class="empty-state"><h2>No ${state.filter.toLowerCase()} in this preview</h2><p>Connect Spotify to search the full catalogue.</p></div>`;
    return `${chips}<div class="search-columns">${top}${songList}</div>${heading('Albums')}<div class="results">${card('Currents','Tame Impala','currents')}${card('The Slow Rush','Tame Impala','slow-rush')}${card('Lonerism','Tame Impala','lonerism')}</div>`;
  }
  function artistPage() {
    return `<div class="artist-hero"><img src="${image('tame-impala')}" alt="Tame Impala"><div><span class="eyebrow" style="color:#f4dfda">✓ Verified artist</span><h1>Tame Impala</h1><p>Artist</p><div style="display:flex;align-items:center;gap:15px"><button class="play-round" data-track="0" aria-label="Play Tame Impala">${icon('play')}</button><button class="outline-button" data-action="follow">${state.followed?'Following':'Follow'}</button><a href="https://open.spotify.com/artist/5INjqkS1o8h1imAzPqGZBb" target="_blank" rel="noopener" aria-label="Open Tame Impala on Spotify">···</a></div></div></div>
      <div class="chips"><span class="chip active">Music</span><a class="chip" href="https://open.spotify.com/artist/5INjqkS1o8h1imAzPqGZBb" target="_blank" rel="noopener">About ↗</a></div>
      <div class="artist-body"><div><h3>Popular</h3>${[5,6,0].map(i=>songRow(songs[i],i)).join('')}</div><div><h3>Albums</h3><div class="results" style="grid-template-columns:repeat(3,minmax(0,1fr));gap:12px">${card('Currents','2015','currents')}${card('The Slow Rush','2020','slow-rush')}${card('Lonerism','2012','lonerism')}</div></div></div>`;
  }
  function album(slug='currents') {
    const albums = {
      'currents':{name:'Currents',artist:'Tame Impala',year:'2015'},
      'slow-rush':{name:'The Slow Rush',artist:'Tame Impala',year:'2020'},
      'lonerism':{name:'Lonerism',artist:'Tame Impala',year:'2012'}
    };
    const art=albums[slug]?slug:'currents';
    const record=albums[art];
    return `<div class="demo-toolbar"><a class="icon-button" href="#artist" aria-label="Back to artist">${icon('back')}</a></div><article class="item"><div class="details"><div class="artwork"><img src="${image(art)}" alt="${record.name} album cover"></div><div class="meta"><p class="eyebrow">Album</p><h1>${record.name}</h1><p><a href="#artist">${record.artist}</a> · ${record.year}</p>${art==='currents'?'<p>13 songs · 51 min</p>':''}<div class="reference-links">${art==='currents'?`<button class="play-round" data-track="0" aria-label="Play Currents">${icon('play')}</button>`:''}<button class="icon-button" data-action="like" aria-label="${state.liked?'Remove from':'Add to'} liked songs">${icon('heart')}</button></div></div></div>${art==='currents'?`<div class="tracklist">${songs.slice(0,6).map((s,i)=>songRow(s,i,true)).join('')}</div>`:'<div class="empty-state"><p>Connect Spotify to explore this album’s tracks.</p><a href="/auth/login" class="button">Connect Spotify</a></div>'}</article>`;
  }
  function nowPlaying() {
    return `<div class="now-playing-layout"><img src="${image(cover())}" alt="${cover()==='currents'?'Currents':'Short n’ Sweet'} album cover"><div><p class="eyebrow">Playing from album</p><a href="#album">${state.track<0?'Short n’ Sweet':'Currents'}</a><div style="display:flex;justify-content:space-between;align-items:center"><h1>${current().name}</h1><button class="icon-button" data-action="like" aria-label="Like song" style="color:${state.liked?'var(--green)':'white'}">${icon('heart')}</button></div><p class="muted">${artist()}</p><input class="seek" type="range" value="${state.elapsed}" min="0" max="${current().duration}" aria-label="Seek position" data-seek><div class="seek-labels"><span data-elapsed>${time(state.elapsed)}</span><span>${time(current().duration)}</span></div><div class="big-player-controls"><button class="icon-button" data-action="shuffle" aria-label="Shuffle" aria-pressed="${state.shuffle}" style="color:${state.shuffle?'var(--green)':'white'}">${icon('shuffle')}</button><button class="icon-button" data-action="prev" aria-label="Previous track">${icon('prev')}</button><button class="icon-button big-play" data-action="toggle-play" aria-label="${state.playing?'Pause':'Play'}">${icon(state.playing?'pause':'play')}</button><button class="icon-button" data-action="next" aria-label="Next track">${icon('next')}</button><button class="icon-button" data-action="repeat" aria-label="Repeat" aria-pressed="${state.repeat}" style="color:${state.repeat?'var(--green)':'white'}">${icon('repeat')}</button></div><div style="display:flex;justify-content:space-between"><button class="icon-button" data-action="devices" aria-label="Playback devices">${icon('device')}</button><button class="icon-button" data-action="queue" aria-label="Open queue">${icon('queue')}</button></div><div class="device-status">${icon('device')} Playing on ${state.device}</div></div></div>`;
  }
  function library() {
    return `<div class="chips" role="group" aria-label="Library type">${['Playlists','Artists','Albums','Podcasts'].map((n,i)=>`<button class="chip ${i===0?'active':''}" data-library="${n}" aria-pressed="${i===0}">${n}</button>`).join('')}</div><div id="library-items">${libraryItems('Playlists')}</div>`;
  }
  function libraryItems(type) {
    if (type==='Podcasts') return '<div class="empty-state"><h2>Your next favourite is out there</h2><p>Connect Spotify to see your saved podcasts.</p></div>';
    if (type==='Artists') return heading('Your artists')+`<div class="results">${card('Tame Impala','Artist','lonerism','artist')}${card('Taylor Swift','Artist','taylor','search/Taylor%20Swift')}${card('Sabrina Carpenter','Artist','short-sweet','search/Sabrina%20Carpenter')}</div>`;
    if (type==='Albums') return heading('Recently Added')+`<div class="results">${card('Currents','Tame Impala','currents')}${card('The Slow Rush','Tame Impala','slow-rush')}${card('folklore','Taylor Swift','taylor','search/Taylor%20Swift')}</div>`;
    return heading('Recently Added')+`<div class="results library-grid">${card('Liked Songs','Playlist',null,'liked')}${card('Chilled Vibes','Playlist','slow-rush','search/chill')}${card('Running','Playlist','short-sweet','search/workout')}${card('Road Trip','Playlist','stick-season','search/indie')}${card('Work Focus','Playlist','lonerism','search/focus')}</div>`;
  }
  function render() {
    const [page='home', ...rest] = (location.hash.slice(1) || 'home').split('/');
    const term = rest.length ? decodeURIComponent(rest.join('/')) : '';
    const views = {home, search:()=>search(term),artist:artistPage,album:()=>album(term||'currents'),'now-playing':nowPlaying,library,liked:()=>heading('Liked Songs')+songs.map((s,i)=>songRow(s,i)).join('')};
    content.innerHTML = (views[page]||home)();
    if (document.activeElement!==query) query.value = page==='search'?term:'';
    document.querySelectorAll('[data-nav]').forEach(el=>{const active=el.dataset.nav===page;el.classList.toggle('active',active);if(active)el.setAttribute('aria-current','page');else el.removeAttribute('aria-current');});
    document.querySelectorAll('details[open]').forEach(el=>el.removeAttribute('open'));
    content.scrollTop = 0;
    updatePlayer();
  }
  function updatePlayer() {
    document.querySelector('#mini-title').textContent=current().name;
    document.querySelector('#mini-artist').textContent=artist();
    document.querySelector('#mini-artist').href=state.track<0?'#search/Sabrina%20Carpenter':'#artist';
    const miniCover=document.querySelector('#mini-cover'); miniCover.src=image(cover()); miniCover.alt=`${state.track<0?'Short n’ Sweet':'Currents'} album cover`;
    document.querySelectorAll('[data-action="toggle-play"]').forEach(button=>{button.innerHTML=icon(state.playing?'pause':'play');button.setAttribute('aria-label',state.playing?'Pause':'Play');});
    document.querySelector('#mini-elapsed').textContent=time(state.elapsed);
    document.querySelector('#mini-duration').textContent=time(current().duration);
    const progress=document.querySelector('#demo-progress');progress.max=current().duration;progress.value=state.elapsed;
    document.querySelectorAll('[data-elapsed]').forEach(el=>el.textContent=time(state.elapsed));
    document.querySelectorAll('[data-seek]').forEach(el=>{if(document.activeElement!==el)el.value=state.elapsed;});
  }
  function play(index) {
    state.track=Number(index);state.elapsed=0;state.playing=true;
    updatePlayer();if(location.hash==='#now-playing')render();
    if(!drawer.hidden&&drawer.dataset.panel==='queue')showPanel('queue');
  }
  function showPanel(panel) {
    drawer.dataset.panel=panel;drawer.hidden=false;
    drawer.innerHTML=`<div class="drawer-heading"><h2>${panel==='queue'?'Queue':'Play on'}</h2><button class="icon-button" data-action="close-panel" aria-label="Close panel">${icon('close')}</button></div>`;
    if(panel==='queue')drawer.innerHTML+=`<h3 style="font-size:12px">Now Playing</h3><div class="song-row"><img src="${image(cover())}" alt=""><span>${current().name}<small>${artist()}</small></span></div><h3 style="font-size:12px;margin-top:25px">Next in Queue</h3>${songs.map((s,i)=>songRow(s,i)).join('')}`;
    else drawer.innerHTML+=['This Echo Show','Kitchen Speaker','Living Room','Bedroom'].map((name,i)=>`<button class="device-row ${name===state.device?'active':''}" data-device="${name}">${icon(i===0?'device':'speaker')}<span>${name}</span>${name===state.device?'<small>Active device ✓</small>':''}</button>`).join('')+`<div style="display:flex;align-items:center;gap:15px;margin-top:22px">${icon('volume')}<input type="range" min="0" max="100" value="${state.volume}" data-volume aria-label="Device volume" style="width:100%"><span data-volume-label>${state.volume}%</span></div><p class="muted" style="font-size:10px;margin:20px 0 0">Sample devices · Connect Spotify for live playback</p>`;
    drawer.querySelector('button').focus();
  }
  document.querySelector('#demo-search').addEventListener('submit',event=>{event.preventDefault();clearTimeout(searchTimer);state.filter='All';location.hash=query.value.trim()?'search/'+encodeURIComponent(query.value.trim()):'search';});
  query.addEventListener('input',()=>{clearTimeout(searchTimer);searchTimer=setTimeout(()=>{state.filter='All';location.hash=query.value.trim()?'search/'+encodeURIComponent(query.value.trim()):'search';},250);});
  document.addEventListener('click',event=>{
    const button=event.target.closest('[data-action],[data-track],[data-filter],[data-device],[data-library]');
    if(!button)return;
    if(button.hasAttribute('data-track')){play(button.dataset.track);return;}
    if(button.dataset.filter){state.filter=button.dataset.filter;render();return;}
    if(button.dataset.library){document.querySelectorAll('[data-library]').forEach(el=>{const selected=el===button;el.classList.toggle('active',selected);el.setAttribute('aria-pressed',selected);});document.querySelector('#library-items').innerHTML=libraryItems(button.dataset.library);return;}
    if(button.dataset.device){state.device=button.dataset.device;showPanel('devices');if(location.hash==='#now-playing')render();return;}
    switch(button.dataset.action){
      case 'toggle-play':state.playing=!state.playing;updatePlayer();break;
      case 'next':play(state.shuffle?Math.floor(Math.random()*songs.length):(state.track+1)%songs.length);break;
      case 'prev':if(state.elapsed>3){state.elapsed=0;updatePlayer();}else play((state.track-1+songs.length)%songs.length);break;
      case 'devices':case 'queue':if(!drawer.hidden&&drawer.dataset.panel===button.dataset.action){drawer.hidden=true;}else showPanel(button.dataset.action);break;
      case 'close-panel':drawer.hidden=true;document.querySelector(`[data-action="${drawer.dataset.panel}"]`).focus();break;
      case 'like':state.liked=!state.liked;notify(state.liked?'Added to liked songs':'Removed from liked songs');render();break;
      case 'follow':state.followed=!state.followed;render();notify(state.followed?'Following Tame Impala':'Unfollowed Tame Impala');break;
      case 'shuffle':state.shuffle=!state.shuffle;render();break;
      case 'repeat':state.repeat=!state.repeat;render();break;
    }
  });
  document.addEventListener('input',event=>{
    if(event.target.matches('[data-volume]')){state.volume=Number(event.target.value);document.querySelectorAll('[data-volume]').forEach(el=>el.value=state.volume);document.querySelectorAll('[data-volume-label]').forEach(el=>el.textContent=state.volume+'%');}
    if(event.target.matches('[data-seek]')){state.elapsed=Number(event.target.value);updatePlayer();}
  });
  document.addEventListener('keydown',event=>{if(event.key==='Escape'){drawer.hidden=true;document.querySelectorAll('details[open]').forEach(el=>el.removeAttribute('open'));}if(event.code==='Space'&&!event.target.closest('input,button,a,summary')){event.preventDefault();state.playing=!state.playing;updatePlayer();}});
  window.addEventListener('hashchange',()=>{drawer.hidden=true;render();});
  setInterval(()=>{if(!state.playing)return;state.elapsed++;if(state.elapsed>=current().duration){if(state.repeat)state.elapsed=0;else play((state.track+1)%songs.length);}updatePlayer();},1000);
  render();
})();
