# How can I learn the Perl programming language?

Here are some introductory resources to learn Perl:

## Quick start 

- [Perl Youtube Tutorial](https://www.youtube.com/watch?v=c0k9ieKky7Q) - Perl Enough to be dangerous // FULL COURSE 3 HOURS.
- [Perl - Introduction](https://www.tutorialspoint.com/perl/perl_quick_guide.htm) - Introduction to perl from tutorialspoint
- [Impatient Perl](https://blob.perl.org/books/impatient-perl/iperl.pdf) - PDF document for people wintrested in learning perl.

## Official Documentation

- [Perl.org](https://www.perl.org/) - Official Perl website with documentation, tutorials, and community resources.
- [Learn Perl](https://learn.perl.org/) - Perl programming language tutorials for beginners.
- [Perl Maven](https://perlmaven.com/) - Perl programming tutorials, tips, and code examples.

# See the logs while running Perl locally
## Types of logs
### Logs that are always printed
Those logs are like this:
```
$log->debug("extracting ingredients from text", {text => $text})
     if $log->is_debug();
```
or this:
```
$log->trace("compare_nutriments", {nid => $nid}) if $log->is_trace();
```

### Logs that you have to activate
Those logs are not printed by default. You have to "activate" them by editing the corresponding variable. For example, for **Ingredients.pm** you have to set the following variable to 1:
```my $debug_ingredients = 0;```

This type of logs is found in **Ingredients.pm** and **Tags.pm**

## See the logs
There is a make command to see (all) logs:  

```make tail```

Nevertheless, if you want to see only perl-related logs, you can either edit temporarily the **Makefile** (replace ```tail -f logs/**/*``` by following command. **Do not forget to rollback changes!**)file or directly run the following command in a terminal:
```tail -f logs/apache2/log4perl.log```

Additionally, sometimes you want to focus only to some specific logs in the code. In this case you can use combination of tail and grep commands to find specific text in the logs. For example this command will fetch all logs containing the text "found the first separator":
```tail -f logs/apache2/log4perl.log | grep -a "found the first separator"```

**Remark:** to 
