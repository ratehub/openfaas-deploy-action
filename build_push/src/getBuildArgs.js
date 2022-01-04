function getBuildArgs(tag) {
    let buildArgs = '';
    // currently we support upto 6 build arguments
    for (let i = 1; i <= 6; i++) {
        const key = process.env[`BUILD_ARG_${i}_NAME`];
        const value = process.env[`BUILD_ARG_${i}_VALUE`];

        if (key && value) {
            buildArgs = `${buildArgs} --build-arg ${key}=${value}`
        }
    }

    // bake-in DOCKER_TAG build arg
    buildArgs = `${buildArgs} --build-arg DOCKER_TAG=${tag}`

    // bake-in GITHUB_SHA build arg
    buildArgs = `${buildArgs} --build-arg GIT_SHA=${process.env.GITHUB_SHA}`

    // bake-in GITHUB_REF build arg. Aka refs/heads/main or refs/tags/1.0.0
    buildArgs = `${buildArgs} --build-arg GIT_REF=${process.env.GITHUB_REF}`

    return buildArgs;
}

module.exports = getBuildArgs;
