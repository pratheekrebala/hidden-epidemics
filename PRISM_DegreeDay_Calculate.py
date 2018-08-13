
# coding: utf-8

# In[ ]:


import rasterio
import numpy as np
from scipy import stats
import glob
import os.path
import re
from datetime import datetime
import copy
import argparse
import sys


# # Generating Rasters of Lyme Habitability
# 
# This script generates a raster of Lyme habitability based on a 6 degree threshold. This threshold value comes from "Thermal accumulation and the early development of Ixodes scapularis." from Rand et.al [https://pdfs.semanticscholar.org/fd95/ff4de3f2a88b1d51b90c0d84a9707bc226d8.pdf]
# 
# An explanation of the "Degree Day" metric is available here: http://www.degreedays.net/introduction
# 
# The surface temperature data is available from PRISM: http://www.prism.oregonstate.edu/
# 
# Here's a rough outline of the methodology:
# 
# E.g. the data for 1981-1990:
#  
# 1. Acquire the PRISM data from here: http://www.prism.oregonstate.edu/recent/ (Node script is available in repo to automate this)
# 2. For each day of each year in the interval, estimate the degree-day using the following formula: tmean – 6 [Assuming a 6 degree threshold]
# 3. Generate average degree-day value for each day of the year by taking a mean of each day across the set. E.g. mean of all the January 1sts, all January 2nds etc.
# 4. Add up the degree day value for the months of Jan – August to get the accumulation value for 1981-1990
# 

# In[ ]:


THRESHOLD = 6
DATE_REGEX = 'PRISM_tmean_stable_4kmD1_(\d*)_bil.bil'
FILE_REGEX = 'PRISM/**/*%s*.bil'

dayRegex = re.compile(DATE_REGEX)


# In[ ]:


interesting_years = range(1981, 2018, 10)


# ## Read/Write Raster PRISM files

# In[ ]:


def readFile(file):
    with rasterio.open(file, driver='Ehdr') as src:
        tmean = src.read(1, masked=True)
        return (src.meta, tmean)


# In[ ]:


def writeFile(file, dest, meta):
    meta = copy.deepcopy(meta)
    #file = copy.deepcopy(file)
    file = np.ma.filled(file, fill_value=meta['nodata'])
    file = file.astype(meta['dtype'])

    meta['driver'] = 'GTiff'    
    
    with rasterio.open(dest, 'w', **meta) as dst:
        dst.write(file, 1)
        del meta, file


# ## Degree day thresholding

# In[ ]:


def thresholdDay(tmean, threshold):
    degree_days = tmean - threshold
    return degree_days


# In[ ]:


def thresholdYear(yearStart, yearEnd):
    aggregate = []
    meta = None
    lookupYears = list(range(yearStart, yearEnd))
    days = [day for year in lookupYears for day in glob.glob(FILE_REGEX % year)]

    print('%s-%s: Processing %s days in %s years' % (yearStart, yearEnd, len(days), len(lookupYears)))

    for year in lookupYears:
        yearAggregate = dict()
        for day in glob.glob(FILE_REGEX % year):
            basename = os.path.basename(day)
            dateString = dayRegex.search(basename).groups(0)[0]
            objDate = datetime.strptime(dateString, '%Y%m%d')
            
            if objDate.year in lookupYears:
                (tmeta, tmean) = readFile(day)
                yearAggregate[objDate] = tmean
                meta = tmeta
            else: pass
        if yearAggregate: aggregate.append(yearAggregate)
    return (aggregate, meta)


# In[ ]:


def remap(matrix):
    m = matrix
    m[(m > 0) & (m < 800)] = 800
    return m


# In[ ]:


def aggregateYears(aggregates, month, threshold):
    years_filtered = []
    for year in aggregates:
        days = [matrix - threshold for day, matrix in year.items() if day.month <= month]
        years_filtered.append(days)

    yearsComposite = [np.ma.mean(day, axis=0) for day in zip(*years_filtered)]
    yearsComposite = [np.ma.masked_less_equal(year, 0) for year in yearsComposite]
    yearsComposite = np.ma.sum(yearsComposite, axis=0)

    return yearsComposite


# In[ ]:


def processYear(year, increment=9):
    yearStart = year
    yearEnd = year + increment
    
    dest = './dist/source/%s-%s.tiff' % (yearStart, yearEnd)

    (aggregates, meta) = thresholdYear(yearStart, yearEnd)
    
    yearlyThreshold = aggregateYears(aggregates, 8, THRESHOLD)

    writeFile(yearlyThreshold, dest, meta)


# ## Processing Loop

# In[ ]:


try:
    isnotebook = get_ipython()
except:
    isnotebook = None

if __name__ == "__main__" and not isnotebook:
    parser = argparse.ArgumentParser("Lyme Modeling")
    parser.add_argument("range", help="What range to generate files for?", type=str)
    args = parser.parse_args()
    rg = args.range
    start_year = int(rg.split('-')[0])
    end_year = int(rg.split('-')[1])
    increment = end_year - start_year
    interesting_years = [start_year]
else:
    increment = 9
    interesting_years = interesting_years # DRY ¯\_(ツ)_/¯


# In[ ]:


for year in interesting_years:
    processYear(year, increment=increment)

