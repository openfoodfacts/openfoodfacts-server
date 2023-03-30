# How to write and run tests

If you are a developer you are really encouraged to write tests as you fix bug or develop new features.

Having a test is also a good way to debug a particular piece of code.

We would really love to see our test coverage augment.

If you are new to tests, please read:
- [something about test pyramid](https://automationstepbystep.com/2020/05/02/what-is-a-test-pyramid/) to understand importance of unit tests and integration tests
- [perldoc on test](https://perldoc.perl.org/Test)
- [Test::More module doc](https://perldoc.perl.org/Test::More)


## Helpers

We have some helpers for tests.

See mainly:
* [Test.pm](https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-perl-pod/ProductOpener/Test.html) (notably `init_expected_results` and `compare_to_expected_results`)
* [TestAPI.pm](https://openfoodfacts.github.io/openfoodfacts-server/dev/ref-perl-pod/ProductOpener/APITest.html)

and other modules with Test in their name !


## Unit and Integration tests

Unit tests are located in `tests/unit/`.

Integration tests are in `tests/integration/`.

Most integration tests issue queries to an open food facts

## Integration with docker-compose

Using Makefile targets, tests are run 
* with a specific `COMPOSE_PROJECT_NAME° to avoid crashing your development data while running tests (as the project name [changes container, network and volumes names](https://docs.docker.com/compose/environment-variables/envvars/#compose_project_name))
* with a specific expose port for Mongodb, to avoid clashes with dev instance.

## Writing tests

You can read other tests to understand how we write them (inspire yourself from recently created tests).

One effective way is to create a list of tests each represented by a hashmap with inputs and expected outputs and run them in a loop. Add an `id` and/or a `desc` (description) and use it as last argument to check functions (like `ok`, `is`, …) to easily see tests running and identify failing tests.

If your outputs are consequent, you might use json files (one per tests), stored on disk. See tests using `init_expected_results` (and see below to refresh those files).


## Running tests

The best way to run all test is to run:

```bash
make tests
```

To run a single test you can use:
### On Windows:

* for unit test:
   ```bash
   make unit_test test="filename.t"
   ```
* for integration test:
   ```bash
   make int_test test="filename.t"
   ```
### On Other Systems:

* for unit test:
   ```bash
   make unit-test test="filename.t"
   ```
* for integration test:
   ```bash
   make int-test test="filename.t"
   ```
If you made change that impact stored expected results, you can use:

* to re-generate all expected results:
  ```bash
  make update_tests_results
  ```
* or to generate expected results for a single test
  (here for integration test, `unit-test` otherwise)
  ```bash
  make int-test="filename.t --update-expected results"
  ```

If you re-generate test results, be sure to look carefully that the changes your commit are expected changes.


## Debugging with tests

Launching a test is a very effective way to understand what's going on in the code using the debugger.

This is done calling the test with `perl -d`.
You can also use "args" argument with make target:

```bash
make test-unit test="my-test.t" args="-d"
```

Most of the time, you will have to use the next command "n" four times, before landing in you test, where you can easily set a breakpoint with `b <line-number>`.

Read [perldoc about debugger](https://perldoc.perl.org/perldebug) to learn. more.


> :pencil: Note: With this explanation, in integration tests that issue requests to the server, you won't be able to run the debugger inside the server code, only in the test.

