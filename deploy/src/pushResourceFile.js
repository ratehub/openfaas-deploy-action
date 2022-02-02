const exec = require('@actions/exec');
const path = require('path');


const CLUSTERS = {
    dev: 'do-dev-1',
    qa: 'gke-staging-01',
    prod: 'gcp-prod-01'
}

async function pushResourceFile(groupPath, subPath, environment, resourceFilePaths = []) {
    let resourceFiles = '';
    for (let index = 0; index < resourceFilePaths.length; index++) {
        resourceFiles = `${resourceFiles} ${resourceFilePaths[index]}`;
    }

    await exec.exec('git config --global user.name ratehub-machine');
    await exec.exec('git config --global user.email dev@ratehub.ca');

    const crdBasePath = path.join(CLUSTERS[environment], 'faas-functions');
    const groupName = path.basename(groupPath);
    const crdPath = `${crdBasePath}/${groupName}/${subPath}`;

    await exec.exec(`mkdir -p ${crdPath}`);
    await exec.exec(`mv ${resourceFiles} ${crdPath}`);

    let gitStatusOutput = '';
    const options = {
        'listeners': {
            stdout: (data) => {
                gitStatusOutput += data.toString();
            }
        }
    };
    await exec.exec('git status --porcelain', [], options); // give the output in an easy-to-parse format

    if (gitStatusOutput.includes(CLUSTERS[environment])) {
        await exec.exec(`git add ${crdPath}/*`);
        await exec.exec(`git commit -m "deploy(${subPath === '.' ? groupName : `${groupName}/${subPath}`}): Update resource definition file(s)."`);
        await push();
    } else {
        console.log('No changes to resource file.');
    }
}

async function push() {
    try {
        await exec.exec('git push origin HEAD');
    } catch (error) {
        console.log('Error: git push failed');
        console.log('Retrying...');
        await exec.exec('git pull --rebase');
        await push();
    }
}

module.exports = pushResourceFile;
