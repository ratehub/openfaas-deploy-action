// This script creates stack file named `updated-stack.yml` by merging
// global and function specific settings to already present stack.yml file

// Expects following arguments:
// 1. gobal settings file
// 2. relative path to function specific deploy settings
// 3. relative path to stack.yml
// 4. gcr hostname and project id
// 5. config override
// 6. tag override (optional)

const yaml = require('js-yaml');
const fs = require('fs');
const object = require('lodash/fp/object');

if (process.argv.length < 6) {
    console.log("Insufficient args supplied!");
    // Exit - fail
    process.exit(1);
}

// Parse supplied arguments
const globalFilePath = process.argv[2];
const deployFilePath = process.argv[3];
const stackFile = process.argv[4];
const gcrProjectId = process.argv[5];
const tagOverride = process.argv[6] ? process.argv[6] : undefined;

function customizer(objValue, srcValue) {
    if (object.isArray(objValue)) {
        return objValue.concat(srcValue);
    }
}

try {
    // read all yamls
    const stack = yaml.safeLoad(fs.readFileSync(stackFile, 'utf8'));
    const globalSettings = yaml.safeLoad(fs.readFileSync(globalFilePath, 'utf8'));
    const deployFunctions = yaml.safeLoad(fs.readFileSync(deployFilePath, 'utf8'));

    // version 1.0 is converted to 1 while converting yaml to json
    stack.version = stack.version.toFixed(1);
    const functions = stack.functions;

    // Merge global settings
    const functionsWithGlobalSettings = Object.keys(functions).reduce((acc, key) => {
        acc[key] = object.mergeWith(functions[key], globalSettings, customizer);
        return acc;
    }, {});

    // Merge function specific settings
    const updatedFunctions = deployFunctions
        ? Object.keys(deployFunctions).reduce((acc, key) => {
            const globalSettingFunction = functionsWithGlobalSettings[key]
                ? functionsWithGlobalSettings[key]
                : functionsWithGlobalSettings[Object.keys(functionsWithGlobalSettings)[0]];

            acc[key] = object.mergeWith(globalSettingFunction, deployFunctions[key], customizer);

            return acc;
        }, {})
        : functionsWithGlobalSettings;

    // Append GCR project ID to image, override tag and 
    // Update node-pool constraint if needed
    Object.keys(updatedFunctions).forEach(key => {
        const image = updatedFunctions[key].image;
        // read the tag from image after `:`
        const tag = image.match(/:(.*)/g).pop().replace(":", "");
        const imageWithUpdatedTag = tagOverride
            ? image.replace(tag, tagOverride)
            : image;

        const imageWithProjectId = `${gcrProjectId}${imageWithUpdatedTag}`;
        updatedFunctions[key].image = imageWithProjectId;
    });

    console.log('[create-stack] updatedFunctions:', updatedFunctions);

    // Create updated/final stack json
    const updatedStack = {
        ...stack,
        functions: updatedFunctions
    }

    // Write updated/final stack.yml - `updated-stack.yml`
    fs.writeFileSync('updated-stack.yml', yaml.dump(updatedStack, {
        // Don't convert duplicate objects into references
        noRefs: true
    }));

    // Exit - success
    process.exit(0);

} catch (e) {
    console.log('Error creating stack.yml file:', e);
    // Exit - fail
    process.exit(1);
}
