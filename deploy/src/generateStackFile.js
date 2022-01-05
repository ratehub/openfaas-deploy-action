const core = require('@actions/core');

const { dump, safeLoad } = require('js-yaml');
const { readFileSync, writeFileSync, existsSync } = require('fs');
const { isArray, mergeWith, uniq } = require('lodash');


async function generateStackFile(groupPath, subPath, environment) {
    const configOverride = core.getInput('config-override');
    const stackFile = core.getInput('stack-file');
    const gcrProjectId = core.getInput('image-registry');
    const tagOverride = core.getInput('tag-override');

    const stackFilePath = `${groupPath}/${stackFile}`;
    const globalSettingsFilePath = `${groupPath}/global-${environment}-deploy.yml`;
    const localSettingsFilePath = configOverride === 'none'
        ? `${groupPath}/${subPath}/${environment}-deploy.yml`
        : `${groupPath}/${subPath}/${configOverride}`;

    try {
        // read all yamls
        const stack = safeLoad(readFileSync(stackFilePath, 'utf8'));
        const globalSettings = existsSync(globalSettingsFilePath) ? safeLoad(readFileSync(globalSettingsFilePath, 'utf8')) : {};
        const deployFunctions = safeLoad(readFileSync(localSettingsFilePath, 'utf8'));

        // 1.0 is converted to 1 while converting yaml to json
        stack.version = stack.version.toFixed(1);
        const functions = stack.functions;

        // merge global settings
        const functionsWithGlobalSettings = Object.keys(functions).reduce((acc, key) => {
            acc[key] = mergeWith({}, functions[key], globalSettings, customizer);
            return acc;
        }, {});

        // merge function specific settings
        const updatedFunctions = deployFunctions
            ? Object.keys(deployFunctions).reduce((acc, key) => {
                const globalSettingFunction = functionsWithGlobalSettings[key]
                    ? functionsWithGlobalSettings[key]
                    : functionsWithGlobalSettings[Object.keys(functionsWithGlobalSettings)[0]];

                acc[key] = mergeWith({}, globalSettingFunction, deployFunctions[key], customizer);

                return acc;
            }, {})
            : functionsWithGlobalSettings;

        // append GCR project ID to image apply override tag
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

        // create final stack json
        const updatedStack = {
            ...stack,
            functions: updatedFunctions
        }

        // write final stack to updated-stack.yml
        writeFileSync('updated-stack.yml', dump(updatedStack, {
            // do not convert duplicate objects into references
            noRefs: true
        }));
    } catch (e) {
        console.log('Error generating final stack file:', e);
        process.exit(1);
    }
}

function customizer(objValue, srcValue) {
    if (isArray(objValue)) {
        return uniq(objValue.concat(srcValue));
    }
}

module.exports = generateStackFile;