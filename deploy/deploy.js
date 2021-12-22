const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
    generateStackFile,
} = require('./src');

(async () => {
    try {
        await installFaasCli();

        const groupPath = core.getInput('group-path');
        const subPath = core.getInput('deploy-function');
        const environment = core.getInput('deployment-env');
        console.log(`>>> Starting to generate stack file: ${groupPath}/${subPath}`);

        await generateStackFile(groupPath, subPath, environment);

        // do not log FE exporter stack
        if (!groupPath.includes('frontend-export')) {
            console.log('>>> Generated stack file:');
            await exec.exec('cat updated-stack.yml');
        }

        const gateway = core.getInput('openfaas-gateway');
        await exec.exec(`${process.env.GITHUB_WORKSPACE}/faas-cli deploy -f updated-stack.yml --gateway=${gateway}`);
    } catch (error) {
        core.setFailed(error.message);
    }
})();
