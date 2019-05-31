function util()
{
	this.getversion = function(url)
	{
		var xmlDoc = null;
		url += "?"+Math.random();
		try
		{
			xmlDoc = new ActiveXObject("Microsoft.XMLDOM");
			xmlDoc.async = false;
			xmlDoc.load(url);
		}
		catch(e)
		{
			try
			{
				xmlDoc = document.implementation.createDocument("", "", null);
				xmlDoc.async = false;
				xmlDoc.load(url);
			}
			catch(e)
			{
				try
				{
					var xmlhttp = new XMLHttpRequest();
					xmlhttp.open("GET", url, false);
					xmlhttp.send(null);
					if (xmlhttp.status == 200)
					{
						xmlDoc = xmlhttp.responseXML;
					}
				}
				catch(e)
				{
					alert(e.message);
					xmlDoc = null;
				}
			}
		}
		if(xmlDoc != null)
		{
			/*
			 * 获取version属性节点
			 */
			/*var debug = xmlDoc.getElementsByTagName("debug")[0].attributes[0].nodeValue;
			var bDebug = false;
			if(debug == 1)
				bDebug = true;
			if(bDebug)
				return "";*/
			var ver = xmlDoc.getElementsByTagName("version")[0].attributes[0].nodeValue;
			
			if(ver != undefined && ver != null)
			{
				var str = new String(ver);
				var arr = str.split(".");
				if(arr == null || arr.length == 0)
					return "";
				str = new String(arr[arr.length - 1]);
				return str;
			}
		}
		return "";
	};
}