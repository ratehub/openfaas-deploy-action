const exec = require('@actions/exec');


async function getDiff() {
    let diffOutput = '';

    const options = {
        'listeners': {
            stdout: (data) => {
                diffOutput += data.toString();
            }
        }
    };

    await exec.exec('git diff HEAD HEAD~1 --name-only', [], options);

    return diffOutput.split('\n').filter(file => file !== '')
        // Ignore changes if the file is prefixed with a "." or "_"
        .filter(file => !file.startsWith('.'))
        .filter(file => !file.startsWith('_'));
}

module.exports = getDiff;
