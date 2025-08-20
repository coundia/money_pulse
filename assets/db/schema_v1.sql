PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS  account (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  balance INTEGER DEFAULT 0,
  balance_prev INTEGER DEFAULT 0,
  balance_blocked INTEGER DEFAULT 0,

balance_init   INTEGER DEFAULT 0,
balance_goal   INTEGER DEFAULT 0,
balance_limit  INTEGER DEFAULT 0,

dateStartAccount TEXT,
dateEndAccount   TEXT,

typeAccount TEXT,

  code TEXT,
  description TEXT,
  status TEXT,
  currency TEXT,
  isDefault INTEGER DEFAULT 0,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE INDEX idx_account_code ON account(code);
CREATE INDEX idx_account_dirty ON account(isDirty);
CREATE INDEX idx_account_deleted ON account(deletedAt);

CREATE TABLE IF NOT EXISTS  category (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT,
  description TEXT,
  typeEntry TEXT DEFAULT 'DEBIT' CHECK(typeEntry IN ('DEBIT','CREDIT')),
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE INDEX idx_category_code ON category(code);
CREATE INDEX idx_category_dirty ON category(isDirty);
CREATE INDEX idx_category_deleted ON category(deletedAt);

CREATE TABLE IF NOT EXISTS  transaction_entry (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT,
  description TEXT,
  amount INTEGER DEFAULT 0,
  typeEntry TEXT DEFAULT 'DEBIT',
  dateTransaction TEXT,
  status TEXT,
  entityName TEXT,
  entityId TEXT,
  accountId TEXT,
  categoryId TEXT,
  companyId TEXT,    
  customerId TEXT,     
  debtId TEXT,     
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE INDEX idx_txn_date ON transaction_entry(dateTransaction);
CREATE INDEX idx_txn_account ON transaction_entry(accountId);
CREATE INDEX idx_txn_category ON transaction_entry(categoryId);
CREATE INDEX IF NOT EXISTS idx_txn_company ON transaction_entry(companyId);   
CREATE INDEX IF NOT EXISTS idx_txn_customer ON transaction_entry(customerId);  
CREATE INDEX idx_txn_dirty ON transaction_entry(isDirty);
CREATE INDEX idx_txn_deleted ON transaction_entry(deletedAt);
 
CREATE TABLE  IF NOT EXISTS change_log (
  id TEXT PRIMARY KEY,
  entityTable TEXT NOT NULL,
  entityId TEXT NOT NULL,
  operation TEXT,
  payload TEXT,
  status TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  createdAt TEXT DEFAULT (datetime('now')) NOT NULL,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL,
  processedAt TEXT,
  UNIQUE(entityTable, entityId, status)
);

CREATE INDEX idx_changelog_status ON change_log(status);
CREATE INDEX idx_changelog_entity ON change_log(entityTable, entityId);
 

CREATE TABLE IF NOT EXISTS  sync_state (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entityTable TEXT NOT NULL UNIQUE,
  lastSyncAt TEXT,
  lastCursor TEXT,
  updatedAt TEXT DEFAULT (datetime('now')) NOT NULL
);
  

CREATE TABLE IF NOT EXISTS unit (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT NOT NULL,
  name TEXT,
  description TEXT,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_unit_code_active ON unit(code) WHERE deletedAt IS NULL;
CREATE INDEX IF NOT EXISTS idx_unit_dirty ON unit(isDirty);
CREATE INDEX IF NOT EXISTS idx_unit_deleted ON unit(deletedAt);
 

CREATE TABLE IF NOT EXISTS product (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT,                   
  name TEXT,                  
  description TEXT,
  barcode TEXT,              
  unitId TEXT,                
  categoryId TEXT,           
  defaultPrice   INTEGER DEFAULT 0,   -- prix de vente (cents)
  statuses TEXT ,
  purchasePrice  INTEGER DEFAULT 0,   -- prix d'achat (cents)
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
 
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_product_code_active ON product(code) WHERE deletedAt IS NULL;
CREATE INDEX IF NOT EXISTS idx_product_barcode ON product(barcode);
CREATE INDEX IF NOT EXISTS idx_product_unit ON product(unitId);
CREATE INDEX IF NOT EXISTS idx_product_category ON product(categoryId);
CREATE INDEX IF NOT EXISTS idx_product_dirty ON product(isDirty);
CREATE INDEX IF NOT EXISTS idx_product_deleted ON product(deletedAt);

 
CREATE TABLE IF NOT EXISTS transaction_item (
  id TEXT PRIMARY KEY,
  transactionId TEXT NOT NULL,   
  productId TEXT,                
  label TEXT,                     
  quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity >= 0),    
  unitId TEXT,                   
  unitPrice INTEGER NOT NULL DEFAULT 0 CHECK(unitPrice >= 0),  
  total INTEGER NOT NULL DEFAULT 0 CHECK(total >= 0),       
  notes TEXT,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_item_txn ON transaction_item(transactionId);
CREATE INDEX IF NOT EXISTS idx_item_product ON transaction_item(productId);
CREATE INDEX IF NOT EXISTS idx_item_unit ON transaction_item(unitId);
CREATE INDEX IF NOT EXISTS idx_item_dirty ON transaction_item(isDirty);
CREATE INDEX IF NOT EXISTS idx_item_deleted ON transaction_item(deletedAt);
  

-- =========================
-- COMPANY
-- =========================
CREATE TABLE IF NOT EXISTS company (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT NOT NULL,
  name TEXT ,
  description TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  taxId TEXT,                     
  currency TEXT,                 
  addressLine1 TEXT,
  addressLine2 TEXT,
  city TEXT,
  region TEXT,
  country TEXT,
  postalCode TEXT,
  isDefault INTEGER DEFAULT 0,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_company_code_active
  ON company(code) WHERE deletedAt IS NULL;

CREATE INDEX IF NOT EXISTS idx_company_name ON company(name);
CREATE INDEX IF NOT EXISTS idx_company_phone ON company(phone);
CREATE INDEX IF NOT EXISTS idx_company_email ON company(email);
CREATE INDEX IF NOT EXISTS idx_company_deleted ON company(deletedAt);
CREATE INDEX IF NOT EXISTS idx_company_dirty ON company(isDirty);

-- =========================
-- CUSTOMER
-- =========================
CREATE TABLE IF NOT EXISTS customer (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT,                      
  firstName TEXT,
  lastName TEXT,
  fullName TEXT,
  balance INTEGER DEFAULT 0,
  balanceDebt INTEGER DEFAULT 0,                 
  phone TEXT,
  email TEXT,
  notes TEXT,
  status TEXT,                   
  companyId TEXT,                 
  addressLine1 TEXT,
  addressLine2 TEXT,
  city TEXT,
  region TEXT,
  country TEXT,
  postalCode TEXT,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_code_active
  ON customer(code) WHERE deletedAt IS NULL;

CREATE  INDEX IF NOT EXISTS uq_customer_email_active
  ON customer(email) WHERE email IS NOT NULL AND deletedAt IS NULL;

CREATE  INDEX IF NOT EXISTS uq_customer_phone_active
  ON customer(phone) WHERE phone IS NOT NULL AND deletedAt IS NULL;

-- Index de recherche usuels
CREATE INDEX IF NOT EXISTS idx_customer_fullname ON customer(fullName);
CREATE INDEX IF NOT EXISTS idx_customer_company ON customer(companyId);
CREATE INDEX IF NOT EXISTS idx_customer_deleted ON customer(deletedAt);
CREATE INDEX IF NOT EXISTS idx_customer_dirty ON customer(isDirty);


CREATE TABLE stock_level
(
    createdAt        TEXT DEFAULT (datetime('now')) ,
    updatedAt        TEXT DEFAULT (datetime('now')) ,
    stockOnHand      INTEGER                        ,
    stockAllocated   INTEGER                        ,
    id               INTEGER                         PRIMARY KEY AUTOINCREMENT,
    productVariantId TEXT                        
        REFERENCES product(id) ON DELETE CASCADE,
    companyId        TEXT                           
        REFERENCES company(id) ON DELETE CASCADE
);
 
CREATE  INDEX IF NOT EXISTS IDX_stocklevel_prod_company
    ON stock_level (productVariantId, companyId);

CREATE INDEX IF NOT EXISTS IDX_stocklevel_company
    ON stock_level (companyId);

CREATE INDEX IF NOT EXISTS IDX_stocklevel_product
    ON stock_level (productVariantId);


CREATE TABLE IF NOT EXISTS stock_movement (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  type_stock_movement TEXT ,
  quantity          INTEGER  ,
  companyId         TEXT  ,
  productVariantId  TEXT ,
  orderLineId       TEXT,
  discriminator     TEXT,
  createdAt         TEXT DEFAULT (datetime('now')),
  updatedAt         TEXT DEFAULT (datetime('now'))

);

CREATE INDEX IF NOT EXISTS IDX_stockmove_company   ON stock_movement(companyId);
CREATE INDEX IF NOT EXISTS IDX_stockmove_product   ON stock_movement(productVariantId);
CREATE INDEX IF NOT EXISTS IDX_stockmove_orderline ON stock_movement(orderLineId);
CREATE INDEX IF NOT EXISTS IDX_stockmove_type      ON stock_movement(type_stock_movement);
CREATE INDEX IF NOT EXISTS IDX_stockmove_created   ON stock_movement(createdAt);

CREATE TABLE IF NOT EXISTS debt (
  id TEXT PRIMARY KEY,
  remoteId TEXT,
  code TEXT,
  notes TEXT,
  balance INTEGER DEFAULT 0,
  balanceDebt INTEGER DEFAULT 0,
  dueDate TEXT,
  statuses TEXT ,
  customerId TEXT,
  createdAt TEXT DEFAULT (datetime('now')),
  updatedAt TEXT DEFAULT (datetime('now')),
  deletedAt TEXT,
  syncAt TEXT,
  version INTEGER DEFAULT 0,
  isDirty INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS uq_debt_code_active ON debt(code) WHERE deletedAt IS NULL;
  