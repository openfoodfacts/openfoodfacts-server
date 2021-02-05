// This script is used to convert GDSN data from Equadis in XML format
// to a corresponding JSON structure

const xml2json = require('xml2json')
const fs = require("fs")

const directoryPath = "/srv2/off-pro/equadis-data-tmp/"

const filter = /\.xml$/

// force arrays for some fields even if there is only one value supplied
const options = {
    arrayNotation: ['nutrientHeader', 'allergen', 'packagingMarkedLabelAccreditationCode']
};

fs.readdir(directoryPath, function(err, files) {
  if (err) {
    console.log("Error getting directory information.")
  } else {
    files.forEach(function(file) {

     if (filter.test(file)) {

       let content = fs.readFileSync(directoryPath+file, 'utf8');
       let json = xml2json.toJson(content, options);
       fs.writeFileSync(directoryPath+file.replace('.xml','.json'), json);
     }

    })
  }
})

