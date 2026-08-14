// quiet: true suppresses dotenv's startup log line, which as of v17 also
// rotates in unrelated self-promotional "tips" from the package maintainer.
require('dotenv').config({ quiet: true });
const express = require('express');
const { plaidClient } = require('./plaid');
const { saveItem, loadItem, clearItem } = require('./storage');
const { Products, CountryCode } = require('plaid');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4001;

// Single-user app — one fixed client_user_id is enough, no auth system needed.
const CLIENT_USER_ID = 'mooney-single-user';

// Plaid errors arrive as a structured object (err.response.data); everything
// else is a plain Error. Normalize both to a single display string so the
// iOS client never has to guess the shape of the "error" field on the wire.
function errorMessage(err) {
  const data = err.response?.data;
  if (data && typeof data === 'object') {
    return data.error_message || JSON.stringify(data);
  }
  return err.message || 'Unknown error';
}

app.post('/link_token', async (req, res) => {
  try {
    const response = await plaidClient.linkTokenCreate({
      client_name: 'Mooney',
      language: 'en',
      country_codes: [CountryCode.Us],
      user: { client_user_id: CLIENT_USER_ID },
      products: [Products.Balance],
      redirect_uri: process.env.PLAID_REDIRECT_URI,
    });
    res.json({ link_token: response.data.link_token });
  } catch (err) {
    console.error('link_token error:', err.response?.data || err.message);
    res.status(500).json({ error: errorMessage(err) });
  }
});

app.post('/exchange_public_token', async (req, res) => {
  const { public_token, account_id } = req.body;
  if (!public_token || !account_id) {
    return res.status(400).json({ error: 'public_token and account_id are required' });
  }
  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token });
    saveItem({ accessToken: response.data.access_token, accountId: account_id });
    res.json({ ok: true });
  } catch (err) {
    console.error('exchange_public_token error:', err.response?.data || err.message);
    res.status(500).json({ error: errorMessage(err) });
  }
});

app.get('/balance', async (req, res) => {
  const item = loadItem();
  if (!item) {
    return res.status(404).json({ error: 'No bank account connected yet' });
  }
  try {
    const response = await plaidClient.accountsBalanceGet({
      access_token: item.accessToken,
      options: { account_ids: [item.accountId] },
    });
    const account = response.data.accounts.find(a => a.account_id === item.accountId);
    if (!account) {
      return res.status(404).json({ error: 'Connected account not found — it may have been closed or the connection may need to be re-linked' });
    }
    res.json({
      name: account.name,
      current: account.balances.current,
      available: account.balances.available,
      isoCurrencyCode: account.balances.iso_currency_code,
      asOf: new Date().toISOString(),
    });
  } catch (err) {
    console.error('balance error:', err.response?.data || err.message);
    res.status(500).json({ error: errorMessage(err) });
  }
});

app.post('/disconnect', (req, res) => {
  clearItem();
  res.json({ ok: true });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Mooney Plaid backend listening on 0.0.0.0:${PORT} (env: ${process.env.PLAID_ENV || 'sandbox'})`);
});
