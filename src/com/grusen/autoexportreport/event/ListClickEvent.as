package com.grusen.autoexportreport.event
{
	import flash.events.Event;
	
	public class ListClickEvent extends Event
	{
		public var param:Object;
		
		public function ListClickEvent(type:String, param:Object ) {
			super(type, true);
			this.param = param;
		}
		
		override public function clone():Event {
			return new ListClickEvent( type, param );
		}
	}
}