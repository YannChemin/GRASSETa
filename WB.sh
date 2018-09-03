
tsw=0.75
lue=1.0
for file in *TIF
do
	r.in.gdal -e input=$file output=$(echo $file | sed 's/.TIF//') --o
done
g.region -s raster=$(ls *TIF | grep B1.TIF | sed 's/.TIF//')
LC08=$(ls *TIF | grep B1.TIF | sed 's/1.TIF//')
LC08met=$(ls *MTL.txt)
r.import input=dem.tif output=dem extent=region --o
date=$(i.landsat.toar input=$LC08 output=l8 metfile=$LC08met lsatmet=date --o) 
echo $date
i.landsat.toar input=$LC08 output=l8 metfile=$LC08met --o
for file in $(g.list type=raster pattern=LC08*)
do
	r.null map=$file setnull=0
done

#Set computing area to B10 active pixels
for n in 1 2 3 4 5 6 7 8 9
do
	r.mapcalc expression="temp=if(isnull(l810),null(),l8$n)" --o
	g.rename raster=temp,l8$n --o
done

base=l8
#Create config files for 6s
year=$(cat *MTL* | grep DATE_ACQUIRED | grep -oP '(=)[^;]+' | sed 's/=\ \(.*\)/\1/' | sed 's/\(.*\)-\(.*\)-\(.*\)/\1/')
mm=$(cat *MTL* | grep DATE_ACQUIRED | grep -oP '(=)[^;]+' | sed 's/=\ \(.*\)/\1/' | sed 's/\(.*\)-\(.*\)-\(.*\)/\2/')
dd=$(cat *MTL* | grep DATE_ACQUIRED | grep -oP '(=)[^;]+' | sed 's/=\ \(.*\)/\1/' | sed 's/\(.*\)-\(.*\)-\(.*\)/\3/')
doy=$( date -I -d "$year-$mm-$dd" | date +%j)
hh=$(cat *MTL* | grep TIME | grep -oP '(=)[^;]+' | sed 's/=\ \"\(.*\):\(.*\):\(.*\)\.\(.*\)/\1/')
mn=$(cat *MTL* | grep TIME | grep -oP '(=)[^;]+' | sed 's/=\ \"\(.*\):\(.*\):\(.*\)\.\(.*\)/\2/')
ss=$(cat *MTL* | grep TIME | grep -oP '(=)[^;]+' | sed 's/=\ \"\(.*\):\(.*\):\(.*\)\.\(.*\)/\3/')
time=$(echo "$hh + ($mn / 60.0) + ($ss / 3600.0)" | bc -l)
lat=$(echo $(cat *MTL* | grep CORNER_ | grep LAT | grep -oP '(=)[^;]+' | sed 's/=//' | awk '{s+=$1} END {print s}') "/4.0" |  bc -l)
lon=$(echo $(cat *MTL* | grep CORNER_ | grep LON | grep -oP '(=)[^;]+' | sed 's/=//' | awk '{s+=$1} END {print s}') "/4.0" |  bc -l)
echo "18                            - geometrical conditions=Landsat 8" > 6s_conf.txt
echo "$mm $dd $hh.$mm $lon $lat    - month day hh.ddd longitude latitude ("hh.ddd" is in GMT decimal hours)" >> 6s_conf.txt
echo "1                            - atmospheric model=midlatitude summer" >> 6s_conf.txt
echo "1                            - aerosols model=continental" >> 6s_conf.txt
echo "24                           - visibility [km] (aerosol model concentration)" >> 6s_conf.txt
echo "-0.110                       - mean target elevation above sea level [km]" >> 6s_conf.txt
echo "-1000                        - sensor on board a satellite" >> 6s_conf.txt
#For Band 1:
cat 6s_conf.txt > $base\1_conf.txt
echo "115                           - Coastal band of OLI Landsat 8" >> $base\1_conf.txt
#For Band 2:
cat 6s_conf.txt > $base\2_conf.txt
echo "116                           - Blue band of OLI Landsat 8" >> $base\2_conf.txt
#For Band 3:
cat 6s_conf.txt > $base\3_conf.txt
echo "117                           - Green band of OLI Landsat 8" >> $base\3_conf.txt
#For Band 4:
cat 6s_conf.txt > $base\4_conf.txt
echo "118                           - Red band of OLI Landsat 8" >> $base\4_conf.txt
#For Band 5:
cat 6s_conf.txt > $base\5_conf.txt
echo "120                           - NIR band of OLI Landsat 8" >> $base\5_conf.txt
#For Band 6:
cat 6s_conf.txt > $base\6_conf.txt
echo "122                           - SWIR1 band of OLI Landsat 8" >> $base\6_conf.txt
#For Band 7:
cat 6s_conf.txt > $base\7_conf.txt
echo "123                           - SWIR2 band of OLI Landsat 8" >> $base\7_conf.txt
#For Band 8:
cat 6s_conf.txt > $base\8_conf.txt
echo "119                           - PAN band of OLI Landsat 8" >> $base\8_conf.txt
#For Band 9:
cat 6s_conf.txt > $base\9_conf.txt
echo "121                           - Cirrus band of OLI Landsat 8" >> $base\9_conf.txt

for file in $base\1 $base\2 $base\3 $base\4 $base\5 $base\6 $base\7 $base\8 $base\9
do
	i.atcorr -r $file elevation=dem parameters=$file\_conf.txt output=s$file --o
	r.mapcalc expression="temp=if(isnull(l810),null(),s$file)" --o
	g.rename raster=temp,s$file --o
	r.colors map=$file color=grey
done

#Mask
g.rename raster=l83,l7.2
g.rename raster=l84,l7.3
g.rename raster=l85,l7.4
g.rename raster=l86,l7.5
g.rename raster=l810,l7.6
i.landsat.acca -5 -f input=l7. output=temp --o
g.rename raster=l7.2,l83
g.rename raster=l7.3,l84
g.rename raster=l7.4,l85
g.rename raster=l7.5,l86
g.rename raster=l7.6,l810
r.mapcalc expression="temp1=if(isnull(temp),0,1)" --o
r.mapcalc expression="maskVIS=if(isnull(l810),null(),temp1)" --o
#Apply mask
r.mask raster=maskVIS maskcats=0
#Latitude map
r.latlong input=l81 output=latitude --o
#Longitude map
r.latlong -l input=l81 output=longitude --o
#i.albedo
i.albedo -8 -c input=sl81,sl82,sl83,sl84,sl85,sl86,sl87 output=l8alb --o
r.colors -e map=l8alb color=grey
#i.vi viname=ndvi
i.vi viname=ndvi red=sl84 nir=sl85 output=l8ndvi --o
r.colors map=l8ndvi color=ndvi
#Update processing mask with water
r.mapcalc expression="maskWATER=if(l8ndvi<=0,0,maskVIS)" --o
r.mask -r
r.mask raster=maskWATER maskcats=0
#i.emissivity
i.emissivity input=l8ndvi output=l8emis --o
#i.vi viname=savi
i.vi viname=savi red=sl84 nir=sl85 output=l8savi --o
r.colors map=l8savi color=ndvi
#RNETD
r.mapcalc expression="temp=if(isnull(l810),null(),dem)" --o
r.slope.aspect elevation=temp slope=slopedd aspect=aspectdd --o
r.sun elevation=temp aspect=aspectdd slope=slopedd albedo=l8alb glob_rad=rnetd insol_time=sunhours day=$doy nprocs=8 --o
r.mapcalc expression="l8rnetd=rnetd/sunhours" --o
#RNET
timelocal=$(echo "$time + (24.0 / 360.0) * $lon" | bc -l)
r.sun elevation=temp aspect=aspectdd slope=slopedd albedo=l8alb glob_rad=l8rnet day=$doy time=$timelocal nprocs=8 --o
#G0
r.mapcalc expression="overpasstime=$time" --o
i.eb.soilheatflux albedo=l8alb ndvi=l8ndvi temperature=l810 netradiation=l8rnet localutctime=overpasstime output=l8g0 --o
#H
i.eb.z0m -p input=l8savi output=z0m --o
r.mapcalc expression="T0dem=0.00612*dem+l810" --o
i.eb.hsebal01 -a netradiation=l8rnet soilheatflux=l8g0 aerodynresistance=z0m temperaturemeansealevel=T0dem frictionvelocitystar=0.32407 vapourpressureactual=1.511 output=l8h --o
#Evaporative Fraction & SM
i.eb.evapfr -m netradiation=l8rnet soilheatflux=l8g0 sensibleheatflux=l8h evaporativefraction=l8evapfr soilmoisture=l8sm --o
#ETa
i.eb.eta netradiationdiurnal=l8rnetd evaporativefraction=l8evapfr temperature=l810 output=l8eta --o
#Biomass growth
r.mapcalc expression="l8fpar=1.257*l8ndvi-0.161" --o
r.mapcalc expression="doy=$doy" --o
r.mapcalc expression="tsw=$tsw" --o
r.mapcalc expression="lue=$lue" --o
i.biomass fpar=l8fpar lightuse_efficiency=lue latitude=latitude dayofyear=doy transmissivity_singleway=tsw water_availability=l8evapfr output=l8biom --o

#export everything we need
for rstF in l8eta l8sm l8biom l8ndvi l8alb l8rnet l8g0 l8rnetd
do
	r.null map=$rstF setnull=-100000-0
	r.out.gdal -c -m input=$rstF output=$rstF\_$year$mm$dd.tif nodata=-32768 --o
done
