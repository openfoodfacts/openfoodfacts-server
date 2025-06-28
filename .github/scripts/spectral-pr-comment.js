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
  let spectralOutput = '';
  let errorCount = 0;
  let warningCount = 0;
  let infoCount = 0;
  let hintCount = 0;
  
  try {
    spectralOutput = execSync('npx spectral lint -f json docs/api/ref/*.yaml', { 
      encoding: 'utf8',
      cwd: process.env.GITHUB_WORKSPACE 
    });
    
    const results = JSON.parse(spectralOutput);
    for (const result of results) {
      switch(result.severity) {
        case 0: errorCount++; break;
        case 1: warningCount++; break;
        case 2: infoCount++; break;
        case 3: hintCount++; break;
      }
    }
  } catch (error) {
    try {
      spectralOutput = execSync('npx spectral lint docs/api/ref/*.yaml', { 
        encoding: 'utf8',
        cwd: process.env.GITHUB_WORKSPACE 
      });
      
      errorCount = (spectralOutput.match(/error/gi) || []).length;
      warningCount = (spectralOutput.match(/warning/gi) || []).length;
      infoCount = (spectralOutput.match(/information/gi) || []).length;
      hintCount = (spectralOutput.match(/hint/gi) || []).length;
    } catch (e) {
      console.log('Could not run spectral:', e.message);
    }
  }
  
  const totalIssues = errorCount + warningCount + infoCount + hintCount;
  
  // Build simple comment with stats and command
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
  
  // Post comment to GitHub PR using curl
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
    // Output the comment body as fallback
    console.log(commentBody);
  }
}

main().catch(console.error);
