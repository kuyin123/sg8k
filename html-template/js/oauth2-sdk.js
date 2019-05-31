//用于OAUTH认证的客户端ID
var SGCK_OAUTH_CLIENT_ID = 'sg8k';
//用于OAUTH认证的客户端密码
var SGCK_OAUTH_CLIENT_SECRET = '';
//认证服务器服务名
var SGCK_OAUTH_AUTH_SERVER = 'authserver';

var SGCK_LOGOUT_SERVER = 'sgck_web';
var IS_DEBUG = true;
var sidStr1 = '0c0c8870f57db695cbf3f122c0aa872b';
var DEBUG_NAME = 'admin';
if(IS_DEBUG){
	SGCK_SET_COOKIES('sgSid' , sidStr1 , 90);
}

// 检验SID有效性
//function SGCK_CHECK_SID() {
//
//	var sid = SGCK_GET_COOKIES('SG_SID');
//	if (!sid)
//		return "{\"success\":0}";
//
//	$.ajax({
//		type : "get" , 
//		url : "../" + SGCK_OAUTH_AUTH_SERVER + "/check?" + (new UUID()).createUUID(),
//		async : false ,
//		data : {
//			sid : sid
//		},
//		dataType : "json",
//		success : function(data) {
//			if ( data && typeof(data.success) != "undefined" &&  data.success == 1) {
//				return "{\"success\":1}";
//			} else {
//				return "{\"success\":0}";
//			}
//		},
//		error : function() {
//			return "{\"success\":0}";
//		}
//	});
//
//}

// 登录
//function SGCK_LOGIN(username , password , isrem){
//	
//	if(!username  || !password)
//		return null;
//	
//	$.ajax({
//		type : "post",
//		url : "../" + SGCK_OAUTH_AUTH_SERVER + "/oauth/token?" + (new UUID()).createUUID(),
//		async : false,
//		data : {
//			username : username,
//			password : password,
//			grant_type : 'password',
//			client_id : SGCK_OAUTH_CLIENT_ID
// 		},
// 		beforeSend : function(xhr){
// 			xhr.setRequestHeader("Accept-Charset", "utf-8");
// 			xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
// 			xhr.setRequestHeader("accept", "*/*");
// 			xhr.setRequestHeader("connection", "Keep-Alive");
// 			xhr.setRequestHeader("Authorization", "Basic " + base64_encode(SGCK_OAUTH_CLIENT_ID + ":"));
// 		},
//		dataType : "json",
//		success : function(data) {
//			if ( data   &&  data.access_token) {
//				if(isrem){
//					SGCK_SET_COOKIES("SG_TOKEN" , data.access_token , 90);
// 				}
//				SGCK_SET_COOKIES("SG_REMEMBER_USER" , (isrem? 1 : 0) , 90);
//				// 通过token获取用户信息
//				var uinfos = SGCK_GET_USER_BY_TOKEN(data.access_token);
//				if(uinfos  &&  uinfos.sid){
//					SGCK_SET_COOKIES("SG_SID" , uinfos.sid , 1);
//					return uinfos.toString();
//				}
//			} 
//		},
//		error : function() {
//		}
//	});
//	return null;
//}

 

//function SGCK_GET_USER_BY_SID(){
//
//	var sid = SGCK_GET_COOKIES_BY_NAME('SG_SID');
//	if (!sid || sid == "")
//	   sid = SGCK_GET_COOKIES_BY_NAME('sgSid');
//	if (!sid || sid == "")
//		return "{\"sid\":''}";
//	
//	$.ajax({
//		type : "post",
//		url : "../" + SGCK_OAUTH_AUTH_SERVER + "/userinfo?" + (new UUID()).createUUID(),
//		async : false,
//		data : {
//			sid : sid
// 		},
//		//dataType : "json",
//		success : function(data) {
//		    var restr = data.toString();
//			return restr;
//		},
//		error : function() {
//			return "{\"sid\":''}";
//		}
//	});
//		
//}

// 通过TOKEN获取SID及用户信息 del
//function SGCK_GET_USER_BY_TOKEN(token){
//	if(!token)
//		return null;
//	
//	$.ajax({
//		type : "post",
//		url : "../" + SGCK_OAUTH_AUTH_SERVER + "/userinfo?" + (new UUID()).createUUID(),
//		async : false,
//		data : {
//			access_token : token
// 		},
//		dataType : "json",
//		success : function(data) {
//			if(data && data.sid)
//			   SGCK_SET_COOKIES("SG_SID" , data.sid , 1);
//			return data;
//		},
//		error : function() {
//			return null;
//		}
//	});
//	
// }

// 登出
function SGCK_LOGOUT(){
	SGCK_REMOVE_COOKIES("sgSid");
	SGCK_REMOVE_COOKIES("SG_REMEMBER_USER");
//	SGCK_REMOVE_COOKIES("SG_TOKEN");
	
//	SGCK_REMOVE_COOKIES("uname");
	window.location.href = "../" + SGCK_LOGOUT_SERVER + "/sgck_logout_from_authserver_handle?";
	
	
	
	
	
}

// 获取COOKIES
function SGCK_GET_COOKIES(cookiesname) {
	var arr, reg = new RegExp("(^| )" + name + "=([^;]*)(;|$)");
	if (arr = document.cookie.match(reg))
		return unescape(arr[2]);
	else 
		return null;
}

function SGCK_GET_COOKIES_BY_NAME(cn){
    var arrstr = document.cookie.split(";");
    for(var i=0;i<arrstr.length;i++){
       var tep = arrstr[i].split("="); 
       if(tep[0].replace(/^\s+|\s+$/g,"") == cn)
          return tep[1];
    }
    return null;
}

// 设置COOKIES
function SGCK_SET_COOKIES(cookiesname , cookiesvalue , exdays) {
	var d = new Date();
    d.setTime(d.getTime() + (exdays*24*60*60*1000));
    var expires = "expires=" + d.toUTCString();
    document.cookie = cookiesname + "=" + cookiesvalue + "; " + expires + ";path=/";
}

// 删除COOKIES
//function SGCK_REMOVE_COOKIES(cookiesname){
	//SGCK_SET_COOKIES(cookiesname , '' , -1);
//}

function SGCK_REMOVE_COOKIES(cookiesname)
{
  var exp = new Date();
  exp.setTime(exp.getTime() - 1);
  var cval=getCookie(cookiesname);
  if(cval!=null)
  document.cookie= cookiesname + "="+cval+";expires="+exp.toGMTString();
}



 