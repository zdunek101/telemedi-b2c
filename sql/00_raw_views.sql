-- Widoki na surowe pliki CSV, bez czyszczenia (duplikaty zostają).
-- Ścieżki względem katalogu głównego repozytorium.

CREATE OR REPLACE VIEW raw_users           AS SELECT * FROM read_csv('data/users.csv', sample_size = -1);
CREATE OR REPLACE VIEW raw_sessions        AS SELECT * FROM read_csv('data/sessions_*.csv', sample_size = -1);
CREATE OR REPLACE VIEW raw_events          AS SELECT * FROM read_csv('data/events_*.csv', sample_size = -1);
CREATE OR REPLACE VIEW raw_orders          AS SELECT * FROM read_csv('data/orders.csv', sample_size = -1);
CREATE OR REPLACE VIEW raw_go_memberships  AS SELECT * FROM read_csv('data/go_memberships.csv', sample_size = -1);
CREATE OR REPLACE VIEW raw_marketing_spend AS SELECT * FROM read_csv('data/marketing_spend.csv', sample_size = -1);
