const core = require('@actions/core');

const {
    getDiff,
    getStackFiles,
    getStackFunctions,
    generateFunctionDetails,
    analyseUpdatedFiles,
} = require('./src');


(async () => {
    try {
        const caller = core.getInput('caller');
        const stackFiles = await getStackFiles(caller);

        // List for files updated
        const updatedFiles = await getDiff();

        const functionDetails = stackFiles.map(stack => {

            const groupPath = stack.includes('/') ? stack.substring(0, stack.lastIndexOf('/')) : '.';

            const filteredUpdatedFiles = groupPath === '.'
                ? updatedFiles
                : updatedFiles.filter(file => (file.startsWith(groupPath) || file.startsWith('common/')));

            const stackFunctions = getStackFunctions(stack);
            const force = core.getInput('force');

            if (!force || force === 'none') {
                const updatedFunctions = analyseUpdatedFiles(filteredUpdatedFiles, caller, groupPath, stackFunctions);
                return generateFunctionDetails(groupPath, updatedFunctions);
            } else {
                if (force === '*') {
                    return generateFunctionDetails(groupPath, stackFunctions);
                } else {
                    return generateFunctionDetails(groupPath, force.split(','));
                }
            }

        });

        const formattedOutput = functionDetails.flat().length === 0
            ? { 'include': [{ 'function-sub-path': 'none', 'function-group-path': 'none' }] }
            : { 'include': functionDetails.flat() }

        console.log('output:', formattedOutput);
        core.setOutput("function-details", formattedOutput);

    } catch (error) {
        core.setFailed(error.message);
    }
})();
