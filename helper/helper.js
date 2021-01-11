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
        console.log('Caller:', caller);

        const stackFiles = await getStackFiles(caller);
        console.log('Stack files:', stackFiles);

        // List for files updated
        const updatedFiles = await getDiff();
        console.log('Updated files:', updatedFiles);

        const functionDetails = stackFiles.map(stack => {
            console.log(`Processing ${stack}`);

            const groupPath = stack.includes('/') ? stack.substring(0, stack.lastIndexOf('/')) : '.';
            console.log('Group path:', groupPath);

            const filteredUpdatedFiles = groupPath === '.' ? updatedFiles : updatedFiles.filter(file => file.startsWith(groupPath));
            console.log('Relevant updated file:', filteredUpdatedFiles);

            const stackFunctions = getStackFunctions(stack);
            console.log('All funcions in stack file', stackFunctions);

            const force = core.getInput('force');
            console.log('force:', force);

            if (force !== 'none') {
                if (force === '*') {
                    return generateFunctionDetails(groupPath, stackFunctions);
                } else {
                    return generateFunctionDetails(groupPath, force.split(','));
                }
            } else {
                const updatedFunctions = analyseUpdatedFiles(filteredUpdatedFiles, caller, groupPath, stackFunctions);
                console.log('Updated functions after git analysis:', updatedFunctions);
                return generateFunctionDetails(groupPath, updatedFunctions);
            }

        });

        const formattedOutput = functionDetails.flat().length === 0
            ? { 'include': [{ 'function-name': 'none', 'function-group': 'none' }] }
            : { 'include': functionDetails.flat() }

        console.log('formattedOutput:', formattedOutput);

        core.setOutput("function-details", formattedOutput);

    } catch (error) {
        core.setFailed(error.message);
    }
})();
