mkdir -p clipped
mkdir -p resampled
mkdir -p reclassified
mkdir -p colorized

for fl in `ls -d $PWD/source/*.tiff`
do
    clipped="clipped/`basename $fl`"
    reclassified="reclassified/`basename $fl`"
    colorized="colorized/`basename $fl`"

    echo "Clipping and Upscaling $fl"
    # Clip to Northeast & Resample (Bilinear with 0.003 Cell Size; Aligned to Extent)
    gdalwarp -overwrite -co COMPRESS=LZW -dstnodata -9999 -cutline northeast.geojson -crop_to_cutline -dstalpha -ts 19515 8626 -r bilinear $fl $clipped

    echo "Re-classifying $clipped"
    calculation="0*(A<800)+1700*(A>1600)+((A//80)*80)*((A>=800)*(A<=1600))"
    gdal_calc.py --overwrite --co COMPRESS=LZW -A $clipped --outfile=$reclassified --calc=$calculation --NoDataValue=-9999

    echo "Applying color-relief on $reclassified"
    gdaldem color-relief -alpha -compute_edges -co COMPRESS=LZW $reclassified rgba.txt $colorized
done;