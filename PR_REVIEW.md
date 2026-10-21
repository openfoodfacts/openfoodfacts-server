The volume of PRs keeps increasing. Here are a few shortcuts and tips to help us manage the load.

### Tasks you can do to help
* Approve running tests on PRs made from forks, after quickly checking the code is not dangerous (eg Hashed contents, weird URLs, new dependancies)
* Solve merge conflicts
* /update_tests_results and /lint when tests are failing due to non updated tests
* Add any relevant missing labels
* Invoke Coderabbit if the changes are substantial / complex. @coderabbitai review to trigger one, we are rate limited, so do one or two every hour
* Check PRs that are duplicate of one-another, and add a little comment on both linking to the other one.
* (Reviewers) Adding the P1 Candidate label to impactful PRs that seem reasonably mergeable 

### Useful links
* PR that are interesting to be reviewed first: https://github.com/openfoodfacts/openfoodfacts-server/pulls?q=is%3Apr+state%3Aopen+label%3A%22%F0%9F%8E%AF+P1+candidate%22
* PRs that already got an initial AI review: https://github.com/openfoodfacts/openfoodfacts-server/pulls?q=is%3Apr+state%3Aopen+label%3A%22%F0%9F%90%B0+AI-Reviewed%22
* PRs that didn't get an initial AI review yet : https://github.com/openfoodfacts/openfoodfacts-server/pulls?q=is%3Apr+state%3Aopen+-label%3A%22%F0%9F%90%B0+AI-Reviewed%22
* PRs that are approved (but not merged yet): https://github.com/openfoodfacts/openfoodfacts-server/pulls?q=is%3Apr+state%3Aopen+review%3Aapproved
