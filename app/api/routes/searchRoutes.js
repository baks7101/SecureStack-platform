const express = require('express');
const router = express.Router();
const db = require('../models/db');

// DELIBERATELY VULNERABLE - SQL Injection
// This endpoint concatenates user input directly into SQL
// SAST (CodeQL) and DAST (ZAP) should both flag this
router.get('/users', (req, res) => {
  const { name } = req.query;

  if (!name) {
    return res.status(400).json({ error: 'Search query required' });
  }

  // VULNERABLE: string concatenation in SQL query
  const query = "SELECT id, name, email FROM users WHERE name LIKE '%" + name + "%'";

  db.query(query, (err, results) => {
    if (err) {
      // VULNERABLE: leaking internal error details to client
      return res.status(500).json({
        error: 'Database query failed',
        details: err.message,
        sql: err.sql
      });
    }
    res.json(results);
  });
});

// DELIBERATELY VULNERABLE - No authentication required
// Anyone can access this endpoint without a token
// This violates OWASP API Top 10: Broken Authentication
router.get('/admin/stats', (req, res) => {
  // VULNERABLE: no auth check, exposes sensitive data
  db.query(
    'SELECT COUNT(*) as total_users, role FROM users GROUP BY role',
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({
        stats: results,
        server_info: {
          node_version: process.version,
          platform: process.platform,
          uptime: process.uptime(),
          memory: process.memoryUsage()
        }
      });
    }
  );
});

module.exports = router;
