const axios = require('axios');
const querystring = require('querystring');
const fs = require('fs');
const path = require('path');

axios.defaults.headers.post['Content-Type'] = 'application/x-www-form-urlencoded';

const _ = require('highland');

const year_start = 1981;
const year_end = 2017;

const years = Array.from({length: year_end - year_start + 1}, (v, i) => year_start + i);
const dlUrl = 'http://prism.oregonstate.edu/fetchData.php';

async function makeRequest(year, element){
    const reqParams = {
        type: 'all_year',
        kind: 'recent',
        elem: element,
        range: 'daily',
        temporal: parseInt(`${year}0101`)
    };

    let response = await axios.post(dlUrl, querystring.stringify(reqParams), {
        responseType: 'stream'
    });
    
    let disposition = response.headers['content-disposition']
    let filename = decodeURI(disposition.match(/filename=(.*)/)[1])

    return [filename, response.data]
}

function writeFile(response) {
    return new Promise((resolve, reject) => {
        const stream = response[1];
        const filename = path.join('./PRISM', response[0]);
        
        const writeStream = fs.createWriteStream(filename);
        console.log(`Downloading ${filename}`);
    
        let handler = stream.pipe(writeStream)

        handler.on('finish', () => resolve(filename))
        handler.on('error', (e) => reject(e))
    })
}

_(years)
.drop(7)
.flatMap(year => _(makeRequest(year, 'tmean')))
.map(response => _(writeFile(response)))
.mergeWithLimit(4)
.each(console.log)