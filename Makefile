# Pipeline: PRISM -> Threshold -> Clip & Upscale -> Re-Classify -> Apply color relief -> Convert to mbtiles -> Extract MBTiles

# Classification Rules
# 800 => A < 880
# 1700 => A > 1680
# (A//80)*80 => A >= 880 & A <= 1680
calculation = '800*(A<880)+1700*(A>1680)+((A//80)*80)*((A>=880)*(A<=1680))'
colorramp = 'dist/rgba.txt'

PRISM:
	mkdir -p PRISM
	echo node download_PRISM.js

dist/source/%.tiff: PRISM
	@echo "Thresholding $<"
	mkdir -p dist/source
	python3 PRISM_DegreeDay_Calculate.py $(increment) $*

dist/clipped/%.tiff: dist/source/%.tiff
	mkdir -p dist/clipped
	@echo "Clipping and Upscaling $<"
	# Clip to Northeast & Resample (Bilinear with 0.003 Cell Size; Aligned to Extent)
	gdalwarp -overwrite -co COMPRESS=LZW -dstnodata -9999 -cutline dist/northeast.geojson -crop_to_cutline -dstalpha -ts 19515 8626 -r bilinear $< $@

dist/reclassified/%.tiff: dist/clipped/%.tiff
	mkdir -p dist/reclassified
	@echo "Re-classifying $<"
	gdal_calc.py --quiet --overwrite --co COMPRESS=LZW -A $< --outfile=$@ --calc=$(calculation) --NoDataValue=-9999

dist/colorized/%.tiff: dist/reclassified/%.tiff
	mkdir -p dist/colorized
	@echo "Applying color-relief on $<"
	gdaldem color-relief -alpha -compute_edges -co COMPRESS=LZW $< $(colorramp) $@

dist/mbtiles/%.mbtiles: dist/colorized/%.tiff
	mkdir -p dist/mbtiles
	@echo "Converting $< to $@."
	gdal2mbtiles --name $* --min-resolution=1 --max-resolution=7 --format="jpg" $< $@

dist/tiles/%: dist/mbtiles/%.mbtiles
	mkdir -p dist/tiles
	@echo "Extracting $< to $@"
	mb-util --silent --image_format=png --do_compression $< $@

all: dist/tiles/1981-1990 dist/tiles/1991-2000 dist/tiles/2001-2010 /dist/tiles/2011-2020