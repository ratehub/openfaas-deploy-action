const yaml = require('js-yaml');
const fs = require('fs');
const object = require('lodash/fp/object');

if (process.argv.length < 4) {
    console.log("Insufficient args supplied!");
    // Exit - fail
    process.exit(1);
}

// Parse supplied arguments
const functionName = process.argv[2];
const outputFile = process.argv[3];

try {
    // create dummy function-specific deploy file
    fs.writeFileSync(outputFile, yaml.dump({ [functionName]: { 'image': `${functionName}:latest` } }, {
        // Don't convert duplicate objects into references
        noRefs: true
    }));

    // Exit - success
    process.exit(0);

} catch (e) {
    console.log(`Error creating ${outputFile} file:`, e);
    // Exit - failed
    process.exit(1);
}
