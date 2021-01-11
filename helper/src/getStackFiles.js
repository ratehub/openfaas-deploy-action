const glob = require('@actions/glob');
const path = require('path');


const GITHUB_WORKSPACE = process.env.GITHUB_WORKSPACE;

async function getStackFiles(caller) {

    const patterns = caller === 'build_push'
        ? ['stack.yml', '**/stack.yml', '**/**/stack.yml']
        : ['stack-deploy.yml', '**/stack-deploy.yml', '**/**/stack-deploy.yml'];

    const globber = await glob.create(patterns.join('\n'));
    const files = await globber.glob();

    const relativePaths = files.map(absPath => path.relative(GITHUB_WORKSPACE, absPath));

    return relativePaths;
}

module.exports = getStackFiles;
