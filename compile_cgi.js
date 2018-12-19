/*eslint no-console: "off"*/
/*eslint no-await-in-loop: "off"*/
/*global process*/

const util = require('util');
const glob = util.promisify(require('glob').glob);
const execFile = util.promisify(require('child_process').execFile);

async function main() {
  const files = await glob('cgi/*.pl');
  for (var i = 0; i < files.length; ++i) {
    const path = files[i];
    console.log(`Compiling ${path}`);
    try {
      const {stdout, stderr} = await execFile(`perl`, ['-c', '-CS', '-Ilib', files[i]]);
      if (stderr) {
        console.error(stderr);
      }

      console.log(stdout);
    } catch (e) {
      console.error(e);
      process.exitCode = e.code;
      throw e;
    }
  }

  console.log('Done!');
}

main();
