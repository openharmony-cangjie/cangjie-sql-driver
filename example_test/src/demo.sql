CREATE TABLE `users` (
                         `id` int unsigned NOT NULL AUTO_INCREMENT,
                         `age` int DEFAULT NULL,
                         `name` varchar(255) DEFAULT NULL,
                         `coin` double DEFAULT NULL,
                         `create_at` datetime DEFAULT NULL,
                         PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;