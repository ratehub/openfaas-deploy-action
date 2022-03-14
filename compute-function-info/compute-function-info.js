const core = require('@actions/core');
const { safeLoad } = require('js-yaml');
const { readFileSync } = require('fs');

const getStackFiles = require('../common/getStackFiles');
const getStackFunctions = require('../common/getStackFunctions');

(async () => {
    try {
        const tag = core.getInput('git-tag');
        console.log('>>> tag:', tag);

        const pattern = '[0-9]+\.[0-9]+\.[0-9]+.*$';
        const matchIndex = tag.search(pattern);


        // we assume subpath is same as function name
        const funcitonName = tag.substring(0, matchIndex - 1);
        console.log('>>> funcitonName:', funcitonName);

        const stackFiles = await getStackFiles('build_push');
        console.log('>>> stackFiles:', stackFiles);
        let groupPath = '';

        for (let index = 0; index < stackFiles.length; index++) {
            const stackFilePath = stackFiles[index];
            console.log('>>> stackFilePath:', stackFilePath);
            const stack = safeLoad(readFileSync(stackFilePath, 'utf8'));
            console.log('>>> stack:', stack);
            const stackFunctions = getStackFunctions(stack);
            console.log('>>> stackFunctions:', stackFunctions);
            const found = stackFunctions.find(name => name === funcitonName);

            if (found) {
                groupPath = stackFilePath.includes('/') ? stackFilePath.substring(0, stack.lastIndexOf('/')) : '.';
                break;
            }
        }

        const formattedOutput = groupPath === ''
            ? { 'include': { 'function-sub-path': 'none', 'function-group-path': 'none' } }
            // we assume subpath is same as function name
            : { 'include': { 'function-sub-path': funcitonName, 'function-group-path': groupPath } }

        console.log('output:', formattedOutput);
        core.setOutput("function-details", formattedOutput);

    } catch (error) {
        core.setFailed(error.message);
    }
})();
