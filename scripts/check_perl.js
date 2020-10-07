/*eslint no-console: "off"*/
/*eslint no-await-in-loop: "off"*/

const process = require("process");
const util = require('util');
const glob = util.promisify(require("glob").glob);
const { spawn } = require('child_process');

// Github actions have 2 CPUs: 
// https://docs.github.com/en/free-pro-team@latest/actions/reference/specifications-for-github-hosted-runners#supported-runners-and-hardware-resources
// Travis also seems to have 2 CPUs:
// https://docs.travis-ci.com/user/reference/overview/#virtualisation-environment-vs-operating-system

const maxRunning = 2;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {

  const filesToCheck = [];

  // build array of paths from given arguments
  // 0 = node; 1 = check_perl.js
  for (const arg of process.argv.slice(2)) {
    const files = await glob(arg);
    for (var i = 0; i < files.length; ++i) {
      filesToCheck.push(files[i]);
    }
  }
  const numFilesToCheck = filesToCheck.length;

  const spawns = [];

  console.log(`Checking ${numFilesToCheck} files, max ${maxRunning} processes...`);

  let running = Number.MAX_SAFE_INTEGER;

  // loop until we've popped all the files off the array
  while (filesToCheck.length > 0) {

    // count how many spawned processes don't have an exit code yet
    running = spawns.reduce((pv, cv) => {
      if (cv.exitCode === null) {
        return pv + 1;
      }
      else {
        return pv;
      }
    }, 0);

    // if we're not at the maximum number of processes, fire off another
    if (running < maxRunning) {
      try {

        const file = filesToCheck.shift();
        console.log(`Queueing ${file}`);

        const perl = spawn(
          'perl', 
          ["-c", "-CS", "-Ilib", file ],
        );
        spawns.push(perl);

        // prefix any output with the relevant file name. trim() for double newlines.
        perl.stdout.on("data", (data) => console.log("[" + file + "] " + data.toString().trim() ));
        perl.stderr.on("data", (data) => console.error("[" + file + "] " + data.toString().trim() ));

        perl.on('close', (code, signal) => {
          if (code !== null) {
            console.log(`[${file}] child process exited with code ${code}`);
            if (code != 0) {
              process.exitCode = code;
            }
          }
          else if ( signal !== null ) {
            console.log(`[${file}] child process exited with signal ${signal}`);
          }
        });

      } catch (e) {
        console.error(e);
        process.exitCode = e.code;
        throw e;
      }
    }

    // wait before looping
    if (running > 0) {
      await sleep(100);
    }

  }

  console.log('Finished queueing files.');

  // don't return until all child processes have finished
  running = Number.MAX_SAFE_INTEGER;
  while (running > 0) {
    running = spawns.reduce((pv, cv) => {
      if (cv.exitCode === null) {
        return pv + 1;
      }
      else {
        return pv;
      }
    }, 0);

    if (running > 0) {
      await sleep(100);
    }
  }

  console.log("Done!");
}

main();
