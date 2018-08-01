mkdir -p clipped
mkdir -p resampled
mkdir -p reclassified
mkdir -p colorized
mkdir -p mbtiles
mkdir -p tiles

for fl in `ls -d $PWD/source/*.tiff`
do
    fileExt=${fl##*/}
    file=${fileExt%.*}
    echo $file

    clipped="clipped/${file}.tiff"
    reclassified="reclassified/${file}.tiff"
    colorized="colorized/${file}.tiff"
    mbtiles="mbtiles/${file}.mbtiles"
    tiles="tiles/${file}"

    echo "Clipping and Upscaling $fl"
    # Clip to Northeast & Resample (Bilinear with 0.003 Cell Size; Aligned to Extent)
    gdalwarp -overwrite -co COMPRESS=LZW -dstnodata -9999 -cutline northeast.geojson -crop_to_cutline -dstalpha -ts 19515 8626 -r bilinear $fl $clipped

    echo "Re-classifying $clipped"
    # 800 => A < 880
    # 1700 => A > 1680
    # (A//80)*80 => A >= 880 & A <= 1680
    calculation="800*(A<880)+1700*(A>1680)+((A//80)*80)*((A>=880)*(A<=1680))"
    gdal_calc.py --quiet --overwrite --co COMPRESS=LZW -A $clipped --outfile=$reclassified --calc=$calculation --NoDataValue=-9999

    echo "Applying color-relief on $reclassified"
    gdaldem color-relief -alpha -compute_edges -co COMPRESS=LZW $reclassified rgba.txt $colorized

    echo "Converting $colorized to $mbtiles."
    gdal2mbtiles --name $file --min-resolution=1 --max-resolution=7 --format="jpg" $colorized $mbtiles

    echo "Exporting $mbtiles"
    rm -rf $tiles
    mb-util --silent --image_format=png --do_compression $mbtiles $tiles

done;