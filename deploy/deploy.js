const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
    generateStackFile,
    generateResourceFile,
    pushResourceFile,
} = require('./src');

const getStackFunctions = require('../common/getStackFunctions');

const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

(async () => {
    try {
        const groupPath = core.getInput('group-path');
        const subPath = core.getInput('function-path');
        // we assume subpath is same as function name
        const environment = core.getInput('deployment-env');

        console.log(`Generating stack file: ${groupPath}/${subPath}`);
        const generatedStackFilePaths = await generateStackFile(groupPath, subPath, environment);

        const deployStrategy = core.getInput('deploy-strategy');
        if (deployStrategy === 'faas-cli') {
            await installFaasCli({ isLoginRequired: true });
            const gateway = core.getInput('openfaas-gateway');

            for (let index = 0; index < generatedStackFilePaths.length; index++) {
                const stackFile = generatedStackFilePaths[index];
                await exec.exec(`${FAAS} deploy -f ${stackFile} --gateway=${gateway}`);
            }
        } else if (deployStrategy === 'crd') {
            // Becasue this one is first deploy using CRD we will first do faas-cli remove
            await installFaasCli({ isLoginRequired: true });
            const gateway = core.getInput('openfaas-gateway');

            for (let index = 0; index < generatedStackFilePaths.length; index++) {
                const stackFile = generatedStackFilePaths[index];
                const stackFunctions = getStackFunctions(stackFile);
    
                for (let j = 0; j < stackFunctions.length; j++) {
                    const functionName = stackFunctions[j];
                    console.log(`Removing function: ${functionName}`);
                    await exec.exec(`${FAAS} remove -f ${functionName} --gateway=${gateway}`);
                }
            }

            const generatedResourceFilePaths = await generateResourceFile(generatedStackFilePaths);
            await pushResourceFile(groupPath, subPath, environment, generatedResourceFilePaths);
        } else {
            core.setFailed(`Deployment strategy not supported: ${deployStrategy}`);
        }

    } catch (error) {
        core.setFailed(error.message);
    }
})();
