-- CMPE 341 REAL ESTATE PROPERTY MANAGEMENT SYSTEM - DATABASE INITIALIZATION
-- Schema, sample data and queries match the project report (Chapter 5).

DROP TABLE IF EXISTS Payment, Lease_agreement, Property, Owner_contact, Agent_contact,
    Tenant_contact, Tenant, Agent, Owner, Users CASCADE;

-- Web application login accounts (not part of the report's data model).
-- Passwords are bcrypt hashes: admin / admin123, agent1 / agent123, agent2 / agent123
CREATE TABLE Users (
    user_id       SERIAL PRIMARY KEY,
    username      VARCHAR(50)  UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('admin', 'agent')),
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO Users (username, password_hash, role) VALUES
('admin',  '$2b$12$2lbieECIWtUio8.RJ3YOz.I25JFKx7TbYNn3uIzFs0rJL3H9vDvzq', 'admin'),
('agent1', '$2b$12$sOnSHFMTjfZUaopjny2A7uYtbZoFcIhf3eF0MVXx9xDqlzxSkU6yi', 'agent'),
('agent2', '$2b$12$EnpEyowDzuyCUCj7VOEdzu2U4MXVV7jiYenSP3dPIH99VBcyIQQMG', 'agent');

-- ===== TABLES (Report Listing 5.1) =====
-- 1. OWNER TABLE
CREATE TABLE Owner (
    O_id        SERIAL PRIMARY KEY,
    Fname       VARCHAR(50)  NOT NULL,
    L_name      VARCHAR(50)  NOT NULL,
    O_address   VARCHAR(200) NOT NULL,
    Phone       VARCHAR(20)  NOT NULL,
    email       VARCHAR(100) NOT NULL
);

-- 2. AGENT TABLE
CREATE TABLE Agent (
    Agent_id    SERIAL PRIMARY KEY,
    Fname       VARCHAR(50)  NOT NULL,
    L_name      VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL,
    Phone       VARCHAR(20)  NOT NULL,
    Rate        NUMERIC(5,2) NOT NULL CHECK (Rate >= 0 AND Rate <= 100)
);

-- 3. TENANT TABLE
CREATE TABLE Tenant (
    Tenant_id   SERIAL PRIMARY KEY,
    Fname       VARCHAR(50)  NOT NULL,
    L_name      VARCHAR(50)  NOT NULL,
    Phone       VARCHAR(20)  NOT NULL,
    email       VARCHAR(100) NOT NULL,
    Job_status  VARCHAR(50)  NOT NULL
);

-- 4. PROPERTY TABLE
CREATE TABLE Property (
    Property_id      SERIAL PRIMARY KEY,
    Status           VARCHAR(20)   NOT NULL CHECK (Status IN ('Available', 'Rented', 'Sold')),
    Property_address VARCHAR(200)  NOT NULL,
    City             VARCHAR(60)   NOT NULL,
    Postal_code      VARCHAR(15)   NOT NULL,
    Property_type    VARCHAR(40)   NOT NULL CHECK (Property_type IN ('Apartment', 'Villa', 'Office', 'Commercial')),
    Rent_amount      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (Rent_amount >= 0),
    Sale_amount      NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (Sale_amount >= 0),
    Agent_id         INT           NOT NULL,
    O_id             INT           NOT NULL,
    CONSTRAINT fk_property_agent FOREIGN KEY (Agent_id)
        REFERENCES Agent(Agent_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_property_owner FOREIGN KEY (O_id)
        REFERENCES Owner(O_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 5. LEASE_AGREEMENT TABLE
CREATE TABLE Lease_agreement (
    Lease_id    SERIAL PRIMARY KEY,
    Contract_type VARCHAR(10) NOT NULL CHECK (Contract_type IN ('Rent', 'Sale')),
    Amount      NUMERIC(14,2) NOT NULL CHECK (Amount >= 0),
    Start_date  DATE          NOT NULL,
    Deposit     NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (Deposit >= 0),
    End_date    DATE          NOT NULL,
    Rent_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (Rent_amount >= 0),
    Property_id INT           NOT NULL,
    Tenant_id   INT           NOT NULL,
    CONSTRAINT chk_contract_terms CHECK (
        (Contract_type = 'Rent' AND End_date > Start_date
         AND Rent_amount > 0 AND Amount > 0)
        OR
        (Contract_type = 'Sale' AND End_date >= Start_date
         AND Rent_amount = 0 AND Deposit = 0 AND Amount > 0)
    ),
    CONSTRAINT fk_contract_property FOREIGN KEY (Property_id)
        REFERENCES Property(Property_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_contract_tenant FOREIGN KEY (Tenant_id)
        REFERENCES Tenant(Tenant_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- 6. PAYMENT TABLE
CREATE TABLE Payment (
    Payment_id     SERIAL PRIMARY KEY,
    Payment_date   DATE          NOT NULL,
    Payment_method VARCHAR(30)   NOT NULL CHECK (Payment_method IN ('Bank Transfer', 'Credit Card', 'Cash')),
    Payment_amount NUMERIC(14,2) NOT NULL CHECK (Payment_amount > 0),
    Payment_type   VARCHAR(30)   NOT NULL CHECK (Payment_type IN ('Monthly Rent', 'Deposit', 'Sale Settlement')),
    Lease_id       INT           NOT NULL,
    CONSTRAINT fk_payment_contract FOREIGN KEY (Lease_id)
        REFERENCES Lease_agreement(Lease_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Additional contact details; Phone and email above hold the primary contacts.
CREATE TABLE Owner_contact (
    O_id INT NOT NULL REFERENCES Owner(O_id) ON DELETE CASCADE,
    Contact_type VARCHAR(10) NOT NULL CHECK (Contact_type IN ('Phone', 'Email')),
    Contact_value VARCHAR(100) NOT NULL,
    PRIMARY KEY (O_id, Contact_type, Contact_value)
);
CREATE TABLE Agent_contact (
    Agent_id INT NOT NULL REFERENCES Agent(Agent_id) ON DELETE CASCADE,
    Contact_type VARCHAR(10) NOT NULL CHECK (Contact_type IN ('Phone', 'Email')),
    Contact_value VARCHAR(100) NOT NULL,
    PRIMARY KEY (Agent_id, Contact_type, Contact_value)
);
CREATE TABLE Tenant_contact (
    Tenant_id INT NOT NULL REFERENCES Tenant(Tenant_id) ON DELETE CASCADE,
    Contact_type VARCHAR(10) NOT NULL CHECK (Contact_type IN ('Phone', 'Email')),
    Contact_value VARCHAR(100) NOT NULL,
    PRIMARY KEY (Tenant_id, Contact_type, Contact_value)
);

-- ===== SAMPLE DATA (Report Listing 5.2) =====
-- Insert Owners
INSERT INTO Owner (Fname, L_name, O_address, Phone, email) VALUES
('Mehmet', 'Yilmaz', 'Cankaya Mah. Ataturk Bulv. No:42, Ankara', '+905550000011', 'mehmet.yilmaz@example.com'),
('Ayse', 'Kaya', 'Bagdat Cad. No:118 Kadikoy, Istanbul', '+905550000012', 'ayse.kaya@example.com'),
('Can', 'Demir', 'Alsancak Mah. Kordon Boyu No:15, Izmir', '+905550000013', 'can.demir@example.com'),
('Zeynep', 'Aydin', 'Yasamkent Mah. 3250. Cad. No:9, Ankara', '+905550000014', 'zeynep.aydin@example.com');

-- Insert Agents
INSERT INTO Agent (Fname, L_name, email, Phone, Rate) VALUES
('Kerem', 'Ozturk', 'kerem.ozturk@example.com', '+905550000021', 3.50),
('Selin', 'Arslan', 'selin.arslan@example.com', '+905550000022', 4.00),
('Burak', 'Sahin', 'burak.sahin@example.com', '+905550000023', 3.00),
('Elif', 'Celik', 'elif.celik@example.com', '+905550000024', 4.50);

-- Insert Tenants
INSERT INTO Tenant (Fname, L_name, Phone, email, Job_status) VALUES
('Emre', 'Koc', '+905550000031', 'emre.koc@example.com', 'Software Engineer'),
('Deniz', 'Yildiz', '+905550000032', 'deniz.yildiz@example.com', 'Medical Doctor'),
('Mert', 'Aksoy', '+905550000033', 'mert.aksoy@example.com', 'Financial Analyst'),
('Ece', 'Gunes', '+905550000034', 'ece.gunes@example.com', 'Academic Researcher');

-- Insert Properties
INSERT INTO Property (Status, Property_address, City, Postal_code, Property_type, Rent_amount, Sale_amount, Agent_id, O_id) VALUES
('Rented', 'Yasamkent Mah. 3222. Sok. No:14/8', 'Ankara', '06810', 'Apartment', 28000.00, 6500000.00, 1, 1),
('Rented', 'Moda Cad. Deniz Apt. No:24/5', 'Istanbul', '34710', 'Apartment', 42000.00, 11200000.00, 2, 2),
('Available', 'Cankaya Tunali Hilmi Cad. No:88/3', 'Ankara', '06680', 'Office', 55000.00, 14500000.00, 1, 4),
('Sold', 'Cesme Marina Villalari No:7', 'Izmir', '35930', 'Villa', 0.00, 24000000.00, 4, 3);

-- Insert Contracts
INSERT INTO Lease_agreement (Contract_type, Amount, Start_date, Deposit, End_date, Rent_amount, Property_id, Tenant_id) VALUES
('Rent', 336000.00, '2026-01-01', 56000.00, '2026-12-31', 28000.00, 1, 1),
('Rent', 504000.00, '2026-02-01', 84000.00, '2027-01-31', 42000.00, 2, 2),
('Sale', 24000000.00, '2026-03-15', 0.00, '2026-04-15', 0.00, 4, 3),
('Rent', 168000.00, '2025-01-01', 28000.00, '2025-12-31', 14000.00, 1, 4);

-- Insert Payments
INSERT INTO Payment (Payment_date, Payment_method, Payment_amount, Payment_type, Lease_id) VALUES
('2026-01-01', 'Bank Transfer', 56000.00, 'Deposit', 1),
('2026-01-05', 'Bank Transfer', 28000.00, 'Monthly Rent', 1),
('2026-02-05', 'Credit Card', 28000.00, 'Monthly Rent', 1),
('2026-02-01', 'Bank Transfer', 42000.00, 'Monthly Rent', 2),
('2026-03-15', 'Bank Transfer', 24000000.00, 'Sale Settlement', 3);

-- Additional owner contacts
INSERT INTO Owner_contact (O_id, Contact_type, Contact_value) VALUES
(1, 'Phone', '+905550000051'),
(2, 'Phone', '+905550000052'),
(3, 'Email', 'owner3.additional@example.com');

-- Additional agent contacts
INSERT INTO Agent_contact (Agent_id, Contact_type, Contact_value) VALUES
(1, 'Phone', '+905550000071'),
(2, 'Phone', '+905550000072'),
(3, 'Email', 'agent3.additional@example.com');

-- Additional tenant contacts
INSERT INTO Tenant_contact (Tenant_id, Contact_type, Contact_value) VALUES
(1, 'Phone', '+905550000061'),
(2, 'Phone', '+905550000062'),
(3, 'Email', 'tenant3.additional@example.com');

-- ===== REPORT QUERIES (Listings 5.3-5.5) =====
-- QUERY 1 (JOIN)
SELECT
    l.Lease_id,
    p.City,
    t.Fname || ' ' || t.L_name AS Tenant_Name,
    a.Fname || ' ' || a.L_name AS Managing_Agent,
    l.Rent_amount AS Monthly_Rent
FROM Lease_agreement l
INNER JOIN Property p ON l.Property_id = p.Property_id
INNER JOIN Tenant t   ON l.Tenant_id   = t.Tenant_id
INNER JOIN Agent a    ON p.Agent_id    = a.Agent_id
WHERE p.Status = 'Rented'
  AND l.Contract_type = 'Rent'
  AND DATE '2026-11-16' BETWEEN l.Start_date AND l.End_date;

-- QUERY 2 (GROUP BY & ORDER BY)
SELECT
    Payment_method,
    Payment_type,
    COUNT(Payment_id) AS Transaction_Count,
    SUM(Payment_amount) AS Total_Collected_TRY
FROM Payment
GROUP BY Payment_method, Payment_type
ORDER BY Total_Collected_TRY DESC;

-- QUERY 3 (SUBQUERY)
SELECT
    t.Tenant_id,
    t.Fname,
    t.L_name,
    t.Job_status,
    l.Rent_amount
FROM Tenant t
INNER JOIN Lease_agreement l ON t.Tenant_id = l.Tenant_id
WHERE l.Contract_type = 'Rent'
  AND l.Rent_amount > (
    SELECT AVG(Rent_amount)
    FROM Lease_agreement
    WHERE Contract_type = 'Rent' AND Rent_amount > 0
);

