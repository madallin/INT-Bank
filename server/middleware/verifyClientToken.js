const jwt = require('jsonwebtoken');

async function verifyClientToken(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing client token', code: 'NO_TOKEN' });
  }

  const token = auth.slice(7);

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.client = payload;
    return next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Token invalid', code: 'TOKEN_INVALID' });
  }
}

module.exports = verifyClientToken;
