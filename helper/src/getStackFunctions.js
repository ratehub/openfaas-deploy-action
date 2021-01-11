const yaml = require('js-yaml');
const fs = require('fs');


function getStackFunctions(stackFile) {
    const stack = yaml.safeLoad(fs.readFileSync(stackFile, 'utf8'));
    return Object.keys(stack.functions);
}

module.exports = getStackFunctions;
