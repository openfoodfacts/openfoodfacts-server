# Using Repl

On your local dev instance, the "backend" container
comes with [Devel::REPL](https://metacpan.org/pod/Devel::REPL) installed.

Thanks to `PERL5LIB` variable which is already configured,
you can load any module of `ProductOpener` from within it.

Also it as the right

## Launch Repl

Just run

```
docker-compose run --rm docker-compose re.pl
```

If you want to access external services (like mongodb), do not forget to start them.


## Testing perl code

It can be a handy way to get your hand into perl by testing some code patterns,
or seeing how they react.

For example one can test a regular expression:

```perl
$ my $text = "Hello World";
Hello World
$ $text =~ /Hello (\w+)/i
World
```

## Reading a sto

Another use case is reading a sto file to see what it contains.

Eg. for a user:

```perl
$ use ProductOpener::Store qw/:all/;
$ my $user_id = "xxxx";
$ my $user_ref = retrieve("/mnt/podata/users/$user_id.sto");
```