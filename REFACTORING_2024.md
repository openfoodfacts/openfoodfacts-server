# Refactoring ProductOpener

## Goals

This branch aims at breaking circular dependencies between ProductOpener/* modules.

The old architecture had many modules calling each other and sharing data
through global variables. As a result, the loading order is unpredictable,
and changes in one module may have unexpected remote effects within other
modules.

Here we try to create a directed acyclic graph (DAG) of dependencies :
modules at the bottom do not depend on any other internal module;
then modules at the next layer only depend on bottom modules, etc.

# New architecture

## Principle

Breaking dependencies will not be possible without restructuring the overall architecture :
tasks such as analyzing the incoming HTTP request, searching data,
performing computations on the data, building the HTTP response, etc. should sit
in different modules. The new proposed architecture follows the well-established
[Model-View-Controller pattern]( https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller).

# Classes

## Request.pm

Information about the incoming HTTP request (scriptname, params, query_string, body).
This is an abstraction over the request object from the future underlying Web framework.
This is a readonly object.

*Note* : in modperl the Apache2::Request object also holds information about the
response (for example `$r->headers_out->...`). Here this is different : the
response is handled in a separate class.

## Response.pm

Class for accumulating information necessary to build the HTTP response.
Mostly a write-only object.

## App.pm

Class instanciated at startup time for holding global information about the application
(paths to directories, global timestamps, etc.)

## Controller/*

Classes instanciated for the duration of a single HTTP request.

The controller receives a request object, may invoke a number of model objects
for working on data, and creates a response object.

The controller has a link to the app object.



## View/*

Generate the content responses in various formats (HTML, JSON, XML, whatever).


# Tasks

Not clear yet.

This will be a huge endeavour, it will require collective effort, but it's not ready
yet to organize subtasks.







