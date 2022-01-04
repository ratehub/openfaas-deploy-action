const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
    generateStackFile,
    getBuildArgs,
} = require('./src');


const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

(async () => {
    try {
        await installFaasCli();

        const user = core.getInput('docker-username');
        const password = core.getInput('docker-password');
        const gcrProjectId = core.getInput('image-registry');

        const dockerLoginArgs = ['--username', user, '--password-stdin', gcrProjectId];
        await exec.exec('docker login', dockerLoginArgs, { input: password });

        const groupPath = core.getInput('group-path');
        // assume subpath is same as function name
        const subPath = core.getInput('function-name');

        process.chdir(`${groupPath}`);

        await exec.exec(`${FAAS} template pull`);
        const customTemplateUrl = core.getInput('custom-template-url');
        if (customTemplateUrl) {
            await exec.exec(`${FAAS} template pull ${customTemplateUrl}`);
        }

        console.log(`Generating stack file: ${groupPath}/${subPath}`);

        const tag = core.getInput('tag');
        await generateStackFile(tag, gcrProjectId);
        await exec.exec('cat updated-stack.yml');

        const buildArgs = getBuildArgs(tag);
        console.log(`Build args: ${buildArgs}`);

        const isPushRequired = core.getInput('enable-image-push');
        if (subPath !== '.') {
            await exec.exec(`${FAAS} build -f updated-stack.yml ${buildArgs} --filter=${subPath}`);
            if (isPushRequired) {
                await exec.exec(`${FAAS} push -f updated-stack.yml --filter=${subPath}`);
            }
        } else {
            await exec.exec(`${FAAS} build -f updated-stack.yml ${buildArgs}`);
            if (isPushRequired) {
                await exec.exec(`${FAAS} push -f updated-stack.yml`);
            }
        }
    } catch (error) {
        core.setFailed(error.message);
    }
})();
