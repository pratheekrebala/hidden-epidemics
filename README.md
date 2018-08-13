# hidden-epidemics
Download and Process PRISM Temperature data to generate Vector Tiles for Lyme Habitability

Story: https://www.publicintegrity.org/2018/08/06/21999/disease-bearing-ticks-head-north-weak-government-response-threatens-public-health

**PRISM_DegreeDay_Calculate.py**

This script generates a raster of Lyme habitability based on a 6 degree threshold. This threshold value comes from ["Thermal accumulation and the early development of Ixodes scapularis." from Rand et.al](https://pdfs.semanticscholar.org/fd95/ff4de3f2a88b1d51b90c0d84a9707bc226d8.pdf)

* An explanation of the "Degree Day" metric is [available here](http://www.degreedays.net/introduction)
* The surface temperature data is available from [PRISM](http://www.prism.oregonstate.edu/) @ OregonState

**Methodology e.g. 1981-1990**

1. Acquire the PRISM data from here: http://www.prism.oregonstate.edu/recent/ (Node script is available in repo to automate this),
2. For each day of each year in the interval, estimate the degree-day using the following formula: tmean – 6 [Assuming a 6 degree threshold],
3. Generate average degree-day value for each day of the year by taking a mean of each day across the set. E.g. mean of all the January 1sts, all January 2nds etc.,
4. Add up the degree day value for the months of Jan – August to get the accumulation value for 1981-1990

**Generating Raster Tiles**

Run `make all` to generate all the required files. The mbtiles will be generated in `dist/mbtiles` and the exported tiles will be generated in `dist/tiles`

**This is the process for generating the tiles e.g. 1981-1990 `make dist/tiles/1981-1990`**

1. PRISM: `node download_PRISM.js` downloads all available PRISM data for 30 years.
2. Thresholding: `python3 PRISM_DegreeDay_Calculate.py '1981-1990'` applies thresholding for data on years from `1981-1990`
3. Clip: The output raster from the above is clipped to the north-east region (`dist/northeast.geojson`)
4. Upscale: The clipped output is upscaled using `gdal_translate` with the `bilinear` flag.
5. Re-classification: The data is clipped to the domain [800, 1680]
6. Color Shading: The output is colorized using the color ramp provided in `dist/rgba.txt`
7. Output data is converted to MBTiles using `gdal2mbtiles`
8. MBTiles are extracted for upload to AWS S3.