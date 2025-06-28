#!/usr/bin/env node

const fs = require('fs');
const { execSync } = require('child_process');

const context = {
  issue: {
    number: process.env.PR_NUMBER || 1
  },
  repo: {
    owner: process.env.GITHUB_REPOSITORY_OWNER || 'openfoodfacts',
    repo: (process.env.GITHUB_REPOSITORY || 'openfoodfacts/openfoodfacts-server').split('/')[1]
  }
};

async function main() {
  let errorCount = 0;
  let warningCount = 0;
  let infoCount = 0;
  let hintCount = 0;
  
  try {
    console.log('Running Spectral to get linting stats...');
    const spectralOutput = execSync('npx spectral lint -r .spectral.yaml -f json docs/api/ref/*.yaml', { 
      encoding: 'utf8',
      cwd: process.env.GITHUB_WORKSPACE || process.cwd()
    });
    
    const results = JSON.parse(spectralOutput);
    console.log(`Found ${results.length} total linting issues`);
    
    for (const result of results) {
      switch(result.severity) {
        case 0: errorCount++; break;
        case 1: warningCount++; break;
        case 2: infoCount++; break;
        case 3: hintCount++; break;
      }
    }
    
    console.log(`Parsed counts - Errors: ${errorCount}, Warnings: ${warningCount}, Info: ${infoCount}, Hints: ${hintCount}`);
    
  } catch (error) {
    console.log('JSON parsing failed, trying text output...');
    try {
      const spectralOutput = execSync('npx spectral lint -r .spectral.yaml docs/api/ref/*.yaml', { 
        encoding: 'utf8',
        cwd: process.env.GITHUB_WORKSPACE || process.cwd()
      });
      
      console.log('Spectral text output (first 1000 chars):');
      console.log(spectralOutput.substring(0, 1000));
      
      errorCount = (spectralOutput.match(/\s+error\s+/gi) || []).length;
      warningCount = (spectralOutput.match(/\s+warning\s+/gi) || []).length;
      infoCount = (spectralOutput.match(/\s+information\s+/gi) || []).length;
      hintCount = (spectralOutput.match(/\s+hint\s+/gi) || []).length;
      
      console.log(`Text parsed counts - Errors: ${errorCount}, Warnings: ${warningCount}, Info: ${infoCount}, Hints: ${hintCount}`);
      
    } catch (e) {
      console.log('Could not run spectral:', e.message);
      console.log('Working directory:', process.env.GITHUB_WORKSPACE || process.cwd());
      console.log('Spectral step outcome:', process.env.SPECTRAL_STEP_OUTCOME);
    }
  }
  
  const totalIssues = errorCount + warningCount + infoCount + hintCount;

  let commentBody = `## API Linting Results\n\n`;
  commentBody += `**Stats:**\n`;
  commentBody += `- Errors: ${errorCount}\n`;
  commentBody += `- Warnings: ${warningCount}\n`;
  commentBody += `- Info: ${infoCount}\n`;
  commentBody += `- Hints: ${hintCount}\n`;
  commentBody += `- **Total Issues: ${totalIssues}**\n\n`;
  
  commentBody += `**Run linting locally:**\n`;
  commentBody += `\`\`\`bash\n`;
  commentBody += `make check_openapi_spectral\n`;
  commentBody += `\`\`\``;
  
  const payload = JSON.stringify({
    body: commentBody
  });
  
  const curlCommand = `curl -X POST \
    -H "Authorization: token ${process.env.GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d '${payload.replace(/'/g, "'\\''")}' \
    "https://api.github.com/repos/${context.repo.owner}/${context.repo.repo}/issues/${context.issue.number}/comments"`;
  
  try {
    execSync(curlCommand, { stdio: 'inherit' });
    console.log('Posted comment to PR successfully');
  } catch (error) {
    console.error('Failed to post comment:', error.message);
    console.log(commentBody);
  }
}

main().catch(console.error);
