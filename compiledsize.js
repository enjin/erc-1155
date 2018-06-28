const path = require('path');
const fs = require("fs");

let dir = './build/contracts';
files = fs.readdirSync(dir);

for (f of files) {
    let contents = fs.readFileSync(path.join(dir, f));
    let jsonContent = JSON.parse(contents);

    let size = jsonContent.deployedBytecode.length / 2 - 1;
    let maxSize = 0x6000;
    console.log(jsonContent.contractName, size, (100 * size / maxSize).toFixed(2) + "%" );
}