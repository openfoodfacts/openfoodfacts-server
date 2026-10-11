# Explanation on Docker Setup of pro platform for development

This explains how we setup docker file for pro platform development.
For explanations on how to use it, see: [how-to-guides/pro-development](how-to-develop-producer-platform.md)

off is the public facing application (world.openfoodfacts.org)
off-pro is the producers platform (world.pro.openfoodfacts.org)

When we work on the pro platform for development we want:
* off containers to talk to each other, and have their own volumes
* off-pro containers to talk to each other, and, generally, have their own volumes
* off and off-pro containers to talk to shared containers
  (from openfoodfacts-authentication and openfoodfacts-shared-services),
  see [dependencies](https://github.com/openfoodfacts/.github/blob/main/docs/service-dependencies.md)
* minion and backend from both apps to access the same postgres database
  (which stores tasks queues)
* off and off-pro backends / minion needs to share some volumes:
  orgs, users, product_images and some files living in podata

Still we would like to avoid having different clones of the repository,
but we can isolate projects thanks to `COMPOSE_PROJECT_NAME`,
which will prefix containers names, volumes and default network,
thus isolate each projects.

This is achieved by sourcing .env-pro which sets up some environment variables
that will supersede the .env variables.
The main one being setting `COMPOSE_PROJECT_NAME` and `PRODUCERS_PLATFORM`, but also others like `MINION_QUEUE`.

On the volume side, we will simply give hard-coded names to volumes
that should be shared between off and pro platform, thus they will be shared.
Ideally we should not have to share single files but this is a work in progress,
we will live without it as a first approx.

To satisfy the access to the same database,
we will use postgres database from off as the common database.

In order to achieve that:
* we use profiles, so we won't start postgres in pro docker compose
* we connect `postgres`, `backend` and `minion` services to a shared network, called `minion_db`
Fortunately this works, but note that there is a pitfall:
on the `minion_db` network both `backend` services (`off` and `off-pro`) will respond to the same name.
For the moment it is not a problem for we don't need to communicate directly
between instances.
If it were, we would have to define custom aliases for those services on the `minion_db` network.

```
network    OFF              network       PRO              network
po_default containers       minion_db     containers       po_pro_default
    |                          |                              |
    +------postgres------------+                              |
    |                          |                              |
    |                          |                              |
    +-----backend--------------+                              |
    |                          +----------backend-------------+
    |                          |                              |
    +------minion--------------+                              |
    |                          +----------minion--------------+
    |                          |                              |
    |                          |                              |
```

## Multi-Flavor Architecture (OBF, OPF, OPFF)

For custom flavors such as Open Beauty Facts (`obf`), Open Products Facts (`opf`), and Open Pet Food Facts (`opff`), isolation follows similar principles but with standalone datastores:

* **Independent Compose Projects & Shared Product History**: Each flavor has its own `COMPOSE_PROJECT_NAME` (e.g. `po_obf`), prefixing its containers. However, the `products` volume is explicitly shared across instances (`po_products`), alongside `product_images` (`po_off_product_images`), ensuring that revision files, changes, and product history remain fully accessible when products transition between flavors (e.g., moving between OFF and OBF).
* **Network & Port Isolation**: Each flavor defines its own internal network (`PRODUCT_OPENER_NETWORK`, e.g. `po_obf_network`) and maps to a distinct host port (e.g. 81 for OBF, 82 for OPF). Frontend network aliases are dynamically generated from `${PRODUCT_OPENER_DOMAIN}` to prevent DNS alias collisions. Furthermore, shared service networks (`COMMON_NET_NAME`) are flavor-scoped (e.g. `obf_shared_network`, `off_shared_network`) so Compose backend and minion service aliases do not collide across concurrent flavor instances.
* **Datastore & Task Queue Isolation**:
  * MongoDB uses flavor-specific databases (e.g. `obf`).
  * Standalone PostgreSQL instances retain the standard database name (`POSTGRES_DB=minion`), preserving compatibility with existing development `pgdata` volumes and healthchecks.
  * Task queue isolation is achieved via flavor-specific Minion queues (`MINION_QUEUE=openbeautyfacts.localhost`).
* **Shared Infrastructure**: On staging/production, common services (MongoDB, Redis) are accessed across instances over flavor-scoped shared networks.

