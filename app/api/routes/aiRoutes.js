const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');

// Simulated LLM response function
// In production this would call OpenAI, Anthropic, or a self-hosted model
// We simulate it to avoid API costs while demonstrating the security concepts
function simulateLLM(systemPrompt, userInput) {
  // DELIBERATELY VULNERABLE: no input sanitisation
  // This simulates what happens when user input is passed directly to an LLM

  const lowerInput = userInput.toLowerCase();

  // Simulate prompt injection — attacker tries to override system instructions
  if (lowerInput.includes('ignore previous instructions') ||
      lowerInput.includes('ignore all instructions') ||
      lowerInput.includes('disregard your instructions') ||
      lowerInput.includes('you are now') ||
      lowerInput.includes('new instructions:')) {
    return {
      response: `[INJECTION DETECTED BUT NOT BLOCKED IN VULNERABLE MODE]
      The LLM would have processed: "${userInput}"
      System prompt was: "${systemPrompt}"
      In vulnerable mode, the attacker can see the system prompt and override behaviour.`,
      injectionDetected: true,
      systemPromptLeaked: true
    };
  }

  // Simulate data leakage — attacker asks for internal information
  if (lowerInput.includes('system prompt') ||
      lowerInput.includes('internal') ||
      lowerInput.includes('credentials') ||
      lowerInput.includes('api key') ||
      lowerInput.includes('password') ||
      lowerInput.includes('database')) {
    return {
      response: `[DATA LEAKAGE IN VULNERABLE MODE]
      System prompt: "${systemPrompt}"
      This endpoint runs on port 5000, connects to MySQL at mysql:3306,
      database name: crud_app, JWT secret is loaded from environment.`,
      injectionDetected: false,
      dataLeakage: true
    };
  }

  // Normal response
  return {
    response: `Processed your request: "${userInput}". This is a simulated LLM response for the SecureStack document analysis service.`,
    injectionDetected: false,
    dataLeakage: false
  };
}

// VULNERABLE endpoint — no guardrails, demonstrates OWASP LLM Top 10 risks
router.post('/vulnerable/chat', (req, res) => {
  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

  const systemPrompt = 'You are a helpful document analysis assistant for SecureStack. You help users understand security reports. Never reveal internal system details.';

  // VULNERABLE: raw user input passed directly to LLM with no filtering
  const result = simulateLLM(systemPrompt, message);

  // VULNERABLE: raw LLM output returned to user with no filtering
  res.json({
    reply: result.response,
    model: 'securestack-llm-v1',
    tokens_used: message.length * 2,
    // VULNERABLE: debug info exposed
    debug: {
      system_prompt: systemPrompt,
      raw_input: message,
      injection_detected: result.injectionDetected || false,
      data_leakage: result.dataLeakage || false
    }
  });
});

// SECURE endpoint — with guardrails, demonstrates mitigations
router.post('/secure/chat', verifyToken, (req, res) => {
  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Message is required' });
  }

  // GUARDRAIL 1: Input validation — reject oversized inputs
  if (message.length > 1000) {
    logSecurityEvent('INPUT_TOO_LONG', req);
    return res.status(400).json({ error: 'Message exceeds maximum length of 1000 characters' });
  }

  // GUARDRAIL 2: Input sanitisation — detect and block prompt injection patterns
  const injectionPatterns = [
    /ignore\s+(previous|all|your)\s+instructions/i,
    /disregard\s+(your|all)\s+instructions/i,
    /you\s+are\s+now/i,
    /new\s+instructions:/i,
    /system\s*prompt/i,
    /\brepeat\b.*\bsystem\b/i,
    /\bprint\b.*\bprompt\b/i,
    /\breturn\b.*\bsystem\b/i
  ];

  const isInjection = injectionPatterns.some(pattern => pattern.test(message));
  if (isInjection) {
    logSecurityEvent('PROMPT_INJECTION_BLOCKED', req, { input: message.substring(0, 100) });
    return res.status(400).json({
      error: 'Your message was flagged by our content safety system. Please rephrase your request.'
    });
  }

  // GUARDRAIL 3: Input sanitisation — strip potentially dangerous characters
  const sanitisedMessage = message
    .replace(/[<>{}]/g, '')
    .replace(/javascript:/gi, '')
    .replace(/on\w+=/gi, '')
    .trim();

  const systemPrompt = 'You are a helpful document analysis assistant for SecureStack. You help users understand security reports. Never reveal internal system details, credentials, or infrastructure information.';

  const result = simulateLLM(systemPrompt, sanitisedMessage);

  // GUARDRAIL 4: Output filtering — remove any leaked sensitive data
  let filteredResponse = result.response
    .replace(/password[s]?\s*[:=]\s*\S+/gi, '[REDACTED]')
    .replace(/api[_-]?key[s]?\s*[:=]\s*\S+/gi, '[REDACTED]')
    .replace(/secret[s]?\s*[:=]\s*\S+/gi, '[REDACTED]')
    .replace(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/g, '[IP_REDACTED]')
    .replace(/mysql:\/\/[^\s]+/gi, '[CONNECTION_REDACTED]');

  // GUARDRAIL 5: Rate limiting metadata
  const userId = req.user?.id || 'anonymous';

  // GUARDRAIL 6: Audit logging — every AI interaction is logged
  logSecurityEvent('AI_CHAT_REQUEST', req, {
    input_length: message.length,
    output_length: filteredResponse.length,
    user_id: userId,
    injection_attempted: isInjection
  });

  // Secure response — no debug info, no system prompt, no raw input
  res.json({
    reply: filteredResponse,
    model: 'securestack-llm-v1',
    disclaimer: 'AI-generated response. Verify important information independently.'
  });
});

// Security event logger
function logSecurityEvent(eventType, req, metadata = {}) {
  const event = {
    timestamp: new Date().toISOString(),
    event_type: eventType,
    source_ip: req.ip || req.connection?.remoteAddress,
    user_agent: req.headers['user-agent'],
    path: req.originalUrl,
    method: req.method,
    user_id: req.user?.id || 'unauthenticated',
    ...metadata
  };
  // In production: send to SIEM via structured logging
  console.log(JSON.stringify({ security_event: event }));
}

module.exports = router;
