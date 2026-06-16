CREATE TABLE IF NOT EXISTS `pr_elevator_elevator` (
  `id`              int(11)          NOT NULL AUTO_INCREMENT,
  `name`            varchar(50)      DEFAULT NULL                 COMMENT 'Nome do elevador',
  `job`             json             DEFAULT NULL                 COMMENT 'Json com as informacoes do emprego',
  `access_key`      varchar(50)      DEFAULT NULL                 COMMENT 'Chave de acesso',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `pr_elevator_floor` (
  `id`              int(11)          NOT NULL AUTO_INCREMENT     COMMENT 'ID do andar - 1 id por andar!',
  `elevator_id`     int(11)          NOT NULL                    COMMENT 'ID do elevador',
  `floor`           int(11)          DEFAULT 0                   COMMENT 'Numero do andar',
  `distance`        float            DEFAULT 2.0                 COMMENT 'Distância necessária para interagir com o elevador',
  `theme_color`     varchar(50)      DEFAULT NULL                COMMENT 'Cor do tema',
  `theme_background`varchar(50)      DEFAULT NULL                COMMENT 'Cor do fundo do tema',
  `coords`          json             DEFAULT NULL                COMMENT 'Coordenadas do andar',
  `interact_coords` json             DEFAULT NULL                COMMENT 'Payload de interacao: vector3 legado ou prop DUI',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_elevator_floor_elevator`
    FOREIGN KEY (`elevator_id`)
    REFERENCES `pr_elevator_elevator` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

