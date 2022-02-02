function generateFunctionDetails(functionGroup, functionNames) {
    const details = functionNames.map(functionName => {
        return {
            'function-group-path': functionGroup,
            'function-sub-path': functionName
        }
    });

    return details;
}

module.exports = generateFunctionDetails;
