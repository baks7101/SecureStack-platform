const client = require('prom-client');

const register = new client.Registry();

client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
});

const loginAttemptsTotal = new client.Counter({
  name: 'login_attempts_total',
  help: 'Total login attempts',
  labelNames: ['status'],
  registers: [register]
});

const securityEventsTotal = new client.Counter({
  name: 'security_events_total',
  help: 'Total security events detected',
  labelNames: ['type'],
  registers: [register]
});

module.exports = {
  register,
  httpRequestsTotal,
  httpRequestDuration,
  loginAttemptsTotal,
  securityEventsTotal
};
