/*eslint no-console: "off"*/
/*eslint no-await-in-loop: "off"*/
/*global process */

const util = require('util');
const { spawn, execFile } = require('child_process');
const execFilePromise = util.promisify(execFile);

// Github actions have 2 CPUs: 
// https://docs.github.com/en/free-pro-team@latest/actions/reference/specifications-for-github-hosted-runners#supported-runners-and-hardware-resources
// Travis also seems to have 2 CPUs:
// https://docs.travis-ci.com/user/reference/overview/#virtualisation-environment-vs-operating-system

const maxRunning = 2;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function gitMtime(path) {
  const { stdout } = await execFilePromise('git', ['log', '-1', '--format="%at"', '--', path]);

  return parseInt(stdout.trim().replace(/"/g, '').trim(), 10);
}

async function main() {
  const files = [
    'additives_classes',
    'additives',
    'allergens',
    'amino_acids',
    'categories',
    'countries',
    'data_quality',
    'ingredients',
    'ingredients_analysis',
    'ingredients_processing',
    'labels',
    'languages',
    'minerals',
    'nova_groups',
    'nucleotides',
    'origins',
    'other_nutritional_substances',
    'packaging_materials',
    'packaging_recycling',
    'packaging_shapes',
    'states',
    'test',
    'vitamins'
  ];
  const taxonomiesToBuild = [];

  for (const file of files) {
    const txtPath = `taxonomies/${file}.txt`;
    const stoPath = `taxonomies/${file}.result.sto`;
    const txtMtimeMs = await gitMtime(txtPath);
    const stoMtimeMs = await gitMtime(stoPath);

    if (stoMtimeMs >= txtMtimeMs) {
      console.log(`${txtPath} is up-to-date`);
    }
    else {
      console.log(`${txtPath} needs to be rebuilt; ${txtMtimeMs} vs ${stoMtimeMs}`);
      taxonomiesToBuild.push(file);
    }
  }
  const numToBuild = taxonomiesToBuild.length;

  const spawns = [];
  
  console.log(`Building ${numToBuild} taxonomies, max ${maxRunning} processes...`);
  
  let running = Number.MAX_SAFE_INTEGER;

  // loop until we've popped all the files off the array
  while (taxonomiesToBuild.length > 0) {

    // count how many spawned processes don't have an exit code yet
    running = spawns.reduce((pv, cv) => {
      if (cv.exitCode === null && cv.signalCode === null) {
        return pv + 1;
      }
      else {
        return pv;
      }
    }, 0);

    // if we're not at the maximum number of processes, fire off another
    if (running < maxRunning) {
      try {

        const file = taxonomiesToBuild.shift();
        
        // Launch the Perl script to rebuild the taxonomy
        const perl = spawn(
          'perl',
          ['-CS', '-Ilib', 'scripts/build_tags_taxonomy.pl', file, '1'],
          { stdio: ['pipe', 'inherit', 'inherit'] }
        );
        spawns.push(perl);

        perl.on('close', (code, signal) => {
          if (code !== null) {
            console.log(`[${file}] child process exited with code ${code}`);

            if (code != 0) {
              process.exitCode = code;
            }
          }
          else if ( signal !== null ) {
            console.log(`[${file}] child process exited with signal ${signal}`);
            console.log('If this is in Travis: To make it rerun the workflow, close the pull request, wait a minute, and reopen it.');
            process.exitCode = 128; // consider a spawn getting killed a failure
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
      await sleep(250);
    }

  }

  console.log('Waiting for spawned processes to exit.');
  
  // don't return until all child processes have finished
  let lastMsg = new Date();
  running = Number.MAX_SAFE_INTEGER;
  while (running > 0) {
    running = spawns.reduce((pv, cv) => {
      if (cv.exitCode === null && cv.signalCode === null) {
        return pv + 1;
      }
      else {
        return pv;
      }
    }, 0);
    const now = new Date();
    const dateDiff = now - lastMsg;
    if (dateDiff >= 300000) {
      // Output a log statement at most and at least every 5 minutes,
      // because Travis CI jobs are assumed to be dead and get killed
      // after 10 Minutes of inactivity.
      console.log(`${running} processes still running`);
      lastMsg = now;
    }

    if (running > 0) {
      await sleep(250);
    }
  }

  console.log('Done!');
}

main();
