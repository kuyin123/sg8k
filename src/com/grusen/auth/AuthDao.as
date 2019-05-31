package com.grusen.auth
{
	import com.grusen.events.ModelEvent;
	import com.grusen.interfaces.IAuthDao;
	import com.grusen.model.vo.Auth;
	import com.grusen.model.vo.Role;
	import com.grusen.model.vo.User;
	import com.grusen.services.ServiceConst;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	import ppf.base.log.Logger;
	import ppf.base.math.XmlUtil;
	import ppf.base.resources.LoadManager;
	import ppf.tool.auth.AuthConst;
	import ppf.tool.auth.AuthUtil;
	import ppf.tool.rpc.managers.RPCManager;
	
	
	public final class AuthDao extends EventDispatcher implements IAuthDao
	{
		public function get currUserName():String
		{
			if (null != _currUser)
				return _currUser.name;
			return  "";
		}
		
		/**
		 * 获取当前用户姓名
		 */
		public function get currUserTrueName():String
		{
			if (null != _currUser)
				return _currUser.username;
			return  "";
		}
		
		/**
		 * 当前登录用户 
		 */
		public function get currUser():User
		{
			return _currUser;
		}
		
		/**
		 * @private
		 */
		public function set currUser(value:User):void
		{
			_currUser = value;
			if (null != value.valueList)
				currAuthIDList = value.valueList.source;
			if(value.roleLevel==AuthConst.DEBUG)
				AuthConst.isSuperAdmin = true;
			else if(value.roleLevel==AuthConst.ADMIN)
				AuthConst.isAdmin = true;
			
			this.disEvent(ModelEvent.CURRENT_USER_REFRESH);
		}
		
		/**
		 * 获取子系统角色过滤掉的权限值 
		 * @return 
		 */		
		public function get sysAuthArr():Array
		{
			return _sysAuthArr;
		}
		
		/**
		 * 权限值列表 
		 */
		public function get currAuthIDList():Array
		{
			return _currAuthIDList;
		}
		
		/**
		 * @private
		 */
		public function set currAuthIDList(arr:Array):void
		{
			_currAuthIDList = arr;
			
			AuthConst.isSuperAdmin = false;
			AuthUtil.setAuthList(new ArrayCollection( arr ));
			
			//			AuthConst.isAdmin = false;
			//			for each (var value:int in _currAuthIDList)
			//			{
			//				if (value == AuthConst.ADMIN)
			//				{
			//					AuthConst.isAdmin = true;
			//				}
			//				else if (value == AuthConst.DEBUG)
			//				{
			//					AuthConst.isDebug = true;
			//				}
			//			}
		}
		
		/**
		 * 当前登录用户id 
		 */
		public function get currUserID():int
		{
			return currUser.id;
		}
		
		/**
		 * 权限所有数据都获取完成 
		 * @return 
		 * 
		 */		
		public function get authIsReady():Boolean
		{
			if (_authIsReady && _roleIsReady && _userIsReady)
				return true;
			
			return false;
		}
		
		/**
		 * 重新获取所有的权限数据 
		 * 
		 */		
		public function reLoadAllAuth():void
		{
			_isRecalculateAuth = true;
			getUser();
			getRole();
			getAuth();
		}
		
		/**
		 * 重新获取角色数据 
		 * 
		 */		
		public function reLoadRole():void
		{
			_isRecalculateAuth = true;
			getRole();
		}
		/**
		 * 重新获取权限值数据  
		 * 
		 */		
		public function reLoadAuth():void
		{
			_authList = null;
			getAuth();
		}
		/**
		 * 重新获取用户数据  
		 * 
		 */		
		public function reLoadUser():void
		{
			_isRecalculateAuth = true;
			getUser();
		}
		/**
		 * 获取角色列表 
		 * @return 
		 * 
		 */	
		public function getRoleList():ArrayCollection
		{
			if (null == _roleList)
			{
				getRole();
				getAuthList();
				return null;
			}
			return new ArrayCollection(_roleList.source);
		}
		/**
		 * 获取用户列表
		 * @param isRefresh 是否强制刷新获取 
		 * @return 
		 * 
		 */	
		public function getUserList(isRefresh:Boolean=false):ArrayCollection
		{
			if (null == _userList || isRefresh)
			{
				getUser();
				getRoleList();
				return null;
			}
			return new ArrayCollection(_userList.source);
		}
		
		/**
		 * 获取角色的权限值列表 
		 * @param idList 角色的权限值id列表
		 * @return 角色的权限值列表 
		 * 
		 */		
		public function getRoleAuthList(idList:Array):ArrayCollection
		{
			var tmpArr:ArrayCollection = new ArrayCollection;
			
			for each (var id:int in idList)
			{
				for each (var auth:Auth in _authList)
				{
					//					if (id == auth.id)
					if (id == auth.value)
					{
						tmpArr.addItem(auth);
						break;
					}
				}
			}
			return tmpArr;
		}
		
		/**
		 * 根据角色获取权限列表  
		 * @param roleId 角色id 0：所有
		 * @param func 
		 * @return 
		 * 
		 */		
		//		public function getAuthList():ArrayCollection
		//		{
		//			if (null == _authList)
		//			{
		//				getAuth();
		//				return null;
		//			}
		//			
		//			return new ArrayCollection(_authList.source);
		//		}
		
		/**
		 * 获取角色使用的权限数据  
		 * @param idList 角色的权限值id列表
		 * 
		 */		
		public function getAuthList(idList:Array=null):ArrayCollection
		{
			if (null == _authDataProvider)
			{
				LoadManager.loadXML("authList.xml", ServiceConst.SVN_VERSION, assetLoaderHandler,true);
			}
			
			var tmpArr:ArrayCollection = ObjectUtil.copy(_authDataProvider) as ArrayCollection;
			
			if(tmpArr && ServiceConst.SYSTEM_TYPE != ServiceConst.TS8000){
				//不是试车台系统则在权限列表中不能看到试车权限
				for (var i:int=0;i<tmpArr.length;i++){
					var qObj:Object  =  tmpArr.getItemAt(i);
					if(qObj && qObj.actionID == "90000" && qObj.label == "试车模块"){
						tmpArr.removeItemAt(i);
						break;
					}
				}
			}
			
			if (null != idList)
			{
				//				var authIDList:ArrayCollection = getRoleAuthList(idList);
				//				setAuthState(tmpArr,authIDList);
				setAuthState(tmpArr,idList);
				setSysAuth(idList);
			}
			else
				setAuthState(tmpArr,null);
			
			return tmpArr;
		}
		
		/**
		 * 获取权限Auth列表
		 * @param func 自定义返回函数
		 * @param roleId 角色id 0：所有
		 * 
		 */		
		public function getAuth(roleId:int=0):void
		{
			if (!_called_A)
			{
				Logger.debug("getAuth "+new Date);
				_authIsReady = false;
				_called_A = true;
				RPCManager.caller.onResult = onAuthResult;
				RPCManager.call(ServiceConst.DS_GET_SETUP,"GetAuthList");
			}
		}
		
		/**
		 * 获取用户列表 
		 * 
		 */		
		public function getUser():void
		{
			if (!_called_U)
			{
				Logger.debug("getUser "+new Date);
				_userIsReady = false;
				_called_U = true;
				RPCManager.caller.onResult = onUserResult;
				RPCManager.call(ServiceConst.DS_GET_SETUP,"GetUserList");
			}
		}
		
		/**
		 * 获取角色列表 
		 * 
		 */		
		public function getRole():void
		{
			if (!_called_R)
			{
				Logger.debug("getRole "+new Date);
				_roleIsReady = false;
				_called_R = true;
				RPCManager.caller.onResult = onRoleResult;
				RPCManager.call(ServiceConst.DS_GET_SETUP,"GetRoleList");
			}
		}
		
		/**
		 * 检查是否重复用户名 
		 * @param name
		 * @return true:不重复 false重复
		 * 
		 */		
		public function checkUserName(name:String):Boolean
		{
			for each (var user:User in _userList)
			{
				if (user.name == name)
					return false;
			}
			
			if (!AuthConst.isSuperAdmin)
			{
				name = name.toLowerCase();
				
				if (name == "admin" || name == "debug" || name == "grusen" || name == "格鲁森")
				{
					return false;
				}
			}
			
			return true;
		}
		
		public function AuthDao(target:IEventDispatcher=null)
		{
			super(target);
		}
		
		/**
		 * 用户成功获取处理函数 
		 * @param event ResultEvent
		 * 
		 */	
		private function onUserResult(event:ResultEvent):void
		{
			Logger.debug("onUserResult"+new Date);
			
			if(event.result)
			{
				_userList =new ArrayCollection( event.result as Array);
			}
			
			_userIsReady = true;
			_debugIsFormat_U = false;
			_called_U = false;
			//格式化用户把角色名加入 
			formatUser();
			//格式化当前登录用户的权限id列表 
			formatAuthID();
			
			
			if(_currUser){
				for each(var user:User  in _userList){
					if(user.id  == _currUser.id){
						currUser = User(user.clone());
						break;
					}
				}
			}
		}
		
		/**
		 * 角色成功获取处理函数 
		 * @param event ResultEvent
		 * 
		 */		
		private function onRoleResult(event:ResultEvent):void
		{
			Logger.debug("onRoleResult"+new Date);
			
			if(event.result)
				_roleList=new ArrayCollection(event.result as Array);
			
			_roleIsReady = true;
			_debugIsFormat_R = false;
			_called_R = false;
			//格式化用户把角色名加入 
			formatUser();
			//格式化当前登录用户的权限id列表 
			formatAuthID();
			//去除非debug用户的数据
			formatDebug();
		
			
			
			disEvent(ModelEvent.A_R_SUCCESS);
		}
		
		/**
		 * 权限成功获取处理函数 
		 * @param event ResultEvent
		 * 
		 */	
		private function onAuthResult(event:ResultEvent):void
		{
			Logger.debug("onAuthResult"+new Date);
			_authList = event.result as ArrayCollection;
			
			_authIsReady = true;
			_debugIsFormat_A = false;
			_called_A = false;
			//格式化当前登录用户的权限id列表 
			formatAuthID();
			//格式化角色使用的权限数据
			formatAuth();
			//去除非debug用户的数据
			formatDebug();
			
			disEvent(ModelEvent.A_A_SUCCESS);
		}
		
		/**
		 * 统一发送 
		 * @param type 事件的类型
		 * 
		 */		
		private function disEvent(type:String,ids:Object=null):void
		{
			var evt:ModelEvent = new ModelEvent(ModelEvent.A_SUCCESS);
			evt.ids = type;
			this.dispatchEvent(evt);
		}
		
		/**
		 * 格式化当前登录用户的权限id列表 
		 * 
		 */		
		private function formatAuthID():void
		{
			if (_isRecalculateAuth && authIsReady)
			{
				formatCurrAuth();
				_isRecalculateAuth = false;
			}
				//需要重新计算，但是数据不足
			else if (_isRecalculateAuth)
			{
				if (!_roleIsReady)
					reLoadRole();
				if (!_authIsReady)
					reLoadAuth();
				if (!_userIsReady)
					reLoadUser();
			}
		}
		/**
		 * 格式化用户把角色名加入 
		 * 
		 */		
		private function formatUser():void
		{
			if (_userIsReady && _roleIsReady)
			{
				for each (var user:User in _userList)
				{
					for each (var role:Role in _roleList)
					{
						if (user.roleId == role.id)
						{
							user.roleName = role.name;
							break;
						}
					}
				}
				//去除非debug用户的数据
				formatDebug();
				
				disEvent(ModelEvent.A_U_SUCCESS);
			}
		}
		/**
		 * 格式化当前登录用户的权限id列表 
		 * 
		 */		
		private function formatCurrAuth():void
		{
			var tmpArr:Array = [];
			//找到当前用户的角色
			for each (var user:User in _userList)
			{
				if (user.id == currUserID)
				{
					currUser.roleId = user.roleId;
					break;
				}
			}
			//找到当前用户角色关联的权限id列表
			//			var _authIDList:Array;
			for each (var role:Role in _roleList)
			{
				if (role.id == currUser.roleId)
				{
					//					_authIDList = role.authList.source;
					//					currAuthIDList = role.authList.source;
					break;
				}
			}
			//根据权限id列表，格式化权限值列表
			//			if (null != _authIDList && _authIDList.length != 0)
			//			{
			//				for each (var value:int in _authIDList)
			//				{
			//					for each (var auth:Auth in _authList)
			//					{
			//						if (auth.id == value)
			//						{
			//							tmpArr.push(auth.value);
			//							break;
			//						}
			//					}
			//				}
			//			}
			
			//			currAuthIDList = tmpArr;
			
			//			disEvent(ModelEvent.AllAUTHREADY);
		}
		
		/**
		 * 获取角色使用的权限数据源成功处理函数
		 * @param obj
		 * 
		 */		
		private function assetLoaderHandler(obj:Object):void
		{
			_authDataProvider = XmlUtil.xml2ArrayCollection(XML(obj.asset));
			_authIsReady = true;
			
			//不是debug用户过滤掉一些权限值选项
			if (!AuthConst.isSuperAdmin)
			{
				var delArr:Array=[];
				for each (var item:Object in _authDataProvider)
				{
					if (item.hasOwnProperty("constrainState"))
					{
						if ("0" == item.authState.toString())
						{
							delArr.push(item);
							//							sysAuthDict(item);
						}
					}
					
					//过滤掉权限管理
					//					else if (AuthUnit.AUTH.toString() == item.value_0)
					//					{
					//						for each (var item2:Object in item.children)
					//						{
					//							if (AuthUnit.A_ACTION_ACCESS.toString() == item2.value_0)
					//								(item.children as ArrayCollection).removeItemAt((item.children as ArrayCollection).getItemIndex(item2));
					//						}
					//					}
				}
				for each (var delItem:Object in delArr)
				{
					_authDataProvider.removeItemAt(_authDataProvider.getItemIndex(delItem));
				}
			}
			//设置id和未选中状态
			formatAuth();
		}
		
		/**
		 * 格式化角色使用的权限数据
		 * 初始化设置角色使用的权限树数据的id和containState为未选中 
		 * 
		 */		
		private function formatAuth():void
		{
			if (_authIsReady && _authIsReady)
			{
				//				setAuthID(_authDataProvider);
				//				disEvent(ModelEvent.AUTHSUCCESS);
			}
		}
		
		/**
		 * 初始化设置角色使用的权限树数据的id和containState为未选中
		 * @param arr 权限的数据数组
		 */	
		//		private function setAuthID(arr:ArrayCollection):void
		//		{
		//			for each (var item:Object in arr)
		//			{
		//				item.containState = -1;
		//				var id:int = int(item.value_0);
		//				var id2:int = -1;
		//				if (item.hasOwnProperty("value_1"))
		//				{
		//					id2 = int(item.value_1);
		//				}
		//				for each (var auth:Auth in _authList)
		//				{
		//					if (auth.value == id)
		//					{
		//						item.id_0 = auth.id;
		//						continue;
		//					}
		//					if (auth.value == id2)
		//					{
		//						item.id_1 = auth.id;
		//						continue;
		//					}
		//				}
		//				if (null != item.children)
		//					setAuthID(item.children);
		//			}
		//		}
		
		/**
		 * 设置权限的选中状态
		 * @param arr 权限的数据数组
		 * @param authIDList 权限值列表
		 */		
		private function setAuthState(arr:ArrayCollection,authIDList:Array):void
		{
			//item:大模块    例如：常规图谱                     10000
			//sub:具体模块 例如：波形频谱图                  10200
			//subSub：具体权限 ：例如 波形频谱图访问 10201
			if(null==authIDList||authIDList.length==0)
				return;
			
			var isDebug:Boolean=false;
			if(authIDList[0]=="-1")  //表示debug用户
				isDebug=true;
			var sub:Object;
			var subSub:Object;
			var subCnt:int;
			var ssubCnt:int;
			for each (var item:Object in arr)
			{
				subCnt=0;
				for each(sub in item.children)
				{
					ssubCnt=0;
					for each(subSub in sub.children)
					{
						if(isDebug||authIDList.indexOf(subSub.actionID)!=-1)
						{
							subSub.containState=1;
							ssubCnt++;
						}
					}
					
					if(isDebug|| (sub.children != null && ssubCnt==sub.children.length))
					{
						sub.containState=1;
						subCnt++;
					}
					else if(ssubCnt==0)
						sub.containState=0;
					else
						sub.containState=2; //选中部分
				}
				if(isDebug||subCnt==item.children.length||isDebug)
					item.containState=1;
				else if(subCnt==0)
				{
					var arr:ArrayCollection =  item.children as ArrayCollection;
					var hasSelected:Boolean = false;
					for (var i:int = 0; i <arr.length; i++) 
					{
						if(arr.getItemAt(i).containState == 2)
						{
							hasSelected = true;
							break;
						}
					}
					if(hasSelected)
						item.containState=2;
					else
						
						item.containState=0;
				}
					
				else
					item.containState=2;					
			}
		}
		
		//		/**
		//		 * 设置不同子系统时，角色已存在权限值，在不同系统中已经从权限树数据中过滤的权限值查询字典
		//		 */		
		//		private function sysAuthDict(item:Object):void
		//		{
		//			if (item.hasOwnProperty("value_0"))
		//				_sysAuthDict[item.value_0] = item.value_0;
		//			
		//			if (item.hasOwnProperty("value_1"))
		//				_sysAuthDict[item.value_1] = item.value_1;
		//			
		//			if (null != item.children)
		//			{
		//				for each (var child:Object in item.children)
		//				{
		//					sysAuthDict(child);
		//				}
		//			}
		//		}
		
		/**
		 * 设置不同子系统时，角色已存在权限值，在不同系统中已经从权限树数据中过滤，
		 * 所以需要备份一下用于修改角色权限列表时再次加入。
		 * @param authIDList
		 * 
		 */		
		private function setSysAuth(authIDList:Array):void
		{
			_sysAuthArr = [];
			for each (var value:int in authIDList)
			{
				//如果角色有的权限值在权限树数据过滤，则加入
				if (null != _sysAuthDict[value])
					_sysAuthArr.push(value);
			}
		}
		/**
		 * 格式化非debug用户的数据源,去除不需要的显示
		 * 
		 */		
		private function formatDebug():void
		{
			if (!AuthConst.isSuperAdmin)
			{
				if (_authIsReady && !_debugIsFormat_A)
				{
					_debugIsFormat_A = true;
					var delArr_A:Array=[];
					for each (var authItem:Auth in _authList)
					{
						//删除掉权限数据，不显示
						if (authItem.value < 0)
						{
							delArr_A.push(authItem);
						}
					}
					for each (var delItem_A:Object in delArr_A)
					{
						_authList.removeItemAt(_authList.getItemIndex(delItem_A));
					}
				}
				
				if (_roleIsReady && !_debugIsFormat_R)
				{
					_debugIsFormat_R = true;
					for each (var roleItem:Role in _roleList)
					{
						if (roleItem.name == DEBUG)
						{
							_roleList.removeItemAt(_roleList.getItemIndex(roleItem));
							break;
						}
					}
				}
				if (_userIsReady && _roleIsReady && !_debugIsFormat_U)
				{
					_debugIsFormat_U = true;
					var delArr_U:Array=[];
					for each (var userItem:User in _userList)
					{
						if (userItem.roleName == DEBUG || userItem.name == DEBUG)
						{
							delArr_U.push(userItem);
						}
					}
					for each (var delItem_U:Object in delArr_U)
					{
						_userList.removeItemAt(_userList.getItemIndex(delItem_U));
					}
				}
			}
		}
		
		/**
		 * 权限列表是否获取 true：已获取 false：未获取
		 */		
		private var _authIsReady:Boolean  = false;
		/**
		 * 用户列表是否获取 true：已获取 false：未获取
		 */	
		private var _userIsReady:Boolean = false;
		/**
		 * 角色列表是否获取 true：已获取 false：未获取
		 */	
		private var _roleIsReady:Boolean = false;
		
		/**
		 * 是否计算权限 true：计算 false：不计算 
		 */		
		private var _isRecalculateAuth:Boolean = false;
		
		/**
		 * 角色使用的权限树数据是否获取 true：已获取 false：未获取
		 */			
		//		private var _authIsReady:Boolean = false;
		
		/**
		 * 是否调用获取权限请求  true：是 false：不是
		 */		
		private var _called_A:Boolean = false;
		/**
		 * 是否调用获取角色请求  true：是 false：不是
		 */		
		private var _called_R:Boolean = false;
		/**
		 * 是否调用获取用户请求  true：是 false：不是
		 */
		private var _called_U:Boolean = false;
		/**
		 * 权限列表
		 */
		private var _authList:ArrayCollection;
		/**
		 * 权限值列表
		 */
		private var _authIDList:Object={};
		/**
		 * 用户列表 
		 */		
		private var _userList:ArrayCollection;
		/**
		 * 角色列表 
		 */		
		private var _roleList:ArrayCollection;
		
		/**
		 * 权限值列表 
		 */		
		private var _currAuthIDList:Array;
		/**
		 * 角色使用的权限树数据
		 */		
		private var _authDataProvider:ArrayCollection;
		
		/**
		 * 不同子系统过滤的权限树数据
		 */		
		private var _sysAuthDict:Dictionary = new Dictionary(true);
		
		/**
		 * 不同子系统角色过滤的权限树数据
		 */		
		private var _sysAuthArr:Array;
		
		/**
		 * debug 的用户名
		 */		
		private const DEBUG:String = "debug";
		/**
		 * 权限是否过滤debug信息 
		 */		
		private var _debugIsFormat_A:Boolean = false;
		/**
		 * 角色是否过滤debug信息  
		 */		
		private var _debugIsFormat_R:Boolean = false;
		/**
		 * 用户是否过滤debug信息  
		 */	
		private var _debugIsFormat_U:Boolean = false;
		private var _currUser:User;
	}
}