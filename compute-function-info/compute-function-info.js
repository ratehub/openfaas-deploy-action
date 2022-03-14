const core = require('@actions/core');

const getStackFiles = require('../common/getStackFiles');
const getStackFunctions = require('../common/getStackFunctions');


(async () => {
    try {
        const { GITHUB_REF } = process.env;
        const tag = GITHUB_REF.replace('refs/tags/', '');

        const pattern = '[0-9]+\.[0-9]+\.[0-9]+.*$';
        const matchIndex = tag.search(pattern);

        const funcitonName = tag.substring(0, matchIndex - 1);
        const stackFiles = await getStackFiles('build_push');
        let groupPath = '';

        for (let index = 0; index < stackFiles.length; index++) {
            const stackFilePath = stackFiles[index];
            const stackFunctions = getStackFunctions(stackFilePath);
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
        core.setOutput("function-info", formattedOutput);

    } catch (error) {
        core.setFailed(error.message);
    }
})();
