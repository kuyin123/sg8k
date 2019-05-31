package com.grusen.auth.controls
{
	import com.grusen.auth.views.AuthDG;
	import com.grusen.auth.views.AuthEdit;
	import com.grusen.constants.CMDOpConst;
	import com.grusen.events.ModelEvent;
	import com.grusen.managers.SgResourceManager;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.vo.Auth;
	import com.grusen.services.ServiceConst;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.events.FlexEvent;
	
	import ppf.tool.components.views.GrManager;
	import ppf.tool.rpc.managers.RPCManager;
	
	
	public final class AuthManager extends GrManager
	{
		public function AuthManager()
		{
			super();
			dg = new AuthDG;
			editPanel = new AuthEdit;
			editTitle = SgResourceManager.getSetString('SET_AUTH_036');//"权限";
			GlobalModel.getInstance().addEventListener(ModelEvent.A_A_SUCCESS,onInit,false,0,true);
		}
		
		override public function onInit(event:Event=null):void
		{
			dg.dataProvider = GlobalModel.getInstance().authDao.getAuthList();
			if (null != dg.dataProvider)
				(dg.dataProvider as ArrayCollection).filterFunction = actionFilter;
		}
		
		/**
		 * 检测界面的权限状态 
		 */	
		override protected function checkAuth():void
		{
//			auth_btnAdd = AuthUtil.checkAuth(AuthValueConst.A_AUTH_ADD);
			dg.invalidateDisplayList();
		}
		
		override protected function onComplete():void
		{
			dg.opDataProvider = cmdManager.resourceManager.getResources([CMDOpConst.MODIFY,CMDOpConst.DEL]);
		}
		
		override protected function onDelItem(item:Object):void
		{
			RPCManager.call(ServiceConst.DS_MAINHANDLER,"DelAuth",item.id);
		}
		
		override protected function onUpdateDelResult(obj:Object):void
		{
//			cmdManager.authDao.getAuth();
			GlobalModel.getInstance().authDao.getAuth();
		}
		
		private function actionFilter(item:Object):Boolean
		{
			if (null == t_filter)
				return true;
			
			var tmpItem:Auth = item as Auth;
			
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
	}
}