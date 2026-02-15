#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');
const defaultSqlPath = path.join(repoRoot, 'docs', 'scripts', 'BD', 'script_creacionBd.sql');
const sqlPath = path.resolve(process.argv[2] || defaultSqlPath);
const outputDir = path.join(repoRoot, 'test');
const outputFile = path.join(outputDir, 'BD_creada.postman_collection.json');
const baseUrl = 'http://localhost:3000';

function readFileSafe(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function parseCreateTableBlocks(sql) {
  const blocks = [];
  const regex = /CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+`?([a-zA-Z0-9_]+)`?\s*\(([^;]*?)\)\s*ENGINE/gi;
  let match = null;
  while ((match = regex.exec(sql)) !== null) {
    blocks.push({ name: match[1], body: match[2] });
  }
  return blocks;
}

function parseColumns(blockBody) {
  const lines = blockBody
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean);

  const columns = [];

  for (const line of lines) {
    const upper = line.toUpperCase();
    if (
      upper.startsWith('PRIMARY KEY') ||
      upper.startsWith('UNIQUE KEY') ||
      upper.startsWith('KEY ') ||
      upper.startsWith('CONSTRAINT')
    ) {
      continue;
    }

    const colMatch = /^`?([a-zA-Z0-9_]+)`?\s+([^,]+),?$/.exec(line);
    if (!colMatch) continue;

    const name = colMatch[1];
    const def = colMatch[2];
    const defUpper = def.toUpperCase();

    const isAutoIncrement = defUpper.includes('AUTO_INCREMENT');
    const isNullable = !defUpper.includes('NOT NULL');
    const hasDefault = defUpper.includes('DEFAULT');

    columns.push({ name, def, isAutoIncrement, isNullable, hasDefault });
  }

  return columns;
}

function exampleValue(def) {
  const upper = def.toUpperCase();

  if (upper.includes('INT')) return 1;
  if (upper.includes('DECIMAL') || upper.includes('NUMERIC') || upper.includes('FLOAT') || upper.includes('DOUBLE')) return 1.5;
  if (upper.includes('DATE') && !upper.includes('DATETIME')) return '2026-02-01';
  if (upper.includes('DATETIME') || upper.includes('TIMESTAMP')) return '2026-02-01 10:00:00';
  if (upper.includes('ENUM')) {
    const enumMatch = /ENUM\(([^)]+)\)/i.exec(def);
    if (enumMatch) {
      const first = enumMatch[1].split(',')[0].trim().replace(/^'+|'+$/g, '');
      return first;
    }
    return 'value';
  }
  if (upper.includes('TEXT')) return 'text';
  if (upper.includes('CHAR') || upper.includes('VARCHAR')) return 'string';

  return 'value';
}

function buildBody(columns) {
  const body = {};
  for (const col of columns) {
    if (col.isAutoIncrement) continue;
    if (col.hasDefault && /CURRENT_TIMESTAMP/i.test(col.def)) continue;
    if (col.name === 'id') continue;

    body[col.name] = exampleValue(col.def);
  }
  return body;
}

function postmanRequest(name, method, url, body) {
  const item = {
    name,
    request: {
      method,
      header: [{ key: 'Content-Type', value: 'application/json' }],
      url: {
        raw: url,
        protocol: 'http',
        host: ['localhost'],
        port: '3000',
        path: url.replace(/^https?:\/\/[^/]+\//, '').split('/'),
      },
    },
  };

  if (body) {
    item.request.body = {
      mode: 'raw',
      raw: JSON.stringify(body, null, 2),
    };
  }

  return item;
}

function buildCollection(tables) {
  const items = tables.map(table => {
    const base = `${baseUrl}/${table.name}`;
    const body = buildBody(table.columns);

    return {
      name: table.name,
      item: [
        postmanRequest(`GET /${table.name}`, 'GET', base),
        postmanRequest(`GET /${table.name}/:id`, 'GET', `${base}/1`),
        postmanRequest(`POST /${table.name}`, 'POST', base, body),
        postmanRequest(`PUT /${table.name}/:id`, 'PUT', `${base}/1`, body),
        postmanRequest(`DELETE /${table.name}/:id`, 'DELETE', `${base}/1`),
      ],
    };
  });

  return {
    info: {
      name: 'BD creada API',
      description: 'Coleccion generada automaticamente para probar endpoints CRUD por tabla.',
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    },
    variable: [{ key: 'baseUrl', value: baseUrl }],
    item: items,
  };
}

function main() {
  if (!fs.existsSync(sqlPath)) {
    console.error(`SQL file not found: ${sqlPath}`);
    process.exit(1);
  }

  const sql = readFileSafe(sqlPath);
  const blocks = parseCreateTableBlocks(sql);
  if (blocks.length === 0) {
    console.error('No CREATE TABLE statements found.');
    process.exit(1);
  }

  const tables = blocks.map(block => ({
    name: block.name,
    columns: parseColumns(block.body),
  }));

  const collection = buildCollection(tables);

  ensureDir(outputDir);
  fs.writeFileSync(outputFile, JSON.stringify(collection, null, 2), 'utf8');
  console.log(`Postman collection generated: ${outputFile}`);
}

main();
