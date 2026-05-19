const promClient = require('prom-client');

promClient.collectDefaultMetrics({ prefix: 'taskflow_' });

const httpRequestDuration = new promClient.Histogram({
  name: 'taskflow_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
});

const httpRequestTotal = new promClient.Counter({
  name: 'taskflow_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

module.exports = {
  register: promClient.register,
  httpRequestDuration,
  httpRequestTotal,
};
