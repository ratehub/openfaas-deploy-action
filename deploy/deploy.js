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
        const subPath = core.getInput('deploy-function');
        const environment = core.getInput('deployment-env');
        await generateStackFile(groupPath, subPath, environment);

        console.log(`Generating stack file: ${groupPath}/${subPath}`);

        await generateStackFile(groupPath, subPath, environment);

        const gateway = core.getInput('openfaas-gateway');
        // await exec.exec(`${FAAS} deploy -f updated-stack.yml --gateway=${gateway}`);
        await generateResourceFile();
        await pushResourceFile(groupPath, subPath, environment);
    } catch (error) {
        core.setFailed(error.message);
    }
})();
