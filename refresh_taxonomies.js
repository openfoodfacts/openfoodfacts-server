/*eslint no-console: "off"*/
/*eslint no-await-in-loop: "off"*/
/*global process require*/

const util = require('util');
const fs = require('fs');
const stat = util.promisify(fs.stat);
const { spawn } = require('child_process');

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const files = [
    'additives_classes',
    'additives',
    'allergens',
    'amino_acids',
    'categories',
    'countries',
    'ingredients',
    'labels',
    'languages',
    'minerals',
    'nova_groups',
    'nucleotides',
    'other_nutritional_substances',
    'test',
    'vitamins'
  ];

  const spawns = [];
  for (const file of files) {
    const txtPath = `taxonomies/${file}.txt`;
    const stoPath = `taxonomies/${file}.result.sto`;
    const txtStat = await stat(txtPath);
    let stoMtimeMs;
    try {
      const stoStat = await stat(stoPath);
      stoMtimeMs = stoStat.mtimeMs;
    }
    catch (e) {
      console.error(e);
      stoMtimeMs = 0;
    }

    if (stoMtimeMs >= txtStat.mtimeMs) {
      console.log(`${txtPath} is up-to-date`);
    }
    else {
      console.log(`${txtPath} needs to be rebuilt; ${txtStat.mtimeMs} vs ${stoMtimeMs}`);

      try {
        // Launch the Perl script to rebuild the taxonomy and output STDOUT
        // and STDERR to /dev/null, because Travis CI cannot take that much
        // build log information.
        const perl = spawn(
          'perl',
          ['-CS', '-Ilib', 'scripts/build_tags_taxonomy.pl', file, '1'],
          { stdio: ['pipe', 'ignore', 'ignore'] }
        );
        spawns.push(perl);

        perl.on('close', (code) => {
          console.log(`[${file}] child process exited with code ${code}`);

          if (code != 0) {
            process.exitCode = code;
          }
        });
      } catch (e) {
        console.error(e);
        process.exitCode = e.code;
        throw e;
      }
    }
  }

  console.log('Waiting for spawned processed to exit.');
  let running = Number.MAX_SAFE_INTEGER;
  let lastMsg = new Date();
  while (running > 0) {
    running = spawns.reduce((pv, cv) => {
      if (cv.exitCode === null) {
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
