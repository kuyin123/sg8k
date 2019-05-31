package com.grusen.auth.controls
{
	import com.grusen.auth.views.UserDG;
	import com.grusen.auth.views.UserEdit;
	import com.grusen.auth.views.UserOrgEdit;
	import com.grusen.constants.AuthValueConst;
	import com.grusen.constants.CMDOpConst;
	import com.grusen.events.ModelEvent;
	import com.grusen.interfaces.IOrganization;
	import com.grusen.managers.SgResourceManager;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.vo.User;
	import com.grusen.services.ServiceConst;
	
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.collections.ArrayCollection;
	import mx.core.EventPriority;
	import mx.events.FlexEvent;
	import mx.rpc.events.ResultEvent;
	
	import ppf.base.object.VOObject;
	import ppf.base.resources.LocaleConst;
	import ppf.tool.auth.AuthUtil;
	import ppf.tool.components.PropertiesConst;
	import ppf.tool.components.events.OpRendererEvent;
	import ppf.tool.components.views.GrManager;
	import ppf.tool.rpc.managers.RPCManager;
	
	
	public final class UserManager extends GrManager
	{
		
		private var userOrgEdit:UserOrgEdit;
		
		
		public function UserManager()
		{
			super();
			
			dg = new UserDG;
			
			editPanel = new UserEdit;
			userOrgEdit = new UserOrgEdit;
			userOrgEdit.addEventListener(FlexEvent.CREATION_COMPLETE,onOrgEditCreated,false,EventPriority.DEFAULT_HANDLER,true);
   			
			editTitle = SgResourceManager.getSetString('SET_AUTH_038');//"用户";
			GlobalModel.getInstance().addEventListener(ModelEvent.A_U_SUCCESS,onInit,false,0,true);
		}
		
		//屏蔽双击
		override protected function onDoubleClick(event:MouseEvent):void{
			return;
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			if (null != dg)
			{
				this.addEventListener(OpRendererEvent.USER_EDIT_ORG ,onOrgModify,false,0,true);
			}
		}
		
		private function onOrgModify(e:OpRendererEvent):void{
			
			userOrgEdit.isAdd = false;
			popupOrgPanel();
			
			if (userOrgEdit.isCreationComplete)
			{
				if (dg.selectedItem is VOObject)
					userOrgEdit.onModifyItem((dg.selectedItem as VOObject).clone());
				else
					userOrgEdit.onModifyItem(dg.selectedItem);
			}
			
		}
		
		private function popupOrgPanel():void
		{
			userOrgEdit.title = SgResourceManager.getSetString('SET_AUTH_040');//resourceManager.getString(LocaleConst.PUBLIC,PropertiesConst.MODIFY) + "用户组织结构权限";
 			cmdManager.mainFrame.addDisplayObject(userOrgEdit);
		}
		
		private function onOrgEditCreated(e:FlexEvent):void{
			userOrgEdit.removeEventListener(FlexEvent.CREATION_COMPLETE,onOrgEditCreated);
			if (!userOrgEdit.isAdd)
			{
				if (dg.selectedItem is VOObject)
					userOrgEdit.onModifyItem((dg.selectedItem as VOObject).clone());
				else
					userOrgEdit.onModifyItem(dg.selectedItem);
			}
		}
		
		override public function onInit(event:Event=null):void
		{
			dg.dataProvider = GlobalModel.getInstance().authDao.getUserList();
			if (null != dg.dataProvider)
				(dg.dataProvider as ArrayCollection).filterFunction = userFilter;
		}
		
		/**
		 * 检测界面的权限状态 
		 */	
		override protected function checkAuth():void
		{
			auth_btnAdd = AuthUtil.checkAuth(AuthValueConst.USER_ADD);
			dg.invalidateDisplayList();
		}
		
		override protected function onComplete():void
		{
			dg.opDataProvider = cmdManager.resourceManager.getResources([CMDOpConst.USER_MODIFY , CMDOpConst.USER_ORG_MODIFY ,CMDOpConst.USER_DEL]);
		}
		
		/**
		 * 右键菜单
		 * @param cmdEvt.cmdID 命令ID
		 * @return 
		 */		
		override protected function menuItemClickHandler(cmdID:String):Boolean
		{
			switch(cmdID)
			{
				case "USER_ADD":
					onAdd(null);
					return true;
				case "USER_MODIFY":
					onModify(null);
					return true;
				case "USER_DEL":
					onDel(null);
					return true;
			}
			return false;
		}
		
		/**
		 * 获取右键的菜单
		 * @return 右键的菜单
		 */	
		override protected function getRightMenu():Array
		{
			var tmpArr:Array;
			if (AuthUtil.checkAuth(AuthValueConst.USER_ADD))  //是否拥有添加用户的权限
				tmpArr = cmdManager.resourceManager.getResources(['USER_ADD','USER_MODIFY','USER_DEL']);
			else
				tmpArr = cmdManager.resourceManager.getResources(['USER_MODIFY','USER_DEL']);
			if(dg.selectedItem==null)
			{
				tmpArr.pop();
				tmpArr.pop();
			}
			else
			{
				if(dg.selectedItem.name=="debug")
					tmpArr.pop();
			}
			return tmpArr;
		}
		
		override protected function onDelItem(item:Object):void
		{
			RPCManager.call(ServiceConst.DS_MAINHANDLER,"DelUser",item.id);
		}
		
		override protected function onUpdateDelResult(obj:Object):void
		{
			GlobalModel.getInstance().authDao.getUser();
		}
		
		private function userFilter(item:Object):Boolean
		{
			if (null == t_filter)
				return true;
			
			var tmpItem:User = item as User;
			
			var keyword:String = t_filter.text;
			if (keyword.length > 0)
			{
				try{
					
					var i:int = tmpItem.name.indexOf(keyword);
					if (i> -1)
						return true;
					//else
					//return false;
					if(tmpItem.username  &&  tmpItem.username.indexOf(keyword) >= 0)
						return true;
					
					if(tmpItem.company && tmpItem.company.length > 0){
						if(!isNaN(Number(tmpItem.company))){
							var org:IOrganization = GlobalModel.getInstance().getOrganizationById(tmpItem.company);
							if(org.name && org.name.indexOf(keyword) >= 0)
								return true;
						}else{
							if(tmpItem.company.indexOf(keyword) >= 0)
								return true;
						}
					}
					
					if(tmpItem.phoneInfo){
						for(var k in tmpItem.phoneInfo){
							var tk:String = String(k);
							if(tk.length == 12 &&  tk.substr(0,1) == "P" && !isNaN(Number(tk.substr(1,11))) && tk.indexOf(keyword) >= 0)
								return true;
						}
					}
					
				}catch(err:Error){
					//return false;
				}
				
 				
				return false
  				
			}
			else
			{
				return true;
			}
			return false;
		}
	}
}