const soda = require('soda-js');
const axios = require('axios');
const querystring = require('querystring');
const Papa = require('papaparse');
const fs = require('fs');

require('axios-debug-log');

let availableNNDSS = {};

axios.get('https://api.us.socrata.com/api/catalog/v1', {
    params: {
    categories: "NNDSS",
    search_context: "data.cdc.gov"
}})
.then(d => {
    for (let dataset of d.data.results) {
        let resource = {
            date: new Date(dataset.resource.updatedAt),
            title: dataset.resource.name,
            desc: dataset.resource.description.split(/(?<=- ?\d{4})\./)[0],
            link: dataset.link
        }
        
        availableNNDSS[resource.title] = availableNNDSS[resource.title] || {max: null, objs: []};
        availableNNDSS[resource.title].objs.push(resource.date);
        availableNNDSS[resource.title].max = new Date(Math.max(...availableNNDSS[resource.title].objs));
        if (availableNNDSS[resource.title].max.valueOf() === resource.date.valueOf()) {
            availableNNDSS[resource.title] = Object.assign(resource, availableNNDSS[resource.title]);
        }
    }
    
    let auditArray = [['Table Name', 'Last Updated', 'Table Description', 'Table Link']].concat(Object.keys(availableNNDSS).map(table => {
        return [table, availableNNDSS[table].max.toISOString(), availableNNDSS[table].desc, availableNNDSS[table].link];
    }));

    fs.writeFileSync('./table_dates.csv', Papa.unparse(auditArray));
})
.catch(err => {
    console.dir(err);
});