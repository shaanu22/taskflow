require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const { register, httpRequestDuration, httpRequestTotal } = require('./metrics');

const app = express();
app.use(express.json());

// Database connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
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

// Health check — verifies database connectivity
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
    await pool.query('SELECT 1');
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
