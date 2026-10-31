import assert from "node:assert/strict";
import test from "node:test";

import {findProblems, run} from "../../.github/scripts/pr_precheck.mjs";

const outsider = {association: "CONTRIBUTOR", files: ["lib/ProductOpener/Food.pm"], authorComments: [], linkedIssues: [{number: 1}]};
const visible = {...outsider, files: ["templates/web/pages/product/product_page.tt.html"]};

test("an outside pull request without a linked issue is asked for one", () => {
    assert.match(findProblems({...outsider, body: "", linkedIssues: []})[0], /Link the issue/);
});

test("a maintainer pull request without a linked issue passes", () => {
    assert.deepEqual(findProblems({...outsider, association: "MEMBER", body: "", linkedIssues: []}), []);
});

test("a taxonomy-only pull request does not need a linked issue", () => {
    assert.deepEqual(findProblems({...outsider, files: ["taxonomies/food/ingredients.txt"], body: "", linkedIssues: []}), []);
    assert.equal(findProblems({...outsider, files: ["taxonomies/food/ingredients.txt", "lib/ProductOpener/Food.pm"], body: "", linkedIssues: []}).length, 1);
    assert.equal(findProblems({...outsider, files: [], body: "", linkedIssues: []}).length, 1);
});

test("a template change needs a screenshot, a video, or no visible change written down", () => {
    assert.match(findProblems({...visible, body: "### Screenshot or video\n"})[0], /changes the UI/);
    assert.deepEqual(findProblems({...visible, body: "No visible change"}), []);
    assert.deepEqual(findProblems({...visible, body: "### What\r\n- [X] no visible change\r\n"}), []);
    assert.deepEqual(findProblems({...visible, body: "![after](https://github.com/user-attachments/assets/abc)"}), []);
    assert.deepEqual(findProblems({...visible, body: "", authorComments: ["<video src=demo.mp4>"]}), []);
});

test("the template's own hints do not count", () => {
    const body = "<!-- Insert a screenshot or a video ![x](a.png) -->\n<!-- No visible change -->";
    assert.equal(findProblems({...outsider, files: ["scss/_product.scss"], body}).length, 1);
    assert.equal(findProblems({...outsider, files: ["scss/_product.scss"], body: "<!<!-- -->-- ![x](a.png) -->"}).length, 1);
    assert.equal(findProblems({...outsider, files: ["scss/_product.scss"], body: "<!-- Insert a screenshot ![x](a.png)"}).length, 1);
});

test("Perl and test changes do not need a screenshot", () => {
    assert.deepEqual(findProblems({...outsider, files: ["lib/ProductOpener/Display.pm", "tests/js/tagify_init.test.mjs"], body: ""}), []);
});

const repository = {nameWithOwner: "o/r"};
const bot = (body) => ({id: 3, user: {type: "Bot", login: "github-actions[bot]"}, body});

function fakeGithub({pr = {}, files = [], comments = [], issues = [], payload = {pull_request: {number: 7, author_association: "CONTRIBUTOR"}}, removeLabel}) {
    const calls = [];
    const record = (name) => async (args) => {
        calls.push([name, args]);
    };
    const github = {
        paginate: async (method, args) => (await method(args)).data,
        rest: {
            pulls: {
                get: async () => ({data: {state: "open", draft: false, user: {login: "author", type: "User"}, body: "", labels: [], ...pr}}),
                listFiles: async () => ({data: files.map((file) => (typeof file === "string" ? {filename: file} : file))})
            },
            issues: {
                listComments: async () => ({data: comments}),
                createComment: record("create"),
                updateComment: record("update"),
                deleteComment: record("delete"),
                addLabels: record("label"),
                removeLabel: removeLabel || record("unlabel")
            }
        },
        graphql: async () => ({repository: {pullRequest: {closingIssuesReferences: {nodes: issues}}}})
    };
    return {github, context: {repo: {owner: "o", repo: "r"}, payload}, calls};
}

const names = (fake) => fake.calls.map(([name]) => name);

test("a pull request with problems gets one comment and the label", async () => {
    const fake = fakeGithub({});
    await run(fake);
    assert.deepEqual(names(fake), ["create", "label"]);
});

test("moving a file into taxonomies still needs a linked issue", async () => {
    const fake = fakeGithub({files: [{filename: "taxonomies/food.txt", previous_filename: "lib/ProductOpener/Food.pm"}]});
    await run(fake);
    assert.deepEqual(names(fake), ["create", "label"]);
});

test("a comment on the pull request runs the same check", async () => {
    const fake = fakeGithub({payload: {issue: {number: 7, author_association: "MEMBER"}}});
    await run(fake);
    assert.deepEqual(names(fake), []);
});

test("closed, draft and bot pull requests are skipped", async () => {
    for (const pr of [{state: "closed"}, {draft: true}, {user: {login: "dependabot[bot]", type: "Bot"}}]) {
        const fake = fakeGithub({pr});
        await run(fake);
        assert.deepEqual(names(fake), []);
    }
});

test("once fixed, the comment is deleted and the label removed", async () => {
    const fake = fakeGithub({pr: {labels: [{name: "needs-author"}]}, comments: [bot("<!-- pr-precheck -->\nold")], issues: [{number: 1, repository, closedByPullRequestsReferences: {nodes: []}}]});
    await run(fake);
    assert.deepEqual(names(fake), ["delete", "unlabel"]);
});

test("a label already removed by hand does not fail the run", async () => {
    const removeLabel = async () => {
        throw Object.assign(new Error("Not Found"), {status: 404});
    };
    const fake = fakeGithub({pr: {labels: [{name: "needs-author"}]}, issues: [{number: 1, repository, closedByPullRequestsReferences: {nodes: []}}], removeLabel});
    await assert.doesNotReject(run(fake));
});

test("a changed problem list updates the comment, an unchanged one is left alone", async () => {
    const first = fakeGithub({});
    await run(first);
    const current = first.calls[0][1].body;
    const changed = fakeGithub({pr: {labels: [{name: "needs-author"}]}, comments: [bot("<!-- pr-precheck -->\nold")]});
    await run(changed);
    assert.deepEqual(names(changed), ["update"]);
    const unchanged = fakeGithub({pr: {labels: [{name: "needs-author"}]}, comments: [bot(current)]});
    await run(unchanged);
    assert.deepEqual(names(unchanged), []);
});

test("only the author's own comments count as a screenshot", async () => {
    const shot = (login) => ({id: 5, user: {type: "User", login}, body: "![after](shot.png)"});
    const issues = [{number: 1, repository, closedByPullRequestsReferences: {nodes: []}}];
    const byAuthor = fakeGithub({files: ["scss/_product.scss"], comments: [shot("author")], issues});
    await run(byAuthor);
    assert.deepEqual(names(byAuthor), []);
    const byOther = fakeGithub({files: ["scss/_product.scss"], comments: [shot("someone")], issues});
    await run(byOther);
    assert.deepEqual(names(byOther), ["create", "label"]);
});

test("a comment by someone else that copies the marker is not edited", async () => {
    const copy = {id: 4, user: {type: "User", login: "author"}, body: "<!-- pr-precheck -->\ncopied"};
    const fake = fakeGithub({comments: [copy]});
    await run(fake);
    assert.deepEqual(names(fake), ["create", "label"]);
});

test("another open pull request for the same issue is mentioned, without the label", async () => {
    const nodes = [{number: 7, author: {login: "author"}, repository}, {number: 5, author: {login: "someone"}, repository}, {number: 9, author: {login: "else"}, repository: {nameWithOwner: "o/other"}}];
    const issues = [{number: 1, repository, closedByPullRequestsReferences: {nodes}}, {number: 2, repository: {nameWithOwner: "o/other"}, closedByPullRequestsReferences: {nodes}}];
    const fake = fakeGithub({pr: {labels: [{name: "needs-author"}]}, issues});
    await run(fake);
    assert.deepEqual(names(fake), ["create", "unlabel"]);
    const body = fake.calls[0][1].body;
    assert.match(body, /#5 is already open for #1/);
    assert.doesNotMatch(body, /#7 is|#9 is|for #2/);
});
