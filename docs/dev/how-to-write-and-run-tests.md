# How to write and run tests

If you are a developer you are really encouraged to write tests as you fix bugs or develop new features.

Having a test is also a good way to debug a particular piece of code.

We would really love to see our test coverage grow.

If you are new to tests, please read:
- [introduction to test pyramids](https://automationstepbystep.com/2020/05/02/what-is-a-test-pyramid/) to understand importance of unit tests and integration tests
- [perldoc on test](https://perldoc.perl.org/Test)
- [Test::More module doc](https://perldoc.perl.org/Test::More)


## Unit and Integration tests

Unit tests are located in `tests/unit/`.

Integration tests are in `tests/integration/`.

Most integration tests issue queries to an open food facts

For some tests, we store expected results in form of HTML and JSON files (and some other formats like CSV).
See below on how you can use this mechanism and how to regenerate those files in case your modification affect them
(for example if you change the HTML of product pages).

## Integration with docker compose

Using Makefile targets, tests are run
* with a specific `COMPOSE_PROJECT_NAME° to avoid crashing your development data while running tests (as the project name [changes container, network and volumes names](https://docs.docker.com/compose/environment-variables/envvars/#compose_project_name))
* with a specific exposed port for Mongodb, to avoid clashes with the dev instance.

## Writing tests

You can read other tests to understand how we write them (get inspiration from recently created tests).

One effective way is to create a list of tests each represented by a hashmap with inputs and expected outputs and run them in a loop. Add an `id` and/or a `desc` (description) and use it as last argument to check functions (like `ok`, `is`, …) to easily see tests running and identify failing tests.

### Helpers

We have some helper functions for tests.

See mainly:
* [Test.pm](https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-perl-pod/ProductOpener/Test.html) (notably `init_expected_results` and `compare_to_expected_results`)
* [APITest.pm](https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-perl-pod/ProductOpener/APITest.html)

and other modules with Test in their name!


### Using JSON files to save expected results of tests

If the output of the function you are testing is small (e.g. a function that returns one single value), the expected return value can be stored in the .t test file.

If your outputs are complex and/or large (e.g. for unit tests of functions that return a complex structure, or for API integration tests that return a JSON response), you can use json files to store the expected result of each test.

[Test.pm](https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-perl-pod/ProductOpener/Test.html) contains helper functions to compare results to expected results and to update the expected results. For instance if your function returns a reference $results_ref to a complex object (like a product):

`compare_to_expected_results($results_ref, "$expected_result_dir/$testid.json", $update_expected_results);`

After writing the test, you need to use `init_expected_results` (see below) once to create a JSON file that contains the resulting object.

Then the next time you run the test, the results will be compared to the stored expected results.

You can also use `init_expected_results` to generate new expected results file and easily see what has changed using `git diff`. If the changes are expected, you can commit the new expected results.


## Running tests

The best way to run all tests is to run:

```bash
make tests
```

To run a single test you can use:

* for a unit test:
   ```bash
   make test-unit test="filename.t"
   ```
* for an integration test:
   ```bash
   make test-int test="filename.t"
   ```
## Regenerating tests results

If you made a change that affects stored expected results, you can use:

* to regenerate all expected results:
  ```bash
  make update_tests_results
  ```
* or to generate expected results for a single test
  (here for an integration test, `test-unit` otherwise)
  ```bash
  make test-int test="filename.t :: --update-expected-results"
  ```
  (the `::` tell the yath test runner that following arguments are for the test, not for yath)

If you regenerate test results, be sure to check carefully that the changes in your commit are expected.

**NOTE:** When making changes to language files (.pot, .po), make sure to run `make build_lang_test` so that the language files are rebuild in the test environment, before regenerating expected results for integration tests.

### Github action helper

You can trigger an update of tests results using a special comment on your PR.
See [How to use automated PR actions - updating tests-results](./how-to-use-automated-pr-actions.md#updating-tests-results)

## Debugging with tests

Starting a test is a very effective way to understand what's going on in the code using the debugger.

This is done by running the test with `perl -d`.
You can also use a "TEST_CMD" argument with the make target:

```bash
make test-unit test="my-test.t" TEST_CMD="perl -d"
```

Most often, you will have to use the next command "n" four times before landing in your test, where you can easily set a breakpoint with `b <line-number>`.

Read [perldoc about debugger](https://perldoc.perl.org/perldebug) to learn more.


> :pencil: Note: With this method, in integration tests that issue requests to the server, you won't be able to run the debugger inside the server code, only in the test.
>

## API Testing

This section describes how to write and run API-level tests for the Open Food Facts server.

### Purpose of API tests

API tests ensure that endpoints:
- Return correct HTTP status codes
- Produce valid and stable response structures
- Handle invalid inputs gracefully
- Do not introduce regressions over time

API tests are usually written as integration tests.

### Writing API tests

API tests are generally located in:

API tests usually rely on real HTTP requests made to the running server.
They verify that API endpoints behave as expected and return correct responses.

When writing API tests:
- Test both success and error cases
- Validate important fields in the JSON response
- Use clear test identifiers (`id` or `desc`) for easier debugging

Example API endpoint tested:

```http
GET /api/v2/product/3274080005003.json


## Some known errors

### test stops with Error 137

Sometimes you may get a test failing with no output but *error 137*.
It may simply means that the backend container was stopped.
Most of the time this is due to a fatal error that makes apache ends.

Beware that you may also have a completely unrelated message when running with the debugger,
mostly due to the fact that it is an abrupt kill of the process.
For example it can be a misleading message from `SSLeay.pm`
(because your test stop while waiting for the apache server to be ready)

The right reflex is to look at last logs in logs/apache (`ls -ltr logs/apache`)
and understand what is missing.

It might be as simple as a  `make build_taxonomies_test` or `make build_lang_test` is needed
(it is not run automatically for the single test targets)
