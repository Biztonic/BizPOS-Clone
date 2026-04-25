const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        if(isDirectory) {
            walkDir(dirPath, callback);
        } else {
            callback(path.join(dir, f));
        }
    });
}

const libDir = path.join(__dirname, 'lib');
walkDir(libDir, function(filePath) {
    if (filePath.endsWith('.dart')) {
        let content = fs.readFileSync(filePath, 'utf8');
        let regex = /\.withOpacity\((.*?)\)/g;
        if (regex.test(content)) {
            let replaced = content.replace(regex, '.withValues(alpha: $1)');
            fs.writeFileSync(filePath, replaced, 'utf8');
            console.log('Modified', filePath);
        }
    }
});
