# Explanation on Docker Setup of pro platform for development

This explains how we setup docker file for pro platform development.
For explanations on how to use it, see: [how-to-guides/pro-development](how-to-develop-producer-platform.md)

off is the public facing application (world.openfoodfacts.org)
off-pro is the producers platform (world.pro.openfoodfacts.org)

When we work on the pro platform for development we want:
* off containers to talk between each other, and have their own volumes
* off-pro containers to talk between each other, and, generally, have their own volumes
* minion and backend from both app access to the same postgres database
  (which stores tasks queues)
* off and off-pro backends / minion needs to share some volumes :
  orgs, users ands some files living in podata

Still we would like to avoid having different clone of the repository,
but we can isolate projects thanks to `COMPOSE_PROJECT_NAME`,
which will prefix containers names, volumes and default network,
thus isolate each projects.

This is achieved by sourcing the .env-pro which setup some environment variables
that will superseed the .env variables.
The main one being setting `COMPOSE_PROJECT_NAME` and `PRODUCERS_PLATFORM`, but also other like `MINION_QUEUE`.

On volume side, we will simply give hard-coded names to volumes
that should be shared between off and pro platform, thus they will be shared.
Ideally we should not have to share single files but this is a work in progress,
we will live without it as a first approx.

To satisfy the access to the same database,
we will use postgres database from off as the common database.

In order to achieve that:
* we use profiles, so we won't start postgres in pro docker compose
* we connect `postgres`, `backend` and `minion` services to a shared network, called `minion_db`
Fortunately this works, but note that there is a pitfall:
on `minion_db` network both `backend` services (`off` and `off-pro`) will respond to same name.
For the moment it is not a problem for we don't need to communicate directly
between instances.
If it was, we would have to define custom aliases for those services on the `minion_db` network.

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
    +------frontend            |          frontend------------+
    +------mongodb             |          mongodb-------------+
    |                          |                              |
```