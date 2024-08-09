Open Food Facts Server - Release Guide
======================================

Welcome to the release guide for the Open Food Facts Server. This guide outlines the process for releasing updates to the server, considering both the automated `.net` release and the manual `.org` release handled by @stephanegigandet.

https://world.openfoodfacts.org (production - manual by @stephanegigandet)
https://world.openfoodfacts.net (pre-production - automatic on each merge, including merges on openfoodfacts-web)
https://world.openfoodfacts.dev (experimental server - manual)

1. Pre-release Checklist
-------------------------

Before you proceed with the release, ensure the following:

-   [ ] All planned features, fixes, and data updates are merged into the `main` branch.
-   [ ] Automated tests pass successfully (normally it's not possible to merge to main if they fail)
-   [ ] Review the `CHANGELOG.md` to ensure it accurately reflects the changes in this release (if the PRs had proper names, this should be the case)
-   [ ] **Important**: Coordinate with @stephanegigandet if you need a manual `.org` release due to a time-sensitive event or a bug in production.

2. Trigger Automated `.net` Release
------------------------------------

1.  Merge a pull request
2.  The automated CI/CD pipeline will initiate the deployment to `.net` (20 min approx)
3.  Monitor the pipeline's logs for any errors or warnings.

3. Manual `.org` Release (Coordinated by @stephanegigandet)
--------------------------------------------------------------

1.  @stephanegigandet will initiate the deployment process to `.org`, that might involve database updates, running scripts and server configuration changes.
2.  Collaborate with @stephanegigandet to list and address any issues that arise during the `.org` deployment in the Slack #product-opener channel or in a github issue with the ```P0``` label

4. Verify Deployment
---------------------

-   [ ] Once both `.net` and `.org` deployments are complete, thoroughly test the production environment to ensure functionality, API and data integrity.
-   [ ] Verify that all expected changes are visible and working correctly on both `.net` and `.org`.

5. Post-release
----------------

1.  **Documentation**:
    -   If necessary, update relevant documentation (e.g., API docs, user guides) to reflect the changes in this release. This should be done in PR, rather that after-the-fact.
    -   Create issues in the mobile app, SDK package… if some behaviour changes or new features require action or enable opportunities there.
2.  **Communication**:
    -   If applicable, announce the release on the Open Food Facts slack, blog, forum, and social media channels (@stephanegigandet typically does this)
    -   Highlight significant new features or changes that might be of interest to the community.
  
3.  **Issue Tracking**:
    -   Check and close any relevant issues that have been addressed in this release, and not closed automatically by PRs
    -   Review the issue tracker for any follow-up tasks or bug reports that may have arisen.

6. Troubleshooting
-------------------

In the event of any issues:

1.  Immediately notify @stephanegigandet and other relevant team members.
2.  @stephanegigandet will revert to the previous stable version or correct on `.org`.
3.  Investigate the issue thoroughly, implement fixes, and redeploy after careful testing.

* * * * *

**Additional Notes:**

-   This guide is a living document and may evolve as processes change.
-   Feel free to suggest improvements or clarifications through the repository's issue tracker.
-   Open communication is key to a successful release.
