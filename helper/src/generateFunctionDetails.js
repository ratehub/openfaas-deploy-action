function generateFunctionDetails(functionGroup, functionNames) {
    const details = functionNames.map(functionName => {
        return {
            'function-group': functionGroup,
            'function-name': functionName
        }
    });

    return details;
}

module.exports = generateFunctionDetails;
