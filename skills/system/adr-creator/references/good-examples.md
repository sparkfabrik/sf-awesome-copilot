# Good ADR Examples

These examples demonstrate ADRs that follow Michael Nygard's format correctly.
Use them as a quality reference when writing new ADRs.

---

## Example 1: Infrastructure decision with tension between competing concerns

```markdown
# 5. Redis for Application Caching

Date: 2026-03-25

## Status

Accepted

## Context

The site experiences significant traffic during peak hours, handling approximately
50,000 requests per hour. Under this load, Drupal's built-in database cache has
become a performance bottleneck, adding roughly 200 milliseconds of latency to each
request. Because the cache backend shares the primary MySQL database, cache reads
compete with content queries for connection pool and I/O resources, amplifying the
problem as traffic scales.

The team evaluated two external caching solutions: Redis and Memcached. Both would
offload cache operations from the database and dramatically reduce per-request
latency. However, the project also requires a reliable queue processing backend for
background tasks such as search indexing, email dispatch, and content import jobs.
Redis natively supports list-based queue semantics, which means a single service can
fulfill both the caching and queue-processing roles. Memcached does not offer
comparable data-structure support and would require a separate queue backend.

There is a tension between operational simplicity — fewer moving parts — and the
added infrastructure complexity that any external service introduces. The team also
considered whether Drupal's database cache could be optimized (query tuning, table
partitioning), but benchmarks showed that even an optimized database cache could not
meet the sub-50 ms target at the current traffic volume.

## Decision

We will adopt Redis as the application cache backend, replacing Drupal's default
database cache. Drupal's cache bins will be configured to use the Redis module,
routing all cache reads and writes to a dedicated Redis instance. We will also use
Redis as the queue backend for background job processing, consolidating both
responsibilities in a single service.

The Redis instance will run alongside the existing Docker services in local
development and will be provisioned as a managed service (with replication) in
staging and production environments.

## Consequences

Replacing the database cache with Redis eliminates the approximately 200 ms
per-request overhead measured under peak load, bringing cache-hit latency well below
50 ms. This directly improves page load times and reduces pressure on the primary
MySQL database, freeing it to handle content queries more efficiently.

Consolidating caching and queue processing in a single Redis instance simplifies the
technology stack compared to running separate Memcached and queue services. The team
only needs to build operational expertise around one additional data store.

On the other hand, Redis becomes a critical infrastructure dependency. If the Redis
instance becomes unavailable, both caching and queue processing are affected
simultaneously, which could degrade the site more severely than if the two concerns
were decoupled. The team will need to plan for Redis high availability — at minimum a
replica set with automatic failover — in staging and production environments, adding
operational complexity and cost.

Developers must now maintain Redis configuration alongside the existing MySQL setup
in local, CI, and deployed environments. The Docker Compose stack will grow by one
service, and infrastructure-as-code definitions will need to account for Redis
provisioning, monitoring, and backup.

Finally, this decision opens the door for future use of Redis data structures beyond
caching and queues — for example, rate limiting, session storage, or real-time
counters — without introducing yet another service.
```

### Why this is good

- **Context is value-neutral.** It lays out the performance problem, names both
  alternatives (Redis and Memcached), and even mentions the option of optimizing
  the existing cache — all without advocating for the eventual choice.
- **Tensions are explicit.** "There is a tension between operational simplicity
  and the added infrastructure complexity" — this is exactly the kind of force
  balancing Nygard describes.
- **Decision is concrete and active.** "We will adopt Redis as the application
  cache backend" — clear subject, clear action, clear scope.
- **Consequences are balanced.** Positives (performance, consolidation), negatives
  (single point of failure, HA complexity, Docker stack growth), and a neutral
  forward-looking note (opens door for future Redis uses).
- **Full prose paragraphs.** Each section reads like a conversation with a future
  developer, not a list of bullet points.

---

## Example 2: Superseding a previous decision

```markdown
# 5. PostgreSQL for Primary Database

Date: 2026-03-25

## Status

Accepted

Supersedes [ADR 3](0003-mysql-for-primary-database.md)

## Context

The project currently uses MySQL 8.0 as its primary relational database, as recorded
in ADR 3. Since that decision was made, several forces have shifted.

Our application increasingly relies on storing and querying semi-structured data.
MySQL's JSON support, while functional, requires workarounds for complex queries and
lacks the expressive power of PostgreSQL's native JSON/JSONB operators and indexing
capabilities. Features that we need — such as partial JSON indexing and JSON path
expressions — are either unavailable or significantly less mature in MySQL.

Full-text search is another area of growing importance. The project needs to support
multilingual search, relevance ranking, and flexible tokenization. PostgreSQL's
built-in full-text search engine supports these requirements natively with
`tsvector`, `tsquery`, and configurable dictionaries, whereas MySQL's full-text
capabilities are more limited and would likely require an external search service to
meet our needs.

Finally, the composition of the team has changed. The majority of current developers
have deeper experience with PostgreSQL administration, performance tuning, and
tooling. Continuing with MySQL means the team operates outside its primary area of
expertise, which increases the risk of misconfiguration and slows down incident
response.

These three forces — better JSON support, stronger full-text search, and alignment
with team expertise — are all pulling in the same direction.

## Decision

We will migrate from MySQL 8.0 to PostgreSQL as the primary database for the
project. All new development will target PostgreSQL, and existing MySQL-specific
queries and schema definitions will be adapted during the migration. We will use
PostgreSQL 16 or later to take advantage of the latest JSON and performance
improvements.

## Consequences

Migrating to PostgreSQL enables richer JSON querying and indexing, which will
simplify the data access layer for semi-structured content and reduce the need for
application-level workarounds. It also gives us native full-text search capabilities
that are sufficient for our current requirements without introducing an external
search dependency.

The team will be working with a database engine they know well, which should improve
the quality of schema design, query optimization, and operational response times.
Onboarding new developers who already know PostgreSQL also becomes easier.

On the other hand, the migration itself carries risk and cost. Existing data must be
migrated carefully, with schema and query differences accounted for — MySQL and
PostgreSQL differ in areas such as auto-increment handling, case sensitivity, and
date/time types. Any Drupal modules or configuration that assume MySQL will need to
be reviewed and potentially replaced.

The hosting and infrastructure configuration will need to be updated to provision
PostgreSQL instead of MySQL. CI/CD pipelines, backup procedures, and monitoring
dashboards that reference MySQL must all be adapted.

This decision closes the door on MySQL-specific tooling and extensions the project
might have leveraged in the future, but opens up access to PostgreSQL's broader
ecosystem of extensions (e.g., PostGIS, pg_trgm) should the need arise.
```

### Why this is good

- **Superseding is explicit.** The Status section clearly links to the old ADR,
  and the Context opens by acknowledging the prior decision and explaining what
  changed.
- **Context narrates converging forces.** Three forces are presented individually,
  then tied together: "These three forces are all pulling in the same direction."
  This gives structure without resorting to a bullet list.
- **Technical detail serves the reader.** Naming `tsvector`/`tsquery`,
  auto-increment differences, and `PostGIS` gives a future developer actionable
  information — not just vague claims about "better support."
- **Consequences acknowledge doors closed.** "This decision closes the door on
  MySQL-specific tooling" — honest about trade-offs, not just benefits.
