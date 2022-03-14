const core = require('@actions/core');

const getStackFiles = require('../common/getStackFiles');
const getStackFunctions = require('../common/getStackFunctions');


(async () => {
    try {
        const { GITHUB_REF } = process.env;
        console.log('>>> GITHUB_REF: ', GITHUB_REF);

        const tag = GITHUB_REF.replace('refs/tags/', '');
        console.log('>>> tag:', tag);

        const pattern = '[0-9]+\.[0-9]+\.[0-9]+.*$';
        const matchIndex = tag.search(pattern);

        const funcitonName = tag.substring(0, matchIndex - 1);
        console.log('>>> funcitonName:', funcitonName);

        const stackFiles = await getStackFiles('build_push');
        console.log('>>> stackFiles:', stackFiles);
        let groupPath = '';

        for (let index = 0; index < stackFiles.length; index++) {
            const stackFunctions = getStackFunctions(stackFiles[index]);
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
