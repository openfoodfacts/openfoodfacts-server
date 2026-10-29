// Checks a pull request for what reviewers ask for first, and keeps one comment up to date.

const MARKER = "<!-- pr-precheck -->";
const LABEL = "needs-author";
const MEMBERS = ["OWNER", "MEMBER", "COLLABORATOR"];
// Perl is left out on purpose: most Perl changes alter data, not what the page looks like.
const VISIBLE_FILES = /^(templates|scss|html\/js|html\/css)\//;
const MEDIA = /!\[|<img|<video|user-attachments\/assets\/|\.(png|jpe?g|gif|webp|mp4|mov|webm)\b/i;
const NO_VISIBLE_CHANGE = /no visible change/i;

function stripComments(text) {
    return (text || "").replace(/<!--[\s\S]*?-->/g, "");
}

export function findProblems({body, association, files, authorComments, linkedIssues}) {
    const problems = [];
    const text = stripComments(body);
    if (!MEMBERS.includes(association) && linkedIssues.length === 0) {
        problems.push("Link the issue this fixes, with `Fixes #123` in the description. Pull requests are only accepted for an issue a maintainer agreed to.");
    }
    const visible = files.some((file) => VISIBLE_FILES.test(file));
    const media = [text, ...authorComments].some((comment) => MEDIA.test(comment));
    if (visible && !media && !NO_VISIBLE_CHANGE.test(text)) {
        problems.push("This pull request changes the UI. Please add a screenshot or video to the description, or write \"No visible change\" in the description if nothing looks different.");
    }
    return problems;
}

export function duplicateNotes(otherPullRequests) {
    return otherPullRequests.map(({number, issue}) => `#${number} is already open for #${issue}. Please check with its author or in the issue, so you don't both work on the same thing.`);
}

export function commentBody(problems, notes) {
    const lines = [...problems, ...notes].map((line) => `- ${line}`).join("\n");
    return `${MARKER}\nThanks for the pull request! Before a review:\n\n${lines}\n\nThis comment updates by itself when the description changes.`;
}

export async function run({github, context}) {
    const {owner, repo} = context.repo;
    const event = context.payload.pull_request || context.payload.issue;
    const number = event.number;
    const pr = (await github.rest.pulls.get({owner, repo, pull_number: number})).data;
    if (pr.state !== "open" || pr.draft || pr.user.type === "Bot") {
        return;
    }

    const files = (await github.paginate(github.rest.pulls.listFiles, {owner, repo, pull_number: number, per_page: 100})).map((file) => file.filename);
    const comments = await github.paginate(github.rest.issues.listComments, {owner, repo, issue_number: number, per_page: 100});
    const authorComments = comments.filter((comment) => comment.user.login === pr.user.login).map((comment) => comment.body);

    const {repository} = await github.graphql(`query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) { pullRequest(number: $number) { closingIssuesReferences(first: 5) { nodes {
            number repository { nameWithOwner }
            closedByPullRequestsReferences(first: 10, includeClosedPrs: false) { nodes { number author { login } repository { nameWithOwner } } }
        } } } }
    }`, {owner, repo, number});
    const issues = repository.pullRequest.closingIssuesReferences.nodes;
    const here = (node) => node.repository.nameWithOwner === `${owner}/${repo}`;
    const otherPullRequests = issues.filter(here).flatMap((issue) => issue.closedByPullRequestsReferences.nodes
        .filter((other) => here(other) && other.author?.login !== pr.user.login)
        .map((other) => ({number: other.number, issue: issue.number})));

    const problems = findProblems({body: pr.body, association: event.author_association, files, authorComments, linkedIssues: issues});
    const notes = duplicateNotes(otherPullRequests);
    const body = commentBody(problems, notes);
    const existing = comments.find((comment) => comment.user.login === "github-actions[bot]" && comment.body.startsWith(MARKER));

    if (problems.length + notes.length === 0) {
        if (existing) {
            await github.rest.issues.deleteComment({owner, repo, comment_id: existing.id});
        }
    } else if (!existing) {
        await github.rest.issues.createComment({owner, repo, issue_number: number, body});
    } else if (existing.body !== body) {
        await github.rest.issues.updateComment({owner, repo, comment_id: existing.id, body});
    }

    const labelled = pr.labels.some((label) => label.name === LABEL);
    if (problems.length > 0 && !labelled) {
        await github.rest.issues.addLabels({owner, repo, issue_number: number, labels: [LABEL]});
    }
    if (problems.length === 0 && labelled) {
        // a maintainer may have removed it by hand in the meantime
        await github.rest.issues.removeLabel({owner, repo, issue_number: number, name: LABEL}).catch((error) => {
            if (error.status !== 404) {
                throw error;
            }
        });
    }
}
