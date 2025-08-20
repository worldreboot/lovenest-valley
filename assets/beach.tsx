<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="beach" tilewidth="16" tileheight="16" tilecount="84" columns="12">
 <image source="images/Beach/Tiles/Tiles.png" width="192" height="112"/>
 <tile id="46" probability="0.01"/>
 <tile id="58" probability="0.01"/>
 <wangsets>
  <wangset name="Sand-Shoreline" type="corner" tile="-1">
   <wangcolor name="Sand" color="#ff0000" tile="-1" probability="1"/>
   <wangcolor name="ShallowWater" color="#00ff00" tile="-1" probability="1"/>
   <wangtile tileid="6" wangid="0,2,0,1,0,2,0,2"/>
   <wangtile tileid="7" wangid="0,2,0,1,0,1,0,2"/>
   <wangtile tileid="8" wangid="0,2,0,2,0,1,0,2"/>
   <wangtile tileid="18" wangid="0,1,0,1,0,2,0,2"/>
   <wangtile tileid="19" wangid="0,1,0,1,0,1,0,1"/>
   <wangtile tileid="20" wangid="0,2,0,2,0,1,0,1"/>
   <wangtile tileid="30" wangid="0,1,0,2,0,2,0,2"/>
   <wangtile tileid="31" wangid="0,1,0,2,0,2,0,1"/>
   <wangtile tileid="32" wangid="0,2,0,2,0,2,0,1"/>
   <wangtile tileid="42" wangid="0,1,0,1,0,1,0,2"/>
   <wangtile tileid="43" wangid="0,2,0,1,0,1,0,1"/>
   <wangtile tileid="54" wangid="0,1,0,1,0,2,0,1"/>
   <wangtile tileid="55" wangid="0,1,0,2,0,1,0,1"/>
  </wangset>
  <wangset name="Shallow-DeepWater" type="corner" tile="-1">
   <wangcolor name="ShallowWater" color="#ff0000" tile="-1" probability="1"/>
   <wangcolor name="DeepWater" color="#00ff00" tile="-1" probability="1"/>
   <wangtile tileid="0" wangid="0,1,0,2,0,1,0,1"/>
   <wangtile tileid="1" wangid="0,1,0,2,0,2,0,1"/>
   <wangtile tileid="2" wangid="0,1,0,1,0,2,0,1"/>
   <wangtile tileid="12" wangid="0,2,0,2,0,1,0,1"/>
   <wangtile tileid="13" wangid="0,2,0,2,0,2,0,2"/>
   <wangtile tileid="14" wangid="0,1,0,1,0,2,0,2"/>
   <wangtile tileid="24" wangid="0,2,0,1,0,1,0,1"/>
   <wangtile tileid="25" wangid="0,2,0,1,0,1,0,2"/>
   <wangtile tileid="26" wangid="0,1,0,1,0,1,0,2"/>
  </wangset>
  <wangset name="DeepWater-Abyss" type="corner" tile="-1">
   <wangcolor name="DeepWater" color="#ff0000" tile="-1" probability="1"/>
   <wangcolor name="AbyssWater" color="#00ff00" tile="-1" probability="1"/>
   <wangtile tileid="3" wangid="0,1,0,2,0,1,0,1"/>
   <wangtile tileid="4" wangid="0,1,0,2,0,2,0,1"/>
   <wangtile tileid="5" wangid="0,1,0,1,0,2,0,1"/>
   <wangtile tileid="15" wangid="0,2,0,2,0,1,0,1"/>
   <wangtile tileid="16" wangid="0,2,0,2,0,2,0,2"/>
   <wangtile tileid="17" wangid="0,1,0,1,0,2,0,2"/>
   <wangtile tileid="27" wangid="0,2,0,1,0,1,0,1"/>
   <wangtile tileid="28" wangid="0,2,0,1,0,1,0,2"/>
   <wangtile tileid="29" wangid="0,1,0,1,0,1,0,2"/>
  </wangset>
 </wangsets>
</tileset>
