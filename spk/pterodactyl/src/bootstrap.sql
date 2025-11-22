CREATE DATABASE IF NOT EXISTS `pterodactyl` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS `pterodactyl`@'%' IDENTIFIED BY 'changeMeNow!';
GRANT ALL PRIVILEGES ON `pterodactyl`.* TO `pterodactyl`@'%';
FLUSH PRIVILEGES;
