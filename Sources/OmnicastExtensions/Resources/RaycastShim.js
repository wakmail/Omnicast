(function(global){
"use strict";
var React=global.React;
var pending=new Map();
var sequence=0;
function bridge(operation,payload){
  return new Promise(function(resolve,reject){
    var id="message"+String(++sequence);
    pending.set(id,{resolve:resolve,reject:reject});
    global.webkit.messageHandlers.omnicast.postMessage({id:id,operation:operation,payload:payload||{}});
  });
}
global.__omnicastReceive=function(response){
  var callback=pending.get(response.id);
  if(!callback)return;
  pending.delete(response.id);
  if(response.error)callback.reject(new Error(response.error));
  else callback.resolve(response.result===undefined?null:response.result);
};
function actionButton(props,onAction){
  return React.createElement("button",{className:"raycastAction",onClick:function(event){event.stopPropagation();Promise.resolve(onAction()).catch(reportError);}},props.title||"Action");
}
function Action(props){return actionButton(props,props.onAction||function(){});}
Action.OpenInBrowser=function(props){return actionButton(props,function(){return bridge("open",{url:String(props.url||props.target||"")});});};
Action.Open=Action.OpenInBrowser;
Action.CopyToClipboard=function(props){return actionButton(props,function(){return bridge("clipboardWriteText",{text:String(props.content||"")});});};
ActionPanel=function(props){return React.createElement("div",{className:"raycastActions"},props.children);};
ActionPanel.Section=function(props){return React.createElement("div",{className:"raycastActionSection"},props.title?React.createElement("h4",null,props.title):null,props.children);};
ActionPanel.Item=Action;
function List(props){
  return React.createElement("section",{className:"raycastList"},
    React.createElement("header",{className:"raycastSearch"},
      React.createElement("input",{placeholder:props.searchBarPlaceholder||"Search",value:props.searchText||"",onInput:function(event){if(props.onSearchTextChange)props.onSearchTextChange(event.target.value);}}),
      props.isLoading?React.createElement("span",null,"Loading"):null
    ),
    React.createElement("div",{className:"raycastListBody"},props.children)
  );
}
List.Item=function(props){
  var icon=typeof props.icon==="string"?props.icon:(props.icon&&props.icon.source)||"";
  return React.createElement("article",{className:"raycastListItem",onClick:props.onAction},
    icon?React.createElement("span",{className:"raycastIcon"},icon):null,
    React.createElement("div",{className:"raycastListText"},
      React.createElement("strong",null,props.title||""),
      props.subtitle?React.createElement("small",null,String(props.subtitle)):null
    ),
    props.accessories?React.createElement("div",{className:"raycastAccessories"},props.accessories.map(function(item,index){return React.createElement("span",{key:index},item.text||item.tag||"");})):null,
    props.actions
  );
};
List.Section=function(props){return React.createElement("section",{className:"raycastSection"},props.title?React.createElement("h3",null,props.title):null,props.children);};
function inlineMarkdown(text,lineKey){
  var result=[];
  var pattern=/(\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`)/g;
  var cursor=0;
  var match;
  while((match=pattern.exec(text))!==null){
    if(match.index>cursor)result.push(text.slice(cursor,match.index));
    if(match[2])result.push(React.createElement("strong",{key:lineKey+"b"+match.index},match[2]));
    else if(match[3])result.push(React.createElement("a",{key:lineKey+"a"+match.index,href:match[4],onClick:function(event){event.preventDefault();bridge("open",{url:event.currentTarget.href});}},match[3]));
    else result.push(React.createElement("code",{key:lineKey+"c"+match.index},match[5]));
    cursor=pattern.lastIndex;
  }
  if(cursor<text.length)result.push(text.slice(cursor));
  return result;
}
function renderMarkdown(source){
  var inCode=false;
  return String(source||"").split("\n").map(function(line,index){
    var key="line"+index;
    if(line.slice(0,3)==="```"){inCode=!inCode;return null;}
    if(inCode)return React.createElement("pre",{key:key},line);
    if(line.slice(0,4)==="### ")return React.createElement("h3",{key:key},inlineMarkdown(line.slice(4),key));
    if(line.slice(0,3)==="## ")return React.createElement("h2",{key:key},inlineMarkdown(line.slice(3),key));
    if(line.slice(0,2)==="# ")return React.createElement("h1",{key:key},inlineMarkdown(line.slice(2),key));
    if(line.slice(0,2)==="- "||line.slice(0,2)==="* ")return React.createElement("div",{key:key,className:"raycastMarkdownItem"},"• ",inlineMarkdown(line.slice(2),key));
    if(line.length===0)return React.createElement("br",{key:key});
    return React.createElement("p",{key:key},inlineMarkdown(line,key));
  });
}
function Detail(props){
  return React.createElement("article",{className:"raycastDetail"},
    props.isLoading?React.createElement("p",null,"Loading"):null,
    props.markdown?React.createElement("div",{className:"raycastMarkdown"},renderMarkdown(props.markdown)):null,
    props.children,
    props.actions
  );
}
function showToast(options){
  var message=typeof options==="string"?options:(options&&((options.title||"")+(options.message?" "+options.message:"")))||"";
  return bridge("toast",{message:message});
}
showToast.Style={Success:"success",Failure:"failure",Animated:"animated"};
function showHUD(message){return bridge("hud",{message:String(message||"")});}
function getPreferenceValues(){return Object.assign({},global.__omnicastContext.preferences||{});}
var LocalStorage={
  getItem:function(key){return bridge("localStorageGetItem",{key:String(key)});},
  setItem:function(key,value){return bridge("localStorageSetItem",{key:String(key),value:value});},
  removeItem:function(key){return bridge("localStorageRemoveItem",{key:String(key)});},
  allItems:function(){return bridge("localStorageAllItems",{});},
  clear:function(){return bridge("localStorageClear",{});}
};
var Clipboard={
  readText:function(){return bridge("clipboardReadText",{});},
  copy:function(value){return bridge("clipboardWriteText",{text:String(value||"")});},
  paste:function(value){return bridge("clipboardWriteText",{text:String(value||"")});}
};
function open(url){return bridge("open",{url:String(url||"")});}
function closeMainWindow(){return bridge("closeMainWindow",{});}
function reportError(error){
  var message=error&&error.message?error.message:String(error);
  bridge("toast",{message:message}).catch(function(){});
}
function unsupported(name){return function(){throw new Error("Raycast API export "+name+" is not yet supported");};}
var Icon=new Proxy({},{get:function(target,name){return String(name);}});
var Toast={Style:showToast.Style};
var environment=Object.assign({},global.__omnicastContext.environment||{});
var api={
  List:List,
  Detail:Detail,
  ActionPanel:ActionPanel,
  Action:Action,
  showToast:showToast,
  showHUD:showHUD,
  getPreferenceValues:getPreferenceValues,
  LocalStorage:LocalStorage,
  Clipboard:Clipboard,
  open:open,
  environment:environment,
  closeMainWindow:closeMainWindow,
  Icon:Icon,
  Toast:Toast
};
global.__raycastAPI=new Proxy(api,{get:function(target,name){return name in target?target[name]:unsupported(String(name));}});
})(globalThis);
