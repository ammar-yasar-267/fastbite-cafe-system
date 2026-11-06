// Runs once, the first time the MongoDB volume is empty.
// Creates ONE application user that can only read/write the five FastBite databases
// (each service still uses its own database). The password comes from the environment,
// never from this file.
const user = process.env.APP_DB_USER;
const pwd = process.env.APP_DB_PASSWORD;
const dbs = ['fastbite_menu', 'fastbite_orders', 'fastbite_inventory', 'fastbite_customers', 'fastbite_payments'];

db.getSiblingDB('admin').createUser({
  user,
  pwd,
  roles: dbs.map((name) => ({ role: 'readWrite', db: name })),
});
print('FastBite application user created for databases: ' + dbs.join(', '));
