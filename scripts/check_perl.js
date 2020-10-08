/*eslint no-console: "off"*/
/*eslint no-await-in-loop: "off"*/

const process = require("process");
const util = require("util");
const glob = util.promisify(require("glob").glob);
const { spawn } = require("child_process");

function checkFile(path, doneCallback) {
  console.log(`Checking ${path}`);
  try {
    const child = spawn(`perl`, ["-c", "-CS", "-Ilib", path]);
    child.stdout.on("data", (data) => console.log("[" + path + "] " + data));
    child.stderr.on("data", (data) => console.error("[" + path + "] " + data));
    child.on("close", (code) => {
      console.log("[" + path + "] result: " + code);
      if (code != 0) {
        process.exitCode = code;
      }
      doneCallback();
    });
  } catch (e) {
    console.error("[" + path + "] " + e);
    process.exitCode = e.code;
    throw e;
  }
}

const check = util.promisify(checkFile);

async function main() {
  // 0 = node; 1 = check_perl.js
  for (const arg of process.argv.slice(2)) {
    const files = await glob(arg);
    for (var i = 0; i < files.length; ++i) {
      const path = files[i];
      await check(path);
    }
  }

  console.log("Done!");
}

main();
