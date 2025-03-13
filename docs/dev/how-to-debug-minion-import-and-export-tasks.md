# How to debug Minion import and export tasks

For imports on the pro platform, and exports from the pro platform and imports on the public platform, we use Minion tasks.

Those tasks are run by a Minion worker service, which is configured in /etc/systemd/system/minion\@off.service

## Log files

in the logs directory, we have:
- minion.log - states which tasks are started
- minion_log4perl.log - debug messages from the Perl code that implements the Minion tasks

## Checking the status of Minion tasks (jobs)

````
off@off:/srv/off$ (off) ./scripts/minion_producers.pl minion job 
[..]
132132  inactive  pro.openfoodfacts.org  update_export_status_for_csv_file
132131  failed    openfoodfacts.org      import_csv_file
132130  finished  pro.openfoodfacts.org  export_csv_file
````

## Debugging failed import of pro platform data on public platform

The following are notes on how a specific issue was debugged in production:

We now are loading automatically Systeme U (a big French retailer) imports in the producers platform.

The checkbox in the Systeme U organization (admin field) to automatically export new products is checked, but the products have not been loaded on the producers platform.

We can launch the export and import manually:

off@off-pro:/srv/off-pro$ (off-pro) scripts/export_and_import_to_public_database.pl --query states_tags=en:to-be-exported --owner org-systeme-u

And we can see the details of the corresponding minion jobs:

````
off@off-pro:/srv/off-pro$ (off-pro) ./scripts/minion_producers.pl minion job
[..]
132132  inactive  pro.openfoodfacts.org  update_export_status_for_csv_file
132131  failed    openfoodfacts.org      import_csv_file
132130  finished  pro.openfoodfacts.org  export_csv_file
````

In the off container, there is little useful information in the logs:

/srv/off/logs/minion.log:

````
import_csv_file_task - job: 132131 started - args: {"comment":"Import from producers platform","csv_file":"/srv/off-pro/export_files/org-systeme-u/export.1741792171.exported.csv","global_values":{"data_sources":"Producers, Producer - systeme-u"},"query":{"owner":"org-systeme-u","states_tags":"en:to-be-exported","data_quality_errors_producers_tags.0":{"$exists":false},"code":"3256221408515"},"export_job_id":132130,"source_id":"org-systeme-u","manufacturer":1,"org_id":"systeme-u","export_id":1741792171,"include_images_paths":1,"user_id":"org-systeme-u","source_name":"systeme-u","include_obsolete_products":1,"exported_t":1741792171,"owner_id":"org-systeme-u"}
````

To get more data (debug level) in minion_log4perl.log:

We can stop the minion daemon

as the root user: `systemctl stop minion@off.service`

And run it manually as a normal process

as the off user:
```bash
sudo -u off bash
source env/setenv off
TAP_LOG_FILTER=none perl scripts/minion_producers.pl minion worker -m production
```

I added a print STDERR in Import.pm to see if a specific product is causing the problem:

```
Import.pm - org: systeme-u - code: 3256221408515
```

Trying to export this single product indeed fails.

Last lines in minion_log4perl.log:

````
[24193] /srv/off/lib/ProductOpener/TaxonomiesEnhancer.pm 257 ProductOpener.TaxonomiesEnhancer {} check_ingredients_between_languages > detect_missing_stop_words_before_list -   first ingredient in ingredients1 (fr:ble-dur-precuit-concasse) is unknown (is_in_taxonomy => 1) or first ingredient in ingredients2 is known (is_in_taxonomy => 1)
[24193] /srv/off/lib/ProductOpener/TaxonomiesEnhancer.pm 356 ProductOpener.TaxonomiesEnhancer {} check_ingredients_between_languages > detect_missing_stop_words_after_list - start, lang1: fr, lang2: en
[60104] scripts/minion_producers.pl 87 main {minion_backend => [..] minion producers workers stopped
````

Unfortunately there's no clearer error message.

To debug it, I added print STDERR statements in TaxonomiesEnhancer.pm, to try to see where it stopped.

The following line is the error:

````
                $log->debug(
                        "check_ingredients_between_languages > detect_missing_stop_words_after_list -   too much difference between languages to raise warning. diff/total > tolerance: $translation_difference_count / $#$ingredients1 = "
                                . $translation_difference_count / $#$ingredients1 . " > "
                                . $translation_difference_accepted_percentage)
                        if $log->is_debug();
````

`$#array` is equal to `0` when `@array` contains 1 element, so it makes a `division by 0 error` and the task fails. But unfortunately I could not find any log where this division by zero error was reported, the only thing we get from Minion is that the task failed...


**Finally:** don't forget to **restart the minion service** !

```bash
sudo systemctl start minion@off.service
