# Services

Default place for **Docker volume mounts** and service data, so containers can
expose and persist data in one predictable spot.

```
# e.g. a postgres volume
docker run -v ~/Documents/Services/postgres:/var/lib/postgresql/data postgres
```
