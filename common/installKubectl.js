const exec = require('@actions/exec');


async function installKubectl() {
    await exec.exec(`curl -LO https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl`);
    await exec.exec('chmod +x kubectl');
    await exec.exec('./kubectl version');
}

module.exports = installKubectl;
