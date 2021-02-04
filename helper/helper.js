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
        console.log('caller: ', caller);
        const stackFiles = await getStackFiles();
        console.log('stackFiles: ', stackFiles);

        // List for files updated
        const updatedFiles = await getDiff();
        console.log('updatedFiles: ', updatedFiles);

        const functionDetails = stackFiles.map(stack => {

            const groupPath = stack.includes('/') ? stack.substring(0, stack.lastIndexOf('/')) : '.';
            console.log('groupPath: ', groupPath);
            const filteredUpdatedFiles = groupPath === '.' ? updatedFiles : updatedFiles.filter(file => file.startsWith(groupPath));
            console.log('filteredUpdatedFiles: ', filteredUpdatedFiles);
            const stackFunctions = getStackFunctions(stack);
            console.log('stackFunctions: ', stackFunctions);
            const force = core.getInput('force');

            if (force !== 'none') {
                if (force === '*') {
                    return generateFunctionDetails(groupPath, stackFunctions);
                } else {
                    return generateFunctionDetails(groupPath, force.split(','));
                }
            } else {
                const updatedFunctions = analyseUpdatedFiles(filteredUpdatedFiles, caller, groupPath, stackFunctions);
                return generateFunctionDetails(groupPath, updatedFunctions);
            }

        });

        const formattedOutput = functionDetails.flat().length === 0
            ? { 'include': [{ 'function-name': 'none', 'function-group': 'none' }] }
            : { 'include': functionDetails.flat() }

        console.log('output:', formattedOutput);
        core.setOutput("function-details", formattedOutput);

    } catch (error) {
        core.setFailed(error.message);
    }
})();
