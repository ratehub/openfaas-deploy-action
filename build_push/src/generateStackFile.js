const core = require('@actions/core');

const { dump, safeLoad } = require('js-yaml');
const { readFileSync, writeFileSync } = require('fs');


async function generateStackFile(tag, gcrProjectId) {
    const stackFile = core.getInput('stack-file');

    try {
        // read stack
        const stack = safeLoad(readFileSync(stackFile, 'utf8'));

        // version 1.0 is converted to 1 while converting yaml to json
        stack.version = stack.version.toFixed(1);
        const functions = stack.functions;

        // Append GCR project ID to image and tag
        Object.keys(functions).forEach(key => {
            const image = functions[key].image;
            // read the tag's value from image after `:`
            const stackTag = image.match(/:(.*)/g).pop().replace(":", "");
            const imageWithUpdatedTag = tag
                ? image.replace(stackTag, tag)
                : image;
            const imageWithProjectId = `${gcrProjectId}${imageWithUpdatedTag}`;
            functions[key].image = imageWithProjectId;
        });

        // Create updated/final stack json
        const updatedStack = {
            ...stack,
            functions: functions
        }

        // Write updated/final stack.yml - `updated-stack.yml`
        writeFileSync('updated-stack.yml', dump(updatedStack, {
            // Don't convert duplicate objects into references
            noRefs: true
        }));
    } catch (e) {
        console.log('Error generating final stack file:', e);
        process.exit(1);
    }
}

module.exports = generateStackFile;
