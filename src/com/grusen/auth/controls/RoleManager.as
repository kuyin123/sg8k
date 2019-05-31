package com.grusen.auth.controls
{
	import com.grusen.auth.views.RoleDG;
	import com.grusen.auth.views.RoleEdit;
	import com.grusen.constants.AuthValueConst;
	import com.grusen.constants.CMDOpConst;
	import com.grusen.constants.LocaleExtendConst;
	import com.grusen.events.ModelEvent;
	import com.grusen.managers.SgResourceManager;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.XmlDao;
	import com.grusen.model.vo.Role;
	import com.grusen.model.vo.User;
	import com.grusen.services.ServiceConst;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	import mx.events.FlexEvent;
	
	import ppf.tool.auth.AuthConst;
	import ppf.tool.auth.AuthUtil;
	import ppf.tool.components.views.GrManager;
	import ppf.tool.rpc.managers.RPCManager;
	
	
	public final class RoleManager extends GrManager
	{
		public function RoleManager()
		{
			super();
			
			dg = new RoleDG;
			editPanel = new RoleEdit;
			editTitle = SgResourceManager.getSetString('SET_AUTH_037');//"角色";
			GlobalModel.getInstance().addEventListener(ModelEvent.A_R_SUCCESS,onInit,false,0,true);
			this.addEventListener("show",onModify,false,0,true);
		}
		
		override public function onInit(event:Event=null):void
		{
			dg.dataProvider = GlobalModel.getInstance().authDao.getRoleList();
			if (null != dg.dataProvider)
			{
				(dg.dataProvider as ArrayCollection).filterFunction = roleFilter;
				var arr:ArrayCollection=dg.dataProvider as ArrayCollection;
				//用户ID
				var uid:int=GlobalModel.getInstance().authDao.currUser.roleId;
				for each(var r:Role in arr)
				{
					if(r.id==uid)
					{
						curRole=r;
						break;
					}
				}
			}
		}
		
		/**
		 * 检测界面的权限状态 
		 */
		override protected function checkAuth():void
		{
			auth_btnAdd = AuthUtil.checkAuth(AuthValueConst.ROLE_ADD);
			dg.invalidateDisplayList();
		}
		
		override protected function onComplete():void
		{
			var arr:Array=getRoleAuthArray(false,false);
			dg.opDataProvider = cmdManager.resourceManager.getResources(arr);
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
				case "ROLE_ADD":
					onAdd(null);
					return true;
				case "ROLE_MODIFY":
					onModify(null);
					return true;
				case "ROLE_DEL":
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
			if(dg.selectedItem==null)  //如果选中任何一条，则只显示添加
			{
				if (AuthUtil.checkAuth(AuthValueConst.ROLE_ADD))
					tmpArr = cmdManager.resourceManager.getResources(['ROLE_ADD']);
			}
			else
			{
				tmpArr=getRoleAuthArray(GlobalModel.getInstance().authDao.currUser.roleId==dg.selectedItem.id
				,true);
				tmpArr = cmdManager.resourceManager.getResources(tmpArr);
			}
			return tmpArr;
		}
		
		override protected function onModify(event:Event=null):void
		{
			//双击可以进入
			//当双击时，
			var roleEdit:RoleEdit=editPanel as RoleEdit;
			if(AuthUtil.checkAuth(AuthValueConst.ROLE_ACCESS))
			{
				super.onModify(event);
				if(!AuthConst.isSuperAdmin)
				{
					roleEdit.editable=false;
					roleEdit.title=SgResourceManager.getSetString('SET_AUTH_039');
				}
			}
		}
		
		override protected function onDel(event:Event=null):void
		{
			//如果没有任何用户关联该角色，则删除该角色，否则显示提示“必须删除关联该角色的所有用户才能删除该角色”
			if(null==dg.selectedItem)
				return;
			var arr:ArrayCollection=GlobalModel.getInstance().authDao.getUserList();
			if(null==arr)
			{
				GlobalModel.getInstance().addEventListener(ModelEvent.A_U_SUCCESS,onUserLoaded,false,0,true);
				GlobalModel.getInstance().authDao.getUser();
			}
			else
				deleteRole(arr);
		}
		
		private function onUserLoaded(event:ModelEvent):void
		{
			GlobalModel.getInstance().removeEventListener(ModelEvent.A_U_SUCCESS,onUserLoaded);
			var arr:ArrayCollection=GlobalModel.getInstance().authDao.getUserList();	
			deleteRole(arr);
		}
		
		/**
		 *删除角色 
		 * @param userList 用户列表（所有角色的的用户）
		 */		
		private function deleteRole(userList:ArrayCollection):void
		{
			var r:Role=dg.selectedItem as Role;
			var hasUser:Boolean=false;//是否存在关联该角色的用户
			for each(var user:User in userList)
			{
				if(user.roleId==r.id)
				{
					hasUser=true;
					break;
				}
			}
			if(hasUser)
			{
				//必须删除关联该角色的所有用户才能删除该角色"
				Alert.show(SgResourceManager.getTipString('TIP_AUTH_019'),
					SgResourceManager.getString(LocaleExtendConst.PUBLIC,'PUBLIC_OP_010'));				
			}
			else
				super.onDel(null);
		}
		
		override protected function onDelItem(item:Object):void
		{
			RPCManager.call(ServiceConst.DS_MAINHANDLER,"DelRole",item.id);
		}
		override protected function onUpdateDelResult(obj:Object):void
		{
//			cmdManager.authDao.getRole();
			GlobalModel.getInstance().authDao.getRole();
		}
		
		private function roleFilter(item:Object):Boolean
		{
			if (null == t_filter)
				return true;
			
			var tmpItem:Role = item as Role;
			
			var keyword:String = t_filter.text;
			if (keyword.length > 0)
			{
				var i:int = tmpItem.name.indexOf(keyword);
				if (i> -1)
					return true;
				else
					return false;
			}
			else
			{
				return true;
			}
			return false;
		}
		
		/**
		 *获取 用户操作列表（添加，删除，修改） 
		 * @param self 是否为登录用户所属的角色
		 * @param rightMenu 是否为右键菜单项， 是：则显示“添加”，否不显示添加
		 * @return 
		 */		
		private function getRoleAuthArray(self:Boolean=false,useAdd:Boolean=false):Array
		{
			var arr:Array;
			if(AuthConst.isSuperAdmin)  //如果当前用户是Debug用户
			{
				if(self)
				{
					if(useAdd)
						arr=['ROLE_ADD','ROLE_MODIFY'];	
					else
						arr=['ROLE_MODIFY'];
				}
				else
				{
					if(useAdd)
						arr=['ROLE_ADD','ROLE_MODIFY','ROLE_DEL'];
					else
						arr=['ROLE_MODIFY','ROLE_DEL'];
				}
			}
			else
			{
				arr=[];
				if(AuthUtil.checkAuth(AuthValueConst.ROLE_ACCESS))
					arr.push('ROLE_ACCESS');
//				if(useAdd&&AuthUtil.checkAuth(AuthValueConst.ROLE_ADD))
//					arr.push('ROLE_ADD');
//				if(AuthUtil.checkAuth(AuthValueConst.ROLE_EDIT))
//					arr.push('ROLE_MODIFY');
//				if(AuthUtil.checkAuth(AuthValueConst.ROLE_DEL)&&!self)
//					arr.push('ROLE_DEL');
			}
			return arr;
		}
		
		private var curRole:Role; //当前角色
	}
}