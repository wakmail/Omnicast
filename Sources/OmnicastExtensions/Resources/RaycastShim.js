(function(global){
"use strict";
var React=global.React;
var bridge=global.__omnicastBridge;
function log(level,args){
  var message=Array.prototype.map.call(args,function(value){
    if(value&&value.stack)return value.stack;
    if(typeof value==="string")return value;
    try{return JSON.stringify(value);}catch(error){return String(value);}
  }).join(" ");
  global.webkit.messageHandlers.log.postMessage({type:"console",level:level,message:message});
}
["log","info","warn","error"].forEach(function(level){
  var original=global.console[level]?global.console[level].bind(global.console):function(){};
  global.console[level]=function(){log(level,arguments);original.apply(null,arguments);};
});
global.onerror=function(message,source,line,column,error){
  log("error",[error&&error.stack?error.stack:String(message)+" at "+String(source)+":"+String(line)+":"+String(column)]);
};
global.addEventListener("unhandledrejection",function(event){log("error",[event.reason||"Unhandled promise rejection"]);});
function reportRendered(){
  var count=document.querySelectorAll(".raycastListItem").length;
  global.webkit.messageHandlers.log.postMessage({type:"rendered",count:count});
}
var root=document.getElementById("root");
if(root){new MutationObserver(reportRendered).observe(root,{childList:true,subtree:true});}
function runAction(action){Promise.resolve(action()).catch(function(error){console.error(error);});}
function actionButton(props,onAction){
  return React.createElement("button",{className:"raycastAction",onClick:function(event){event.stopPropagation();runAction(onAction);}},props.title||"Action",props.shortcut?React.createElement("kbd",null,shortcutLabel(props.shortcut)):null);
}
function shortcutLabel(shortcut){
  var symbols={cmd:"⌘",shift:"⇧",opt:"⌥",ctrl:"⌃",return:"↵"};
  return (shortcut.modifiers||[]).map(function(value){return symbols[value]||value;}).join("")+(symbols[shortcut.key]||shortcut.key||"");
}
function Action(props){return actionButton(props,props.onAction||function(){});}
Action.OpenInBrowser=function(props){return actionButton(props,function(){return bridge("open",{url:String(props.url||props.target||"")});});};
Action.Open=Action.OpenInBrowser;
Action.CopyToClipboard=function(props){return actionButton(props,function(){return bridge("clipboardWriteText",{text:String(props.content||"")});});};
function ActionPanel(props){return React.createElement("div",{className:"raycastActions",role:"menu"},props.children);}
ActionPanel.Section=function(props){return React.createElement("div",{className:"raycastActionSection"},props.title?React.createElement("h4",null,props.title):null,props.children);};
ActionPanel.Item=Action;
var ListContext=React.createContext({query:"",selected:null,select:function(){}});
function visibleItems(){return Array.prototype.filter.call(document.querySelectorAll(".raycastListItem"),function(item){return item.style.display!=="none";});}
function List(props){
  var queryState=React.useState(props.searchText||"");
  var query=props.searchText===undefined?queryState[0]:props.searchText;
  var setQuery=queryState[1];
  var selectedState=React.useState(null);
  var selected=selectedState[0];
  var setSelected=selectedState[1];
  var panelState=React.useState(false);
  var panelOpen=panelState[0];
  var setPanelOpen=panelState[1];
  React.useEffect(function(){
    var frame=requestAnimationFrame(function(){
      var items=visibleItems();
      if(items.length&&!items.some(function(item){return item.dataset.itemId===selected;}))setSelected(items[0].dataset.itemId);
      reportRendered();
    });
    return function(){cancelAnimationFrame(frame);};
  },[props.children,query,selected]);
  React.useEffect(function(){
    function keydown(event){
      var items=visibleItems();
      if(!items.length)return;
      var index=items.findIndex(function(item){return item.dataset.itemId===selected;});
      if(index<0)index=0;
      if(event.key==="ArrowDown"||event.key==="ArrowUp"){
        event.preventDefault();
        index=(index+(event.key==="ArrowDown"?1:-1)+items.length)%items.length;
        setSelected(items[index].dataset.itemId);
        items[index].scrollIntoView({block:"nearest"});
        setPanelOpen(false);
      }else if(event.key==="Enter"){
        var primary=items[index].querySelector(".raycastAction");
        if(primary){event.preventDefault();primary.click();}
      }else if(event.metaKey&&event.key.toLowerCase()==="k"){
        event.preventDefault();setPanelOpen(function(value){return !value;});
      }else if(event.key==="Escape"&&panelOpen){
        event.preventDefault();setPanelOpen(false);
      }
    }
    document.addEventListener("keydown",keydown);
    return function(){document.removeEventListener("keydown",keydown);};
  },[selected,panelOpen]);
  function change(event){
    var value=event.target.value;
    setQuery(value);
    if(props.onSearchTextChange)props.onSearchTextChange(value);
  }
  return React.createElement(ListContext.Provider,{value:{query:query,selected:selected,select:setSelected}},
    React.createElement("section",{className:"raycastList"+(panelOpen?" actionPanelOpen":"")},
      React.createElement("header",{className:"raycastSearch"},
        React.createElement("input",{autoFocus:true,placeholder:props.searchBarPlaceholder||"Search",value:query,onChange:change}),
        props.searchBarAccessory,
        props.isLoading?React.createElement("span",{className:"raycastLoading"},"Loading"):null
      ),
      React.createElement("div",{className:"raycastListBody"},props.children)
    )
  );
}
List.Item=function(props){
  var context=React.useContext(ListContext);
  var id=React.useId();
  var text=String(props.title||"")+" "+String(props.subtitle||"");
  var hidden=context.query&&!text.toLowerCase().includes(String(context.query).toLowerCase());
  var selected=context.selected===id;
  var icon=typeof props.icon==="string"?props.icon:(props.icon&&props.icon.source)||"";
  return React.createElement("article",{className:"raycastListItem"+(selected?" selected":""),style:hidden?{display:"none"}:null,"data-item-id":id,tabIndex:selected?0:-1,onMouseEnter:function(){context.select(id);},onClick:function(){context.select(id);if(props.onAction)runAction(props.onAction);}},
    icon?React.createElement("span",{className:"raycastIcon"},typeof icon==="string"&&icon.length<5?icon:"◆"):null,
    React.createElement("div",{className:"raycastListText"},React.createElement("strong",null,props.title||""),props.subtitle?React.createElement("small",null,String(props.subtitle)):null),
    props.accessories?React.createElement("div",{className:"raycastAccessories"},props.accessories.map(function(item,index){return React.createElement("span",{key:index},item.text||item.tag||"");})):null,
    props.actions
  );
};
List.Section=function(props){return React.createElement("section",{className:"raycastSection"},props.title?React.createElement("h3",null,props.title,props.subtitle?React.createElement("small",null,props.subtitle):null):null,props.children);};
List.EmptyView=function(props){return React.createElement("div",{className:"raycastEmpty"},React.createElement("strong",null,props.title||"No Results"),props.description?React.createElement("small",null,props.description):null);};
List.Dropdown=function(props){return React.createElement("select",{className:"raycastDropdown",defaultValue:props.defaultValue,onChange:function(event){if(props.onChange)props.onChange(event.target.value);}},props.children);};
List.Dropdown.Section=function(props){return React.createElement("optgroup",{label:props.title||""},props.children);};
List.Dropdown.Item=function(props){return React.createElement("option",{value:props.value},props.title||props.value);};
function inlineMarkdown(text,lineKey){
  var result=[];var pattern=/(\*\*([^*]+)\*\*|\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`)/g;var cursor=0;var match;
  while((match=pattern.exec(text))!==null){
    if(match.index>cursor)result.push(text.slice(cursor,match.index));
    if(match[2])result.push(React.createElement("strong",{key:lineKey+"b"+match.index},match[2]));
    else if(match[3])result.push(React.createElement("a",{key:lineKey+"a"+match.index,href:match[4],onClick:function(event){event.preventDefault();bridge("open",{url:event.currentTarget.href});}},match[3]));
    else result.push(React.createElement("code",{key:lineKey+"c"+match.index},match[5]));
    cursor=pattern.lastIndex;
  }
  if(cursor<text.length)result.push(text.slice(cursor));return result;
}
function renderMarkdown(source){
  var inCode=false;
  return String(source||"").split("\n").map(function(line,index){
    var key="line"+index;if(line.slice(0,3)==="```"){inCode=!inCode;return null;}if(inCode)return React.createElement("pre",{key:key},line);
    if(line.slice(0,4)==="### ")return React.createElement("h3",{key:key},inlineMarkdown(line.slice(4),key));
    if(line.slice(0,3)==="## ")return React.createElement("h2",{key:key},inlineMarkdown(line.slice(3),key));
    if(line.slice(0,2)==="# ")return React.createElement("h1",{key:key},inlineMarkdown(line.slice(2),key));
    if(line.slice(0,2)==="- "||line.slice(0,2)==="* ")return React.createElement("div",{key:key,className:"raycastMarkdownItem"},"• ",inlineMarkdown(line.slice(2),key));
    if(line.length===0)return React.createElement("br",{key:key});return React.createElement("p",{key:key},inlineMarkdown(line,key));
  });
}
function Detail(props){return React.createElement("article",{className:"raycastDetail"},props.isLoading?React.createElement("p",null,"Loading"):null,props.markdown?React.createElement("div",{className:"raycastMarkdown"},renderMarkdown(props.markdown)):null,props.children,props.actions);}
function showToast(options){var message=typeof options==="string"?options:(options&&((options.title||"")+(options.message?" "+options.message:"")))||"";return bridge("toast",{message:message});}
showToast.Style={Success:"success",Failure:"failure",Animated:"animated"};
function showHUD(message){return bridge("hud",{message:String(message||"")});}
function getPreferenceValues(){return Object.assign({},global.__omnicastContext.preferences||{});}
var LocalStorage={getItem:function(key){return bridge("localStorageGetItem",{key:String(key)});},setItem:function(key,value){return bridge("localStorageSetItem",{key:String(key),value:value});},removeItem:function(key){return bridge("localStorageRemoveItem",{key:String(key)});},allItems:function(){return bridge("localStorageAllItems",{});},clear:function(){return bridge("localStorageClear",{});}};
var Clipboard={readText:function(){return bridge("clipboardReadText",{});},copy:function(value){return bridge("clipboardWriteText",{text:String(value||"")});},paste:function(value){return bridge("clipboardWriteText",{text:String(value||"")});}};
function open(url){return bridge("open",{url:String(url||"")});}
function closeMainWindow(){return bridge("closeMainWindow",{});}
function clearSearchBar(){var input=document.querySelector(".raycastSearch input");if(input){input.value="";input.dispatchEvent(new Event("input",{bubbles:true}));}}
function popToRoot(){return Promise.resolve();}
function confirmAlert(options){return Promise.resolve(global.confirm(options&&options.title?options.title:"Continue?"));}
function unsupported(name){return function(){throw new Error("Raycast API export "+name+" is not yet supported");};}
var Icon=new Proxy({},{get:function(target,name){return String(name);}});
var Toast={Style:showToast.Style};
var Color={PrimaryText:"currentColor",SecondaryText:"rgba(255,255,255,0.74)"};
var Keyboard={Shortcut:{Common:{CopyPath:{modifiers:["cmd","shift"],key:"c"},Refresh:{modifiers:["cmd"],key:"r"}}}};
var environment=Object.assign({launchType:"userInitiated"},global.__omnicastContext.environment||{});
var api={List:List,Detail:Detail,ActionPanel:ActionPanel,Action:Action,showToast:showToast,showHUD:showHUD,getPreferenceValues:getPreferenceValues,LocalStorage:LocalStorage,Clipboard:Clipboard,open:open,environment:environment,closeMainWindow:closeMainWindow,clearSearchBar:clearSearchBar,popToRoot:popToRoot,confirmAlert:confirmAlert,Icon:Icon,Toast:Toast,Color:Color,Keyboard:Keyboard};
global.__raycastAPI=new Proxy(api,{get:function(target,name){return name in target?target[name]:unsupported(String(name));}});
})(globalThis);
