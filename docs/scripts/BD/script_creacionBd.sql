-- =========================================================
-- To-Do List App - CRUD Completo en SQL (MySQL 8+)
-- Archivo único para uso académico y técnico
-- Nota: MySQL usa '?' como placeholder en prepared statements.
-- =========================================================

-- =========================================================
-- (Opcional) Esquema base compatible con MySQL 8+
-- Si ya tienes las tablas creadas, puedes omitir esta sección.
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(200) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(80) NOT NULL,
  color VARCHAR(20) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_category_name_per_user (user_id, name),
  KEY idx_categories_user (user_id),
  CONSTRAINT fk_categories_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tasks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT NULL,
  priority ENUM('alta','media','baja') NOT NULL DEFAULT 'media',
  status   ENUM('pendiente','en_progreso','completada') NOT NULL DEFAULT 'pendiente',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_date DATE NULL,
  completed_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY idx_tasks_user_status (user_id, status),
  KEY idx_tasks_user_due (user_id, due_date),
  KEY idx_tasks_user_priority (user_id, priority),
  CONSTRAINT fk_tasks_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT fk_tasks_category
    FOREIGN KEY (category_id) REFERENCES categories(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- CRUD: USERS
-- =========================================================

-- CREATE user
INSERT INTO users (full_name, email)
VALUES (?, ?);

-- READ user by id
SELECT id, full_name, email, created_at
FROM users
WHERE id = ?;

-- READ users (list)
SELECT id, full_name, email, created_at
FROM users
ORDER BY created_at DESC
LIMIT ? OFFSET ?;

-- UPDATE user (actualiza campos opcionales)
UPDATE users
SET full_name = COALESCE(?, full_name),
    email     = COALESCE(?, email)
WHERE id = ?;

-- DELETE user
DELETE FROM users
WHERE id = ?;

-- =========================================================
-- CRUD: CATEGORIES
-- =========================================================

-- CREATE category
INSERT INTO categories (user_id, name, color)
VALUES (?, ?, ?);

-- READ category by id (asegurando pertenencia del usuario)
SELECT id, user_id, name, color, created_at
FROM categories
WHERE id = ? AND user_id = ?;

-- READ categories by user
SELECT id, user_id, name, color, created_at
FROM categories
WHERE user_id = ?
ORDER BY name ASC;

-- UPDATE category
UPDATE categories
SET name  = COALESCE(?, name),
    color = COALESCE(?, color)
WHERE id = ? AND user_id = ?;

-- DELETE category
DELETE FROM categories
WHERE id = ? AND user_id = ?;

-- =========================================================
-- CRUD: TASKS
-- =========================================================

-- CREATE task
INSERT INTO tasks (
  user_id, category_id, title, description,
  priority, status, due_date
)
VALUES (
  ?, ?, ?, ?,
  COALESCE(?, 'media'),
  COALESCE(?, 'pendiente'),
  ?
);

-- READ task by id (solo dueño)
SELECT id, user_id, category_id, title, description,
       priority, status, created_at, due_date, completed_at
FROM tasks
WHERE id = ? AND user_id = ?;

-- READ tasks with filters (solo dueño)
-- Parámetros:
-- 1 user_id
-- 2 status (NULL para ignorar)
-- 3 priority (NULL para ignorar)
-- 4 category_id (NULL para ignorar)
-- 5 due_from (NULL para ignorar)
-- 6 due_to (NULL para ignorar)
SELECT id, user_id, category_id, title, description,
       priority, status, created_at, due_date, completed_at
FROM tasks
WHERE user_id = ?
  AND (? IS NULL OR status = ?)
  AND (? IS NULL OR priority = ?)
  AND (? IS NULL OR category_id = ?)
  AND (? IS NULL OR due_date >= ?)
  AND (? IS NULL OR due_date <= ?)
ORDER BY
  FIELD(priority, 'alta','media','baja'),
  (due_date IS NULL), due_date,
  created_at DESC
LIMIT ? OFFSET ?;

-- UPDATE task
-- Nota: MySQL no permite referenciar columnas actualizadas en la misma expresión de forma idéntica a PostgreSQL.
-- Aquí se asume que envías el nuevo status como parámetro 'new_status' (puede ser NULL).
UPDATE tasks
SET
  category_id = COALESCE(?, category_id),
  title       = COALESCE(?, title),
  description = COALESCE(?, description),
  priority    = COALESCE(?, priority),
  status      = COALESCE(?, status),
  due_date    = COALESCE(?, due_date),
  completed_at =
    CASE
      WHEN COALESCE(?, status) = 'completada' AND completed_at IS NULL THEN NOW()
      WHEN COALESCE(?, status) <> 'completada' THEN NULL
      ELSE completed_at
    END
WHERE id = ? AND user_id = ?;

-- DELETE task
DELETE FROM tasks
WHERE id = ? AND user_id = ?;

-- =========================================================
-- CONSULTAS FRECUENTES (REPORTES)
-- =========================================================

-- 1) Tareas pendientes de un usuario
SELECT id, title, priority, due_date
FROM tasks
WHERE user_id = ? AND status = 'pendiente'
ORDER BY (due_date IS NULL), due_date, created_at;

-- 2) Tareas que vencen en los próximos 7 días (desde hoy)
SELECT id, user_id, title, due_date, status
FROM tasks
WHERE user_id = ?
  AND due_date IS NOT NULL
  AND due_date >= CURDATE()
  AND due_date < DATE_ADD(CURDATE(), INTERVAL 7 DAY)
ORDER BY due_date;

-- 3) Cantidad de tareas completadas por usuario
SELECT u.id, u.full_name, COUNT(t.id) AS completed_tasks
FROM users u
LEFT JOIN tasks t ON t.user_id = u.id AND t.status = 'completada'
GROUP BY u.id, u.full_name
ORDER BY completed_tasks DESC;
