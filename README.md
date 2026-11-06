# FastBite - Campus Food-Court Ordering Platform

Six Node.js microservices behind one API gateway, all storing data in MongoDB (one database per service),
packaged as containers and started with **one command**.

## Quick start (needs only `git` and Docker)

```bash
git clone https://github.com/ammar-yasar-267/fastbite-cafe-system.git
cd fastbite-cafe-system
./scripts/init-env.sh              # creates .env with random passwords (git-ignored)
docker compose up -d --build --wait
```

Open http://localhost:3000/menu. That is the only port published to the outside world.

| Want to...                      | Command                                  |
|---------------------------------|------------------------------------------|
| See Hamza's full order demo     | `./scripts/demo.sh`                      |
| Prove data survives restarts    | `./scripts/persistence-demo.sh`          |
| Stop (keep data)                | `docker compose down`                    |
| Start again                     | `docker compose up -d --wait`            |
| Wipe all data (careful!)        | `docker compose down -v`                 |
| Check no secrets are in source  | `./scripts/check-no-secrets.sh`          |
| Prove the code starts natively  | `./scripts/native-smoke.sh` (needs node + mongod) |

Windows: run the `.sh` scripts from Git Bash (it ships with Git for Windows).

## How it is put together

```
                  outside world
                       |  port 3000 (only published port)
                 +-----v------+
   edge network  | api-gateway|
                 +-----+------+
 ======================|================ backend network (internal: no inbound, no internet)
        +--------+-----+------+---------+---------+
        v        v            v         v         v
  menu-service order-service inventory customer  payment-service
     :3001       :3002       :3003      :3004       :3005
        \          |           |         |         /
         +---------+-----------+---------+--------+
                           mongo:27017   (volume: mongo-data)
```

* **Names, not localhost.** Containers reach each other by service name (`http://menu-service:3001`,
  `mongo`). The URLs are set in `docker-compose.yml` through the environment variables the code already supports.
* **One port outside.** Only `api-gateway` is attached to the public `edge` network and publishes a port.
  MongoDB and the five services sit on an `internal` network and cannot be reached from the host.
* **Data survives.** MongoDB writes to the named volume `mongo-data`. Stopping, removing or recreating
  containers does not touch it. Only `docker compose down -v` deletes it. Demo data is seeded only when a
  database is empty, so restarts never reset it.
* **Start order is automatic.** Health checks make each service wait for what it needs (mongo, then
  menu/inventory/customer, then order, then payment, then gateway). No more six terminals.

## Secrets policy

* No credential is ever stored in the source directory. `.env` (git-ignored) holds the MongoDB passwords and
  `scripts/init-env.sh` generates them randomly per machine. `.env.example` has empty placeholders.
* MongoDB requires a login. One application user can only read/write the five `fastbite_*` databases.
* The Docker Hub token lives only in **GitHub Secrets**, never in a file.
* `scripts/check-no-secrets.sh` runs in CI on every push and pull request and fails the build if it finds a
  MongoDB URL with a password, a Docker Hub/GitHub token or a private key.

## Publishing images (GitHub Actions)

`.github/workflows/publish-images.yml` runs on every push to `main`:

1. **test** - starts the whole platform and runs `scripts/demo.sh`. If anything fails, nothing is published.
2. **publish** - builds each of the six services as its own image and pushes it to Docker Hub.

One-time setup in the GitHub repo (Settings > Secrets and variables > Actions):

| Secret               | Value                                                              |
|----------------------|--------------------------------------------------------------------|
| `DOCKERHUB_USERNAME` | your Docker Hub username                                           |
| `DOCKERHUB_TOKEN`    | a Docker Hub access token (Account settings > Security > New token, Read & Write) |

Each image is named `<dockerhub-user>/fastbite-<service>` and gets these tags, so every package traces back to a commit:

| Tag                     | Meaning                                  |
|-------------------------|------------------------------------------|
| `sha-1a2b3c4`           | short id of the commit that produced it  |
| `<40-character commit>` | full commit id                           |
| `latest`                | newest build of `main`                   |

Labels `org.opencontainers.image.revision` and `org.opencontainers.image.source` on every image also record the
full commit id and this repository. Find the commit of any image with:
`docker inspect <image> --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'`

### Run the published images instead of building

```bash
export DOCKERHUB_USERNAME=<dockerhub-user>
export IMAGE_TAG=sha-1a2b3c4          # or latest
docker compose pull
docker compose up -d --wait
```

## Configuration (environment variables)

Every service reads settings from environment variables; `docker-compose.yml` sets them. Defaults (used when
running natively without Docker) are in the original table:

| Service             | Variable                | Default                                    |
|---------------------|-------------------------|--------------------------------------------|
| all services        | `PORT`                  | the service's port from the table below    |
| all except gateway  | `MONGO_URI`             | `mongodb://localhost:27017/<its database>` |
| menu, inventory, customer | `SEED_DATA`       | demo data is inserted when the database is empty; set `false` to disable |
| `api-gateway`       | `MENU_SERVICE_URL`, `ORDER_SERVICE_URL`, `INVENTORY_SERVICE_URL`, `CUSTOMER_SERVICE_URL`, `PAYMENT_SERVICE_URL` | `http://localhost:300x` |
| `order-service`     | `MENU_SERVICE_URL`, `INVENTORY_SERVICE_URL`, `CUSTOMER_SERVICE_URL` | `http://localhost:300x` |
| `payment-service`   | `ORDER_SERVICE_URL`     | `http://localhost:3002`                    |

## Services

| Folder              | Port | Responsibility                                                    | Database              |
|---------------------|------|-------------------------------------------------------------------|-----------------------|
| `api-gateway`       | 3000 | Single entry point, forwards requests to the right service         | none                  |
| `menu-service`      | 3001 | Menu items (name, price, availability)                             | `fastbite_menu`       |
| `order-service`     | 3002 | Coordinates an order (menu, customer, inventory, loyalty points)   | `fastbite_orders`     |
| `inventory-service` | 3003 | Stock levels, refuses to oversell                                  | `fastbite_inventory`  |
| `customer-service`  | 3004 | Customer profile and loyalty points                                | `fastbite_customers`  |
| `payment-service`   | 3005 | Verifies the amount against the order and records the payment      | `fastbite_payments`   |

## Demo data (inserted automatically on first start)

* Menu / stock: `M-101` Zinger Burger Rs. 450 (stock 80), `M-102` Fries Rs. 200 (stock 120),
  `M-103` Cold Drink Rs. 100 (stock 200), `M-104` Chai Rs. 80 (stock 150)
* Customers: `C-1042` Hamza Ali (150 points), `C-1043` Ayesha Khan (20 points)
* Loyalty: 1 point for every Rs. 10 spent; a free drink is unlocked at 200 points.

## API (through the gateway, `http://localhost:3000`)

| Method | Route                       | Body / notes                                                          |
|--------|-----------------------------|-----------------------------------------------------------------------|
| GET    | `/menu`                     | available menu items                                                  |
| GET    | `/customers/:customerId`    | profile and loyalty points                                            |
| POST   | `/customers/update-points`  | `{ "customerId": "C-1042", "points": 65 }`                            |
| GET    | `/inventory`, `/inventory/:itemId` | stock levels                                                   |
| POST   | `/inventory/update`         | `{ "items": [ { "itemId": "M-101", "quantity": 1 } ] }`               |
| POST   | `/orders`                   | `{ "customerId": "C-1042", "items": [ { "itemId": "M-101", "quantity": 1 }, { "itemId": "M-102", "quantity": 1 } ] }` |
| GET    | `/orders`, `/orders/:orderId` | stored orders                                                       |
| POST   | `/payments`                 | `{ "orderId": "ORD-XXXXXXXX", "amount": 650 }`                        |
| GET    | `/payments`, `/payments/:orderId` | recorded payments                                               |

Every service also answers `GET /health`.
