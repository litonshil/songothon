-- Seed Data: initial admin, members, contribution cycles, deposits, and investments
-- Default password for all seed accounts is: Password123!

INSERT INTO users (id, email, password_hash, full_name, phone, role, status)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'admin@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Jane Doe (Admin)', '+8801700000001', 'admin', 'active'),
    ('22222222-2222-2222-2222-222222222222', 'alice@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Alice Rahman', '+8801700000002', 'member', 'active'),
    ('33333333-3333-3333-3333-333333333333', 'bob@songothon.org', '$2a$10$5FsXh.ifaNunSp.aP.XCNOl4mwo/d0Jfe/2feY2qwf3F0U5GwbmkS', 'Bob Hossain', '+8801700000003', 'member', 'active')
ON CONFLICT (email) DO NOTHING;

-- Contribution Periods
INSERT INTO contribution_periods (id, title, frequency, amount_due, due_date, is_active)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'September 2026 Monthly Savings', 'monthly', 200.00, '2026-09-30', false),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'October 2026 Monthly Savings', 'monthly', 200.00, '2026-10-31', true)
ON CONFLICT (id) DO NOTHING;

-- Member Contributions
INSERT INTO contributions (id, user_id, period_id, amount, payment_method, reference_no, status, recorded_by, paid_at, notes)
VALUES
    ('c1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 200.00, 'bank_transfer', 'TXN-SEP-001', 'paid', '11111111-1111-1111-1111-111111111111', '2026-09-15 10:00:00+00', 'Sept contribution paid on time'),
    ('c2222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 200.00, 'mobile_money', 'BKASH-SEP-99', 'paid', '11111111-1111-1111-1111-111111111111', '2026-09-20 14:30:00+00', 'Paid via bKash'),
    ('c3333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 200.00, 'bank_transfer', 'TXN-OCT-002', 'paid', '11111111-1111-1111-1111-111111111111', '2026-10-05 09:15:00+00', 'October contribution received')
ON CONFLICT (id) DO NOTHING;

-- Investments
INSERT INTO investments (id, name, sector, amount_invested, current_valuation, expected_return_rate, realized_returns, status, duration, investment_date, maturity_date, notes, created_by)
VALUES
    ('d1111111-1111-1111-1111-111111111111', 'Green Agro Organic Farming Project', 'Agriculture', 5000.00, 5400.00, 12.00, 400.00, 'active', '1 Year', '2026-03-01', '2027-03-01', 'Organic greenhouse cultivation', '11111111-1111-1111-1111-111111111111'),
    ('d2222222-2222-2222-2222-222222222222', 'Urban Commercial Solar Micro-Grid', 'Clean Tech / Energy', 8000.00, 8650.00, 14.50, 650.00, 'active', '2 Years', '2026-05-15', '2028-05-15', 'Rooftop solar power purchase agreement', '11111111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO UPDATE SET duration = EXCLUDED.duration;

-- Financial Ledger / Transactions
INSERT INTO transactions (id, type, amount, flow, reference_table, reference_id, recorded_by, description)
VALUES
    ('e1111111-1111-1111-1111-111111111111', 'deposit', 200.00, 'inflow', 'contributions', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Member deposit from Alice Rahman (Sep 2026)'),
    ('e2222222-2222-2222-2222-222222222222', 'deposit', 200.00, 'inflow', 'contributions', 'c2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Member deposit from Bob Hossain (Sep 2026)'),
    ('e3333333-3333-3333-3333-333333333333', 'deposit', 200.00, 'inflow', 'contributions', 'c3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Member deposit from Alice Rahman (Oct 2026)'),
    ('e4444444-4444-4444-4444-444444444444', 'investment_dividend', 400.00, 'inflow', 'investments', 'd1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Q3 Dividend from Green Agro Organic Farming'),
    ('e5555555-5555-5555-5555-555555555555', 'investment_dividend', 650.00, 'inflow', 'investments', 'd2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Solar power generation revenue share')
ON CONFLICT (id) DO NOTHING;
