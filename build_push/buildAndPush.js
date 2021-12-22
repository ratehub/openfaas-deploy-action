const core = require('@actions/core');
const exec = require('@actions/exec');

const {
    installFaasCli,
} = require('./src');

(async () => {
    try {
        await installFaasCli();

        const groupPath = core.getInput('group-path');
        const subPath = core.getInput('build-push-function');
        console.log(`>>> Generating stack file: ${groupPath}/${subPath}`);

        console.log(`>>> build args: ${process.env.BUILD_ARG_1_NAME} -> ${process.env.BUILD_ARG_1_VALUE}`);
    } catch (error) {
        core.setFailed(error.message);
    }
})();
