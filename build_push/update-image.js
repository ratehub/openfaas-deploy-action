// This script appends GCR project ID to image and tag

// Expects following arguments:
// 1. relative path to stack.yml
// 2. gcr hostname and project id
// 3. tag

// Output - updated-stack.yml file

const yaml = require('js-yaml');
const fs = require('fs');

if (process.argv.length < 5) {
    console.log("Insufficient args supplied!");
    // Exit - fail
    process.exit(1);
}

// Parse supplied arguments
const stackFile = process.argv[2];
const gcrProjectId = process.argv[3];
const tag = process.argv[4];

try {
    // read stack
    const stack = yaml.safeLoad(fs.readFileSync(stackFile, 'utf8'));

    // version 1.0 is converted to 1 while converting yaml to json
    stack.version = stack.version.toFixed(1);
    const functions = stack.functions;

    // Append GCR project ID to image and tag
    Object.keys(functions).forEach(key => {
        const image = functions[key].image;
        // read the tag's value from image after `:`
        const stackTag = image.match(/:(.*)/g).pop().replace(":", "");
        const imageWithUpdatedTag = image.replace(stackTag, tag);
        const imageWithProjectId = `${gcrProjectId}${imageWithUpdatedTag}`;
        functions[key].image = imageWithProjectId;
    });

    // Create updated/final stack json
    const updatedStack = {
        ...stack,
        functions: functions
    }

    // Write updated/final stack.yml - `updated-stack.yml`
    fs.writeFileSync('updated-stack.yml', yaml.dump(updatedStack, {
        // Don't convert duplicate objects into references
        noRefs: true
    }));

    // Exit - success
    process.exit(0);

} catch (e) {
    console.log('Error updating stack.yml file:', e);
    // Exit - fail
    process.exit(1);
}
