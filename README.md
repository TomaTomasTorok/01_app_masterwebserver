# masterwebserver

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

INSERT INTO product_data (product, master_ip, slave, sensor, sensor_type, sensor_value, workplace_id, sequence)
SELECT 'Strom' AS product, master_ip, slave, sensor, sensor_type, sensor_value, workplace_id, sequence
FROM product_data
WHERE product = 'Auto'

UNION ALL

SELECT 'Macka' AS product, master_ip, slave, sensor, sensor_type, sensor_value, workplace_id, sequence
FROM product_data
WHERE product = 'Auto'

UNION ALL

SELECT 'Pes' AS product, master_ip, slave, sensor, sensor_type, sensor_value, workplace_id, sequence
FROM product_data
WHERE product = 'Auto';
