# Packager Codes Update Agents

This directory contains the automated scripts responsible for synchronizing food traceability and packaging codes from official national and international registries into the Open Food Facts database, and the output files.

## 🎯 Purpose
To ensure our packaging code files remain accurate and up-to-date without manual intervention. These scripts systematically fetch data from the official source URLs documented on the [Food Traceability Codes Wiki](https://wiki.openfoodfacts.org/Food_Traceability_Codes).

## 🤖 Agent Responsibilities
Any automated script or agent added to this directory should handle the following pipeline:

1. **Fetch:** Retrieve the latest packaging code data directly from the authoritative source (e.g., official government endpoints or registry files).
2. **Parse & Transform:** Convert the raw source data (HTML, CSV, PDF, etc.) into the standardized format expected by the Open Food Facts taxonomy. Use the most deterministic methods available.
3. **Validate:** Perform sanity checks on the fetched data before processing (e.g., ensure the payload isn't empty and the schema hasn't unexpectedly changed).
4. **Update:** Output the parsed data to update the local taxonomy files seamlessly.

## 🛠️ Development Guidelines

If you are writing a script to process codes (like the UK codes), please ensure your script adheres to the following rules:

* **Link to the Wiki:** At the top of your script, include a comment linking to the specific section on the wiki where the source URL and methodology are documented. 
* **Graceful Failures:** Official government URLs frequently change or go down. If the source is unreachable or the formatting breaks, the script must fail gracefully and log the error, rather than corrupting or wiping the existing database entries.
* **Idempotency:** Scripts should be safe to run repeatedly. Running an update twice in a row should not create duplicate entries.
* **Execution:** Ensure the script can be easily triggered via a cron job, GitHub Action, or standard command-line execution for regular, automated updates.
