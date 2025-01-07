Open Food Facts Local Caching: A Tutorial
-----------------------------------------

Open Food Facts (OFF) offers a rich dataset of food product information. Creating a local cache can enhance performance for your heavy-duty applications. This tutorial will guide you through the process, considerations, and best practices.

### What is a Local Cache?

A local cache is a copy of OFF data stored directly on your system or server. This allows your application to retrieve information without constantly querying the main OFF API, improving speed and reliability.

### Current Caching Options

-   **FoodVisor Contributed (Python/MongoDB) backend:** The FoodVisor startup contributed a few years ago <a href="https://github.com/openfoodfacts/openfoodfacts-apirestpython">a Python-based backend with a MongoDB export</a>, providing a solid starting point for caching in Python environments.
-   **Project-Specific Caches:** Several OFF projects like open-prices and robotoff have implemented local caches for their own needs. While not immediately reusable, they can serve as valuable references.
-   **SDKs** We have [a number of official SDKs](../api.md#sdks) that can be leveraged as part of a caching backend. Please leverage and contribute to those 🙏
-   **You can start a project within Open Food Facts to solve this**

### Need for Diverse Solutions

We encourage developers who feel the need for very intensive operations not driven by user scans to create local caching solutions in various programming languages. These can be integrated into your own projects, and if well-designed, have the potential to become official OFF backends.

### When NOT to Cache

For applications primarily focused on user-generated requests, a local cache may not be necessary. The OFF API can handle such many such requests efficiently, and direct API usage contributes to valuable scan statistics for the project.

### Licensing and Data Sharing

Even when using a local cache, you're still bound by the Open Database License (ODbL). **Do not mix OFF data with external product data**. All additions or modifications made to OFF data must be shared back to OFF, preferably through the WRITE API. Consider incorporating this functionality into your cache implementation.
For more on legal issues [please read this page](./license-be-on-the-legal-side.md)

### Challenges of Cache Maintenance

Maintaining a cache can be complex due to the dynamic nature of OFF data.

-   **Immediate Updates:** Any writes to OFF data should first go through automatic moderation on your end (see our tutorial about this). After successful submission to OFF, your local cache should be immediately refreshed.
-   **Real-Time Notifications (Future):** Currently, there's no public API for real-time OFF updates stream. However, we have an internal system (REDIS) and are exploring options for a future 3rd party notification API. Express your interest by contacting <a href="mailto:reuse@openfoodfacts.org">reuse@openfoodfacts.org</a>.

### Building Your Own Cache

1.  **Choose Your Technology:** Select a database or storage mechanism suitable for your language and project needs.
2.  **Data Structure:** Design a structure to efficiently store product information, categories, ingredients, etc.
3.  **Synchronization:** Develop processes to regularly fetch updates from the OFF API and refresh your cache.
4.  **Data Validation:** Implement mechanisms to validate the accuracy and integrity of the cached data.
5.  **Sharing Back:** Integrate the OFF WRITE API to automatically share any new or modified data.

### Get Involved!

If you're building a local cache, we'd love to hear about it! Your contribution can benefit the entire OFF community. By sharing your solution, you have the opportunity to make it an official OFF backend.

Let's work together to make Open Food Facts data even more accessible and useful!
