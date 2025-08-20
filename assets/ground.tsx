<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.2" name="ground" tilewidth="16" tileheight="16" tilecount="180" columns="15">
 <image source="images/Tiles/Tile.png" width="240" height="192"/>
 <tile id="1" probability="0.005"/>
 <tile id="2" probability="0.005"/>
 <tile id="3" probability="0.005"/>
 <tile id="4" probability="0.005"/>
 <tile id="16" probability="0.001"/>
 <tile id="19" probability="0.005"/>
 <tile id="24">
  <properties>
   <property name="isTillable" type="bool" value="true"/>
  </properties>
 </tile>
 <tile id="27">
  <properties>
   <property name="tileType" value="tilledSoil"/>
  </properties>
 </tile>
 <tile id="31" probability="0.001"/>
 <tile id="34" probability="0.005"/>
 <tile id="80" probability="0.19"/>
 <wangsets>
  <wangset name="Ground" type="corner" tile="-1">
   <wangcolor name="Dirt" color="#ff0000" tile="-1" probability="1"/>
   <wangcolor name="Pond" color="#0000ff" tile="-1" probability="1"/>
   <wangcolor name="Tilled" color="#ff7700" tile="-1" probability="1"/>
   <wangcolor name="Grass" color="#1aff00" tile="-1" probability="1"/>
   <wangcolor name="HighGround" color="#00e9ff" tile="-1" probability="1"/>
   <wangcolor name="HighGroundMid" color="#ff00d8" tile="-1" probability="1"/>
   <wangtile tileid="8" wangid="0,5,0,4,0,5,0,5"/>
   <wangtile tileid="9" wangid="0,5,0,4,0,4,0,5"/>
   <wangtile tileid="10" wangid="0,5,0,5,0,4,0,5"/>
   <wangtile tileid="11" wangid="0,4,0,1,0,4,0,4"/>
   <wangtile tileid="12" wangid="0,4,0,1,0,1,0,4"/>
   <wangtile tileid="13" wangid="0,4,0,4,0,1,0,4"/>
   <wangtile tileid="23" wangid="0,4,0,4,0,5,0,5"/>
   <wangtile tileid="24" wangid="0,4,0,4,0,4,0,4"/>
   <wangtile tileid="25" wangid="0,5,0,5,0,4,0,4"/>
   <wangtile tileid="26" wangid="0,1,0,1,0,4,0,4"/>
   <wangtile tileid="27" wangid="0,1,0,1,0,1,0,1"/>
   <wangtile tileid="28" wangid="0,4,0,4,0,1,0,1"/>
   <wangtile tileid="38" wangid="0,4,0,5,0,5,0,5"/>
   <wangtile tileid="39" wangid="0,4,0,5,0,5,0,4"/>
   <wangtile tileid="40" wangid="0,5,0,5,0,5,0,4"/>
   <wangtile tileid="41" wangid="0,1,0,4,0,4,0,4"/>
   <wangtile tileid="42" wangid="0,1,0,4,0,4,0,1"/>
   <wangtile tileid="43" wangid="0,4,0,4,0,4,0,1"/>
   <wangtile tileid="47" wangid="0,4,0,2,0,4,0,4"/>
   <wangtile tileid="48" wangid="0,4,0,2,0,2,0,4"/>
   <wangtile tileid="49" wangid="0,4,0,4,0,2,0,4"/>
   <wangtile tileid="54" wangid="0,5,0,5,0,5,0,5"/>
   <wangtile tileid="58" wangid="0,1,0,4,0,1,0,1"/>
   <wangtile tileid="59" wangid="0,1,0,1,0,4,0,1"/>
   <wangtile tileid="62" wangid="0,2,0,2,0,4,0,4"/>
   <wangtile tileid="63" wangid="0,2,0,2,0,2,0,2"/>
   <wangtile tileid="64" wangid="0,4,0,4,0,2,0,2"/>
   <wangtile tileid="73" wangid="0,4,0,1,0,1,0,1"/>
   <wangtile tileid="74" wangid="0,1,0,1,0,1,0,4"/>
   <wangtile tileid="77" wangid="0,2,0,4,0,4,0,4"/>
   <wangtile tileid="78" wangid="0,2,0,4,0,4,0,2"/>
   <wangtile tileid="79" wangid="0,4,0,4,0,4,0,2"/>
   <wangtile tileid="92" wangid="0,2,0,4,0,2,0,2"/>
   <wangtile tileid="93" wangid="0,2,0,2,0,4,0,2"/>
   <wangtile tileid="107" wangid="0,4,0,2,0,2,0,2"/>
   <wangtile tileid="108" wangid="0,2,0,2,0,2,0,4"/>
   <wangtile tileid="120" wangid="0,3,0,4,0,3,0,3"/>
   <wangtile tileid="121" wangid="0,3,0,3,0,4,0,3"/>
   <wangtile tileid="122" wangid="0,4,0,3,0,4,0,4"/>
   <wangtile tileid="123" wangid="0,4,0,3,0,3,0,4"/>
   <wangtile tileid="124" wangid="0,4,0,4,0,3,0,4"/>
   <wangtile tileid="135" wangid="0,4,0,3,0,3,0,3"/>
   <wangtile tileid="136" wangid="0,3,0,3,0,3,0,4"/>
   <wangtile tileid="137" wangid="0,3,0,3,0,4,0,4"/>
   <wangtile tileid="138" wangid="0,3,0,3,0,3,0,3"/>
   <wangtile tileid="139" wangid="0,4,0,4,0,3,0,3"/>
   <wangtile tileid="152" wangid="0,3,0,4,0,4,0,4"/>
   <wangtile tileid="153" wangid="0,3,0,4,0,4,0,3"/>
   <wangtile tileid="154" wangid="0,4,0,4,0,4,0,3"/>
  </wangset>
 </wangsets>
</tileset>
