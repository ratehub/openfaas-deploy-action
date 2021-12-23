const exec = require('@actions/exec');
const core = require('@actions/core');

async function installFaasCli({ isLoginRequired = false } = {}) {
    const version = core.getInput('faas-cli-version');
    await exec.exec(`curl -L https://github.com/openfaas/faas-cli/releases/download/${version}/faas-cli -o faas-cli`);
    await exec.exec('chmod +x faas-cli');

    // TODO: remove faas-cli login once fully migrated to argo deploy
    if (isLoginRequired) {
        const user = core.getInput('openfaas-username');
        const password = core.getInput('openfaas-password');
        const gateway = core.getInput('openfaas-gateway');

        const faasLoginArgs = [`--username=${user}`, '--password-stdin', `--gateway=${gateway}`];
        await exec.exec('./faas-cli login', faasLoginArgs, { input: password });
    }
}

module.exports = installFaasCli;
