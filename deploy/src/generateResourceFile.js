const exec = require('@actions/exec');
const { writeFileSync } = require('fs');


const FAAS = `${process.env.GITHUB_WORKSPACE}/faas-cli`;

async function generateResourceFile(stackFilePaths = []) {
    let crd = '';

    const options = {
        'listeners': {
            stdout: (data) => {
                crd += data.toString();
            }
        }
    };

    for (let index = 0; index < stackFilePaths.length; index++) {
        const stackFile = stackFilePaths[index];
        await exec.exec(`${FAAS} generate -f ${stackFile}`, [], options);
        writeFileSync(stackFile, crd);
        crd = '';
    }
}

module.exports = generateResourceFile;
