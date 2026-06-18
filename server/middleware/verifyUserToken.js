// middleware/verifyUserToken.js
// Middleware JWT pentru utilizatori autentificați (accessToken)

const jwt = require('jsonwebtoken');

function verifyUserToken(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing access token', code: 'NO_TOKEN' });
  }

  const token = auth.slice(7);

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.userId;
    req.userRole = payload.role || 'user';
    return next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Access token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Access token invalid', code: 'TOKEN_INVALID' });
  }
}

module.exports = verifyUserToken;
