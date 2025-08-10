
PRAGMA foreign_keys = ON;

CREATE TABLE account (
  id TEXT PRIMARY KEY,
  remoteId TEXT UNIQUE,
  balance INTEGER DEFAULT 0,
  balance_prev INTEGER DEFAULT 0,
  balance_blocked INTEGER DEFAULT 0,
  code TEXT,
  description TEXT,
  status TEXT,
  currency TEXT,
  isDefault INTEGER DEFAULT 0 NOT NULL,
  createdAt TEXT DEFAULT (datetime('now')) NOT NULL,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL,
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0 NOT NULL,
  isDirty INTEGER DEFAULT 1 NOT NULL
);

CREATE UNIQUE INDEX uq_account_code_active ON account(code) WHERE deletedAt IS NULL;
CREATE INDEX idx_account_dirty ON account(isDirty);
CREATE INDEX idx_account_deleted ON account(deletedAt);

CREATE TABLE category (
  id TEXT PRIMARY KEY,
  remoteId TEXT UNIQUE,
  code TEXT,
  description TEXT,
  createdAt TEXT DEFAULT (datetime('now')) NOT NULL,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL,
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0 NOT NULL,
  isDirty INTEGER DEFAULT 1 NOT NULL
);

CREATE UNIQUE INDEX uq_category_code_active ON category(code) WHERE deletedAt IS NULL;
CREATE INDEX idx_category_dirty ON category(isDirty);
CREATE INDEX idx_category_deleted ON category(deletedAt);

CREATE TABLE transaction_entry (
  id TEXT PRIMARY KEY,
  remoteId TEXT UNIQUE,
  code TEXT,
  description TEXT,
  amount INTEGER DEFAULT 0 NOT NULL CHECK(amount >= 0),
  typeEntry TEXT DEFAULT 'DEBIT' NOT NULL CHECK(typeEntry IN ('DEBIT','CREDIT')),
  dateTransaction TEXT NOT NULL,
  status TEXT,
  entityName TEXT,
  entityId TEXT,
  accountId TEXT NOT NULL REFERENCES account(id) ON DELETE RESTRICT,
  categoryId TEXT REFERENCES category(id) ON DELETE SET NULL,
  createdAt TEXT DEFAULT (datetime('now')) NOT NULL,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL,
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0 NOT NULL,
  isDirty INTEGER DEFAULT 1 NOT NULL
);

CREATE INDEX idx_txn_date ON transaction_entry(dateTransaction);
CREATE INDEX idx_txn_account ON transaction_entry(accountId);
CREATE INDEX idx_txn_category ON transaction_entry(categoryId);
CREATE INDEX idx_txn_dirty ON transaction_entry(isDirty);
CREATE INDEX idx_txn_deleted ON transaction_entry(deletedAt);

CREATE TABLE change_log (
  id TEXT PRIMARY KEY,
  entityTable TEXT NOT NULL,
  entityId TEXT NOT NULL,
  operation TEXT NOT NULL CHECK(operation IN ('INSERT','UPDATE','DELETE')),
  payload TEXT,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SENT','ACK','FAILED')),
  attempts INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  createdAt TEXT DEFAULT (datetime('now')) NOT NULL,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL,
  processedAt TEXT,
  UNIQUE(entityTable, entityId, status)
);

CREATE INDEX idx_changelog_status ON change_log(status);
CREATE INDEX idx_changelog_entity ON change_log(entityTable, entityId);

CREATE TABLE sync_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entityTable TEXT NOT NULL UNIQUE,
  lastSyncAt TEXT,
  lastCursor TEXT,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL
);
 