package extensions
{
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.html.HTMLLoader;
	import flash.utils.ByteArray;
	
	import avm2.intrinsics.memory.lf32;
	import avm2.intrinsics.memory.li16;
	import avm2.intrinsics.memory.li8;
	import avm2.intrinsics.memory.sf32;
	import avm2.intrinsics.memory.si16;
	import avm2.intrinsics.memory.si8;
	
	import cc.makeblock.util.FileUtil;
	import cc.makeblock.util.JsCall;
	import cc.makeblock.util.MemUtil;
	
	import util.LogManager;
	
	public class JavaScriptEngine
	{
		private const _htmlLoader:HTMLLoader = new HTMLLoader();
		private var _ext:Object;
		private var _name:String = "";
//		public var port:String = "";
		public function JavaScriptEngine(name:String="")
		{
			_name = name;
			_htmlLoader.placeLoadStringContentInApplicationSandbox = true;
		}
		private function register(name:String,descriptor:Object,ext:Object,param:Object):void{
			_ext = ext;
			
			LogManager.sharedManager().log("registed:"+_ext._getStatus().msg);
			//trace(SerialManager.sharedManager().list());
			//_timer.start();
		}
		public function get connected():Boolean{
			if(_ext){
				return _ext._getStatus().status==2;
			}
			return false;
		}
		public function get msg():String{
			if(_ext){
				return _ext._getStatus().msg;
			}
			return "Disconnected";
		}
		public function call(method:String,param:Array,ext:ScratchExtension):void{
			var c:Boolean = connected;
			var jscall:Boolean = JsCall.canCall(method);
			if(!(c && jscall)){
				return;
			}
			_ext[method].apply(null, param);
		}
		public function requestValue(method:String,param:Array,ext:ScratchExtension, nextID:int):void
		{
			if(connected){
				getValue(method,[nextID].concat(param),ext);
			}
		}
		public function getValue(method:String,param:Array,ext:ScratchExtension):*{
			if(!this.connected){
				return false;
			}
			for(var i:uint=0;i<param.length;i++){
				param[i] = ext.getValue(param[i]);
			}
			return _ext[method].apply(null, param);
		}
		public function closeDevice():void{
			if(_ext){
				_ext._shutdown();
			}
		}
		private function onConnected(evt:Event):void{
			if(_ext){
				var dev:SerialDevice = SerialDevice.sharedDevice();
				_ext._deviceConnected(dev);
				LogManager.sharedManager().log("register:"+_name);
			}
		}
		private function onClosed(evt:Event):void{
			if(_ext){
				var dev:SerialDevice = SerialDevice.sharedDevice();
				_ext._deviceRemoved(dev);
				LogManager.sharedManager().log("unregister:"+_name);
			}
		}
		private function onRemoved(evt:Event):void{
			if(_ext&&ConnectionManager.sharedManager().extensionName==_name){
				ConnectionManager.sharedManager().removeEventListener(Event.CONNECT,onConnected);
				ConnectionManager.sharedManager().removeEventListener(Event.REMOVED,onRemoved);
				ConnectionManager.sharedManager().removeEventListener(Event.CLOSE,onClosed);
				var dev:SerialDevice = SerialDevice.sharedDevice();
				_ext._deviceRemoved(dev);
				_ext = null;
			}
		}
		public function loadJS(path:String):void{
			var html:String = "var ScratchExtensions = {};" +
				"ScratchExtensions.register = function(name,desc,ext,param){" +
				"	try{			" +
				"		callRegister(name,desc,ext,param);		" +
				"	}catch(err){			" +
				"		setTimeout(ScratchExtensions.register,10,name,desc,ext,param);	" +
				"	}	" +
				"};";
//			html += FileUtil.ReadString(File.applicationDirectory.resolvePath("js/AIRAliases.js"));
			html += FileUtil.ReadString(new File(path));
			_htmlLoader.window.eval(html);
			_htmlLoader.window.callRegister = register;
			_htmlLoader.window.parseFloat = readFloat;
			_htmlLoader.window.parseShort = readShort;
			_htmlLoader.window.parseDouble = readDouble;
			_htmlLoader.window.float2array = float2array;
			_htmlLoader.window.short2array = short2array;
			_htmlLoader.window.string2array = string2array;
			_htmlLoader.window.array2string = array2string;
			_htmlLoader.window.responseValue = responseValue;
			_htmlLoader.window.trace = trace;
			_htmlLoader.window.air = {"trace":trace};
			ConnectionManager.sharedManager().addEventListener(Event.CONNECT,onConnected);
			ConnectionManager.sharedManager().addEventListener(Event.REMOVED,onRemoved);
			ConnectionManager.sharedManager().addEventListener(Event.CLOSE,onClosed);
		}
		private function responseValue(extId:uint,value:*):void{
			MBlock.app.extensionManager.reporterCompleted(_name,extId,value);
		}
		
		static private function readFloat(bytes:Array):Number{
			if(bytes.length < 4){
				return 0;
			}
			si8(bytes[0], 0);
			si8(bytes[1], 1);
			si8(bytes[2], 2);
			si8(bytes[3], 3);
			return lf32(0);
		}
		static private function readDouble(bytes:Array):Number{
			return readFloat(bytes);
		}
		static private function readShort(bytes:Array):Number{
			if(bytes.length < 2){
				return 0;
			}
			si8(bytes[0], 0);
			si8(bytes[1], 1);
			return li16(0);
		}
		static private function float2array(v:Number):Array{
			sf32(v, 0);
			return [li8(0), li8(1), li8(2), li8(3)];
		}
		static private function short2array(v:Number):Array{
			si16(v, 0);
			return [li8(0), li8(1)];
		}
		static private function string2array(v:String):Array{
			var buffer:ByteArray = MemUtil.Mem;
			buffer.position = 0;
			buffer.writeUTFBytes(v);
			var array:Array = [];
			for(var i:int=0;i<buffer.position;i++){
				array[i] = li8(i);
			}
			return array;
		}
		static private function array2string(bytes:Array):String{
			var buffer:ByteArray = MemUtil.Mem;
			buffer.position = 0;
			for(var i:int=0;i<bytes.length;i++){
				si8(bytes[i], i);
			}
			return buffer.readUTFBytes(bytes.length);
		}
	}
}