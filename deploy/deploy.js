const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
    generateStackFile,
    generateResourceFile,
    pushResourceFile,
} = require('./src');


const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

(async () => {
    try {
        await installFaasCli({ isLoginRequired: true });

        const groupPath = core.getInput('group-path');
        const subPath = core.getInput('function-name'); // assume subpath is same as function name
        const environment = core.getInput('deployment-env');

        console.log(`Generating stack file: ${groupPath}/${subPath}`);
        const generatedStackFilePaths = await generateStackFile(groupPath, subPath, environment);
        console.log('>>> generatedStackFilePath:', generatedStackFilePaths);

        await exec.exec('ls -la');

        const gateway = core.getInput('openfaas-gateway');
        // await exec.exec(`${FAAS} deploy -f updated-stack.yml --gateway=${gateway}`);

        const generatedResourceFilePaths = await generateResourceFile(generatedStackFilePaths);
        console.log('>>> generatedResourceFilePaths:', generatedResourceFilePaths);

        await exec.exec('ls -la');
        // await pushResourceFile(groupPath, subPath, environment, generatedResourceFilePaths);
    } catch (error) {
        core.setFailed(error.message);
    }
})();
