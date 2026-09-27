/* Independent full-canvas Photoshop layers; no fitting or recolouring. */
function makeModularAvatar(data) {
 const labels=id=>({darkbrown:'Dark brown',hairColour:'Hair colour'}[id] || id.replace(/-/g,' ').replace(/\b\w/g,c=>c.toUpperCase()));
 const defaults=()=>({...data.defaults,version:3});
 const choices=(s,key)=>key==='tone'?['light','warm','tan','brown','deep','dark'].filter(id=>Object.hasOwn(data.skin[s.body]||{},id)):key==='body'?Object.keys(data.skin):key==='hairColour'?Object.keys(data.hair[s.hair]||{}):Object.keys(data[key]||{});
 function supported(s){return ['body','tone','hair','hairColour','top','bottom','shoes','eyes','brows','mouth','accessory'].every(k=>choices(s,k).includes(s[k]));}
 function normalize(saved){const s={...defaults(),...saved,body:'male',version:3};return supported(s)?s:defaults();}
 function migrate(saved, outfits=[]) {
  if(saved?.version===3)return normalize(saved);
  const next=defaults(), old={...saved};
  if(old.version===2){const outfit=outfits.find(o=>o.id===old.outfit);if(outfit)for(const k of ['top','bottom','shoes'])old[k]=outfit[k].toLowerCase().replace(/ /g,'-');}
  const aliases={top:{hoodie:'cream-hoodie',jacket:'yellow-jacket'},bottom:{shorts:'blue-shorts',trousers:'blue-trousers',skirt:'cream-skirt'},shoes:{cream:'cream-trainers',charcoal:'charcoal-trainers'}};
  for(const key of ['body','tone','hair','hairColour','top','bottom','shoes','eyes','brows','mouth']){
   const value=aliases[key]?.[old[key]]||old[key];if(choices(next,key).includes(value))next[key]=value;
  }
  if(!choices(next,'hairColour').includes(next.hairColour))next.hairColour=choices(next,'hairColour')[0];
  return next;
 }
 function change(s,key,value){const n={...s,[key]:value};if(key==='hair'&&!data.hair[value][n.hairColour])n.hairColour=data.hair[value].darkbrown?'darkbrown':Object.keys(data.hair[value])[0];return supported(n)?n:null;}
 function paths(s){
  if(!supported(s))throw new Error('This asset is not ready yet.');
  return [data.skin[s.body][s.tone],data.bottom[s.bottom],data.shoes[s.shoes],data.top[s.top],data.eyes[s.eyes],data.brows[s.brows],data.mouth[s.mouth],data.hair[s.hair][s.hairColour],data.accessory[s.accessory]].filter(Boolean);
 }
 function options(s,key){return choices(s,key).map(id=>({label:labels(id),on:s[key]===id,next:change(s,key,id),swatch:key==='tone'?data.toneColours[id]:null}));}
 return {defaults,supported,normalize,migrate,change,paths,options};
}
if(typeof module!=='undefined')module.exports=makeModularAvatar;
