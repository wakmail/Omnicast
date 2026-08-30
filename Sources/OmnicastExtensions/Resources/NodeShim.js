(function(global){
"use strict";
var pending=new Map();
var sequence=0;
function bridge(operation,payload){
  return new Promise(function(resolve,reject){
    var id="message"+String(++sequence);
    pending.set(id,{resolve:resolve,reject:reject});
    global.webkit.messageHandlers.omnicast.postMessage({id:id,operation:operation,payload:payload||{}});
  });
}
global.__omnicastBridge=bridge;
global.__omnicastReceive=function(response){
  var callback=pending.get(response.id);
  if(!callback)return;
  pending.delete(response.id);
  if(response.error)callback.reject(new Error(response.error));
  else callback.resolve(response.result===undefined?null:response.result);
};
function sync(operation,payload){
  var source=global.prompt("omnicast.sync",JSON.stringify({operation:operation,payload:payload||{}}));
  if(source===null)throw new Error("The synchronous Node bridge did not respond");
  var response=JSON.parse(source);
  if(response.error)throw new Error(response.error);
  return response.result;
}
function bytesFromBase64(value){
  var raw=global.atob(value||"");
  var bytes=new Uint8Array(raw.length);
  for(var index=0;index<raw.length;index++)bytes[index]=raw.charCodeAt(index);
  return bytes;
}
function base64FromBytes(bytes){
  var parts=[];
  for(var index=0;index<bytes.length;index+=8192){
    parts.push(String.fromCharCode.apply(null,bytes.subarray(index,index+8192)));
  }
  return global.btoa(parts.join(""));
}
function encodeString(value,encoding){
  encoding=String(encoding||"utf8").toLowerCase();
  if(encoding==="base64")return bytesFromBase64(value);
  if(encoding==="hex"){
    var hex=new Uint8Array(Math.floor(value.length/2));
    for(var h=0;h<hex.length;h++)hex[h]=parseInt(value.slice(h*2,h*2+2),16);
    return hex;
  }
  if(encoding==="utf16le"||encoding==="ucs2"||encoding==="ucs-2"){
    var utf16=new Uint8Array(value.length*2);
    for(var u=0;u<value.length;u++){
      utf16[u*2]=value.charCodeAt(u)&255;
      utf16[u*2+1]=value.charCodeAt(u)>>8;
    }
    return utf16;
  }
  return new TextEncoder().encode(String(value));
}
function decodeBytes(bytes,encoding){
  encoding=String(encoding||"utf8").toLowerCase();
  if(encoding==="base64")return base64FromBytes(bytes);
  if(encoding==="hex")return Array.from(bytes,function(value){return value.toString(16).padStart(2,"0");}).join("");
  if(encoding==="utf16le"||encoding==="ucs2"||encoding==="ucs-2"){
    var result="";
    for(var index=0;index+1<bytes.length;index+=2)result+=String.fromCharCode(bytes[index]|bytes[index+1]<<8);
    return result;
  }
  return new TextDecoder(encoding==="ascii"?"windows-1252":"utf-8").decode(bytes);
}
function NodeBuffer(bytes){
  this.bytes=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||0);
  this.length=this.bytes.length;
}
NodeBuffer.prototype.toString=function(encoding,start,end){return decodeBytes(this.bytes.slice(start||0,end===undefined?this.length:end),encoding);};
NodeBuffer.prototype.slice=function(start,end){return new NodeBuffer(this.bytes.slice(start,end));};
NodeBuffer.prototype.subarray=NodeBuffer.prototype.slice;
NodeBuffer.prototype.valueOf=function(){return this.bytes;};
NodeBuffer.from=function(value,encoding){
  if(value instanceof NodeBuffer)return new NodeBuffer(value.bytes.slice());
  if(value instanceof Uint8Array||Array.isArray(value))return new NodeBuffer(new Uint8Array(value));
  if(value&&value.base64)return new NodeBuffer(bytesFromBase64(value.base64));
  return new NodeBuffer(encodeString(String(value||""),encoding));
};
NodeBuffer.alloc=function(size,fill){var value=new Uint8Array(size);if(fill!==undefined)value.fill(fill);return new NodeBuffer(value);};
NodeBuffer.isBuffer=function(value){return value instanceof NodeBuffer;};
NodeBuffer.byteLength=function(value,encoding){return encodeString(String(value),encoding).length;};
NodeBuffer.concat=function(values){
  var size=values.reduce(function(total,value){return total+NodeBuffer.from(value).length;},0);
  var result=new Uint8Array(size);var offset=0;
  values.forEach(function(value){var bytes=NodeBuffer.from(value).bytes;result.set(bytes,offset);offset+=bytes.length;});
  return new NodeBuffer(result);
};
global.Buffer=NodeBuffer;
function encodingFromOption(option){return typeof option==="string"?option:option&&option.encoding?option.encoding:"buffer";}
function statObject(value){
  value=value||{};
  value.isFile=function(){return !!value.isFileValue;};
  value.isDirectory=function(){return !!value.isDirectoryValue;};
  value.isSymbolicLink=function(){return !!value.isSymbolicLinkValue;};
  return value;
}
function normalizeStat(value){
  return statObject({size:value.size||0,mtimeMs:value.mtimeMs||0,isFileValue:value.isFile,isDirectoryValue:value.isDirectory,isSymbolicLinkValue:value.isSymbolicLink});
}
var fsPromises={
  access:function(path){return bridge("fileSystemAccess",{path:String(path)});},
  readFile:function(path,option){var encoding=encodingFromOption(option);return bridge("fileSystemReadFile",{path:String(path),encoding:encoding}).then(function(value){return encoding==="buffer"?NodeBuffer.from(value):value;});},
  stat:function(path){return bridge("fileSystemStat",{path:String(path)}).then(normalizeStat);},
  lstat:function(path){return this.stat(path);},
  readdir:function(path){return bridge("fileSystemReadDirectory",{path:String(path)});},
  writeFile:function(path,data,option){var encoding=encodingFromOption(option);var payload={path:String(path)};if(NodeBuffer.isBuffer(data))payload.base64=data.toString("base64");else if(data instanceof Uint8Array)payload.base64=base64FromBytes(data);else payload.data=String(data);payload.encoding=encoding;return bridge("fileSystemWriteFile",payload);},
  mkdir:function(path,option){return bridge("fileSystemMakeDirectory",{path:String(path),recursive:!!(option&&option.recursive)});}
};
function callbackMethod(promiseFactory){return function(){var args=Array.prototype.slice.call(arguments);var callback=args.pop();promiseFactory.apply(null,args).then(function(value){callback(null,value);},callback);};}
var fs={
  constants:{F_OK:0,R_OK:4,W_OK:2,X_OK:1},
  promises:fsPromises,
  readFileSync:function(path,option){var encoding=encodingFromOption(option);var value=sync("fs.readFileSync",{path:String(path),encoding:encoding});return encoding==="buffer"?NodeBuffer.from(value):value;},
  existsSync:function(path){return !!sync("fs.existsSync",{path:String(path)});},
  statSync:function(path){return normalizeStat(sync("fs.statSync",{path:String(path)}));},
  lstatSync:function(path){return this.statSync(path);}
};
fs.access=callbackMethod(fsPromises.access);
fs.readFile=callbackMethod(fsPromises.readFile);
fs.stat=callbackMethod(fsPromises.stat);
fs.readdir=callbackMethod(fsPromises.readdir);
fs.writeFile=callbackMethod(fsPromises.writeFile);
function normalize(path){
  var absolute=String(path||"").charAt(0)==="/";
  var parts=String(path||"").split("/");var output=[];
  parts.forEach(function(part){if(!part||part===".")return;if(part==="..")output.pop();else output.push(part);});
  var value=(absolute?"/":"")+output.join("/");return value|| (absolute?"/":".");
}
var extensionPath=(global.__omnicastContext.environment||{}).extensionPath||"/extension";
var pathModule={
  sep:"/",delimiter:":",
  normalize:normalize,
  join:function(){return normalize(Array.prototype.join.call(arguments,"/"));},
  resolve:function(){var values=Array.prototype.slice.call(arguments);var result="";for(var index=values.length-1;index>=0;index--){result=String(values[index])+"/"+result;if(String(values[index]).charAt(0)==="/")break;}if(result.charAt(0)!=="/")result=extensionPath+"/"+result;return normalize(result);},
  isAbsolute:function(value){return String(value).charAt(0)==="/";},
  dirname:function(value){value=normalize(value);var index=value.lastIndexOf("/");return index<=0?(value.charAt(0)==="/"?"/":"."):value.slice(0,index);},
  basename:function(value,suffix){var name=normalize(value).split("/").pop()||"";return suffix&&name.endsWith(suffix)?name.slice(0,-suffix.length):name;},
  extname:function(value){var name=this.basename(value);var index=name.lastIndexOf(".");return index<=0?"":name.slice(index);},
  parse:function(value){var dir=this.dirname(value);var base=this.basename(value);var ext=this.extname(base);return {root:String(value).charAt(0)==="/"?"/":"",dir:dir,base:base,ext:ext,name:base.slice(0,base.length-ext.length)};},
  format:function(value){return (value.dir||value.root||"")+((value.dir||value.root)?"/":"")+(value.base||String(value.name||"")+String(value.ext||""));},
  posix:null
};
pathModule.posix=pathModule;
function processCall(kind,command,args,options,callback){
  if(typeof options==="function"){callback=options;options={};}
  options=options||{};
  var payload={kind:kind,command:String(command),arguments:(args||[]).map(String),options:{}};
  ["cwd","timeout","maxBuffer"].forEach(function(name){if(options[name]!==undefined)payload.options[name]=options[name];});
  if(options.env)payload.options.env=options.env;
  var child={pid:0,kill:function(){throw new Error("child_process child handles are not supported");}};
  bridge("childProcessExec",payload).then(function(result){
    var error=null;
    if(result.status!==0||result.timedOut){error=new Error(result.timedOut?"The process timed out":"The process exited with status "+result.status);error.code=result.status;error.killed=!!result.timedOut;error.stdout=result.stdout;error.stderr=result.stderr;}
    callback(error,result.stdout,result.stderr);
  },function(error){callback(error,"","");});
  return child;
}
var childProcess={
  exec:function(command,options,callback){return processCall("exec",command,[],options,callback);},
  execFile:function(command,args,options,callback){if(typeof args==="function"){callback=args;args=[];options={};}else if(typeof options==="function"){callback=options;options={};}return processCall("execFile",command,args||[],options,callback);}
};
function EventEmitter(){this.__events={};}
EventEmitter.prototype.on=function(name,listener){(this.__events[name]||(this.__events[name]=[])).push(listener);return this;};
EventEmitter.prototype.addListener=EventEmitter.prototype.on;
EventEmitter.prototype.once=function(name,listener){var self=this;function once(){self.removeListener(name,once);listener.apply(self,arguments);}return this.on(name,once);};
EventEmitter.prototype.emit=function(name){var args=Array.prototype.slice.call(arguments,1);(this.__events[name]||[]).slice().forEach(function(listener){listener.apply(null,args);});return !!(this.__events[name]||[]).length;};
EventEmitter.prototype.removeListener=function(name,listener){this.__events[name]=(this.__events[name]||[]).filter(function(value){return value!==listener;});return this;};
EventEmitter.prototype.removeAllListeners=function(name){if(name)delete this.__events[name];else this.__events={};return this;};
EventEmitter.EventEmitter=EventEmitter;
var util={
  promisify:function(fn){return function(){var args=Array.prototype.slice.call(arguments);return new Promise(function(resolve,reject){args.push(function(error){if(error)reject(error);else resolve(arguments.length>2?Array.prototype.slice.call(arguments,1):arguments[1]);});fn.apply(null,args);});};},
  callbackify:function(fn){return function(){var args=Array.prototype.slice.call(arguments);var callback=args.pop();Promise.resolve(fn.apply(null,args)).then(function(value){callback(null,value);},callback);};},
  format:function(){return Array.prototype.map.call(arguments,String).join(" ");},
  inspect:function(value){try{return JSON.stringify(value);}catch(error){return String(value);}},
  inherits:function(ctor,superCtor){ctor.super_=superCtor;ctor.prototype=Object.create(superCtor.prototype,{constructor:{value:ctor,writable:true,configurable:true}});},
  types:{isDate:function(value){return value instanceof Date;},isRegExp:function(value){return value instanceof RegExp;}}
};
var nodeEnvironment=(global.__omnicastContext.environment||{});
global.process={platform:"darwin",arch:nodeEnvironment.architecture||"arm64",env:nodeEnvironment.processEnv||{},version:"v20.0.0",versions:{node:"20.0.0"},cwd:function(){return extensionPath;},nextTick:function(callback){var args=Array.prototype.slice.call(arguments,1);queueMicrotask(function(){callback.apply(null,args);});}};
var os={platform:function(){return "darwin";},arch:function(){return global.process.arch;},homedir:function(){return nodeEnvironment.homePath||"";},tmpdir:function(){return nodeEnvironment.temporaryPath||"/tmp";},hostname:function(){return nodeEnvironment.hostName||"localhost";},type:function(){return "Darwin";},release:function(){return "";},EOL:"\n"};
var NativeResponse=global.Response;
global.fetch=function(input,init){
  init=init||{};var headers={};
  if(init.headers&&typeof init.headers.forEach==="function")init.headers.forEach(function(value,name){headers[name]=value;});
  else Object.keys(init.headers||{}).forEach(function(name){headers[name]=String(init.headers[name]);});
  var payload={url:typeof input==="string"?input:String(input.url),method:init.method||"GET",headers:headers};
  if(typeof init.body==="string")payload.body=init.body;
  else if(init.body instanceof Uint8Array)payload.bodyBase64=base64FromBytes(init.body);
  return bridge("fetch",payload).then(function(result){return new NativeResponse(bytesFromBase64(result.bodyBase64),{status:result.status,headers:result.headers});});
};
function unsupportedModule(name){return new Proxy({},{get:function(target,property){throw new Error("Node module "+name+" does not support "+String(property));}});}
global.__omnicastModules={"fs":fs,"fs/promises":fsPromises,"path":pathModule,"os":os,"child_process":childProcess,"util":util,"events":EventEmitter,"buffer":{Buffer:NodeBuffer}};
global.__omnicastUnsupportedModule=unsupportedModule;
})(globalThis);
