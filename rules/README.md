# Tags rules

Rules that add more precise tags to products from data that is already on the product
(e.g. `en:caffeinated-colas` for colas that are not caffeine-free).

The format of the rules files, the conditions, the design choices and how to test a rule are explained in
[docs/dev/explain-tags-rules.md](../docs/dev/explain-tags-rules.md).

Before changing a rule, run `make test-unit test=tags_rules.t`, then the dry run on the latest dump
(`scripts/tags_rules_report.pl`) and review the samples: a rule must show no false positive.
Paste the report lines of the changed rules in the pull request.
