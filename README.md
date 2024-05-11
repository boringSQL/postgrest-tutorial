# Time Off Manager Tutorial

This repository is a source code of the Time Off Manager - tutorial published as part of [boringSQL](https://notso.boringsql.com).

You can find the individual parts of the tutorial here:

- [Part 1](https://notso.boringsql.com/posts/postgrest-tutorial-part1/)

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
psql time_off_manager <db/schema.sql
psql time_off_manager <db/seed.sql

```

## Configuration

Update the `db-uri` in included `postgrest.conf`.

## Usage

Here are some basic cURL commands to interact with the API:

- **Get all users:**
  ```bash
  curl "http://localhost:3000/users"
  ```

- **Add a new user:**
  ```bash
  curl -X POST "http://localhost:3000/users" \
       -H "Content-Type: application/json" \
       -d '{"email": "newuser@example.com", "manager_id": 1}'

- **Get the time off transaction for specific user**
  ```bash 
  curl "http://localhost:3000/time_off_transactions?user_id=eq.1"
  ```

## Contributing

Contributions are welcome! Please feel free to submit pull requests, create issues, or suggest improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```

