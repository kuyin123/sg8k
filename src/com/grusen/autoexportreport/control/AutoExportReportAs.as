package com.grusen.autoexportreport.control
{
	import com.grusen.autoexportreport.event.ListClickEvent;
	import com.grusen.autoexportreport.view.AutoExportReportView;
	import com.grusen.autoexportreport.vo.MachineTreeItem;
	import com.grusen.charts.SGChart;
	import com.grusen.charts.trend.TrendChartUI;
	import com.grusen.charts.trend.TrendDataBlock;
	import com.grusen.charts.trend.TrendDataBuffer;
	import com.grusen.charts.trend.TrendProvider;
	import com.grusen.charts.wave.WaveProvider;
	import com.grusen.constants.CMDConst;
	import com.grusen.constants.ChartConst;
	import com.grusen.constants.DataTypeConst;
	import com.grusen.constants.NodeTypeConst;
	import com.grusen.constants.RMachineStatusConst;
	import com.grusen.constants.ReportProccessConst;
	import com.grusen.constants.TaskTypeConst;
	import com.grusen.constants.TextTypeConst;
	import com.grusen.events.DataBridgeEvent;
	import com.grusen.events.EventBridge;
	import com.grusen.interfaces.IMachine;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.vo.Machine;
	import com.grusen.model.vo.Organization;
	import com.grusen.model.vo.PChartItem;
	import com.grusen.model.vo.Position;
	import com.grusen.model.vo.TreeItem;
	import com.grusen.model.vo.User;
	import com.grusen.overview.OverViewContainer;
	import com.grusen.overview.OverViewTip;
	import com.grusen.overview.OverViews;
	import com.grusen.services.ServiceConst;
	import com.grusen.systems.navigation.NavTree;
	import com.grusen.utils.ConstUtil;
	import com.grusen.utils.HttpConnent;
	import com.grusen.utils.OrganizationUtil;
	import com.grusen.utils.ValueTypeUtil;
	
	import flash.display.Bitmap;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.system.System;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.core.FlexGlobals;
	import mx.events.FlexEvent;
	import mx.graphics.ImageSnapshot;
	import mx.graphics.codec.PNGEncoder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.StringUtil;
	
	import spark.components.Application;
	
	import avmplus.getQualifiedClassName;
	
	import ppf.base.frame.ChartProvider;
	import ppf.base.frame.CommandItem;
	import ppf.base.frame.CommandManager;
	import ppf.base.frame.IChartProvider;
	import ppf.base.graphics.DataDrawer;
	import ppf.tool.math.DateUtil;
	import ppf.tool.rpc.RPCHelper;
	
	public class AutoExportReportAs extends AutoExportReportView
	{
		/**
		 *拖入的节点
		 */
		private var dropItem:TreeItem;
		// 请求
		private var rpc:RPCHelper;
		
		/**
		 *当前的某机组的所有任务 
		 */
		private var _tasks:ArrayCollection = new ArrayCollection();
		/**
		 *当前正在处理的任务索引 
		 */
		private var _currentTaskIndex:int  =  0;
		/**
		 *当前执行的机组 
		 */
		private var _currMachineItem:MachineTreeItem; 
		/**
		 * 
		 *获取最近的启/停机时间
		 */
		private var _startOrStopTimeObj:Object;
		/**
		 *PChartItems 
		 */
		private var _itemList:Array;
		/**
		 *每次最大循环次数 
		 *3 
		 */
		private var _maxDoTaskCount:int = 3;
		/**
		 *已经执行的次数 
		 */
		private var _hasDoneTaskCount:int = 1;
		/**
		 *存放残余量最小值时间 
		 */
		private var _timeForMMValueArray:Array = [];
		
		//最近一次创建图谱的时间，用于快照超时判断
		private var _lastCreateAtlasTime:Date;
		//循环处理函数的引用值
		private var _currentTimeout:uint;
		//引擎函数间隔时间
		private static const JUDGE_TIME:int   =  2000;
		//判断无请求状态至少多少时间以上才被认可拍照
		private static const JUDGE_MIN_TIME:int  =  3 * 1000;
		//单个截图的超时时间，不超过40秒
		private static const TIME_OUT:int  = 5 * 60 * 1000;
		//当前用户
		private var _user:User;
		
		private var _currTask:Object;
		/**
		 *当前视图 
		 */
		private var _currChartUI:Object;
		
		private var url:String;
		private var http:HttpConnent;
		private var variables:URLVariables;
		
		
		public function AutoExportReportAs()
		{
			super();
		}
		
		/**
		 * 
		 *初始化 
		 */
		override protected function init(event:FlexEvent):void
		{
			report_type.selectedIndex = 0;
			
			_user = GlobalModel.getInstance().authDao.currUser;
			if(_user)
				authorText.text = _user.username?_user.username:_user.name;
		}
		override protected function onComplete():void
		{
			super.onComplete();
			setTimeout(expandAll, 300);
			EventBridge.getInstance().addEventListener( DataBridgeEvent.SNAPSHOT_IMG  ,  onGetSnapshotImg );
			EventBridge.getInstance().addEventListener( DataBridgeEvent.VIEW_CREATE_COMPLETE  ,  onViewCreateComplete  );
			this.addEventListener(Event.REMOVED_FROM_STAGE , onRemoveStage , false , 0 ,true);
			
		}
		/**
		 *移除 
		 */
		private function onRemoveStage(e:Event):void{
			this.removeEventListener(Event.REMOVED_FROM_STAGE , onRemoveStage );
			var classPath:String = getQualifiedClassName(this);
			classPath = classPath.replace("::",".");
			CommandManager.getInstance().removePanelInstance(classPath);
		}
		
		/**
		 * 
		 *展开任务列表 
		 */
		private function expandAll():void
		{
			for each(var item:Object in machineTree.dataProvider)
			       machineTree.expandChildrenOf(item,true);
		}
		/**
		 * 
		 *拖入节点 
		 */
		override protected function onDropItem(item:Object):Boolean
		{
			if(_isGeneratingReport)
				return false;
			
			var factory:TreeItem;
			var mashines:ArrayCollection = new ArrayCollection();
			
			if(item is TreeItem)
			{
				var ti:TreeItem = item as TreeItem;
				dropItem = ti;
				if(ti.value is Machine)//拖入机组 
				{
					mashines.addItem(dropItem);
					factory = getFactory(dropItem.parent as TreeItem);//获取工厂
					updateItems(factory,mashines);
					return true;
					
				}else if(ti.value is Organization){
					var org:Organization  = ti.value as Organization;
					if(org.type == NodeTypeConst.ORGANIZATION_FACTORY){//拖入工厂 
						mashines = getMachinesByDropItem();//获取机组
						updateItems(dropItem,mashines);
						return true;
					}
					if(org.type == NodeTypeConst.ORGANIZATION_EQUIPMENT){//拖入装置
						factory = getFactory(dropItem.parent as TreeItem);//获取工厂
						mashines = getMachinesByDropItem();//获取机组
						updateItems(factory,mashines);
						return true;
					}
				}
				
			}
			return false;
		}
		/**
		 * 
		 *刷新机组任务 
		 */
		private function updateItems(ft:TreeItem,machines:ArrayCollection):void{
			var existFacItem:MachineTreeItem;
			var facItem:MachineTreeItem;
			var children:ArrayCollection;
			var machineItem:TreeItem;
			var bool:Boolean = false;
			var macItem:MachineTreeItem;
			
			if(!ft){
				return;
			}
			
			existFacItem = getExistFacItem(ft.id);//工厂是否存在
			if(!existFacItem){//不存在
				facItem = createFactoryItem(ft);
				machineTreeData.addItem(facItem);
			}else{
				facItem = existFacItem;
			}
			
			children = facItem.children as ArrayCollection ;
			for (var i:int = 0,len:int =  machines.length; i < len; i++) 
			{
				machineItem = machines.getItemAt(i) as TreeItem
				bool = getMachineIsExist(children,machineItem);
				
				if(!bool){
					macItem = createMachine(machineItem);
					macItem.parent = facItem;
					children.addItem(macItem);
				}
				
			}
			updateFactoryStatus(facItem);//更新工厂状态
			
			setTimeout(expandAll, 300);
		}
		
		/**
		 * 
		 *移除任务 
		 */
		override protected function removeItemClickHandler(event:ListClickEvent):void
		{
			var selectedItem:MachineTreeItem = event.param as MachineTreeItem;
			var idx:int;
			var facItem:MachineTreeItem;
			var cls:ArrayCollection;
			
			if(selectedItem.type == NodeTypeConst.ORGANIZATION_FACTORY){
				idx = machineTreeData.getItemIndex(selectedItem);
				machineTreeData.removeItemAt(idx);
			}else{
				facItem = selectedItem.parent as MachineTreeItem;
				cls =  facItem.children as ArrayCollection;
				idx = cls.getItemIndex(selectedItem);
				cls.removeItemAt(idx);
			}
		}
		
		/**
		 * 
		 *判断机组是否存在 
		 */
		private function getMachineIsExist(cls:ArrayCollection,item:TreeItem):Boolean{
			var macItem:MachineTreeItem;
			for (var i:int = 0,len:int = cls.length; i < len; i++) 
			{
				macItem = cls.getItemAt(i) as MachineTreeItem;
				if(macItem.id ==  item.id){
					return true;
				}
			}
			return false;
		}
		/**
		 * 
		 *获取有工厂 
		 */
		private function getExistFacItem(id:String):MachineTreeItem{
			for (var i:int = 0,len:int = machineTreeData.length; i < len; i++) 
			{
				var macItem:MachineTreeItem = machineTreeData.getItemAt(i) as MachineTreeItem;
				if(id == macItem.id)
					return macItem;
			}
			
			return null;
		}
		/**
		 * 
		 *创建工厂  
		 */
		private function createFactoryItem(fac:TreeItem):MachineTreeItem{
			var facItem:MachineTreeItem = new MachineTreeItem();
			facItem.id = fac.id;
			facItem.name = fac.label;
			facItem.type = fac.type;
			facItem.status = RMachineStatusConst.FACTORY_UNDO;
			return facItem;
		}
		/**
		 *  
		 *创建机组 
		 */
		private function createMachine(mac:TreeItem):MachineTreeItem{
			var macItem:MachineTreeItem = new MachineTreeItem();
			macItem.id = mac.id;
			var parent:TreeItem = mac.parent as TreeItem;
			/*	var equipment:TreeItem = getEquipment(parent);
			if(equipment)
			macItem.equipmentName = equipment.label;*/
			if(parent && parent.type < NodeTypeConst.ORGANIZATION_FACTORY)
				macItem.equipmentName = parent.label;
			
			macItem.name = mac.label;
			macItem.type = NodeTypeConst.MAINTYPE_MACHINE;
			macItem.status = RMachineStatusConst.MACHINE_WAITING;
			var m:IMachine = GlobalModel.getInstance().getMachineById(mac.id);
			if(m)
			  	macItem.usePositionNumCheck = m.usePositionNum;
			return macItem;
			
		}
		
		/**
		 * 
		 *开始生成报告 
		 */
		override protected function StartOrStopDoTask(event:MouseEvent):void
		{
			if(_isGeneratingReport){
				stop();
			}else{
				go();
			}
		}
		/**
		 *暂停生成 
		 */
		private function stop():void{
			_isGeneratingReport = false;
			startCreateBtn.label = "开始生成";
			form1.enabled = form2.enabled = true;
			
			var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.CANCEL_SNAPSHOT);
			evt.dispatchEvent();
			
			if(_currMachineItem){
				_currMachineItem.status = RMachineStatusConst.MACHINE_WAITING;
				machineTree.invalidateList();
			}
		}
		/**
		 *继续生成
		 * 
		 */
		private function go():void{
			if(!isValidParam())
				return;
			Position.needUpdateValues = false;
			_isGeneratingReport = true;
			startCreateBtn.label = "暂停生成";
			form1.enabled = form2.enabled = false;
			
			
			doNextMachineTasks();
			
			
		}
		/**
		 *生成结束 
		 */
		private function endCreate():void{
			Position.needUpdateValues = true;
			_isGeneratingReport = false;
			startCreateBtn.label = "开始生成";
			form1.enabled = form2.enabled = true;
			clear();
		}
		
		
		private function isValidParam():Boolean{
			var author:String;
			
			if(!_user){
				Alert.show("用户认证失败，请重新登录！");
				return false;
			}
			
			if(!getFirstUnCreateMachineItem()){
				Alert.show("请添加机组任务！");
				return false;
			}
			
			author = StringUtil.trim(authorText.text);
			
			if(!author || author ==""){
				Alert.show("请输入撰写人姓名！");
				return false;
			}
			
			if(endDate < startDate){
				Alert.show("开始日期不能大于结束日期！");
				return false;
			}
			
			
			return true;
		}
		
		/**
		 * 
		 *生成下一个机组的报告
		 *  
		 */
		private function doNextMachineTasks():void{
			_startOrStopTimeObj = null;
			_currMachineItem = null;
			_currentTaskIndex = -1;
			_currTask = null;
			_timeForMMValueArray = [];
			
			if(!_isGeneratingReport)
				return;
			
			_currMachineItem = getFirstUnCreateMachineItem();//获取未生成报告的机组
			
			if(_currMachineItem){
				updateCurrMachineStatus( RMachineStatusConst.MACHINE_DOING);//更新机组状态
				getMachineConfig();//获取机组配置
			}else{ //所有报告生成完成
				endCreate();
				//				addLogText("报告已全部生成完成");
				return;
			}
		}
		
		/**
		 * 
		 *获取一个未生成报告的机组
		 */
		private function getFirstUnCreateMachineItem():MachineTreeItem{
			var factoryItem:MachineTreeItem;
			var cls:ArrayCollection;
			var machineItem:MachineTreeItem;
			
			for (var i:int = 0,len:int = machineTreeData.length; i < len; i++) //检查并更新工厂状态
			{
				factoryItem = machineTreeData.getItemAt(i) as MachineTreeItem;
				
				if (factoryItem.status == RMachineStatusConst.FACTORY_UNDO) 
				{
					cls = factoryItem.children as ArrayCollection;
					break;
				}
			}
			if(!cls)
				return machineItem;
			
			for (var j:int = 0; j < cls.length; j++) 
			{
				var t:MachineTreeItem = cls.getItemAt(j) as MachineTreeItem;
				if (t.status == RMachineStatusConst.MACHINE_WAITING ) 
				{
					machineItem = t;
					break;
				}
			}
			
			return machineItem;
		}
		
		/**
		 * 
		 *获取机组配置 
		 */
		private function getMachineConfig():void{
			var ti:TreeItem;
			var m:Machine;
			
			if(!_isGeneratingReport)
				return;
			
			ti = GlobalModel.getInstance().getMachineItemById(_currMachineItem.id);
			m = ti.value as Machine;
			if(!m.struct_info || m.struct_info == null){
				getMachineConfigFrom8k(_currMachineItem.id)
			}else{
				//直接传给交互平台
				getTaskListByConfig(m.struct_info);
			}
		}
		
		/**
		 * 
		 *开始下一个任务 
		 */
		
		private function doNextTask():void{
			var task:Object;
			
			if(!_isGeneratingReport)
				return;
			task = getUndoTask();
			
			if (!task){//任务执行完成
				
				getMachineParam();
				return;
			}
			if(_currTask && task.sn == _currTask.sn){
				_hasDoneTaskCount++
			}else{
				_hasDoneTaskCount = 1; 
			}
			
			if(_hasDoneTaskCount > _maxDoTaskCount){
				addLogText(_currMachineItem.name +"  " + _currTask.desc +"  失败" ,1 );
				addLogText(_currMachineItem.name +"  "  + ReportProccessConst.getProccessText(ReportProccessConst.FAIL),1);
				updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[失败] "+_currTask.desc);
				doNextMachineTasks();
				return;
			}
			
			_currTask = task;
			
			if(_currTask.taskType == TaskTypeConst.CHART){
				switch(_currTask.type)
				{
					case ChartConst.BODE:
						doBodeTask();
						break;
					case ChartConst.ACHSE:
					{
						doAchseTask();
						break;
					}
					case ChartConst.WAVE:
					{
						doWaveTask();
						break;
					}
					case ChartConst.TREND_PP_CURRENT_VALUE:
					case ChartConst.TREND_HALF_X:
					case ChartConst.TREND_1_X:
					case ChartConst.TREND_2_X:
					case ChartConst.TREND_GAP:
					{
						doTrendTask();
						break;
					}
					case ChartConst.OVERVIEW:
					{
						
						doOverViewTask();
						break;
					}
					default:
					{
						Alert.show("未知图谱任务|"+_currTask.desc);
						break;
					}
				}
			}else if(_currTask.taskType == TaskTypeConst.TEXT){
				switch(_currTask.type)
				{
					case TextTypeConst.MAX_VALUE:
					{
						doVibChanneTask();
						break;
					}
					case TextTypeConst.START_STOP_TIME:
					{
						doStartOrStopTask();
						break;
					}
				}
			}else{
				Alert.show("未知类型任务 | "+_currTask.desc);
			}
		}
		/**
		 * 
		 *总貌图任务 
		 */
		private function doOverViewTask():void{
			var ls:ArrayCollection;
			var mac:IMachine;
			
			mac = GlobalModel.getInstance().getMachineById(_currMachineItem.id);
			
			//			if(mac.statusRT == StatusConst.NORMAL || mac.statusRT == StatusConst.ALARM){
			ls = GlobalModel.getInstance().getOverviewArrayColl(_currMachineItem.id);
			if(ls && ls.length > 0){
				addLogText(_currMachineItem.name+"  "+ _currTask.desc);
				//存在总貌图
				_itemList = ls.source;
				formatChartItem();
			}else{
				addLogText(_currMachineItem.name+"  "+ _currTask.desc  + "  未设置",1);
				//没有总貌图
				_tasks.removeItemAt(_currentTaskIndex);
				doNextTask();
			}
			//			}else{
			//				//机组不在线
			//				addLogText(_currMachineItem.name+"  "+ _currTask.desc + "  " + ReportProccessConst.getProccessText(ReportProccessConst.FAIL) +"  机组不在线",1);
			//				_tasks.removeItemAt(_currentTaskIndex);
			//				doNextTask();
			//			}
		}
		/**
		 * 
		 *BODE图任务 
		 */
		private function doBodeTask():void{
			if(_startOrStopTimeObj){
				if(_hasDoneTaskCount == 1)
					addLogText(_currMachineItem.name+"  "+ _currTask.desc+"  时间："+DateUtil.dateFormart(_startOrStopTimeObj.STime,DateUtil.YYYYMMDD_JJNNSS) +" - " + DateUtil.dateFormart(_startOrStopTimeObj.ETime,DateUtil.YYYYMMDD_JJNNSS) );
				formatChartItem();
			}
		}
		/**
		 * 轴心位置图任务 
		 */
		private function doAchseTask():void{
			if(_startOrStopTimeObj){
				if(_hasDoneTaskCount == 1)
					addLogText(_currMachineItem.name+"  "+ _currTask.desc+"  时间："+DateUtil.dateFormart(_startOrStopTimeObj.STime,DateUtil.YYYYMMDD_JJNNSS) +" - " + DateUtil.dateFormart(_startOrStopTimeObj.ETime,DateUtil.YYYYMMDD_JJNNSS) );
				formatChartItem();
			}
		}
		/**
		 *趋势图任务 
		 */
		private function doTrendTask():void{
			if(_hasDoneTaskCount == 1)
				addLogText(_currMachineItem.name+"  "+ _currTask.desc);
			formatChartItem();
		}
		/**
		 *波形图 
		 */
		private function doWaveTask():void{
			var device:String = _currTask.device;
			var timeObj:Object = getTimeByDevice(device);
			if(timeObj){
				if(_hasDoneTaskCount == 1)
					addLogText(_currMachineItem.name + "  " + _currTask.desc + "  时间："+ DateUtil.dateFormart(timeObj.date,DateUtil.YYYYMMDD_JJNNSS));
				formatChartItem();
			}else{
				getTimeOfMMValueForDevice();
			}
			
		}
		/**
		 *启停机任务 
		 */
		private function doStartOrStopTask():void{
			if(!_startOrStopTimeObj){
				if(_hasDoneTaskCount == 1)
					addLogText(_currMachineItem.name+"  "+ _currTask.desc);
				getNearestStartOrStopTime();
			}
		}
		/**
		 *通频最大值任务 
		 */
		private function doVibChanneTask():void{
			if(_hasDoneTaskCount == 1)
				addLogText(_currMachineItem.name+"  " + _currTask.desc);
			getMaxValueForVibChannel();
		}
		
		private function getTimeByDevice(name:String):Object{
			var obj:Object;
			for (var i:int = 0; i < _timeForMMValueArray.length; i++) 
			{
				obj = _timeForMMValueArray[i] as Object;
				if(obj.device == name)
					return obj;
			}
			return null;
		}
		
		
		
		
		/**
		 * 
		 *创建第一个图谱 
		 * task:Object
		 * 
		 */
		private function createAtlas():void{
			if(  _tasks.length > _currentTaskIndex  &&  _currentTaskIndex > -1 ){
				var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.INIT_ATLAS);
				evt.param = {
					index:_currentTaskIndex ,
					atlasType:_currTask.type ,
						macId:_currMachineItem.id , 
						nodeList:_itemList
				};
				evt.dispatchEvent();
			}
		}
		/**
		 *更新机组(报告生成)状态 
		 */
		private function  updateCurrMachineStatus(st:int,tips:String = ""):void{
			var facItem:MachineTreeItem;
			
			_currMachineItem.status = st;//当前机组状态
			_currMachineItem.tips = tips;
			
			facItem = _currMachineItem.parent as MachineTreeItem;//更新父节点状态
			updateFactoryStatus(facItem);
		}
		
		/**
		 *
		 *更新工厂状态
		 *  
		 */
		private function updateFactoryStatus(facItem:MachineTreeItem):void{
			var cls:ArrayCollection;
			var child:MachineTreeItem;
			var hasUnDoneMachineItem:Boolean = false;
			
			if(!facItem)
				return;
			
			cls = facItem.children as ArrayCollection;
			
			for (var i:int = 0,len:int =  cls.length; i < len; i++) 
			{
				child = cls.getItemAt(i) as MachineTreeItem;
				if(child.status == RMachineStatusConst.MACHINE_WAITING || child.status == RMachineStatusConst.MACHINE_DOING){
					hasUnDoneMachineItem = true;
					break;
				}
				
			}
			if(hasUnDoneMachineItem)
				facItem.status = RMachineStatusConst.FACTORY_UNDO;
			else
				facItem.status = RMachineStatusConst.FACTORY_DONE;
			
			machineTree.invalidateList();
		}
		/**
		 *
		 * 获取装置 
		 */
		private function getEquipment(item:TreeItem):TreeItem{
			
			if(!item)
				return item;
			
			if(item.type == NodeTypeConst.ORGANIZATION_EQUIPMENT){
				return item;
			}else{
				return getEquipment(item.parent as TreeItem);
			}
		}
		
		
		/**
		 * 
		 *获取工厂 
		 */
		private function getFactory(item:TreeItem):TreeItem{
			if(!item || item == null){
				return item;
			}
			
			if(item.type == NodeTypeConst.ORGANIZATION_FACTORY){
				return item;
			}else{
				return getFactory(item.parent as TreeItem);
			}
		}
		
		/**
		 * 
		 *根据节点获取机组 
		 */
		private function getMachinesByDropItem():ArrayCollection{
			var machines:ArrayCollection =new ArrayCollection();
			var children:ArrayCollection = 	dropItem.children as ArrayCollection;
			machines.removeAll();
			
			forEachChildren(children,machines);
			
			return machines;
		}
		
		private function forEachChildren(children:ArrayCollection,machines:ArrayCollection):void{
			if(!children)
				return;
			for (var i:int = 0,len:int = children.length ; i < len ; i++) 
			{
				var item:TreeItem = children.getItemAt(i) as TreeItem;
				if(item.type >= NodeTypeConst.POSITION)
					break;
				if(item.type == NodeTypeConst.MAINTYPE_MACHINE){
					machines.addItem(item);
				}else{
					forEachChildren(item.children,machines);
				}
			}
		}
		
		/**
		 * 
		 *获取还未执行的任务
		 */
		private function getUndoTask():Object{
			for each(var obj:Object in _tasks ){
				if(!obj.value || obj.value == null){
					_currentTaskIndex = _tasks.getItemIndex(obj);
					return obj;
				}
			}
			return null;
		}
		
		private function onViewCreateComplete(e:DataBridgeEvent):void{
			_currChartUI = null;
			_currChartUI = e.param.chartUI;
			_lastCreateAtlasTime = new Date();
			
			if(_currChartUI is OverViews){
				setTimeout(readyCutOverViewPic,2000);
			}else{
				_currentTimeout = setTimeout( readyTakePic  ,   JUDGE_TIME);
			}
		}
		/**
		 * 
		 *截取总貌图 
		 */
		
		private function readyCutOverViewPic():void{
			var overviews:OverViews = _currChartUI as OverViews;
			var ovc:OverViewContainer;
			var posArr:ArrayCollection;
			var el:OverViewTip;
			
			ovc = overviews.overViewBox.canvasView;
			
			posArr = new ArrayCollection();
			
			for (var i:int = 0 ; i < ovc.numElements; i++) 
			{
				el = ovc.getElementAt(i) as OverViewTip;
				
				if (el.type == ConstUtil.TYPE_POSITION || el.type == ConstUtil.TYPE_SHAFT)
				{
					var p:Position = el.currPosition as Position;
					if (p)
					{
						
						var obj:Object = new Object();
						obj.gpid = p.id;
						
						var tmpValues:String = ""; 
						for each (var item:Object in p.valueTypeRTListAll)
						{
							tmpValues = tmpValues + item.valuetype +"|";
						}
						obj.datatypes = tmpValues;
						posArr.addItem(obj);	
						
					}
				}
			}
			
			if(!rpc)
				rpc = new RPCHelper
			
			rpc.onResult = onHisVauleResult;
			rpc.onFault = function(event:FaultEvent):void
			{
				//获取数据失败
				_currChartUI = null;
				doNextTask();
			};
			rpc.call(ServiceConst.DS_GET_DATA, "GetLatestTrendData",posArr, 86400*30);//30天内最新的数据
		}
		
		protected function onHisVauleResult(e:ResultEvent):void
		{
			var postions:ArrayCollection = e.result as ArrayCollection;
			
			if (postions)
			{
				
				for (var i:int = 0; i < postions.length; i++) 
				{
					var obj:Object = postions.getItemAt(i);
					var pos:Position = GlobalModel.getInstance().getPosById(obj.gpid);
					pos.rtValues =  obj;
				}
				setTimeout(takePic,5*1000);
			}else{//无数据
				updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[失败] 机组长时间不在线");//更新机组
				addLogText(_currMachineItem.name+"  " + ReportProccessConst.getProccessText(ReportProccessConst.FAIL) + "  机组长时间不在线",1);
				doNextMachineTasks();
			}
		}
		
		
		
		
		/**
		 *截图引擎函数 
		 */
		private function readyTakePic():void{
			var status:int;
			
			if(!_isGeneratingReport || !_currChartUI)
				return;
			if( _currChartUI is TrendChartUI){
				var chartProvider:IChartProvider = (_currChartUI as TrendChartUI).chartProvider;
				var pitem:PChartItem;
				var tdb:TrendDataBuffer;
				var unLoaded:Boolean = false;
				var viewList:Array;
				
				for (var i:int = 0,len:int = chartProvider.arrayColl.length; i < len; i++) 
				{
					pitem = chartProvider.arrayColl.getItemAt(i) as PChartItem;
					tdb = (chartProvider as TrendProvider).getTrendBuffer(pitem.position,pitem);
					var	bool:Boolean;
					try
					{
						bool = getBufferStatusIsLoaded(tdb);
					} 
					catch(error:Error) 
					{
						Alert.show("Error : "+ error);
					}
					
					if(!bool){
						unLoaded = true;
						break;
					}
				}
				if(unLoaded){//重新执行任务
					if((new Date()).time - _lastCreateAtlasTime.time > TIME_OUT ){//超时
						clearTimeout( _currentTimeout );
						_currChartUI = null;
						doNextTask();
					}else{//没超时
						_currentTimeout = setTimeout( readyTakePic,   JUDGE_TIME);
					}
					return;
				}
			}else if(_currChartUI is SGChart){
				viewList = ( _currChartUI as SGChart).implObject.viewList;
				if(!viewList || viewList.length <= 0){//重新执行任务
					clearTimeout( _currentTimeout );
					_currChartUI = null;
					doNextTask();
					return;
				}else{
					status = getViewDataLoadStatus(viewList);
					if(status == 3 && ( _currChartUI as SGChart).chartProvider is WaveProvider){
						clearTimeout( _currentTimeout );
						addLogText(_currMachineItem.name +"  " + _currTask.desc +"  无数据" ,1 );
						
						_tasks.removeItemAt(_tasks.getItemIndex(_currTask));
						doNextTask();
						return;
					}
					
					if(status >= 0){//重新执行任务
						if((new Date()).time - _lastCreateAtlasTime.time > TIME_OUT ){//超时
							clearTimeout( _currentTimeout );
							_currChartUI = null;
							doNextTask();
						}else{//没超时
							_currentTimeout = setTimeout( readyTakePic,   JUDGE_TIME);
						}
						return;
					}
				}
			}
			clearTimeout( _currentTimeout );
			_currChartUI = null;
			setTimeout(takePic,JUDGE_MIN_TIME);
			System.gc();
			
		}
		
		
		
		/**
		 *获取当前图谱截图，执行快照 
		 */
		private function takePic(isTimeOut:Boolean=false):void{
			if(!_isGeneratingReport)
				return;
			
			var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.SNAPSHOT);
			evt.param = {istimeout:isTimeOut};
			evt.dispatchEvent();
		}
		/**
		 * 
		 *返回截取的图片 
		 */
		private function onGetSnapshotImg(e:DataBridgeEvent):void{
			if(!_isGeneratingReport)
				return;
			
			var img:Bitmap = e.param.img;
			if(!img){
				Alert.show("截取图谱图片失败","提示");
				return;
			}
			/*imgui.removeChildren();
			imgui.addChild(img);*/
			uploadImg(img);
			
		}
		
		
		/**
		 * 
		 *开始生成报告 
		 */
		private function startCreateReport():void{
			var sasFlag:Boolean = false;//启停机模块
			var author:String;
			var approver:String;
			var auditor:String;
			var company:MachineTreeItem;
			
			if(!_isGeneratingReport)
				return;
			
			if(!_user){
				Alert.show("用户认证失败，请重新登录！");
				return;
			}
			
			author = StringUtil.trim(authorText.text);
			
			if(!author || author ==""){
				Alert.show("撰写人不能为空！");
				return;
			}
			approver = StringUtil.trim(approverText.text);
			auditor = StringUtil.trim(auditorText.text);
			
			url = ServiceConst.SERVER_URL_FOR_SIP+ServiceConst.SERVER_NAME_FOR_SIP+"/SG8K/GenerateReport/GenerateReport.do";
			
			if(rd_need.selected)
				variables.sasFlag = true;
			else
				variables.sasFlag = false;
			
			if(!_currMachineItem)
				return;
			
			company = _currMachineItem.parent as MachineTreeItem ;
			
			if(!variables)
				variables = new URLVariables()
			
			variables.companyName = company ? company.name:"未知企业";
			variables.equipmentName = _currMachineItem.equipmentName;
			variables.machineName = _currMachineItem.name;
			variables.guid = _currMachineItem.id;
			variables.machineConfig = _currMachineItem.struct_info;
			variables.author = author;//撰写人
			variables.approver = approver;//审批人
			variables.auditor = auditor;//批准人
			variables.reportCode = _currMachineItem.code;//报告编码
			variables.params = _currMachineItem.param;
			variables.reportType = report_type.selectedItem.value;
			variables.startDate = DateUtil.dateFormart(startDateField.selectedDate,DateUtil.YYYYMMDD);
			variables.endDate = DateUtil.dateFormart(endDateField.selectedDate,DateUtil.YYYYMMDD);
			variables.taskList = JSON.stringify(_tasks.source);
			variables.createUserId = _user.id
				
//			Alert.show(">>>> "+ variables.taskList);
//			variables.taskList = "[{'device':'变速箱|尾透K131501|9','taskType':2,'remark':'尾透K131501','desc':'尾透K131501 最大的通频值','param':{'ids':'1310120303090210036|1310120303090210035'},'value':15,'type':1,'sn':1},{'device':'尾透|尾透K131501|9','taskType':2,'remark':'尾透','desc':'尾透 最大的通频值','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':52,'type':1,'sn':2},{'device':'空压机|尾透K131501|9','taskType':2,'remark':'空压机','desc':'空压机 最大的通频值','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':21,'type':1,'sn':3},{'device':'变速箱|汽轮机K131607|2','taskType':2,'remark':'汽轮机K131607','desc':'汽轮机K131607 最大的通频值','param':{'ids':'1310120303090210013|1310120303090210023'},'value':15,'type':1,'sn':4},{'device':'汽轮机|汽轮机K131607|2','taskType':2,'remark':'汽轮机','desc':'汽轮机 最大的通频值','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':20,'type':1,'sn':5},{'device':'NOx压缩机|汽轮机K131607|2','taskType':2,'remark':'NOx压缩机','desc':'NOx压缩机 最大的通频值','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':31,'type':1,'sn':6},{'device':null,'taskType':1,'remark':'总貌图','desc':'总貌图','param':{'ids':'131012030309021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385357972.png','type':0,'sn':7},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'尾透K131501 通频值趋势图','desc':'变速箱 尾透K131501 通频值趋势图','param':{'ids':'1310120303090210036|1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385367675.png','type':1,'sn':8},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'尾透K131501 Gap电压趋势图','desc':'变速箱 尾透K131501 Gap电压趋势图','param':{'ids':'1310120303090210036|1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385380558.png','type':8,'sn':9},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'尾透K131501 1X趋势图','desc':'变速箱 尾透K131501 1X趋势图','param':{'ids':'1310120303090210036|1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385398067.png','type':3,'sn':10},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'尾透K131501 2X趋势图','desc':'变速箱 尾透K131501 2X趋势图','param':{'ids':'1310120303090210036|1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385416503.png','type':4,'sn':11},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'尾透K131501 0.5X趋势图','desc':'变速箱 尾透K131501 0.5X趋势图','param':{'ids':'1310120303090210036|1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385435565.png','type':2,'sn':12},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'变速箱低速轴振X 波形频谱图','desc':'尾透K131501 变速箱低速轴振X 波形频谱图','param':{'positions':'1310120303090210036|1310120303090210035','ids':'1310120303090210036'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385444667.png','type':5,'sn':13},{'device':'变速箱|尾透K131501|9','taskType':1,'remark':'变速箱低速轴振Y 波形频谱图','desc':'尾透K131501 变速箱低速轴振Y 波形频谱图','param':{'positions':'1310120303090210036|1310120303090210035','ids':'1310120303090210035'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385451666.png','type':5,'sn':14},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透 通频值趋势图','desc':'尾透 尾透 通频值趋势图','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385466179.png','type':1,'sn':17},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透 Gap电压趋势图','desc':'尾透 尾透 Gap电压趋势图','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385479598.png','type':8,'sn':18},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透 1X趋势图','desc':'尾透 尾透 1X趋势图','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385493130.png','type':3,'sn':19},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透 2X趋势图','desc':'尾透 尾透 2X趋势图','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385506704.png','type':4,'sn':20},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透 0.5X趋势图','desc':'尾透 尾透 0.5X趋势图','param':{'ids':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385518040.png','type':2,'sn':21},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透非联侧轴振X 波形频谱图','desc':'尾透 尾透非联侧轴振X 波形频谱图','param':{'positions':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039','ids':'1310120303090210038'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385525014.png','type':5,'sn':22},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透非联侧轴振Y 波形频谱图','desc':'尾透 尾透非联侧轴振Y 波形频谱图','param':{'positions':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039','ids':'1310120303090210037'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385531546.png','type':5,'sn':23},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透联侧轴振X 波形频谱图','desc':'尾透 尾透联侧轴振X 波形频谱图','param':{'positions':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039','ids':'1310120303090210027'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385538245.png','type':5,'sn':24},{'device':'尾透|尾透K131501|9','taskType':1,'remark':'尾透联侧轴振Y 波形频谱图','desc':'尾透 尾透联侧轴振Y 波形频谱图','param':{'positions':'1310120303090210038|1310120303090210037|1310120303090210027|1310120303090210039','ids':'1310120303090210039'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385545214.png','type':5,'sn':25},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机 通频值趋势图','desc':'空压机 空压机 通频值趋势图','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385556823.png','type':1,'sn':29},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机 Gap电压趋势图','desc':'空压机 空压机 Gap电压趋势图','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385570135.png','type':8,'sn':30},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机 1X趋势图','desc':'空压机 空压机 1X趋势图','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385581654.png','type':3,'sn':31},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机 2X趋势图','desc':'空压机 空压机 2X趋势图','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385594967.png','type':4,'sn':32},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机 0.5X趋势图','desc':'空压机 空压机 0.5X趋势图','param':{'ids':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385606681.png','type':2,'sn':33},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机出口轴振X 波形频谱图','desc':'空压机 空压机出口轴振X 波形频谱图','param':{'positions':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028','ids':'1310120303090210030'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385613619.png','type':5,'sn':34},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机出口轴振Y 波形频谱图','desc':'空压机 空压机出口轴振Y 波形频谱图','param':{'positions':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028','ids':'1310120303090210026'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385620380.png','type':5,'sn':35},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机进口轴振X 波形频谱图','desc':'空压机 空压机进口轴振X 波形频谱图','param':{'positions':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028','ids':'1310120303090210034'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385627249.png','type':5,'sn':36},{'device':'空压机|尾透K131501|9','taskType':1,'remark':'空压机进口轴振Y 波形频谱图','desc':'空压机 空压机进口轴振Y 波形频谱图','param':{'positions':'1310120303090210030|1310120303090210026|1310120303090210034|1310120303090210028','ids':'1310120303090210028'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385633954.png','type':5,'sn':37},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'汽轮机K131607 通频值趋势图','desc':'变速箱 汽轮机K131607 通频值趋势图','param':{'ids':'1310120303090210013|1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385645260.png','type':1,'sn':41},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'汽轮机K131607 Gap电压趋势图','desc':'变速箱 汽轮机K131607 Gap电压趋势图','param':{'ids':'1310120303090210013|1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385656368.png','type':8,'sn':42},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'汽轮机K131607 1X趋势图','desc':'变速箱 汽轮机K131607 1X趋势图','param':{'ids':'1310120303090210013|1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385667641.png','type':3,'sn':43},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'汽轮机K131607 2X趋势图','desc':'变速箱 汽轮机K131607 2X趋势图','param':{'ids':'1310120303090210013|1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385678572.png','type':4,'sn':44},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'汽轮机K131607 0.5X趋势图','desc':'变速箱 汽轮机K131607 0.5X趋势图','param':{'ids':'1310120303090210013|1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385689843.png','type':2,'sn':45},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'变速箱高速轴振X 波形频谱图','desc':'汽轮机K131607 变速箱高速轴振X 波形频谱图','param':{'positions':'1310120303090210013|1310120303090210023','ids':'1310120303090210013'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385696553.png','type':5,'sn':46},{'device':'变速箱|汽轮机K131607|2','taskType':1,'remark':'变速箱高速轴振Y 波形频谱图','desc':'汽轮机K131607 变速箱高速轴振Y 波形频谱图','param':{'positions':'1310120303090210013|1310120303090210023','ids':'1310120303090210023'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385703294.png','type':5,'sn':47},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机 通频值趋势图','desc':'汽轮机 汽轮机 通频值趋势图','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385716995.png','type':1,'sn':50},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机 Gap电压趋势图','desc':'汽轮机 汽轮机 Gap电压趋势图','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385731244.png','type':8,'sn':51},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机 1X趋势图','desc':'汽轮机 汽轮机 1X趋势图','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385743057.png','type':3,'sn':52},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机 2X趋势图','desc':'汽轮机 汽轮机 2X趋势图','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385756363.png','type':4,'sn':53},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机 0.5X趋势图','desc':'汽轮机 汽轮机 0.5X趋势图','param':{'ids':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385767979.png','type':2,'sn':54},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机进口轴振X 波形频谱图','desc':'汽轮机 汽轮机进口轴振X 波形频谱图','param':{'positions':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017','ids':'1310120303090210014'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385774871.png','type':5,'sn':55},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机进口轴振Y 波形频谱图','desc':'汽轮机 汽轮机进口轴振Y 波形频谱图','param':{'positions':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017','ids':'1310120303090210015'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385781797.png','type':5,'sn':56},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机出口轴振X 波形频谱图','desc':'汽轮机 汽轮机出口轴振X 波形频谱图','param':{'positions':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017','ids':'1310120303090210016'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385788485.png','type':5,'sn':57},{'device':'汽轮机|汽轮机K131607|2','taskType':1,'remark':'汽轮机出口轴振Y 波形频谱图','desc':'汽轮机 汽轮机出口轴振Y 波形频谱图','param':{'positions':'1310120303090210014|1310120303090210015|1310120303090210016|1310120303090210017','ids':'1310120303090210017'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385795429.png','type':5,'sn':58},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机 通频值趋势图','desc':'NOx压缩机 NOx压缩机 通频值趋势图','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385810680.png','type':1,'sn':62},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机 Gap电压趋势图','desc':'NOx压缩机 NOx压缩机 Gap电压趋势图','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385825916.png','type':8,'sn':63},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机 1X趋势图','desc':'NOx压缩机 NOx压缩机 1X趋势图','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385854023.png','type':3,'sn':64},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机 2X趋势图','desc':'NOx压缩机 NOx压缩机 2X趋势图','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385883488.png','type':4,'sn':65},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机 0.5X趋势图','desc':'NOx压缩机 NOx压缩机 0.5X趋势图','param':{'ids':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385910560.png','type':2,'sn':66},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机出口X 波形频谱图','desc':'NOx压缩机 NOx压缩机出口X 波形频谱图','param':{'positions':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021','ids':'1310120303090210018'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385931848.png','type':5,'sn':67},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机出口Y 波形频谱图','desc':'NOx压缩机 NOx压缩机出口Y 波形频谱图','param':{'positions':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021','ids':'1310120303090210019'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385948862.png','type':5,'sn':68},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机进口X 波形频谱图','desc':'NOx压缩机 NOx压缩机进口X 波形频谱图','param':{'positions':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021','ids':'1310120303090210020'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385966730.png','type':5,'sn':69},{'device':'NOx压缩机|汽轮机K131607|2','taskType':1,'remark':'NOx压缩机进口Y 波形频谱图','desc':'NOx压缩机 NOx压缩机进口Y 波形频谱图','param':{'positions':'1310120303090210018|1310120303090210019|1310120303090210020|1310120303090210021','ids':'1310120303090210021'},'value':'D:/data/sgck-sip/20170510/pictrue/1494385984490.png','type':5,'sn':70}]";
			
			
			if(!http)
				http= new HttpConnent()
			http.url = url;
			http.urlVariables = variables;
			http.completeFun = createReportFun;
			http.errFun = createReportErrFun;
			http.gotoConn(URLRequestMethod.POST);
		}
		
		private function createReportFun(e:Event):void{
			var res:Object = JSON.parse(e.currentTarget.data as String);
			
			if(res.code == 200){
				if(_currMachineItem){
					addLogText(_currMachineItem.name+"  生成成功",2 );
					if(res.data.type == "success" ){
						updateCurrMachineStatus(RMachineStatusConst.MACHINE_SUCCESS,"[成功]");
					}else{
						updateCurrMachineStatus(RMachineStatusConst.MACHINE_SUCCESS,"[成功]"+ res.data.desc);
					}
					
				}
			}else{
				addLogText(_currMachineItem.name+"  生成失败",1 );
				updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[失败]"+ res.msg?res.msg:"");
			}
			doNextMachineTasks();
		}
		private function createReportErrFun(e:IOErrorEvent):void{
//			Alert.show("生成失败！");
			addLogText(_currMachineItem.name+"  生成失败",1 );
			updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[失败]");
			doNextMachineTasks();
		}
		/**
		 * 
		 *获取当前机组报告任务清单 
		 */
		private function getTaskListByConfig(m_c:String):void{
			var sasFlag:Boolean = false;//启停机模块
			
			if(!m_c || m_c == "" || !_currMachineItem )
				return;
			
			_currMachineItem.struct_info = m_c;
			
			url = ServiceConst.SERVER_URL_FOR_SIP+ServiceConst.SERVER_NAME_FOR_SIP+"/SG8K/GenerateReport/GetReportTaskList.do";
			
			if(!variables)
				variables = new URLVariables();
			
			if(rd_need.selected)
				variables.sasFlag = true;
			else
				variables.sasFlag = false;
			
			variables.guid = _currMachineItem.id;
			variables.machineConfig = m_c;
			
			if(rd_machine.selected && !_currMachineItem.usePositionNumCheck)
				variables.displayViewType = "1";
			else
				variables.displayViewType = "2";
			
			if(!http)
				http= new HttpConnent()
			http.url=url;
			http.urlVariables=variables;
			http.completeFun=getTasksFun;
			http.errFun=getTasksErrFun;
			http.gotoConn(URLRequestMethod.POST);
			
		}
		private function getTasksFun(e:Event):void{
			var obj:Object;
			
			_tasks.removeAll();
			
			obj = JSON.parse(e.currentTarget.data as String);
			
			if(obj.code != 200){//获取任务异常
				updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[失败]"+obj.msg);//更新机组
				addLogText(_currMachineItem.name+"  " + ReportProccessConst.getProccessText(ReportProccessConst.FAIL) + "  "+obj.msg,1);
				doNextMachineTasks();
				
			}else{//成功获取任务
				addLogText(_currMachineItem.name+"  开始生成");
				_tasks = new ArrayCollection(obj.data);
				
				doNextTask();
			}
		}
		private function getTasksErrFun(e:IOErrorEvent):void{
			//			Alert.show("获取失败，请稍后重试!");
			addLogText("访问失败  "+ ServiceConst.SERVER_URL_FOR_SIP+ServiceConst.SERVER_NAME_FOR_SIP,1);
			getMachineConfig();
		}
		/**
		 *获取开始时间 
		 */
		private function	get startDate():Date{
			var sDate:Date = startDateField.selectedDate; 
			sDate = new Date(sDate.fullYear,sDate.month,sDate.date,0,0,0,0);
			return sDate;
		}
		
		/**
		 *获取开始时间 
		 */
		private function	get endDate():Date{
			var eDate:Date = endDateField.selectedDate; 
			eDate = new Date(eDate.fullYear,eDate.month,eDate.date,23,59,59,999);
			return eDate;
		}
		/**
		 *
		 *获取某机组一段时间内最近一次的启机/停机/启停机时间 
		 */
		private function getNearestStartOrStopTime():void{
			if(!rpc)
				rpc = new RPCHelper();
			rpc.onResult = onGetNearestStartOrStopTimeResult; 
			rpc.onFault = onGetNearestStartOrStopTimeFault;
			rpc.call(ServiceConst.DS_GET_EVENT_AND_STATUS,"GetNearestSSTime",_currMachineItem.id,startDate,endDate);
			
		}
		private function onGetNearestStartOrStopTimeResult(event:ResultEvent):void
		{
			_startOrStopTimeObj = event.result as Object;
			if(!_startOrStopTimeObj){
				deleteSSModule();
				doNextTask();//执行下一个任务
			}else{
				_currTask.value = JSON.stringify({
					STime:DateUtil.dateFormart(_startOrStopTimeObj.STime,DateUtil.YYYYMMDD),
					ETime:DateUtil.dateFormart(_startOrStopTimeObj.ETime,DateUtil.YYYYMMDD),
					type:_startOrStopTimeObj.type
				});
				
				doNextTask();
			}
		}
		private function onGetNearestStartOrStopTimeFault(event:FaultEvent):void{
			doNextTask();
		}
		/**
		 * 
		 *获取某设备内测点一段时间内的最大的通频值(统计去除启停机部分数据)
		 */
		
		private function getMaxValueForVibChannel():void{
			var ids:Array =_currTask.param.ids.split("|");
			
			if(!ids || ids == []){
				Alert.show("任务无关联ID ");
				return ;
			}
			if(!rpc)
				rpc = new RPCHelper();
			rpc.onResult = onGetMaxValueForVibChannelResult; 
			rpc.onFault = onGetMaxValueForVibChannelFault;
			rpc.call(ServiceConst.DS_GET_EVENT_AND_STATUS,"GetMaxValueForVibChannel",ids,8,0,startDate,endDate);
			
		}
		private function onGetMaxValueForVibChannelResult(event:ResultEvent):void
		{
			if(event.result && _currTask){
				_currTask.value = Math.ceil(event.result as Number);
				doNextTask();
			}else{
				//				trace(" 无数据 ！ 停止当前报告进度，开始生成下一份报告！");
				/*updateCurrMachineStatus(RMachineStatusConst.MACHINE_FAIL,"[获取通频值失败] 无数据！");
				addLogText(_currMachineItem.name+"  生成失败  无数据");
				doNextMachineTasks();*/
				doNextTask();
			}
			
		}
		private function onGetMaxValueForVibChannelFault(event:FaultEvent):void{
			doNextTask();
		}
		/**
		 *获取某设备一段时间内残余量最小的时间(统计去除启停机部分数据)
		 * 
		 */
		private function getTimeOfMMValueForDevice():void{
			var ids:Array = _currTask.param.positions.split("|");
			if(!ids || ids == []){
				Alert.show("任务无关联ID ");
				return ;
			}
			if(!rpc)
				rpc = new RPCHelper();
			rpc.onResult = onGetTimeForDeviceResult; 
			rpc.onFault = onGetTimeForDeviceFault;
			rpc.call(ServiceConst.DS_GET_EVENT_AND_STATUS,"GetTimeOfMMValue",ids,22,1,startDate,endDate);
		}
		private function onGetTimeForDeviceResult(event:ResultEvent):void
		{
			var dt:Date = event.result as Date;
			
			if(dt){
				_timeForMMValueArray.push({
					"device":_currTask.device,
					"date":dt
				});
				if(_hasDoneTaskCount == 1)
					addLogText(_currMachineItem.name + "  " + _currTask.desc + "  时间："+ DateUtil.dateFormart(dt,DateUtil.YYYYMMDD_JJNNSS));
				formatChartItem();
			}else{
				doNextTask();
			}
		}
		private function onGetTimeForDeviceFault(event:FaultEvent):void{
			doNextTask();
		}
		/**
		 *上传图片 
		 * 
		 */
		private function uploadImg(img:Bitmap):void{
			var encoder:PNGEncoder; 
			var imgSnapshot:ImageSnapshot;
			var pngStr:String;
			
			if(!_isGeneratingReport)
				return;
			
			encoder = new PNGEncoder(); 
			imgSnapshot =ImageSnapshot.captureImage(img,0,encoder);
			pngStr = ImageSnapshot.encodeImageAsBase64(imgSnapshot);
			
			url = ServiceConst.SERVER_URL_FOR_SIP+ServiceConst.SERVER_NAME_FOR_SIP+"/SG8K/GenerateReport/UploadReportPicture.do";
			
			if(!variables)
				variables = new URLVariables();
			
			variables.fileStr = pngStr;
			
			if(!http)
				http= new HttpConnent()
			http.url=url;
			http.urlVariables=variables;
			http.completeFun=uploadImgFun;
			http.errFun=uploadImgErrFun;
			http.gotoConn(URLRequestMethod.POST);
		}
		private function uploadImgFun(e:Event):void{
			var res:Object =JSON.parse(e.currentTarget.data as String);
			if(res.code == 200){
				var item:Object = _tasks.getItemAt(_currentTaskIndex);
				item.value = res.data;
				doNextTask();
			}else{
				//				Alert.show("上传失败！");
				doNextTask();
			}
		}
		private function uploadImgErrFun(e:Event):void{
			//			Alert.show("上传图片失败！");
			doNextTask();
		}
		
		/**
		 * 
		 *从8K服务器获取机组配置 
		 */	
		private function getMachineConfigFrom8k(machinId:String):void
		{
			if(!_isGeneratingReport)
				return;
			
			if(!rpc)
				rpc = new RPCHelper();
			rpc.onResult = onGetMachineConfigResult; 
			rpc.onFault = onGetMachineConfigFault;
			rpc.call(ServiceConst.DS_GET_SETUP,"GetMachineInfoById",machinId);
		} 
		private var cmdManager:CommandManager = CommandManager.getInstance() as CommandManager;
		private function onGetMachineConfigResult(event:ResultEvent):void
		{
			var resultMac:Machine = event.result as com.grusen.model.vo.Machine;
			getTaskListByConfig(resultMac.struct_info);
			
			var myTree:NavTree = FlexGlobals.topLevelApplication.navTree;
			var ti:TreeItem = GlobalModel.getInstance().getMachineItemById(	_currMachineItem.id);
			myTree.operateItem = ti;
			if(ti.value.typeStr == ConstUtil.TYPE_MACHINE)
			{
				if(GlobalModel.getInstance().isMachineValid(ti.id))
				{
					
					myTree.createMachineItem(ti);
				}else{
					//已经处于请求状态
					myTree.showWaiter();
					myTree.waiter.startRequest(ti.id,myTree.onMachineHandler);
				}
			}
				
		}
		private function onGetMachineConfigFault(event:FaultEvent):void{
			//			trace(event);
		}
		
		/**
		 * 
		 *获取机组设计参数
		 */ 
		private function getMachineParam():void{
			if(!_isGeneratingReport)
				return;
			if(!rpc)
				rpc = new RPCHelper();
			rpc.onResult  =   onGetParamResult;
			rpc.onFault = onGetParamFail;
			rpc.call(ServiceConst.DS_GET_SETUP   ,   "GetMachineParam" , _currMachineItem.id);
		}
		private function onGetParamResult(e:ResultEvent):void{
			if(e.result && e.result != null && _currMachineItem)
			{
				_currMachineItem.param = e.result.toString();
			}
			startCreateReport();
		}
		private function onGetParamFail(e:FaultEvent):void{
			startCreateReport();
		}
		
		/**
		 *
		 *删除有关启停机的任务(无启停机) 
		 */
		private function deleteSSModule():void{
			var task:Object;
			for (var i:int = 0; i < _tasks.length; i++) 
			{
				task = _tasks[i];
				if(task.taskType == TaskTypeConst.CHART){
					switch(task.type)
					{
						case ChartConst.BODE:
						case ChartConst.ACHSE:
						{
							_tasks.removeItemAt(i);
							i--;
							break;
						}
							
						default:
						{
							break;
						}
					}
				}else if(task.taskType == TaskTypeConst.TEXT){
					switch(task.type)
					{
						case TextTypeConst.START_STOP_TIME:
						{
							_tasks.removeItemAt(i);
							i--;
							break;
						}
							
						default:
						{
							break;
						}
					}
				}else{
					Alert.show("未知任务");
				}
			}
		}
		
		/**
		 * 
		 *是否加载完成
		 * 
		 */
		private function getBufferStatusIsLoaded(tdb:TrendDataBuffer):Boolean{
			var bls:Array;
			var bl:TrendDataBlock;
			
			bls = tdb.blocks;
			
			if(bls && bls.length > 0){
				for (var j:int = 0; j < bls.length; j++) 
				{
					bl = bls[j] as TrendDataBlock;
					if(!bl)
						continue;
					var status:Number = bl.getDataStatus(bl.indexX);
					if(status != 3){
						return false;
					}
				}
			}
			
			return true;
		}
		
		/**
		 *  
		 *初始化图谱的PChartItem数组
		 */
		private function formatChartItem():void{
			var ids:Array;
			
			if(!_currTask)
				return;
			//信息注入
			ids =_currTask.param.ids.split("|");
			
			if(!ids || ids == [])
				return ;
			
			if(_currTask.type  == ChartConst.OVERVIEW){ // 总貌图
				
			}else{//其他图谱
				
				_itemList = [];
				
				for each (var id:String in ids) 
				{
					var pci:PChartItem = OrganizationUtil.getChartItemById( id );
					if(!pci){
						_itemList = null;
					}else{
						
						pci.dataType = DataTypeConst.HISTORY; //历史数据
						
						if(endDate.time - startDate.time > 30*24*60*60*1000)
							pci.dataDensity = DataTypeConst.DENSITY_LOW;
						else if(endDate.time - startDate.time > 10*24*60*60*1000)
							pci.dataDensity = DataTypeConst.DENSITY_MEDIUM;
						else
							pci.dataDensity = DataTypeConst.DENSITY_HIGH;
						
						switch (_currTask.type)
						{
							case ChartConst.WAVE:
								var timeObj:Object = getTimeByDevice(_currTask.device);
								pci.startDate = timeObj.date;
								pci.endDate = timeObj.date;
								break;
							case ChartConst.TREND_PP_CURRENT_VALUE:
								pci.startDate = startDate;
								pci.endDate = endDate;
								break;
							case ChartConst.TREND_HALF_X:
								pci.valueTypeCode = ValueTypeUtil.makeCode(ValueTypeUtil.FREQUENCY_HALF);
								pci.startDate = startDate;
								pci.endDate = endDate;
								break;
							case ChartConst.TREND_1_X:
								pci.valueTypeCode = ValueTypeUtil.makeCode(ValueTypeUtil.FREQUENCY_1_AMPLITUDE);
								pci.startDate = startDate;
								pci.endDate = endDate;
								break;
							case ChartConst.TREND_2_X:
								pci.valueTypeCode = ValueTypeUtil.makeCode(ValueTypeUtil.FREQUENCY_2_AMPLITUDE);
								pci.startDate = startDate;
								pci.endDate = endDate;
								break;
							case ChartConst.TREND_GAP:
								pci.valueTypeCode = ValueTypeUtil.makeCode(ValueTypeUtil.GAP_VOLTAGE);
								pci.rangeMax = 1;
								pci.rangeMin = -25;
								pci.startDate = startDate;
								pci.endDate = endDate;
								break;
							case ChartConst.BODE:	
							case ChartConst.ACHSE:
								pci.startDate = _startOrStopTimeObj.STime;
								pci.endDate = _startOrStopTimeObj.ETime;
								pci.dataDensity = DataTypeConst.DENSITY_HIGH;
								break;
						}
						
						pci.param = {includeFilter:7};
						_itemList.push(pci);
						
					}
				}
			}
			//创建第一个图谱
			createAtlas();
		}
		/**
		 *获取数据当前状态 
		 * 
		 */
		private function getViewDataLoadStatus(viewList:Array):int{
			var status:int = -1;
			var view:Object ;
			var cp:ChartProvider;
			
			view = viewList[0];
			cp = view.chartProvider;
			
			if(cp.arrayColl.length <= 0)
				
				return 999;
			
			for each (var rangItem:PChartItem in cp.arrayColl.source)
			{
				var datadrawer:DataDrawer=view.curdrawer(rangItem);
				if( datadrawer.progressType > 0){
					status = datadrawer.progressType;
					break;
				}
				
			}
			return status;
		}
		
		/**
		 * 
		 *日志
		 * 
		 * 
		 */
		private function addLogText(txt:String,type:int = 0):void{
			var time:String;
			
			time = DateUtil.dateFormart(new Date(),DateUtil.YYYYMMDD_JJNNSS);
			
			if(type == 1){
				logTextArea.htmlText = logTextArea.htmlText+ "["+ time+"] <font color='#FF0000'>"+ txt +"</font><br>";
			}else if(type == 2){
				logTextArea.htmlText = logTextArea.htmlText+ "["+ time+"] <font color='#00FF00'>"+ txt +"</font><br>";
			}else{
				logTextArea.htmlText = logTextArea.htmlText+ "["+ time+"] "+ txt +"<br>";
			}
		}
		/**
		 * 
		 * 
		 */
		private function clear():void{
			_currChartUI = null;
			_currentTaskIndex = -1;
			_currMachineItem = null;
			_tasks.removeAll();
			_currTask = null;
			_startOrStopTimeObj = null;
			dropItem = null;
			rpc = null;
			_itemList = [];
			_timeForMMValueArray = [];
			_lastCreateAtlasTime = null;
			_currentTimeout = 0;
			
			var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.CANCEL_SNAPSHOT);
			evt.dispatchEvent();
		}
		
		
	}
}