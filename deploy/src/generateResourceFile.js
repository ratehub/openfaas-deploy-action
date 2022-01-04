const exec = require('@actions/exec');
const { writeFileSync } = require('fs');


const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

async function generateResourceFile() {
    let crd = '';

    const options = {
        'listeners': {
            stdout: (data) => {
                crd += data.toString();
            }
        }
    };

    await exec.exec(`${FAAS} generate -f updated-stack.yml`, [], options);
    writeFileSync('resource.yaml', crd);
}

module.exports = generateResourceFile;
