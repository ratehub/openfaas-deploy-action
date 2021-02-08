const path = require('path');
const fs = require('fs');


const GITHUB_WORKSPACE = process.env.GITHUB_WORKSPACE;

function analyseUpdatedFiles(filteredUpdatedFiles, caller, groupPath, stackFunctions) {
    let updatedFunctions = [];

    for (var i = 0; i < filteredUpdatedFiles.length; i++) {
        const updatedFile = filteredUpdatedFiles[i];
        if (!(caller == "build_push" && updatedFile.endsWith('deploy.yml'))) {

            if (updatedFile.includes('/')) {
                const functionPath = updatedFile.substring(0, updatedFile.indexOf('/'));
                console.log('functionPath:', functionPath);

                if (stackFunctions.includes(functionPath) && !updatedFunctions.includes(functionPath)) {
                    console.log('Analysing git diff - changes to directory or file specific to a faas-function');
                    updatedFunctions.push(functionPath);
                } else {
                    console.log('Analysing git diff - changes to directory or file common to all stack functions');
                    updatedFunctions = addAllFunctionPaths(stackFunctions, groupPath);
                    break;
                }

            } else {
                console.log('Analysing git diff - changes at root of repo');
                updatedFunctions = addAllFunctionPaths(stackFunctions, groupPath);
                break;
            }
        }
    }
    return updatedFunctions;
}

function addAllFunctionPaths(stackFunctions, groupPath) {

    // single function cases only
    if (stackFunctions.length === 1) {
        const functionName = stackFunctions[0];
        if (fs.existsSync(path.join(GITHUB_WORKSPACE, groupPath, functionName))) {
            return [`${functionName}`];
        } else {
            return ['.'];
        }
    }

    return stackFunctions;
}

module.exports = analyseUpdatedFiles;
