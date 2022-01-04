const exec = require('@actions/exec');
const { writeFileSync } = require('fs');


async function generateResourceFile() {
    let crd = '';

    const options = {
        'listeners': {
            stdout: (data) => {
                crd += data.toString();
            }
        }
    };

    // exec.exec(`/bin/bash -c "${process.env.GITHUB_WORKSPACE}/faas-cli generate -f updated-stack.yml > resource.yaml"`);

    await exec.exec(`${process.env.GITHUB_WORKSPACE}/faas-cli generate -f updated-stack.yml`, [], options);
    writeFileSync('resource.yaml', crd);
}

module.exports = generateResourceFile;
