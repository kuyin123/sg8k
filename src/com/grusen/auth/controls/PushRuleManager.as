package com.grusen.auth.controls
{
	import com.grusen.auth.views.PushRuleDG;
	import com.grusen.auth.views.UserPushRuleEdit;
	import com.grusen.constants.AuthValueConst;
	import com.grusen.constants.CMDOpConst;
	import com.grusen.interfaces.IOrganization;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.vo.FilterRule;
	import com.grusen.services.ServiceConst;
	import com.grusen.utils.OrganizationUtil;
	
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.utils.setTimeout;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import ppf.base.object.VOObject;
	import ppf.tool.auth.AuthUtil;
	import ppf.tool.components.events.OpRendererEvent;
	import ppf.tool.components.views.GrManager;
	import ppf.tool.rpc.RPCHelper;
	
	public class PushRuleManager extends GrManager
	{
		private var _data:Object;
		private var rpc:RPCHelper = new RPCHelper();
		
		public function PushRuleManager()
		{
			super();
			
			dg = new PushRuleDG();
			
			editPanel = new UserPushRuleEdit();
			editPanel.title = "修改用户事件屏蔽规则";
			
			editPanel.addEventListener("reloadRules" , onReLoadRules , false , 0 , true);
		 
		}
		
		private function onReLoadRules(e:Event):void{
			onInit();
		}
		
		public function set initRule(value:Object):void{
			_data = value;
			if(isCreationComplete){
				onInit();
			}
		}
		
		override protected function onAdd(event:MouseEvent=null):void
		{
			
			UserPushRuleEdit(editPanel).initRule = {userId: _data.userId , phone:_data.phone , hasRule:dg.dataProvider};
			super.onAdd(event);
			
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			if (null != dg){
				this.addEventListener(OpRendererEvent.USER_RULE_EDIT ,onRuleModify,false,0,true);
				this.addEventListener(OpRendererEvent.USER_RULE_DEL ,onRuleDel,false,0,true);
			}
		}
		
		//编辑规则
		private function onRuleModify(e:OpRendererEvent):void{
			editPanel.isAdd = false;
			//editPanel.title = "修改用户事件屏蔽规则";
			UserPushRuleEdit(editPanel).initRule = {userId: _data.userId , phone:_data.phone , hasRule:dg.dataProvider};
			cmdManager.mainFrame.addDisplayObject(editPanel);
			
			if (editPanel.isCreationComplete)
			{
				if (dg.selectedItem is VOObject)
					editPanel.onModifyItem((dg.selectedItem as VOObject).clone());
				else
					editPanel.onModifyItem(dg.selectedItem);
			}
			
		}
		
		//删除规则
		private function onRuleDel(e:OpRendererEvent):void{
			if(dg.selectedItem){
				var ru:FilterRule = FilterRule(dg.selectedItem);
				var rid:int = ru.ruleid;
				rpc.onResult = onDelRuleResult;
				rpc.onFault = onDelRuleFault;
				rpc.ids = {rid:rid};
				rpc.call(ServiceConst.DS_MAINHANDLER, "DelFilterRule", rid );
			}
		}
		
		private function onDelRuleResult(e:ResultEvent):void{
			var rid:int = int(e.token.ids.rid);
			var dl:ArrayCollection = dg.dataProvider as ArrayCollection;
			if(dl){
				for(var i:int=0;i<dl.length;i++){
					var ru:FilterRule = dl.getItemAt(i) as FilterRule;
					if(ru && ru.ruleid == rid){
						dl.removeItemAt(i);
						i --;
					}
				}
				dl.refresh();
			}
			
		}
		
		private function onDelRuleFault(e:FaultEvent):void{
			//删除规则失败
		}
		
		override public function onInit(event:Event=null):void
		{
			if(_data){
				var userid:int = int(_data.userId);
 				this.enabled = false;
				rpc.onResult = onResultFun;
				rpc.onFault = onFailFun;
				rpc.call(ServiceConst.DS_GET_SETUP, "GetFilterRuleList", userid , _data.phone , -1 , 1);
			}else{
				dg.dataProvider = new ArrayCollection([]);
			}
  
		}
		
		private function getOrgPath(item:FilterRule , isReload:Boolean = false):void{
			
			var orgid:String = String( item.orgidList );
			
			var org:IOrganization;
			
			if( item.ruleType == 0){
				org =  GlobalModel.getInstance().getMachineById(orgid);
			}else{
				org = GlobalModel.getInstance().getPosById(orgid);
			}
			
			if(!org){
				var macid:String = orgid;
				if(item.ruleType == 1){
					macid = macid.substr(0 , macid.length - 4);
				}
				GlobalModel.getInstance().requestMachine(macid , true);
 				setTimeout( getOrgPath  ,  1500 , item , true);
				return;
 			}
			
			var path:String = OrganizationUtil.getOrgnazaitonPath(org);
			item.ruleName = (path? path : "");
			
			if(isReload  && dg.dataProvider){
				ArrayCollection(dg.dataProvider).refresh();
			}
		}
 
		private function onResultFun(e:ResultEvent):void{
			this.enabled = true;
			
			var dlist:ArrayCollection = e.result as ArrayCollection;
			for each(var it:FilterRule in dlist){
				getOrgPath(it);
			}
 
			dg.dataProvider = dlist;
			if (null != dg.dataProvider)
				(dg.dataProvider as ArrayCollection).filterFunction = ruleFilter;
			
		}
		
		private function onFailFun(e:FaultEvent):void{
			this.enabled = true;
			dg.dataProvider = new ArrayCollection([]);
		}
		
		
		//屏蔽双击
		override protected function onDoubleClick(event:MouseEvent):void{
			return;
		}
		
		override protected function onComplete():void
		{
			dg.opDataProvider = cmdManager.resourceManager.getResources([CMDOpConst.USER_RULE_MODIFY  ,CMDOpConst.USER_RULE_DEL]);
			if(_data){
				onInit();
			}
		 
		}
		
		/**
		 * 检测界面的权限状态 
		 */	
		override protected function checkAuth():void
		{
			auth_btnAdd = AuthUtil.checkAuth(AuthValueConst.USER_RULE_SETTING);
			dg.invalidateDisplayList();
		}
		
		private function ruleFilter(item:Object):Boolean
		{
 			
			var tmpItem:FilterRule = item as FilterRule;
			
 			if (t_filter && t_filter.text.length > 0 ){
				if(tmpItem.ruleName){
					var i:int = tmpItem.ruleName.indexOf(t_filter.text);
					if (i> -1)
						return true;
					else
						return false;
				}else
					return false;
				
 			}else
				return true;
			
			 
		}
	 
		
		
	}
}