const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? 
            walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

const directories = ['lib/screens', 'lib/widgets', 'lib/core', 'lib/utils'];

directories.forEach(dir => {
    if(fs.existsSync(dir)){
        walkDir(dir, function(filePath) {
            if(filePath.endsWith('.dart')) {
                let content = fs.readFileSync(filePath, 'utf8');
                let newContent = content.replace(/\.withValues\(\s*alpha\s*:\s*([0-9.]+)\s*\)/g, '.withOpacity($1)');
                if(content !== newContent) {
                    fs.writeFileSync(filePath, newContent, 'utf8');
                    console.log('Updated: ' + filePath);
                }
            }
        });
    }
});
