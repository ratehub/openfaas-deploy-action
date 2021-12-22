const exec = require('@actions/exec');
const core = require('@actions/core');

async function installFaasCli() {
    const version = core.getInput('faas-cli-version');
    await exec.exec(`curl -L https://github.com/openfaas/faas-cli/releases/download/${version}/faas-cli -o faas-cli`);
    await exec.exec('chmod +x faas-cli');

    // TODO: remove faas-cli login once fully migrated to argo deploy
    const user = core.getInput('openfaas-username');
    const password = core.getInput('openfaas-password');
    const gateway = core.getInput('openfaas-gateway');
    
    await exec.exec(`./faas-cli login --username=${user} --password=${password} --gateway=${gateway}`)
}

module.exports = installFaasCli;
