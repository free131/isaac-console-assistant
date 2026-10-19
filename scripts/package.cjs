const {execFileSync}=require('node:child_process');
const path=require('node:path');
execFileSync('python',[path.join(__dirname,'package.py')],{cwd:path.join(__dirname,'..'),stdio:'inherit'});
