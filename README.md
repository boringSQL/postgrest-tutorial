# Time Off Manager Tutorial

This repository is a source code of the Time Off Manager - tutorial published as part of [boringSQL](https://notso.boringsql.com).

You can find the individual parts of the tutorial here:

- [Part 1](https://notso.boringsql.com/posts/postgrest-tutorial-part1/)
- [Part 2](https://notso.boringsql.com/posts/postgrest-tutorial-part2/)

## Prerequisites

Before you begin, ensure you have the following installed on your system:
- PostgreSQL
- postgREST

## Clone the repository

```bash
git clone https://github.com/yourusername/time-off-manager.git
cd time-off-manager
```

## Initilize the database

Create the database

```bash
psql template1 -c "CREATE DATABASE time_off_manager"
```

Create the schema and seed the database
```bash
psql time_off_manager <db/001_part1_schema.sql
psql time_off_manager <db/002_part2_api.sql
psql time_off_manager <db/seed.sql
```

## Starting the server

Before you can start the server, please, update the `db-uri` in included `postgrest.conf`. Once updated simply start the postgREST server 

```bash
postgrest
```

## Usage

Here are some basic cURL commands to interact with the API:

- **Get all users:**
  ```bash
  curl "http://localhost:3000/users"
  ```

- **Add a new user:**
  ```bash
  curl "http://localhost:3000/rpc/add_user" -X POST \
	-d '{ "email": "admin2@example.com", "manager_id": 2 }' \
	-H "Content-Type: application/json"
   ```

- **Request time off for specific user**
  ```bash 
  curl -X POST "http://localhost:3000/rpc/request_time_off" \
	-d '{"user_id": 6, "leave_type": "vacation", "period": "[2024-05-20,2024-05-21]"} ' \
	-H "Content-Type: application/json"
  ```

- **Approve the time off request**
  ```bash
  curl -X POST "http://localhost:3000/rpc/update_request" \
	-d '{"request_id": 1, "user_id": 2, "new_status": "approved"}' \
	-H "Content-Type: application/json"
  ```

## Contributing

Contributions are welcome! Please feel free to submit pull requests, create issues, or suggest improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```

