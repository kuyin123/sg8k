package com.grusen.auth
{
	public final class AuthTypeConst
	{
		/**
		 * 0:访问1:管理2:访问+管理  
		 */		
		static public const TYPE_ACCESS:String = "0";
		/**
		 *  
		 */		
		static public const TYPE_MANAGER:String = "1";
		/**
		 *  
		 */		
		static public const TYPE_ACC_MANAGER:String = "2";
		
		static public const AUTH:int = 3000;
		public function AuthTypeConst()
		{
			throw new Error("AuthTypeConst类只是一个静态方法类!"); 
		}
	}
}