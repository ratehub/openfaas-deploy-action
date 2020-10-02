// This script reads and lists all handlers from stack.yml to specified file

const yaml = require('js-yaml');
const fs = require('fs');

if (process.argv.length < 4) {
    console.log("Insufficient args supplied!")
    process.exit(1);
}

// Parse supplied arguments
const outputFile = process.argv[2];
const stackFile = process.argv[3]

try {
    // read stack.yml
    const stack = yaml.safeLoad(fs.readFileSync(stackFile, 'utf8'));

    // list all handlers
    const handlers = Object.keys(stack.functions).map(key => stack.functions[key].handler);

    // write to file
    fs.writeFileSync(outputFile, handlers);

    // Exit - success
    process.exit(0);

} catch (e) {
    console.log(`Error creating ${outputFile} file:`, e);
    // Exit - failed
    process.exit(1);
}
