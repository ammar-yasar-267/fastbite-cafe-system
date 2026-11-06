// FastBite API Gateway
// Single entry point for the mobile app. It contains no business logic and no
// database: it only forwards each request to the service that owns that route.
const express = require('express');
const proxy = require('express-http-proxy');

const PORT = process.env.PORT || 3000;

// Addresses of the services behind the gateway.
const MENU_SERVICE_URL = process.env.MENU_SERVICE_URL || 'http://localhost:3001';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://localhost:3002';
const INVENTORY_SERVICE_URL = process.env.INVENTORY_SERVICE_URL || 'http://localhost:3003';
const CUSTOMER_SERVICE_URL = process.env.CUSTOMER_SERVICE_URL || 'http://localhost:3004';
const PAYMENT_SERVICE_URL = process.env.PAYMENT_SERVICE_URL || 'http://localhost:3005';

const app = express();

app.get('/health', (req, res) => {
  res.json({ service: 'api-gateway', status: 'ok' });
});

const routes = {
  '/menu': MENU_SERVICE_URL,
  '/orders': ORDER_SERVICE_URL,
  '/inventory': INVENTORY_SERVICE_URL,
  '/customers': CUSTOMER_SERVICE_URL,
  '/payments': PAYMENT_SERVICE_URL,
};

for (const [prefix, target] of Object.entries(routes)) {
  app.use(
    prefix,
    proxy(target, {
      // forward the full original path (e.g. /menu/M-101) to the target service
      proxyReqPathResolver: (req) => req.originalUrl,
      proxyErrorHandler: (err, res) => {
        console.error(`Gateway error for ${prefix}: ${err.message}`);
        res.status(502).json({ error: `Service for ${prefix} is unavailable` });
      },
    })
  );
}

app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
});
