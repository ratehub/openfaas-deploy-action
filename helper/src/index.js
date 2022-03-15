const getDiff = require('./getDiff');
const getStackFiles = require('../../common/getStackFiles');
const getStackFunctions = require('../../common/getStackFunctions');
const generateFunctionDetails = require('./generateFunctionDetails');
const analyseUpdatedFiles = require('./analyseUpdatedFiles');


module.exports = {
    getDiff,
    getStackFiles,
    getStackFunctions,
    generateFunctionDetails,
    analyseUpdatedFiles,
};
