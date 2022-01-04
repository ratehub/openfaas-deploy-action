const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
    generateStackFile,
} = require('./src');


const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

(async () => {
    try {
        await installFaasCli({ isLoginRequired: true });

        const groupPath = core.getInput('group-path');
        const subPath = core.getInput('deploy-function');
        const environment = core.getInput('deployment-env');
        console.log(`Generating stack file: ${groupPath}/${subPath}`);

        await generateStackFile(groupPath, subPath, environment);

        // do not log FE exporter stack
        if (!groupPath.includes('frontend-export')) {
            console.log('Generated stack file:');
            await exec.exec('cat updated-stack.yml');
        }

        const gateway = core.getInput('openfaas-gateway');
        await exec.exec(`${FAAS} deploy -f updated-stack.yml --gateway=${gateway}`);
    } catch (error) {
        core.setFailed(error.message);
    }
})();
