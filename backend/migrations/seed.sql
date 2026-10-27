-- Multi-tenant Seed Data for Songothon
-- Default password for all seed accounts: Password123!

-- 1. Users
INSERT INTO users (id, email, password_hash, full_name, phone, status)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'admin@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Jane Doe (Admin)', '+8801700000001', 'active'),
    ('22222222-2222-2222-2222-222222222222', 'alice@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Alice Rahman', '+8801700000002', 'active'),
    ('33333333-3333-3333-3333-333333333333', 'bob@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Bob Hossain', '+8801700000003', 'active'),
    ('44444444-4444-4444-4444-444444444444', 'karim@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Karim Uddin', '+8801700000004', 'active')
ON CONFLICT (email) 
DO UPDATE SET 
    password_hash = EXCLUDED.password_hash,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    status = 'active',
    deleted_at = NULL;

-- 2. Organizations
INSERT INTO organizations (id, name, slug, currency, allow_peer_financial_visibility, created_by)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ekota Shomiti (একতা সমিতি)', 'ekota', 'BDT', true, '11111111-1111-1111-1111-111111111111')
ON CONFLICT (slug) 
DO UPDATE SET 
    allow_peer_financial_visibility = EXCLUDED.allow_peer_financial_visibility,
    deleted_at = NULL;

-- 3. Organization Members
INSERT INTO organization_members (id, org_id, user_id, role, shares_count, status)
VALUES
    ('ba111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'org_admin', 2, 'active'),
    ('ba222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'member', 3, 'active'),
    ('ba333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'member', 1, 'active'),
    ('ba444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'member', 2, 'active')
ON CONFLICT (org_id, user_id) 
DO UPDATE SET 
    role = EXCLUDED.role,
    shares_count = EXCLUDED.shares_count,
    status = 'active',
    deleted_at = NULL;

-- 4. Share Configurations (1 Share = 1,000 BDT monthly)
INSERT INTO share_configurations (id, org_id, base_price_per_share, frequency, due_day_of_period, is_active, effective_from)
VALUES
    ('ca111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1000.00, 'monthly', 10, true, '2026-01-01')
ON CONFLICT (id) DO NOTHING;

-- 5. Down Payment Schemes
INSERT INTO down_payment_schemes (id, org_id, title, amount, scheme_type, frequency, due_date, is_active)
VALUES
    ('da111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Initial Capital Reserve Call', 5000.00, 'mandatory', 'one_time', '2026-12-31', true)
ON CONFLICT (id) DO NOTHING;

-- 6. Contributions
-- Approved contributions
INSERT INTO contributions (id, org_id, user_id, type, amount, payment_method, trx_id, sender_account, target_cycle, status, reviewed_by, reviewed_at, paid_at, notes)
VALUES
    ('c1111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'share_installment', 3000.00, 'bkash', 'BKASH-SEP-2026-001', '01711223344', '2026-09', 'APPROVED', '11111111-1111-1111-1111-111111111111', '2026-09-06 12:00:00+00', '2026-09-05 10:00:00+00', 'Alice paid 3 shares for September'),
    ('c2222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'share_installment', 1000.00, 'nagad', 'NAGAD-SEP-2026-002', '01811223355', '2026-09', 'APPROVED', '11111111-1111-1111-1111-111111111111', '2026-09-07 14:00:00+00', '2026-09-06 11:30:00+00', 'Bob paid 1 share for September'),
    ('c3333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'share_installment', 2000.00, 'bank_transfer', 'EBL-TRX-881923', '10410023412', '2026-09', 'APPROVED', '11111111-1111-1111-1111-111111111111', '2026-09-05 18:00:00+00', '2026-09-05 17:00:00+00', 'Admin self-contribution'),
    ('c4444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'share_installment', 3000.00, 'bkash', 'BKASH-OCT-2026-009', '01711223344', '2026-10', 'APPROVED', '11111111-1111-1111-1111-111111111111', '2026-10-06 15:00:00+00', '2026-10-05 10:15:00+00', 'Alice paid 3 shares for October'),
-- Pending contribution in review queue
    ('c5555555-5555-5555-5555-555555555555', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'share_installment', 2000.00, 'bkash', 'BKASH99281X', '01911223366', '2026-10', 'PENDING', NULL, NULL, '2026-10-25 09:30:00+00', 'Karim submitted October dues')
ON CONFLICT (id) DO NOTHING;

-- 7. Investments
INSERT INTO investments (id, org_id, title, category, invested_capital, current_valuation, expected_roi, realized_returns, tenure, notes, status, investment_date, maturity_date, created_by)
VALUES
    ('ea111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Purbachal Commercial Land Plot 42', 'Real Estate / Land', 300000.00, 345000.00, 25.00, 0.00, '3 Years', 'Long-term freehold commercial land plot near 300ft expressway', 'ACTIVE', '2026-01-15', '2029-01-15', '11111111-1111-1111-1111-111111111111'),
    ('ea222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Dhaka Organic Dairy & Agro Project', 'Agro-Business', 50000.00, 56000.00, 18.00, 6000.00, '1 Year', 'High-yield dairy cattle and pasteurization micro-plant', 'ACTIVE', '2026-03-01', '2027-03-01', '11111111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO NOTHING;

-- 8. Ledger Transactions
INSERT INTO transactions (id, org_id, type, amount, flow, reference_table, reference_id, recorded_by, description)
VALUES
    ('fa111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'deposit', 3000.00, 'inflow', 'contributions', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Approved deposit from Alice Rahman (Sep 2026)'),
    ('fa222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'deposit', 1000.00, 'inflow', 'contributions', 'c2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Approved deposit from Bob Hossain (Sep 2026)'),
    ('fa333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'deposit', 2000.00, 'inflow', 'contributions', 'c3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Approved deposit from Jane Doe (Sep 2026)'),
    ('fa444444-4444-4444-4444-444444444444', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'deposit', 3000.00, 'inflow', 'contributions', 'c4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Approved deposit from Alice Rahman (Oct 2026)')
ON CONFLICT (id) DO NOTHING;
