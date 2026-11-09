CREATE TABLE IF NOT EXISTS `pr_elevator_elevator` (
  `id`              int(11)          NOT NULL AUTO_INCREMENT,
  `name`            varchar(50)      DEFAULT NULL                 COMMENT 'Nome do elevador',
  `type`            varchar(50)      NOT NULL DEFAULT 'public'    COMMENT 'Tipo de acesso legado',
  `job`             varchar(50)      DEFAULT NULL                 COMMENT 'Emprego/gang legado',
  `job_grade`       int(11)          DEFAULT 0                    COMMENT 'Nivel de cargo minimo legado',
  `password`        varchar(50)      DEFAULT NULL                 COMMENT 'Senha legada',
  `access_key`      varchar(50)      DEFAULT NULL                 COMMENT 'Chave de acesso legada',
  `citizenid`       varchar(50)      DEFAULT NULL                 COMMENT 'CitizenID legado',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `pr_elevator_floor` (
  `id`               int(11)         NOT NULL AUTO_INCREMENT     COMMENT 'ID do andar - 1 id por andar!',
  `elevator_id`      int(11)         NOT NULL                    COMMENT 'ID do elevador',
  `name`             varchar(50)     NOT NULL DEFAULT 'Andar'    COMMENT 'Nome de exibicao do andar (ex: T, S1)',
  `floor`            int(11)         DEFAULT 0                   COMMENT 'Ordem/Numero do andar',
  `distance`         float           DEFAULT 2.0                 COMMENT 'Distancia necessaria para interagir com o elevador',
  `theme_color`      varchar(50)     DEFAULT NULL                COMMENT 'Cor do tema',
  `theme_background` varchar(50)     DEFAULT NULL                COMMENT 'Cor do fundo do tema',
  `coords`           json            DEFAULT NULL                COMMENT 'Coordenadas de spawn',
  `interact_coords`  json            DEFAULT NULL                COMMENT 'Payload de interacao: vector3 legado ou prop DUI',
  `access_type`      varchar(50)     NOT NULL DEFAULT 'public'   COMMENT 'Tipo de acesso do andar',
  `access_job`       varchar(50)     DEFAULT NULL                COMMENT 'Emprego/gang do andar',
  `access_job_grade` int(11)         DEFAULT 0                   COMMENT 'Nivel minimo do emprego/gang',
  `access_password`  varchar(50)     DEFAULT NULL                COMMENT 'Senha do andar',
  `access_key`       varchar(50)     DEFAULT NULL                COMMENT 'Metadata/chave do cartao',
  `access_item`      varchar(50)     DEFAULT NULL                COMMENT 'Item de cartao exigido',
  `access_citizenid` varchar(50)     DEFAULT NULL                COMMENT 'CitizenID permitido no andar',
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_elevator_floor_elevator`
    FOREIGN KEY (`elevator_id`)
    REFERENCES `pr_elevator_elevator` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
