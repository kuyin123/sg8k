package com.grusen.autoexportreport.control
{
	import com.grusen.autoexportreport.view.SnapshotGroupView;
	import com.grusen.charts.SGChart;
	import com.grusen.charts.aixsposition.AixsPosInfoView;
	import com.grusen.charts.aixsposition.AsPosView;
	import com.grusen.charts.aixsposition.AscheProvider;
	import com.grusen.charts.bode.BodeInfoView;
	import com.grusen.charts.bode.BodeProvider;
	import com.grusen.charts.bode.BodeViewB;
	import com.grusen.charts.bode.BodeViewT;
	import com.grusen.charts.selector.DataTypeSelectorView;
	import com.grusen.charts.trend.TrendChartUI;
	import com.grusen.charts.trend.TrendDataSelector;
	import com.grusen.charts.trend.TrendProvider;
	import com.grusen.charts.trend.TrendView;
	import com.grusen.charts.wave.SpectrumView;
	import com.grusen.charts.wave.WaveProvider;
	import com.grusen.charts.wave.WaveSpectrumInfoView;
	import com.grusen.charts.wave.WaveView;
	import com.grusen.constants.ChartConst;
	import com.grusen.constants.ChartViewConst;
	import com.grusen.constants.DataTypeConst;
	import com.grusen.events.DataBridgeEvent;
	import com.grusen.events.EventBridge;
	import com.grusen.interfaces.IPosition;
	import com.grusen.model.GlobalModel;
	import com.grusen.model.vo.PChartItem;
	import com.grusen.model.vo.Position;
	import com.grusen.overview.OverViewContainer;
	import com.grusen.overview.OverViewTip;
	import com.grusen.overview.OverViews;
	import com.grusen.services.ServiceConst;
	import com.grusen.utils.ConstUtil;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.geom.Matrix;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.collections.ArrayCollection;
	import mx.core.IVisualElement;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import ppf.base.frame.ChartEvent;
	import ppf.base.log.Logger;
	import ppf.tool.rpc.RPCHelper;

	public class SnapshotGroupAs extends SnapshotGroupView
	{
		private var _currentAltasType:int = -1;  
		private var _lastAltasType:int = -1;
		private var _overviewSnapshotTimeout:uint;
		private var _aixsSnapshotTimeout:uint;
		private var _bodeSnapshotTimeout:uint;
		//是否已经进行快照了，单个图谱只能一次快照
		private var _isSnapshot:Boolean = false;
		
		public function SnapshotGroupAs()
		{
			super();
		}
		
		override protected function hgroup1_creationCompleteHandler(event:FlexEvent):void
		{
			//创建一个图谱
			EventBridge.getInstance().addEventListener(DataBridgeEvent.INIT_ATLAS, onInitAltas);
			//执行快照
			EventBridge.getInstance().addEventListener(DataBridgeEvent.SNAPSHOT, onSnapshot);
			//取消快照
			EventBridge.getInstance().addEventListener(DataBridgeEvent.CANCEL_SNAPSHOT, onCancelSnapshot);
			
		}
		//初始化一个新的图谱进行截图
		private function onInitAltas(e:DataBridgeEvent):void
		{
//			trace(">>>>>> 初始化一个新的图谱进行截图" );
			var par:Object=e.param;
			clearTimeout( _overviewSnapshotTimeout );
			//新图谱初始化可以进行快照
			_isSnapshot = false;
			
			_lastAltasType = _currentAltasType;
			if(_currentAltasType != par.atlasType || _currentAltasType == ChartConst.OVERVIEW  || _currentAltasType == ChartConst.WAVE){
				clearAltas();
				rightArea.includeInLayout = true;
				_currentAltasType = par.atlasType;
			}
			var plist:Array =  par.nodeList as Array;
			
			switch (par.atlasType){
				
				case ChartConst.OVERVIEW:
					
					
					var macId:String = par.macId;
					var overview:OverViews = new OverViews;
//					overview.needGetRTValue = false;
					overview.nodeId = macId;
					overview.nodeTypeStr = ConstUtil.TYPE_MACHINE ;
					if(plist && plist.length > 0){
						overview.initOverviewId  =  int( plist[0].id );
					}
					
					rightArea.includeInLayout = false;
					overview.percentWidth = 100;
					overview.percentHeight = 100;
					leftArea.addElement(overview);
					
					overview.addEventListener("hasAddComplete"  ,  onOverviewHasAddComplete ,  false , 0 , true);
//					overview.addEventListener("hasGetRTData"  ,  onOverviewGetRTData ,  false , 0 , true);
					break;
				
				case ChartConst.WAVE:
					
					var chart1:SGChart = new SGChart;
					chart1.chartProvider = new WaveProvider;
					WaveProvider(chart1.chartProvider).isGetNearestWave  = true;
					WaveProvider(chart1.chartProvider).isNearestAfter = false;
					
					chart1.chartProvider.tipClassPath = "com.grusen.charts.views.ChartTip";
					//chart1.dragFilterFun=dragFilterFun; //过滤掉机组
					
					var cv_wave:WaveView = new WaveView;
					cv_wave.type = ChartViewConst.WAVE;
					cv_wave.drawerClass = com.grusen.charts.wave.WaveDrawer1;
					cv_wave.percentHeight = 100;
					cv_wave.percentWidth = 100;
					
					var cv_spectrum:SpectrumView = new SpectrumView;
					cv_spectrum.type = ChartViewConst.SPECTRUM;
					cv_spectrum.percentHeight = 100;
					cv_spectrum.percentWidth = 100;
					
					chart1.addDisplayObject(cv_wave); //添加波形图和频谱图view
					chart1.addDisplayObject(cv_spectrum);
					var righttab:WaveSpectrumInfoView = new WaveSpectrumInfoView;
					righttab.percentWidth = 100;
					righttab.initTabIndex = 1;
					righttab.init(chart1, cv_spectrum, cv_wave);
					
					
					chart1.chartProvider.initUpdate(plist);
					
					chart1.addEventListener(FlexEvent.CREATION_COMPLETE  ,  onTrendViewCreateComplete , false , 0 , true);
					
					leftArea.addElement(chart1);
					rightArea.addElement(righttab);
					break;
				
				case ChartConst.TREND_PP_CURRENT_VALUE:
				case ChartConst.TREND_HALF_X:
				case ChartConst.TREND_1_X:
				case ChartConst.TREND_2_X:
				case ChartConst.TREND_GAP:
					//if(_lastAltasType == par.atlasType){
					//clearCurrentItem();
					//initCurrentAtlasItem(plist);			
					//}else{
					var chart2:TrendChartUI=new TrendChartUI;
					chart2.cv_trend.isExportReport = true;
					chart2.cv_trend.exportTrendType = par.atlasType;
					var trendProvider:TrendProvider =new TrendProvider();
					chart2.chartProvider = trendProvider;
					//chart2.cv_trend.chartProvider = trendProvider;
					
					if(trendProvider._hasTimer){
						trendProvider.stopTimer();
					}
					
					var selector:TrendDataSelector = new TrendDataSelector;
					selector.percentWidth = 100;
					selector.chartProvider = trendProvider;
					
					if(plist && plist.length>0){
						selector.initDateSelector( PChartItem(plist[0]).startDate  ,   PChartItem(plist[0]).endDate);
					}
					
					chart2.trendSelector = selector;
					chart2.initCreateWithoutIndex();
					chart2.chartProvider.initUpdate(plist);
					//chart2.dragFilterFun=dragFilterFun; //过滤掉机组
					
					chart2.addEventListener(FlexEvent.CREATION_COMPLETE  ,  onTrendViewCreateComplete , false , 0 , true);
					
					leftArea.addElement(chart2);
					rightArea.addElement(selector);
					//}
					break;
				
				case ChartConst.BODE:
					
						var bodePro:BodeProvider = new BodeProvider();
						var chart4:SGChart=new SGChart;
						chart4.chartProvider=bodePro;
						//chart4.dragFilterFun=dragFilterFun; //过滤掉机组
						
						var cv_ViewT:BodeViewT = new BodeViewT;
						var cv_ViewB:BodeViewB = new BodeViewB;
						var rigttab:BodeInfoView = new BodeInfoView;
						rigttab.percentWidth =  100 ;
						bodePro.setValue('bode_top', cv_ViewT);
						bodePro.setValue('bode_bottom', cv_ViewB);
						
						cv_ViewT.percentWidth=100;
						cv_ViewT.percentHeight=100;
						cv_ViewB.percentHeight=100;
						cv_ViewB.percentWidth=100;
						
						rigttab.initdata(chart4, cv_ViewT, cv_ViewB);
						rigttab.initTabIndex = 1;
						
						chart4.addDisplayObject(cv_ViewT);
						chart4.addDisplayObject(cv_ViewB);
						
						chart4.chartProvider.initUpdate(plist);
						
						chart4.addEventListener(FlexEvent.CREATION_COMPLETE  ,  onTrendViewCreateComplete , false , 0 , true);
						
						leftArea.addElement(chart4);
						rightArea.addElement(rigttab);
					break;
				case ChartConst.ACHSE:
					
						var chart3:SGChart = new SGChart;
						chart3.chartProvider = new AscheProvider;
						
						var asche_Wave:AsPosView = new AsPosView;
						asche_Wave.type = ChartViewConst.Y_WAVE;
						asche_Wave.percentHeight = 100;
						asche_Wave.percentWidth = 100;
						
						
						chart3.addDisplayObject(asche_Wave);
						
						var righttab2:AixsPosInfoView = new AixsPosInfoView;
						righttab2.initdata(chart3, asche_Wave);
						righttab2.initTabIndex = 1;
						righttab2.percentWidth = 100;
						
						chart3.chartProvider.initUpdate(plist);
						
						chart3.addEventListener(FlexEvent.CREATION_COMPLETE  ,  onTrendViewCreateComplete , false , 0 , true);
						
						
						leftArea.addElement(chart3);
						rightArea.addElement(righttab2);
						
					break;
			}
			
		}
		private function initCurrentAtlasItem(arr:Array):void{
			var sg:SGChart = getChartView();
			if(sg)
				sg.chartProvider.initUpdate(arr);
		}
		private function onTrendViewCreateComplete(e:FlexEvent):void{
			
			var trd:SGChart = getChartView();
			if(trd){
				trd.removeEventListener(FlexEvent.CREATION_COMPLETE  , onTrendViewCreateComplete);
			}
			var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.VIEW_CREATE_COMPLETE);
			evt.param = {
				"chartUI":e.currentTarget
			};
			evt.dispatchEvent();
			
		}
		
		private function onOverviewHasAddComplete(e:Event):void{
			if(_isSnapshot)
				return;
			
			var trd:SGChart = getChartView();
			EventDispatcher(e.currentTarget).removeEventListener( "hasAddComplete"  , onOverviewHasAddComplete );
			var evt:DataBridgeEvent = new DataBridgeEvent(DataBridgeEvent.VIEW_CREATE_COMPLETE);
			evt.param = {
				"chartUI":e.currentTarget
			};
			evt.dispatchEvent();
			
		}
		//执行快照
		private function onSnapshot(e:DataBridgeEvent=null):void
		{
			if(_isSnapshot)
				return;
			
			_isSnapshot = true;
			
			//如果是总貌图需要先解除绑定的事件
			if(_currentAltasType == ChartConst.OVERVIEW){
				/*var ov:IVisualElement = leftArea.getElementAt(0);
				if(ov){
					ov.removeEventListener( "hasGetRTData"  , onOverviewGetRTData );
				}*/
				clearTimeout( _overviewSnapshotTimeout );
			}
			
			//如果是轴心位置图则将补偿电压设置为轴心最低点
			if(_currentAltasType == ChartConst.ACHSE){
				_aixsSnapshotTimeout = setTimeout(drawAtlas , 3000);
				return;
			}
			if(_currentAltasType == ChartConst.BODE){
				var bp:BodeInfoView = getRightSetting() as BodeInfoView;
				if(bp){
					bp.datatypeselector.datatypeselector.setAllButtonOut();
					var evt:ChartEvent = new ChartEvent(DataTypeSelectorView.DATATYPE_CHANGED);
					evt.subType = DataTypeConst.KAI_DOWNTIME;
					bp.datatypeselector.datatypeselector.dispatchEvent(evt);
					bp.datatypeselector.addEventListener("dataListChanged" , onKaiDownDataListChanged , false , 0 , true);
				}
				return;
			}
			
			drawAtlas(e? e.param.istimeout : false );
		}
		private function onKaiDownDataListChanged(e:Event):void{
			if(_currentAltasType == ChartConst.BODE){
				var bp:BodeInfoView = getRightSetting() as BodeInfoView;
				
				if(bp ){
					bp.datatypeselector.datatypeselector.removeEventListener("dataListChanged" , onKaiDownDataListChanged );
					var lists:ArrayCollection = bp.datatypeselector.datadisplay.datagrid.dataProvider as ArrayCollection;
					if(lists && lists.length > 0){
						bp.datatypeselector.datadisplay.datagrid.selectedIndex = 0;
					}
				}
				_bodeSnapshotTimeout  =   setTimeout(drawAtlas  ,  1500 );
			}
		}
		
		private function getRightSetting():UIComponent{
			if(rightArea.numElements > 0){
				var rs:IVisualElement = rightArea.getElementAt(0);
				return (rs as UIComponent);
			}
			return null;
		}
		private function onCancelSnapshot(e:DataBridgeEvent):void{
			
			if(_currentAltasType == ChartConst.BODE){
				var bp:BodeInfoView = getRightSetting() as BodeInfoView;
				if(bp){
					bp.datatypeselector.removeEventListener("dataListChanged" , onKaiDownDataListChanged  );
				}
			}
			
			_currentAltasType = -1;  
			_lastAltasType = -1;
			_isSnapshot = true;
			clearTimeout( _overviewSnapshotTimeout );
			clearTimeout( _aixsSnapshotTimeout );
			clearTimeout( _bodeSnapshotTimeout );
			clearAltas();
		}

		private function drawAtlas(istimeout:Boolean=false):void{
			
			if(!istimeout && (_currentAltasType == ChartConst.TREND_1_X || _currentAltasType == ChartConst.TREND_2_X || _currentAltasType == ChartConst.TREND_HALF_X || _currentAltasType == ChartConst.TREND_PP_CURRENT_VALUE  || _currentAltasType == ChartConst.TREND_GAP)){
				var tv:TrendView = TrendChartUI(getChartView()).cv_trend;
				tv.showAll();
				setTimeout( function sd(){
					drawAtlas(true);
				} , 2000 );
				return;
			}
			
			var bmpData:BitmapData = new BitmapData(this.width , this.height);
			bmpData.draw( this , new Matrix());
			var bitmap:Bitmap  =  new Bitmap( bmpData );
			
			clearAltas();
			
			var evt:DataBridgeEvent = new DataBridgeEvent( DataBridgeEvent.SNAPSHOT_IMG );
			evt.param = { img:bitmap  };
			evt.dispatchEvent();
		}
		private function getChartView():SGChart{
			if(leftArea.numElements > 0){
				var ch:IVisualElement = leftArea.getElementAt(0);
				return (ch as SGChart);
			}
			return null;
		}
		
		
		//清除所有当前图谱内容
		private function clearAltas():void
		{
			//while (leftArea.numChildren > 0)
			//leftArea.removeChildAt(0);
			if (leftArea.numElements > 0)
				leftArea.removeAllElements();
			//while (rightArea.numChildren > 0)
			//rightArea.removeChildAt(0);
			if (rightArea.numElements > 0)
				rightArea.removeAllElements();
		}
	}
}