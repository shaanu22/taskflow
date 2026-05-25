require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const { register, httpRequestDuration, httpRequestTotal } = require('./metrics');

const app = express();
app.use(express.json());

// Lazy pool — does not connect until first query
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

// Handle pool errors without crashing
pool.on('error', (err) => {
  console.error('Unexpected database pool error:', err.message);
});

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode,
    };
    httpRequestDuration.observe(labels, duration);
    httpRequestTotal.inc(labels);
  });
  next();
});

// Health check — verifies database connectivity without crashing
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    checks: {
      api: 'ok',
      database: 'unknown',
    },
  };

  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    health.checks.database = 'ok';
  } catch (err) {
    health.status = 'degraded';
    health.checks.database = 'error';
    health.checks.database_error = err.message;
    return res.status(503).json(health);
  }

  res.json(health);
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`TaskFlow API running on port ${PORT}`);
});

// Liveness probe — is the process alive? Never checks dependencies
app.get('/live', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
