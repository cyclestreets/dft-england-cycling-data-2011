#!/bin/bash

# Install npm using

sudo apt-get install zip
sudo apt-get install npm nodejs-legacy
sudo npm install -g osmtogeojson
sudo npm install -g @mapbox/geojson-merge
sudo npm install -g topojson
sudo npm install -g ndjson-cli
#sudo npm install -g d3
#sudo npm install -g d3-geo-projection
sudo apt-get install jq
# Osmosis also needed, as per https://wiki.openstreetmap.org/wiki/Osmosis/Installation#Linux (not reproduced here)


# Bomb out if something goes wrong
set -e


# Unzip original data
unzip dft-england-cycling-data-2011.zip
rm -rf zip/
mv done zip


# Unzip zip files
rm -rf osm/
mkdir osm/
cd zip/
for zipfile in *.zip ; do
	unzip $zipfile
	osmfile="${zipfile/.zip/.osm}"
	if [ "${zipfile}" == "SuperLondonBorough1-201202201611.zip" ]; then
		mv LondonSuperBorough1-201202201611.osm $osmfile
	fi
	mv "${osmfile}" ../osm/
done
cd ../


# Create a merged .osm file using osmosis --rx file1.osm --rx file2.osm --m --wx merged.osm ; see: https://lists.openstreetmap.org/pipermail/osmosis-dev/2013-October/001619.html
#cd osm/
#ls -lAF
#mergeCommand="osmosis"
#for osmfile in *.osm ; do
#	mergeCommand+=" --rx '${osmfile}'" # --sort
#done
#echo $mergeCommand
#i=0
#for osmfile in *.osm ; do
#	if [ $i -gt 0 ]; then
#		mergeCommand+=" --merge"
#	fi
#	(( i = i + 1 ))
#done
#mergeCommand+=" --wx ../dft-england-cycling-data-2011.osm"
#echo "${mergeCommand}"
#eval "${mergeCommand}"
#cd ../


# https://help.openstreetmap.org/questions/18255/softwarelibraries-to-convert-osm-data-to-geojson-without-using-api
# osmtogeojson in.osm > out.geojson
rm -rf geojson/
mkdir geojson/
cd osm/
for osmfile in *.osm ; do
	echo "Converting ${osmfile}"
	osmtogeojson $osmfile > "../geojson/${osmfile/.osm/.geojson}"
done
cd ../


# List file counts
ls -lAF zip/ | wc -l
ls -lAF osm/ | wc -l
ls -lAF geojson/ | wc -l


# Merge
geojson-merge geojson/*.geojson > combined.geojson


# Filter unwanted features using sed
# Not ideal, as retains commas at end of list
#less combined.geojson | sed -r '/"(timestamp|version|ccg_date)":/d' | sed -r '/        "id":/d' | sed -e 's/ccg_//' | cat > dft-england-cycling-data-2011.geojson.geojson


# Filter unwanted features using ndjson-cat; see: https://github.com/mbostock/ndjson-cli and https://medium.com/@mbostock/command-line-cartography-part-2-c3a82c5c0f3
#   Reformat file to newline-delimited JSON; see: http://www.roblabs.com/ndjson/
ndjson-cat combined.geojson | ndjson-split 'd.features' > combined.ndjson
#   Filter unwanted properties file
ndjson-filter 'delete d.properties.version, true' < combined.ndjson | ndjson-filter 'delete d.properties.timestamp, true' | ndjson-filter 'delete d.properties.id, true' | ndjson-filter 'delete d.properties.ccg_date, true' > filtered.ndjson
sed -i -e 's/ccg_//g' filtered.ndjson
#   Convert back to GeoJSON
ndjson-reduce < filtered.ndjson | ndjson-map '{type: "FeatureCollection", features: d}' > dft-england-cycling-data-2011.geojson
#sed '1s/^/{"type": "FeatureCollection", "features": [/\n' filtered.ndjson > filtered.geojson
#echo ']}' >> filtered.geojson
#mv filtered.geojson dft-england-cycling-data-2011.geojson


# Make a gzipped version for quicker downloading
gzip -k dft-england-cycling-data-2011_formatted.geojson


# Make formatted version of the GeoJSON
jq . dft-england-cycling-data-2011.geojson | cat > dft-england-cycling-data-2011_formatted.geojson
gzip dft-england-cycling-data-2011_formatted.geojson



# Convert to Shapefile
#!# TODO


# Render to SVG using d3; see: https://medium.com/@mbostock/command-line-cartography-part-2-c3a82c5c0f3
#geo2svg -n --stroke none -p 1 -w 960 -h 960 < combined.ndjson > dft-england-cycling-data-2011.svg


# Clean up temporary files
rm combined.geojson
rm combined.ndjson
rm filtered.ndjson


# Add readme
echo "Documentation at: https://wiki.openstreetmap.org/wiki/England_Cycling_Data_project"

